#!/bin/sh
set -eu

for crd in ${CRDS_TO_PATCH}; do
  exists=$(kubectl get crd "${crd}" --ignore-not-found)
  if [ -z "$exists" ]; then
    >&2 echo "WARNING: Skipping '${crd}': not found."
    continue
  fi
  # Export and remove all `metadata` properties except `name`, `labels` and `annotations`
  kubectl get crd "${crd}" -o json > "${crd}.json"
  jq 'del(.status) | .metadata = (.metadata | {name, labels, annotations})' "${crd}.json" > "${crd}.patched.json"
  # Apply the CRD again (this shouldn't change anything, except updating the annotation "kubectl.kubernetes.io/last-applied-configuration")
  # You will also see some warnings in the output mentioning the annotation.
  # This is expected and actually required.
  kubectl apply -f "${crd}.patched.json"
done
