// main template for certificates
local legacy = import 'legacy.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.cert_manager;

// Check if there are any acme clients defined
local acmeClients = params.acmeClients + legacy.acmeClient;
local hasAcmeClients = std.length(acmeClients) > 0;

// Common

local serviceAccount = kube.ServiceAccount('acme-dns') {
  metadata: {
    labels: {
      name: 'acme-dns',
    },
    name: 'acme-dns',
    namespace: params.namespace,
  },
};

local role = kube.Role('acme-dns-secret-editor') {
  metadata: {
    labels: {
      name: 'acme-dns-secret-editor',
    },
    name: 'acme-dns-secret-editor',
    namespace: params.namespace,
  },
  rules: [
    {
      apiGroups: [ '' ],
      resources: [ 'secrets' ],
      verbs: [ 'create', 'patch', 'get' ],
    },
  ],
};

local roleBinding = kube.RoleBinding('acme-dns-secret-editor') {
  metadata: {
    labels: {
      name: 'acme-dns-secret-editor',
    },
    name: 'acme-dns-secret-editor',
    namespace: params.namespace,
  },
  subjects_: [ serviceAccount ],
  roleRef_: role,
};

local configMap = kube.ConfigMap('acme-dns-scripts') {
  metadata: {
    labels: {
      name: 'acme-dns-scripts',
    },
    name: 'acme-dns-scripts',
    namespace: params.namespace,
  },
  data: {
    'register.sh': importstr 'scripts/acme-register.sh',
    'check.sh': importstr 'scripts/acme-check.sh',
  },
};

// Acme DNS Client

local hasRegistrationSecret(name) = std.objectHas(acmeClients[name].api, 'username');
local registrationSecret(name) = kube.Secret('%s-register' % name) {
  metadata: {
    labels: {
      name: '%s-register' % name,
    },
    name: '%s-register' % name,
    namespace: params.namespace,
  },
  stringData: {
    REG_USERNAME: acmeClients[name].api.username,
    REG_PASSWORD: acmeClients[name].api.password,
  },
  data:: {},
};

local clientSecret(name) = kube.Secret('%s-client' % name) {
  metadata: {
    labels: {
      name: '%s-client' % name,
    },
    name: '%s-client' % name,
    namespace: params.namespace,
  },
  data:: {},
};

local mountpaths = {
  acmednsjson: '/etc/acme-dns',
  scripts: '/scripts',
};
local fqdnStripWildcard(fqdns) = [
  // Strips the first 2 characters `*.` from the string if it starts with `*.`
  if std.startsWith(fqdn, '*.') then std.substr(fqdn, 2, std.length(fqdn)) else fqdn
  for fqdn in fqdns
];
local podSpec(name, jobname, script) = {
  assert !(std.length(acmeClients[name].fqdns) > 2) : 'Max 2 FQDNs supported for acme client',

  containers_+: {
    c: kube.Container(jobname) {
      image: '%(registry)s/%(repository)s:%(tag)s' % params.images.kubectl,
      workingDir: '/home/acme-dns',
      command: [ '/scripts/%s' % script ],
      env_: {
        HOME: '/home/acme-dns',
        NAMESPACE: {
          fieldRef: {
            fieldPath: 'metadata.namespace',
          },
        },
        // Script config parameters
        CONFIG_PATH: mountpaths.acmednsjson,
        SCRIPTS_PATH: mountpaths.scripts,
        CLIENT_SECRET_NAME: clientSecret(name).metadata.name,
        ACME_DNS_API: acmeClients[name].api.endpoint,
        ACME_DNS_FQDNS: '%s' % [ fqdnStripWildcard(acmeClients[name].fqdns) ],
        HTTP_PROXY: legacy.httpProxy,
        HTTPS_PROXY: legacy.httpsProxy,
        NO_PROXY: legacy.noProxy,
      },
      envFrom: std.prune([
        if hasRegistrationSecret(name) then {
          secretRef: {
            name: registrationSecret(name).metadata.name,
          },
        },
      ]),
      volumeMounts_: {
        acmedns_client_secret: {
          mountPath: mountpaths.acmednsjson,
          readOnly: true,
        },
        home: {
          mountPath: '/home/acme-dns',
        },
        scripts: {
          mountPath: mountpaths.scripts,
        },
      },
    },
  },
  serviceAccountName: serviceAccount.metadata.name,
  volumes_: {
    acmedns_client_secret: {
      secret: {
        secretName: clientSecret(name).metadata.name,
      },
    },
    home: {
      emptyDir: {},
    },
    scripts: {
      configMap: {
        // We need mode 0770 for the scripts, so they work correctly on OCP
        // 4.11 where the configmap contents are owned by root:<pod-GID>.
        defaultMode: std.parseOctal('770'),
        name: configMap.metadata.name,
      },
    },
  },
};

local jobRegister(name) = kube.Job('%s-register' % name) {
  metadata+: {
    annotations+: {
      // Make registration job an ArgoCD hook.
      // Updating plain Jobs is basically impossible, so we run the
      // registration job as an ArgoCD hook and ensure it gets deleted when
      // it succeeds. The registration script should always be a no-op when
      // acme-dns credentials already exist for in the secret.
      'argocd.argoproj.io/hook': 'Sync',
      'argocd.argoproj.io/hook-delete-policy': 'HookSucceeded',
    },
    namespace: params.namespace,
  },
  spec+: {
    template+: {
      spec+: podSpec(name, 'register-client', 'register.sh'),
    },
  },
};

local schedule(name) = {
  local scope = '%(tenant)s/%(name)s' % inv.parameters.cluster,
  local random = std.foldl(function(x, y) x + y, std.encodeUTF8(std.md5(scope + name)), 0) % 120,

  hour: random / 60,
  minute: random % 60,
};

local cronJobCheck(name) = kube.CronJob('%s-check' % name) {
  metadata: {
    labels: {
      name: '%s-check' % name,
    },
    name: '%s-check' % name,
    namespace: params.namespace,
  },
  spec+: {
    jobTemplate+: {
      spec+: {
        template+: {
          spec+: podSpec(name, 'check-client', 'check.sh'),
        },
      },
    },
    schedule: '%(minute)d %(hour)d * * *' % schedule(name),
  },
};

// Generate manifests
local acmeClientManifests = {
  [name]: [
    registrationSecret(name),
    clientSecret(name),
    jobRegister(name),
    cronJobCheck(name),
  ]
  for name in std.objectFields(acmeClients)
  if acmeClients[name] != null && std.length(acmeClients[name]) > 0
};

// Define outputs below
if hasAcmeClients then
  {
    '50_acme_dns_common': [
      serviceAccount,
      role,
      roleBinding,
      configMap,
    ],
  } + {
    ['50_acme_dns_' + name]: acmeClientManifests[name]
    for name in std.objectFields(acmeClientManifests)
  }
else {}
