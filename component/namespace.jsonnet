local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prom = import 'lib/prometheus.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.cert_manager;

local namespace = kube.Namespace(params.namespace) {
  metadata+: {
    labels+: {
      'openshift.io/cluster-monitoring': 'true',
    },
  },
};

{
  '00_namespace':
    if std.member(inv.applications, 'prometheus') then
      prom.RegisterNamespace(namespace)
    else
      namespace,
}
