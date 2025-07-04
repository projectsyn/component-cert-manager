#!/bin/sh

set -e

readonly force_register="${1}"
readonly client_creds_file="${CONFIG_PATH}/acmedns.json"

reg_auth_args=
if [ -n "${REG_USERNAME}" ]; then
  reg_auth_args="-u${REG_USERNAME}:${REG_PASSWORD}"
fi


if ! [ -f "${client_creds_file}" ] \
  || [ -n "${force_register}" ]; then

  reg=$(curl -XPOST "${reg_auth_args}" "${ACME_DNS_API}/register")
  # Create acme-dns-client secret for provided domain names.
  # Required format for acmedns.json in `stringData`:
  # {
  #   "example.com": { registration output },
  #   "example.org": { registration output }
  # }
  # We create a partial secret here since we use server-side apply
  client_secret=$(jq -n \
    --argjson reg "${reg}" \
    --argjson fqdns "${ACME_DNS_FQDNS}" \
    --arg client_secret_name "${CLIENT_SECRET_NAME}" \
    --arg namespace "${NAMESPACE}" \
    '{
      "apiVersion": "v1",
      "kind": "Secret",
      "metadata": {
        "name": $client_secret_name,
        "namespace": $namespace,
      },
      "stringData": {
        "acmedns.json": (reduce $fqdns[] as $d ({}; . + { ($d): $reg })) | tojson
      }
    }')

  echo "${client_secret}" >"${HOME}/secret.json"
  # Use `kubectl apply --server-side=true` as the empty secret is created by
  # ArgoCD with server-side apply.
  kubectl apply --server-side=true -f "${HOME}/secret.json"
else
  echo "Client credentials config '${client_creds_file}' already exists."
fi
