local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cert_manager;

local acme_dns_api = params.acme_dns_api;

local has_registration_secret = std.objectHas(acme_dns_api, 'username');
local registrationSecret =
  if has_registration_secret then
    kube.Secret('acme-dns-register') {
      metadata+: {
        namespace: params.namespace,
      },
      stringData: {
        REG_USERNAME: acme_dns_api.username,
        REG_PASSWORD: acme_dns_api.password,
      },
    };

local jobnames = {
  registration: 'register-acme-dns-client',
  check: 'check-acme-dns-client',
};
local clientSecret =
  kube.Secret('acme-dns-client') {
    metadata+: {
      annotations+: {
        'cert-manager.syn.tools/managed-by':
          'The contents of this secret are managed by resources Job/%s and CronJob/%s' % [
            jobnames.registration,
            jobnames.check,
          ],
      },
      namespace: params.namespace,
    },
  };

local mountpaths = {
  acmednsjson: '/etc/acme-dns',
  scripts: '/scripts',
};
local scriptConfigmap =
  kube.ConfigMap('register-acme-dns-client') {
    metadata+: {
      namespace: params.namespace,
    },
    data: {
      'register.sh': importstr 'acme-dns-scripts/register.sh',
      'check.sh': importstr 'acme-dns-scripts/check.sh',
    },
  };

local scriptServiceAccount = kube.ServiceAccount('acme-dns') {
  metadata+: {
    namespace: params.namespace,
  },
};

local scriptRole = kube.Role('acme-dns-secret-editor') {
  metadata+: {
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

local scriptRoleBinding = kube.RoleBinding('acme-dns-secret-editor') {
  subjects_: [ scriptServiceAccount ],
  roleRef_: scriptRole,
};

local scriptPodSpec(name, script) = {
  containers_+: {
    c: kube.Container(name) {
      image: '%s/%s:%s' % [
        params.images.kubectl.registry,
        params.images.kubectl.image,
        params.images.kubectl.tag,
      ],
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
        CLIENT_SECRET_NAME: clientSecret.metadata.name,
        ACME_DNS_API: acme_dns_api.endpoint,
        ACME_DNS_FQDNS: '%s' % [ acme_dns_api.fqdns ],
      },
      envFrom: std.prune([
        if has_registration_secret then {
          secretRef: {
            name: registrationSecret.metadata.name,
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
  serviceAccountName: scriptServiceAccount.metadata.name,
  volumes_: {
    acmedns_client_secret: {
      secret: {
        secretName: clientSecret.metadata.name,
      },
    },
    home: {
      emptyDir: {},
    },
    scripts: {
      configMap: {
        // 0700
        defaultMode: 448,
        name: scriptConfigmap.metadata.name,
      },
    },
  },
};

local registrationJob =
  kube.Job(jobnames.registration) {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      template+: {
        spec+: scriptPodSpec('register-client', 'register.sh'),
      },
    },
  };

// Generate randomize cronjob schedule between midnight and 2am
local scope = '%(tenant)s/%(name)s' % inv.parameters.cluster;
local totalminute = std.foldl(
  function(x, y) x + y, std.encodeUTF8(std.md5(scope)), 0
) % 120;
local hour = totalminute / 60;
local minute = totalminute % 60;

local clientcheckCronjob =
  kube.CronJob(jobnames.check) {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      jobTemplate+: {
        spec+: {
          template+: {
            spec+: scriptPodSpec('check-client', 'check.sh'),
          },
        },
      },
      schedule: '%d %d * * *' % [ minute, hour ],
    },
  };

if std.objectHas(acme_dns_api, 'endpoint') then
  {
    manifests: std.filter(
      function(it) it != null,
      [
        scriptServiceAccount,
        scriptRole,
        scriptRoleBinding,
        scriptConfigmap,
        registrationSecret,
        clientSecret,
        registrationJob,
        clientcheckCronjob,
      ]
    ),
  }
else
  {}
