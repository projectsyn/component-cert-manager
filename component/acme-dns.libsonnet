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
  metadata+: {
    annotations: {
      'argocd.argoproj.io/sync-wave': '10',
    },
    namespace: params.namespace,
  },
};

local role = kube.Role('acme-dns-secret-editor') {
  metadata+: {
    annotations: {
      'argocd.argoproj.io/sync-wave': '10',
    },
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
  metadata+: {
    annotations: {
      'argocd.argoproj.io/sync-wave': '10',
    },
    namespace: params.namespace,
  },
  subjects_: [ serviceAccount ],
  roleRef_: role,
};

local configMap = kube.ConfigMap('acme-dns-scripts') {
  metadata+: {
    annotations: {
      'argocd.argoproj.io/sync-wave': '10',
    },
    namespace: params.namespace,
  },
  data: {
    'register.sh': importstr 'scripts/acme-register.sh',
    'check.sh': importstr 'scripts/acme-check.sh',
  },
};

// Acme DNS Client

local hasRegistrationSecret(name) = std.objectHas(acmeClients[name].api, 'username');
local registrationSecret(name) = kube.Secret('acme-dns-%s-register' % name) {
  metadata+: {
    annotations: {
      'argocd.argoproj.io/sync-wave': '10',
    },
    namespace: params.namespace,
  },
  stringData: {
    REG_USERNAME: acmeClients[name].api.username,
    REG_PASSWORD: acmeClients[name].api.password,
  },
};

local clientSecret(name) = kube.Secret('acme-dns-%s-client' % name) {
  metadata+: {
    annotations: {
      'argocd.argoproj.io/sync-wave': '10',
    },
    namespace: params.namespace,
  },
};

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
        CONFIG_PATH: '/etc/acme-dns',
        SCRIPTS_PATH: '/scripts',
        CLIENT_SECRET_NAME: clientSecret(name).metadata.name,
        ACME_DNS_API: acmeClients[name].api.endpoint,
        ACME_DNS_FQDNS: '%s' % [ acmeClients[name].fqdns ],
        HTTP_PROXY: params.components.cert_manager.httpProxy,
        HTTPS_PROXY: params.components.cert_manager.httpsProxy,
        NO_PROXY: params.components.cert_manager.noProxy,
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
          mountPath: '/etc/acme-dns',
          readOnly: true,
        },
        home: {
          mountPath: '/home/acme-dns',
        },
        scripts: {
          mountPath: '/scripts',
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

local jobRegister(name) = kube.Job('acme-dns-%s-register' % name) {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/sync-wave': '10',
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
  local random = std.foldl(function(x, y) x + y, std.encodeUTF8(std.md5(name)), 0) % 120,

  hour: random / 60,
  minute: random % 60,
};

local cronJobCheck(name) = kube.CronJob('acme-dns-%s-check' % name) {
  metadata+: {
    annotations: {
      'argocd.argoproj.io/sync-wave': '10',
    },
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
  if std.length(acmeClients) > 0
};

// Define outputs below
if hasAcmeClients then
  {
    '50_acme_dns': [
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
