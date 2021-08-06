local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.cert_manager;

local crds = [
  'certificaterequests.cert-manager.io',
  'certificates.cert-manager.io',
  'challenges.acme.cert-manager.io',
  'clusterissuers.cert-manager.io',
  'issuers.cert-manager.io',
  'orders.acme.cert-manager.io',
];

local name = 'cert-manager-crd-upgrade';

local addSyncWave = function(object) object {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/sync-wave': '-10',
    },
  },
};

local upgradeScript = importstr './upgrade/patch-crds.sh';

local role = kube.ClusterRole(name) {
  rules: [
    {
      apiGroups: [ 'apiextensions.k8s.io' ],
      resources: [ 'customresourcedefinitions' ],
      verbs: [ 'get', 'patch' ],
    },
  ],
};

local serviceAccount = kube.ServiceAccount(name) {
  metadata+: { namespace: params.namespace },
};

local roleBinding = kube.ClusterRoleBinding(name) {
  subjects_: [ serviceAccount ],
  roleRef_: role,
};

local job = kube.Job(name) {
  metadata+: {
    namespace: params.namespace,
    annotations+: {
      'argocd.argoproj.io/hook': 'Sync',
      'argocd.argoproj.io/hook-delete-policy': 'HookSucceeded',
    },
  },
  spec+: {
    template+: {
      spec+: {
        serviceAccountName: serviceAccount.metadata.name,
        containers_+: {
          patch_crds: kube.Container(name) {
            image: '%s/%s:%s' % [ params.images.kubectl.registry, params.images.kubectl.image, params.images.kubectl.tag ],
            workingDir: '/export',
            command: [ 'sh' ],
            args: [ '-eu', '-c', upgradeScript ],
            env: [
              { name: 'CRDS_TO_PATCH', value: std.join(' ', crds) },
              { name: 'HOME', value: '/export' },
            ],
            volumeMounts: [
              { name: 'export', mountPath: '/export' },
            ],
          },
        },
        volumes+: [
          { name: 'export', emptyDir: {} },
        ],
      },
    },
  },
};

{
  '00_upgrade': [
    addSyncWave(role),
    addSyncWave(serviceAccount),
    addSyncWave(roleBinding),
    addSyncWave(job),
  ],
}
