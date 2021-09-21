#!/bin/sh

set -e

# Extract acme-dns client config from mounted secret file with `jq` and inject
# as variables into the script environment with `eval`.
username=
password=
subdomain=
acmedns_config=$(jq -r --argjson domains "${ACME_DNS_DOMAINS}" '
    .[$domains[0]]
    | "username=\(.username) password=\(.password) subdomain=\(.subdomain)"
  ' "${CONFIG_PATH}/acmedns.json")
# This overrides the empty variables declared above
eval "${acmedns_config}"

reregister=
if ! curl \
  -H"X-Api-User: ${username}" \
  -H"X-Api-Key: ${password}" \
  -d '{
    "subdomain": "'"${subdomain}"'",
    "txt": "___self___verify___client___credentials____"
  }' "${ACME_DNS_API}"/update; then
  echo "Failed to update record... trying reregistration"
  reregister="yes"
fi

if [ -n "${reregister}" ]; then
  "${SCRIPTS_PATH}/register.sh" force
fi
