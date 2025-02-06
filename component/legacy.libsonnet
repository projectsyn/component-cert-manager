local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local legacy = import 'lib/legacy.libsonnet';
// The hiera parameters for the component
local inv = kap.inventory();
local params = inv.parameters.cert_manager;

// Define exports below
{
  helmValues: params.helmValues.cert_manager + com.makeMergeable(
    if std.objectHas(params, 'helm_values') then std.trace('Parameter `helm_values` is deprecated, please use `helmValues.cert_manager`.', params.helm_values) else {},
  ),
  recursiveNameservers: if std.objectHas(params, 'dns01-recursive-nameservers') then std.trace('Parameter `recursiveNameservers` is deprecated, please use `components.cert_manager.recursiveNameservers`.', std.get(params, 'dns01-recursive-nameservers')) else params.components.cert_manager.recursiveNameservers,
  httpProxy: if std.objectHas(params, 'http_proxy') then std.trace('Parameter `http_proxy` is deprecated, please use `components.cert_manager.httpProxy`.', params.http_proxy) else params.components.cert_manager.httpProxy,
  httpsProxy: if std.objectHas(params, 'https_proxy') then std.trace('Parameter `https_proxy` is deprecated, please use `components.cert_manager.httpsProxy`.', params.https_proxy) else params.components.cert_manager.httpsProxy,
  noProxy: if std.objectHas(params, 'no_proxy') then std.trace('Parameter `no_proxy` is deprecated, please use `components.cert_manager.noProxy`.', params.no_proxy) else params.components.cert_manager.noProxy,

  acmeClient: if std.objectHas(params, 'acme_dns_api') then std.trace('Parameter `acme_dns_api` is deprecated, please use `acmeClients`.', {
    'acme-dns': {
      api: {
        endpoint: params.acme_dns_api.endpoint,
        username: params.acme_dns_api.username,
        password: params.acme_dns_api.password,
      },
      fqdns: params.acme_dns_api.fqdns,
    },
  }) else {},
}
