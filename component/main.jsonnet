// main template for certificates
local cert = import 'lib/cert-manager.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prom = import 'lib/prometheus.libsonnet';

local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.cert_manager;
local isOpenshift = std.member([ 'openshift4', 'oke' ], inv.parameters.facts.distribution);
local hasPrometheus = std.member(inv.applications, 'prometheus');

// Namespaces
local namespace = kube.Namespace(params.namespace) {
  metadata+: {
    annotations: {
      'argocd.argoproj.io/sync-wave': '-10',
    },
    labels+: {
      'app.kubernetes.io/name': params.namespace,
      // Configure the namespaces so that the OCP4 cluster-monitoring
      // Prometheus can find the servicemonitors and rules.
      [if isOpenshift then 'openshift.io/cluster-monitoring']: 'true',
    },
  },
};

// Exoscale webhook secret
local exoscaleSecret = kube.Secret('exoscale-secret') {
  metadata: {
    name: 'exoscale-secret',
    namespace: params.namespace,
  },
  stringData: {
    EXOSCALE_API_KEY: params.components.exoscale_webhook.accessKey,
    EXOSCALE_API_SECRET: params.components.exoscale_webhook.secretKey,
  },
  data:: {},
};

local secrets = com.generateResources(
  params.secrets,
  function(s) std.prune(kube.Secret(s) {
    metadata+: {
      namespace: params.namespace,
    },
  })
);

local namespacedName(name) = {
  local namespaced = std.splitLimit(name, '/', 1),
  namespace: if std.length(namespaced) > 1 then namespaced[0] else params.namespace,
  name: if std.length(namespaced) > 1 then namespaced[1] else namespaced[0],
};

local certificates = com.generateResources(
  params.certificates,
  function(c)
    local nsn = namespacedName(c);
    cert.cert(nsn.name) {
      metadata+: {
        namespace: nsn.namespace,
      },
    }
);

local alertlabels = {
  syn: 'true',
  syn_component: 'cert-manager',
};

local alerts = function(name, groupName, alerts)
  com.namespaced(params.namespace, kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', name) {
    metadata+: {
      annotations:: {},
    },
    spec+: {
      groups+: [
        {
          name: groupName,
          rules:
            std.sort(std.filterMap(
              function(field) alerts[field].enabled == true,
              function(field) alerts[field].rule {
                alert: field,
                labels+: alertlabels,
              },
              std.objectFields(alerts)
            ), function(x) x.alert),
        },
      ],
    },
  });

{
  '00_namespace': if hasPrometheus then prom.RegisterNamespace(namespace) else namespace,
  [if std.length(secrets) > 0 then '10_solver_secrets']:
    secrets,
  [if params.components.exoscale_webhook.enabled then '90_secrets_exoscale']: exoscaleSecret,
  [if std.length(certificates) > 0 then '93_certificates']:
    certificates,
  [if std.length(params.alerts) > 0 then '99_alerts']:
    alerts('cert-manager', 'cert-manager-custom.alerts', params.alerts),
}
+ (import 'acme-dns.libsonnet')
+ (import 'issuers.libsonnet')
