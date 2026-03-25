local com = import 'lib/commodore.libjsonnet';

local crd_files = [
  'crd-acme.cert-manager.io_challenges',
  'crd-acme.cert-manager.io_orders',
  'crd-cert-manager.io_certificaterequests',
  'crd-cert-manager.io_certificates',
  'crd-cert-manager.io_clusterissuers',
  'crd-cert-manager.io_issuers',
];

local crds = [
  {
    name: crd_file,
    content: com.yaml_load_all(std.extVar('output_path') + '/' + crd_file + '.yaml'),
  }
  for crd_file in crd_files
];

{
  [crd.name]: crd.content[0] {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/sync-options': 'Prune=false',
        'argocd.argoproj.io/sync-wave': '-10',
      },
    },
  }
  for crd in crds
}
