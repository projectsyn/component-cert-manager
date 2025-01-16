local cm = import 'lib/cert-manager.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cert_manager;

local letsencrypt_email = inv.parameters.cert_manager.letsencrypt_email;

local letsencrypt_staging =
  cm.clusterIssuer('letsencrypt-staging') {
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
  metadata+: {
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

local secrets = [
  kube.Secret(s) {
    metadata+: {
      namespace: params.namespace,
    },
  } + com.makeMergeable(params.secrets[s])
  for s in std.objectFields(params.secrets)
];

local issuers = com.generateResources(params.issuers, cm.issuer);
local clusterIssuers = com.generateResources(params.cluster_issuers, cm.clusterIssuer);

local acmedns = import 'acme-dns.libsonnet';

{
  '00_clusterissuer': std.filter(
    function(it) it != null,
    [
      if params.letsencrypt_clusterissuers.staging then letsencrypt_staging,
      if params.letsencrypt_clusterissuers.production then letsencrypt_production,
    ] + clusterIssuers
  ),
  '05_issuer': issuers,
  [if std.length(secrets) > 0 then '10_solver_secrets']:
    secrets,
  [if std.objectHas(acmedns, 'manifests') then '20_acme_dns']:
    acmedns.manifests,
}
