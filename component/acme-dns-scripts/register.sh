#!/bin/sh

set -e

readonly force_register="${1}"

if ! [ -f /etc/scripts/acmedns.json ] \
  || [ -n "${force_register}" ]; then

  reg=$(curl -XPOST -u "${REG_USERNAME}:${REG_PASSWORD}" \
    "${ACME_DNS_API}/register")
  # Create acme-dns-client secret for provided domain names.
  # Required format for acmedns.json in `stringData`:
  # {
  #   "example.com": { registration output },
  #   "example.org": { registration output }
  # }
  client_secret=$(jq -n \
    --argjson reg "${reg}" \
    --argjson domains "${ACME_DNS_DOMAINS}" \
    --arg client_secret_name "${CLIENT_SECRET_NAME}" \
    --arg namespace "${NAMESPACE}" \
    '{
      "apiVersion": "v1",
      "kind": "Secret",
      "type": "Opaque",
      "metadata": {
        "name": $client_secret_name,
        "namespace": $namespace,
      },
      "stringData": {
        "acmedns.json": (reduce $domains[] as $d ({}; . + { ($d): $reg })) | tojson
      }
    }')

  echo "${client_secret}" >"${HOME}/secret.yaml"
  # Use kubectl apply as the empty secret is created by ArgoCD
  kubectl apply -f "${HOME}/secret.yaml"
fi
