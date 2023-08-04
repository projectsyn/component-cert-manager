local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cert_manager;

local namespace = kube.Namespace(params.namespace);

{
  '00_namespace': namespace,
}
