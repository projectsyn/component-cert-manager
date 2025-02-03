local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local legacy = import 'lib/legacy.libsonnet';
// The hiera parameters for the component
local inv = kap.inventory();
local params = inv.parameters.cert_manager;

// Define exports below
{
  overrides: params.overrides.cert_manager + com.makeMergeable(
    if std.objectHas(params, 'helm_values') then params.helm_values else {},
  ),
  recursiveNameservers: if std.objectHas(params, 'dns01-recursive-nameservers') then std.get(params, 'dns01-recursive-nameservers') else params.config.cert_manager.recursiveNameservers,
  httpProxy: if std.objectHas(params, 'http_proxy') then params.http_proxy else params.config.common.httpProxy,
  httpsProxy: if std.objectHas(params, 'https_proxy') then params.https_proxy else params.config.common.httpsProxy,
  noProxy: if std.objectHas(params, 'no_proxy') then params.no_proxy else params.config.common.noProxy,
}
