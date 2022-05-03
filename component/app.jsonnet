local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.cert_manager;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('cert-manager', params.namespace) {
  spec+: {
    ignoreDifferences: [
      {
        kind: 'Secret',
        name: 'acme-dns-client',
        namespace: params.namespace,
        jsonPointers: [
          '/data',
        ],
      },
      {
        group: 'admissionregistration.k8s.io',
        kind: 'ValidatingWebhookConfiguration',
        name: 'cert-manager-webhook',
        jqPathExpressions: [
          '.webhooks[].namespaceSelector.matchExpressions[] | select(.key == "control-plane")',
        ],
      },
    ],
  },
};

{
  'cert-manager': app,
}
