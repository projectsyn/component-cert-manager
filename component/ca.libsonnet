local cm = import 'lib/cert-manager.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cert_manager;

local ca_name = params.ca.name;

local selfsigned_issuer =
  cm.issuer('%s-selfsigned' % ca_name) {
    spec: {
      selfSigned: {},
    },
  };

local cacert =
  local name = '%s-cacert' % ca_name;
  cm.cert(name) {
    spec: {
      isCA: true,
      commonName: ca_name,
      secretName: name,
      privateKey: {
        algorithm: 'ECDSA',
        size: 256,
      },
      issuerRef: {
        name: selfsigned_issuer.metadata.name,
      },
    },
  };

local ca_issuer =
  cm.clusterIssuer(ca_name) {
    spec: {
      ca: {
        secretName: cacert.metadata.name,
      },
    },
  };

{
  selfsigned_issuer: selfsigned_issuer,
  cacert: cacert,
  clusterissuer: ca_issuer,
}
