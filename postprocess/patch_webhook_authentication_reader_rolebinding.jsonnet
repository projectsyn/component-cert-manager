local com = import 'lib/commodore.libjsonnet';
local target = std.extVar('target');
local component = std.extVar('component');
local output_path = std.extVar('output_path');

local manifests = com.yaml_load_all("compiled/" + target + "/" + output_path + "webhook-rbac.yaml");

// The webhook-authentication-reader role MUST exist in namespace
// "kube-system". This is messed up by the helm_namespace postprocessing and
// restored here.
local patch(manifest) =
  if manifest.metadata.name == "cert-manager-webhook:webhook-authentication-reader" then
    manifest {
      metadata+: {
        namespace: "kube-system"
      }
    }
  else
    manifest;

local patched_manifests = [
  patch(m) for m in manifests
];

{
  "webhook-rbac": patched_manifests
}
