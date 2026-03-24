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

if oc get catalogsource "$CATALOG_NAME" -n "$CATALOG_NS" &>/dev/null; then
    echo "CatalogSource $CATALOG_NAME already exists"

    read -rp "Do you want to delete and recreate it? (Y/N): " DEL
    [[ ! "$DEL" =~ ^[Yy]$ ]] && echo "Skipping CatalogSource operation" && exit 0

    echo "Deleting existing CatalogSource..."
    oc delete catalogsource "$CATALOG_NAME" -n "$CATALOG_NS" --wait=true

else
    echo "CatalogSource $CATALOG_NAME does NOT exist"

    read -rp "Do you want to create it? (Y/N): " CREATE
    [[ ! "$CREATE" =~ ^[Yy]$ ]] && echo "Skipping CatalogSource creation" && exit 0
fi

while true; do
    read -rp "Enter Image IIB only: " IIB
    [[ -n "$IIB" ]] && break
    echo "IIB cannot be empty"
done

IMAGE="brew.registry.redhat.io/rh-osbs/iib:$IIB"

CUSTOM_CATALOG_FILE="$SOURCE_ROOT/istio/jenkins-csb-declaration/resources/ocp/templates/olm/custom/custom-catalog-source.yaml"

yq -i "
  .metadata.name = \"$CATALOG_NAME\" |
  .spec.displayName = \"RH Custom Istio catalog\" |
  .spec.image = \"$IMAGE\"
" "$CUSTOM_CATALOG_FILE"

echo "Applying CatalogSource..."
oc apply -f "$CUSTOM_CATALOG_FILE"

echo "Waiting for CatalogSource to be READY..."

oc wait catalogsource/custom-istio-catalog \
  -n openshift-marketplace \
  --for=jsonpath='{.status.connectionState.lastObservedState}'=READY \
  --timeout=180s

if [[ $? -ne 0 ]]; then
    echo " CatalogSource did not become READY"
    oc get catalogsource custom-istio-catalog -n openshift-marketplace -o yaml | grep -A5 connectionState
    exit 1
fi

echo "CatalogSource is ready"
