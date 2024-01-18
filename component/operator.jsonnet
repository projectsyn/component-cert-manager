local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local operatorlib = import 'lib/openshift4-operators.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.cert_manager;

local isOpenshift = std.startsWith(inv.parameters.facts.distribution, 'openshift');
assert isOpenshift : 'olm install_method only available on Openshift';

local operator_group = operatorlib.OperatorGroup('syn-cert-manager') {
  metadata+: {
    labels+: {
      'app.kubernetes.io/managed-by': 'commodore',
    },
    namespace: params.namespace,
  },
  spec: {
    targetNamespaces: [
      params.namespace,
    ],
  },
};

local subscriptions = operatorlib.namespacedSubscription(
  params.namespace,
  'openshift-cert-manager-operator',
  params.olm.channel,
  'redhat-operators'
) {
  labels+: {
    'app.kubernetes.io/managed-by': 'commodore',
  },
  spec+: {
    config+: {
      resources: params.olm.resources,
    },
  },
};


{
  '00_operator_group': operator_group,
  '10_subscriptions': subscriptions,
}
