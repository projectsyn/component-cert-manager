#!/bin/sh

set -e

# Extract acme-dns client config from mounted secret file with `jq` and inject
# as variables into the script environment with `eval`.
username=
password=
subdomain=
acmedns_config=$(jq -r --argjson fqdns "${ACME_DNS_FQDNS}" '
    .[$fqdns[0]]
    | "username=\(.username) password=\(.password) subdomain=\(.subdomain)"
  ' "${CONFIG_PATH}/acmedns.json")
# This overrides the empty variables declared above
eval "${acmedns_config}"

response=$(
  curl \
    -s \
    -o /dev/null \
    -w '%{http_code}' \
    -H"X-Api-User: ${username}" \
    -H"X-Api-Key: ${password}" \
    -d '{
      "subdomain": "'"${subdomain}"'",
      "txt": "___self___verify___client___credentials____"
    }' "${ACME_DNS_API}"/update
)

reregister=
if [ "${response}" = "401" ]; then
  echo "HTTP Unauthorized when trying to update record... trying reregistration"
  reregister="yes"
else
  echo "ACME-DNS check response code: ${response}"
fi

if [ -n "${reregister}" ]; then
  "${SCRIPTS_PATH}/register.sh" force
fi
