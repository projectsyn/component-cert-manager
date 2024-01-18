local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prom = import 'lib/prometheus.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.cert_manager;

local isOpenshift = std.startsWith(inv.parameters.facts.distribution, 'openshift');

local namespace = kube.Namespace(params.namespace);

{
  '00_namespace':
    if std.member(inv.applications, 'prometheus') then
      prom.RegisterNamespace(namespace)
    else if isOpenshift then
      namespace {
        metadata+: {
          annotations+: {
            'openshift.io/node-selector': 'infra',
          },
          labels+: {
            'openshift.io/cluster-monitoring': 'true',
          },
        },
      }
    else
      namespace,
}
