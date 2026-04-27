#!/bin/bash

set -euo pipefail

# Check OpenShift login
if ! oc whoami &>/dev/null; then
  echo "You are not logged into an OpenShift cluster."
  echo "Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  echo ""
  exit 1
fi

echo "Logged in as: $(oc whoami)"
echo "Current cluster: $(oc whoami --show-server)"

SOURCE_ROOT="$(pwd)"

CATALOG_NS="openshift-marketplace"
CATALOG_NAME="custom-istio-catalog"

while true; do
    read -rp "Enter Image IIB only: " IIB
    [[ -n "$IIB" ]] && break
    echo "IIB cannot be empty"
done

IMAGE="brew.registry.redhat.io/rh-osbs/iib:$IIB"

# Check if catalog exists
if oc get catalogsource "$CATALOG_NAME" -n "$CATALOG_NS" &>/dev/null; then

    EXISTING_IMAGE=$(oc get catalogsource "$CATALOG_NAME" \
        -n "$CATALOG_NS" -o jsonpath='{.spec.image}')

    if [[ "$EXISTING_IMAGE" == "$IMAGE" ]]; then
        echo "Same IIB already configured, Skipping Catalog creation"
        exit 0
    else
        echo "Found Old IIB, Recreating CatalogSource"
        oc delete catalogsource "$CATALOG_NAME" -n "$CATALOG_NS" --wait=true
    fi

else
    echo "No existing custom catalog found, Creating new"
fi

CUSTOM_CATALOG_FILE="$SOURCE_ROOT/jenkins-csb-declaration/resources/ocp/templates/olm/custom/custom-catalog-source.yaml"

yq -i "
  .metadata.name = \"$CATALOG_NAME\" |
  .spec.displayName = \"RH Custom Istio catalog\" |
  .spec.image = \"$IMAGE\"
" "$CUSTOM_CATALOG_FILE"

echo "Applying CatalogSource..."
oc apply -f "$CUSTOM_CATALOG_FILE"

echo "Waiting for CatalogSource to be READY..."

oc wait catalogsource/$CATALOG_NAME \
  -n "$CATALOG_NS" \
  --for=jsonpath='{.status.connectionState.lastObservedState}'=READY \
  --timeout=180s

if [[ $? -ne 0 ]]; then
    echo "CatalogSource did not become READY"
    oc get catalogsource "$CATALOG_NAME" -n "$CATALOG_NS" -o yaml | grep -A5 connectionState
    exit 1
fi

echo "CatalogSource is READY"
