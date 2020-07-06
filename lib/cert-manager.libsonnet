/**
 * \file cert-manager.libsonnet
 * \brief Helpers to create CertManager CRs.
 *        API reference: https://cert-manager.io/docs/reference/api-docs/
 */

local kube = import 'lib/kube.libjsonnet';

local groupVersion = 'cert-manager.io/v1alpha2';

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
