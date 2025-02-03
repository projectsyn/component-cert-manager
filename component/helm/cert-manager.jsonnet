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
  extraEnv: [
    {
      name: 'HTTP_PROXY',
      value: legacy.httpProxy,
    },
    {
      name: 'HTTPS_PROXY',
      value: legacy.httpsProxy,
    },
    {
      name: 'NO_PROXY',
      value: legacy.noProxy,
    },
  ],
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
  dns01RecursiveNameservers: legacy.recursiveNameservers,
  dns01RecursiveNameserversOnly: params.config.cert_manager.recursiveNameserversOnly,
  enableCertificateOwnerRef: params.config.cert_manager.certificateOwnerRef,
  image: {
    registry: params.images.cert_manager.registry,
    repository: params.images.cert_manager.repository,
    tag: params.images.cert_manager.tag,
  },
  resources: params.resources.cert_manager,
  webhook: {
    image: {
      registry: params.images.cert_webhook.registry,
      repository: params.images.cert_webhook.repository,
      tag: params.images.cert_webhook.tag,
    },
    resources: params.resources.cert_webhook,
  },
  cainjector: {
    image: {
      registry: params.images.cert_cainjector.registry,
      repository: params.images.cert_cainjector.repository,
      tag: params.images.cert_cainjector.tag,
    },
    resources: params.resources.cert_cainjector,
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
  'values-overrides': params.overrides,
}
