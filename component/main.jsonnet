// main template for certificates
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

{
  '00_namespace': if hasPrometheus then prom.RegisterNamespace(namespace) else namespace,
}
