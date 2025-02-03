local legacy = import '../legacy.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
// The hiera parameters for the component
local inv = kap.inventory();
local params = inv.parameters.cert_manager;

local component = {
  global: {
    leaderElection: {
      namespace: params.namespace,
    },
    priorityClassName: 'system-cluster-critical',
  },
  crds: {
    enabled: true,
    keep: true,
  },
  prometheus: {
    enabled: true,
    servicemonitor: {
      enabled: true,
    },
  },
  image: {
    registry: params.images.cert_manager.registry,
    repository: params.images.cert_manager.repository,
    tag: params.images.cert_manager.tag,
  },
  webhook: {
    image: {
      registry: params.images.cert_webhook.registry,
      repository: params.images.cert_webhook.repository,
      tag: params.images.cert_webhook.tag,
    },
  },
  cainjector: {
    image: {
      registry: params.images.cert_cainjector.registry,
      repository: params.images.cert_cainjector.repository,
      tag: params.images.cert_cainjector.tag,
    },
  },
  acmesolver: {
    image: {
      registry: params.images.cert_acmesolver.registry,
      repository: params.images.cert_acmesolver.repository,
      tag: params.images.cert_acmesolver.tag,
    },
  },
  startupapicheck: {
    image: {
      registry: params.images.cert_startupapi.registry,
      repository: params.images.cert_startupapi.repository,
      tag: params.images.cert_startupapi.tag,
    },
  },
};

// Define outputs below
{
  'values-component': component,
  'values-overrides': params.helm_values,
}
