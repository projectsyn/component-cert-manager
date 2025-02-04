local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';

// The hiera parameters for the component
local params = com.inventory().parameters.cert_manager;

local crds_file = std.extVar('output_path') + '/crds.yaml';
local crds = com.yaml_load_all(crds_file);

{
  crds: [
    c {
      metadata+: {
        annotations: {
          'argocd.argoproj.io/sync-options': 'Prune=false',
          'argocd.argoproj.io/sync-wave': '-10',
        },
        labels: {
          app: 'cert-manager',
          'app.kubernetes.io/component': 'crds',
          'app.kubernetes.io/name': 'cert-manager',
        },
      },
    }
    for c in crds
  ],
}
