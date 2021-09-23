/**
 * \file cert-manager.libsonnet
 * \brief Helpers to create CertManager CRs.
 *        API reference: https://cert-manager.io/docs/reference/api-docs/
 */

local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters;

local groupVersion =
  if
    std.objectHas(params, 'cert_manager') &&
    std.startsWith(params.cert_manager.charts['cert-manager'], 'v0')
  then
    // legacy variant: use v1alpha2 for v0.x chart versions
    'cert-manager.io/v1alpha2'
  else
    // default to v1
    'cert-manager.io/v1';

/**
  * \brief Helper to create Certificate objects.
  *
  * \arg The name of the Certificate.
  * \return A Certificate object.
  */
local cert(name) = kube._Object(groupVersion, 'Certificate', name);

/**
  * \brief Helper to create Issuer objects.
  *
  * \arg The name of the Issuer.
  * \return An Issuer object.
  */
local issuer(name) = kube._Object(groupVersion, 'Issuer', name);

/**
  * \brief Helper to create ClusterIssuer objects.
  *
  * \arg The name of the ClusterIssuer.
  * \return A ClusterIssuer object.
  */
local clusterIssuer(name) = kube._Object(groupVersion, 'ClusterIssuer', name);

{
  cert: cert,
  issuer: issuer,
  clusterIssuer: clusterIssuer,
}
