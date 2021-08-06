local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.cert_manager;

local letsencrypt_email = inv.parameters.cert_manager.letsencrypt_email;

local letsencrypt_staging = {
  apiVersion: 'cert-manager.io/v1alpha2',
  kind: 'ClusterIssuer',
  metadata: {
    name: 'letsencrypt-staging',
  },
  spec: {
    acme: {
      email: letsencrypt_email,
      server: 'https://acme-staging-v02.api.letsencrypt.org/directory',
      privateKeySecretRef: {
        name: 'letsencrypt-staging',
      },
      solvers: std.prune([
        params.solvers[s]
        for s in std.objectFields(params.solvers)
      ]),
    },
  },
};

local letsencrypt_production = letsencrypt_staging {
  metadata: {
    name: 'letsencrypt-production',
  },
  spec+: {
    acme+: {
      server: 'https://acme-v02.api.letsencrypt.org/directory',
      privateKeySecretRef: {
        name: 'letsencrypt-production',
      },
    },
  },
};

{
  '00_clusterissuer': [
    letsencrypt_staging,
    letsencrypt_production,
  ],
}
