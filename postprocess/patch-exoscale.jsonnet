local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';

// The hiera parameters for the component
local params = com.inventory().parameters.cert_manager;

local pki_file = std.extVar('output_path') + '/pki.yaml';
local pki_obj = com.yaml_load_all(pki_file);

local deploy_file = std.extVar('output_path') + '/deployment.yaml';
local deploy_obj = com.yaml_load(deploy_file);

{
  pki: [
    if obj.kind == 'Certificate' then obj {
      spec+: {
        duration: '%s0m0s' % obj.spec.duration,
      },
    } else obj
    for obj in pki_obj
  ],
  deployment: deploy_obj {
    spec+: {
      template+: {
        spec+: {
          priorityClassName: 'system-cluster-critical',
          containers: [
            super.containers[0] {
              args+: [
                '--secure-port=8443',
              ],
              ports: [
                super.ports[0] {
                  containerPort: 8443,
                },
              ],
            },
          ],
        },
      },
    },
  },
}
