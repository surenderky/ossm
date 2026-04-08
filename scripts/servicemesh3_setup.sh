#!/usr/bin/env bash
set -euo pipefail

# Check OpenShift login
if ! oc whoami &>/dev/null; then
  echo "You are not logged into an OpenShift cluster."
  echo "Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  echo ""
  exit 1
fi

echo ""
echo "CatalogSources:"
echo ""
mapfile -t CATS < <(oc get catalogsource -n openshift-marketplace -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
(( ${#CATS[@]} == 0 )) && { echo "No CatalogSource found"; exit 1; }

for i in "${!CATS[@]}"; do echo "$((i+1))) ${CATS[i]}"; done
echo ""
while true; do
  read -rp "Select catalog number: " n
  [[ $n =~ ^[0-9]+$ && n -ge 1 && n -le ${#CATS[@]} ]] && { CATALOG=${CATS[n-1]}; break; }
  echo "Invalid selection. Try again."
done
echo ""

CAT_NS="openshift-marketplace"
NS="openshift-operators"
PKG="servicemeshoperator3"

# Ensure catalog is ready
oc get catalogsource "$CATALOG" -n "$CAT_NS" \
  -o jsonpath='{.status.connectionState.lastObservedState}' \
  | grep -q READY

# Ensure OperatorGroup exists
oc get operatorgroup -n "$NS" >/dev/null 2>&1 || {
  echo "No OperatorGroup found in $NS"
  exit 1
}

# Fetch available channels
mapfile -t CH < <(oc get packagemanifest "$PKG" -n "$CAT_NS" -o jsonpath='{.status.channels[*].name}' | xargs -n1)
(( ${#CH[@]} == 0 )) && { echo "No channels for $PKG"; exit 1; }
echo ""
echo "Available Channels:"; for i in "${!CH[@]}"; do echo "$((i+1))) ${CH[i]}"; done
echo ""
while :; do
  read -rp "Select channel: " n
  [[ $n =~ ^[0-9]+$ && n -ge 1 && n -le ${#CH[@]} ]] && { CHANNEL=${CH[n-1]}; break; }
  echo "Invalid selection. Try agaiin."
done
echo""

while :; do
  read -rp "Enter Service Mesh version (e.g. 3.3.0): " SM_VERSION
  [[ -n "$SM_VERSION" ]] && break
  echo "Service Mesh version is required"
done

# Create / update Subscription
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: $PKG
  namespace: $NS
spec:
  name: $PKG
  channel: $CHANNEL
  startingCSV: servicemeshoperator3.v${SM_VERSION}
  source: $CATALOG
  sourceNamespace: $CAT_NS
  installPlanApproval: Automatic
EOF

# Wait for CSV
until oc get csv -n "$NS" | grep -q "servicemeshoperator3.v${SM_VERSION}.*Succeeded"; do
  sleep 30
done

echo "Service Mesh ${SM_VERSION} installed successfully on channel ${CHANNEL}"
