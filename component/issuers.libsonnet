// main template for certificates
local legacy = import 'legacy.libsonnet';
local cert = import 'lib/cert-manager.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.cert_manager;
local acmeClients = params.acmeClients + legacy.acmeClient;

// namespacedName decodes a namespaced name into a namespace and name
local namespacedName(string) = {
  local namespaced = std.splitLimit(string, '/', 1),
  namespace: if std.length(namespaced) > 1 then namespaced[0] else params.namespace,
  name: if std.length(namespaced) > 1 then namespaced[1] else namespaced[0],
};

// Let's Encrypt convenience
local isLetsEncrypt(string) = std.any([
  std.startsWith(string, prefix)
  for prefix in [ 'letsencrypt-staging', 'letsencrypt-production' ]
]);
local letsEncryptServer(string) = if std.startsWith(string, 'letsencrypt-staging') then 'https://acme-staging-v02.api.letsencrypt.org/directory'
else if std.startsWith(string, 'letsencrypt-production') then 'https://acme-v02.api.letsencrypt.org/directory'
else '';

// Merge letsencrypt acme config if named letsencrypt
local patchLetsEncrypt(name) = {
  [if isLetsEncrypt(name) then 'spec']: {
    acme: {
      email: legacy.email,
      privateKeySecretRef: {
        name: name,
      },
      server: letsEncryptServer(name),
    },
  },
};

// Merge solvers if solverRefs are defined
local patchSolverRefs(obj) = {
  [if std.objectHas(obj, 'solverRefs') then 'spec']: {
    acme: {
      solvers: [
        params.solvers[solver]
        for solver in obj.solverRefs
        if std.length(params.solvers[solver]) > 0
      ],
    },
  },
};

// Merge solvers if acmeClientRefs are defined
local patchAcmeClientRefs(obj) = {
  [if std.objectHas(obj, 'acmeClientRefs') then 'spec']: {
    acme: {
      solvers: [
        {
          dns01: {
            acmeDNS: {
              accountSecretRef: {
                key: 'acmedns.json',
                name: '%s-client' % client,
              },
              host: acmeClients[client].api.endpoint,
            },
          },
          [if std.objectHas(acmeClients[client], 'fqdns') then 'selector']: {
            dnsNames: [
              fqdn
              for fqdn in acmeClients[client].fqdns
            ],
          },
        }
        for client in obj.acmeClientRefs
        if std.length(acmeClients[client]) > 0
      ],
    },
  },
};

// Merge keys metadata and spec if they exist
local patchSpec(obj) = {
  [key]: obj[key]
  for key in std.objectFields(obj)
  if std.member([ 'metadata', 'spec' ], key)
};

// Consecutively apply patches to result of previous apply.
local process(obj, initManifest) = std.prune(std.foldl(
  function(manifest, patch) manifest + com.makeMergeable(patch),
  [
    patchLetsEncrypt(initManifest.metadata.name),
    patchAcmeClientRefs(obj),
    patchSolverRefs(obj),
    patchSpec(obj),
  ],
  initManifest
));

local clusterIssuers = [
  process(params.cluster_issuers[name], cert.clusterIssuer(name))
  for name in std.objectFields(params.cluster_issuers)
  if params.cluster_issuers[name] != null && std.length(params.cluster_issuers[name]) > 0
];

local issuers = [
  process(
    params.issuers[name],
    cert.issuer(namespacedName(name).name) {
      metadata+: {
        namespace: namespacedName(name).namespace,
      },
    }
  )
  for name in std.objectFields(params.issuers)
  if params.issuers[name] != null && std.length(params.issuers[name]) > 0
];

// Define outputs below
{
  [if std.length(clusterIssuers) > 0 then '60_clusterissuer']: clusterIssuers,
  [if std.length(issuers) > 0 then '60_issuer']: issuers,
}
