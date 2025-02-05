local kap = import 'lib/kapitan.libjsonnet';

// The hiera parameters for the component
local inv = kap.inventory();
local params = inv.parameters.cert_manager;

local component = {
  image: {
    repository: '%(registry)s/%(repository)s' % params.images.exoscale_webhook,
    tag: std.stripChars(params.images.exoscale_webhook.tag, 'v'),
  },
  resources: params.resources.exoscale_webhook,
  secret: {
    accessKey: params.components.exoscale_webhook.accessKey,
    secretKey: params.components.exoscale_webhook.secretKey,
  },
};

// Define outputs below
{
  'values-component': component,
  'values-overrides': params.helmValues.exoscale_webhook,
}
