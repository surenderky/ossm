#!/bin/bash

set -euo pipefail

# Check OpenShift login
if ! oc whoami &>/dev/null; then
  echo "You are not logged into an OpenShift cluster."
  echo "Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  exit 1
fi

echo "Logged in as: $(oc whoami)"
echo "Current cluster: $(oc whoami --show-server)"

SOURCE_ROOT="$(pwd)"

if oc get catalogsource custom-istio-catalog -n openshift-marketplace &>/dev/null; then
    echo "Catalog custom-istio-catalog already exists"
else

while true; do
    read -p "Enter Image IIB only: " IIB
    [[ -n "$IIB" ]] && break
    echo "IIB cannot be empty"
done

IMAGE="brew.registry.redhat.io/rh-osbs/iib:$IIB"

CUSTOM_CATALOG_FILE="$SOURCE_ROOT/istio/jenkins-csb-declaration/resources/ocp/templates/olm/custom/custom-catalog-source.yaml"

yq -i '
  .metadata.name = "custom-istio-catalog" |
  .spec.displayName = "RH Custom Istio catalog" |
  .spec.image = "'$IMAGE'"
' "$CUSTOM_CATALOG_FILE"

oc apply -f "$CUSTOM_CATALOG_FILE"
fi
