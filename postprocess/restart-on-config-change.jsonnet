local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';

// The hiera parameters for the component
local params = com.inventory().parameters.cert_manager;

local config = std.get(params.helmValues.cert_manager, 'config', {});
local config_hash = std.md5(std.manifestJsonMinified(config));

local deploy_file = std.extVar('output_path') + '/deployment.yaml';
local deployment = com.yaml_load_all(deploy_file);

local patched_deployment =
  assert std.length(deployment) == 1 : 'Expected one manifest in deployment.yaml';

  deployment[0] {
    spec+: {
      template+: {
        metadata+: {
          annotations+: {
            'cert-manager.syn.tools/config-hash': config_hash,
          },
        },
      },
    },
  };

{
  [if std.length(config) > 0 then 'deployment']:
    patched_deployment,
}
