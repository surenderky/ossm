#!/usr/bin/env bash
set -euo pipefail

CATALOG="custom-istio-catalog"
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
CHANNELS=$(oc get packagemanifest "$PKG" -n "$CAT_NS" \
  -o jsonpath='{.status.channels[*].name}')

if [[ -z "$CHANNELS" ]]; then
  echo "No channels found for package $PKG"
  exit 1
fi

echo "Available channels:"
select CHANNEL in $CHANNELS; do
  [[ -n "$CHANNEL" ]] && break
  echo "Invalid selection"
done

read -rp "Enter Service Mesh version (e.g. 3.0.1): " SM_VERSION
[[ -z "$SM_VERSION" ]] && { echo "Service Mesh version is required"; exit 1; }

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
  sleep 5
done

echo "Service Mesh ${SM_VERSION} installed successfully on channel ${CHANNEL}"
