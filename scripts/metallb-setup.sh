#!/bin/bash

set -euo pipefail

# Check if the user is logged in
if ! oc whoami &>/dev/null; then
  echo " You are not logged into an OpenShift cluster."
  echo " Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  exit 1
fi

# Optional: Show current user and cluster
echo " Logged in as: $(oc whoami)"
echo " Current cluster: $(oc whoami --show-server)"


# Step 0: Check and delete existing MetalLB Operator Subscription if it exists
echo "[0/8] Checking if MetalLB Operator is already installed..."
if oc get subscription -n metallb-system metallb >/dev/null 2>&1; then
  echo "  -> MetalLB Subscription found. Deleting..."
  oc delete subscription -n metallb-system metallb

  CSV_NAME=$(oc get csv -n metallb-system -o name | grep metallb || true)
  if [ -n "$CSV_NAME" ]; then
    echo "  -> Deleting CSV: $CSV_NAME"
    oc delete -n metallb-system "$CSV_NAME"
  fi
fi

# Step 1: Delete existing metallb-system namespace if it exists
echo "[1/8] Checking for 'metallb-system' namespace..."
if oc get ns metallb-system >/dev/null 2>&1; then
  echo "  -> Namespace 'metallb-system' exists. Deleting..."
  oc delete ns metallb-system
  echo "  -> Waiting for namespace to terminate..."
  while oc get ns metallb-system >/dev/null 2>&1; do
    sleep 5
  done
fi

echo "  -> Creating 'metallb-system' namespace..."
oc create namespace metallb-system

# Step 2: Install MetalLB Operator (AllNamespaces mode)
echo "[2/8] Installing MetalLB Operator in AllNamespaces mode..."
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: metallb-operator-group
  namespace: metallb-system
spec: {}
EOF

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: metallb
  namespace: metallb-system
spec:
  channel: stable
  name: metallb-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

# Step 3: Wait for Operator CSV to reach Succeeded phase
echo "[3/8] Waiting for MetalLB Operator to be installed..."
while true; do
  CSV_STATUS=$(oc get csv -n metallb-system -o jsonpath='{.items[?(@.status.phase=="Succeeded")].metadata.name}' 2>/dev/null || echo "")
  if [[ "$CSV_STATUS" == *"metallb"* ]]; then
    break
  fi
  sleep 10
done
echo "  -> Operator installed successfully."

# Step 4: Create MetalLB instance
echo "[4/8] Creating MetalLB instance..."
cat <<EOF | oc apply -f -
apiVersion: metallb.io/v1beta1
kind: MetalLB
metadata:
  name: metallb
  namespace: metallb-system
EOF

# Step 5: Verify controller deployment
echo "[5/8] Waiting for MetalLB controller deployment to be ready..."
while true; do
  AVAILABLE=$(oc get deployment controller -n metallb-system -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "")
  if [[ "$AVAILABLE" == "1" ]]; then
    break
  fi
  sleep 5
done
echo "  -> Controller is running."

# Step 6: Verify speaker daemonset
echo "[6/8] Waiting for MetalLB speaker daemonset to be ready..."
while true; do
  DESIRED=$(oc get daemonset speaker -n metallb-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "")
  READY=$(oc get daemonset speaker -n metallb-system -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "")
  if [[ "$DESIRED" == "$READY" && "$DESIRED" != "" && "$DESIRED" != "0" ]]; then
    break
  fi
  sleep 5
done
echo "  -> Speaker is running ($READY/$DESIRED pods ready)."

# Step 7: Prompt for IP address range
echo "[7/8] Setting up IPAddressPool..."
read -p "Enter the IP address range for MetalLB (e.g., 192.168.150.11-192.168.150.25): " ip_range

cat <<EOF | oc apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: nat
  namespace: metallb-system
spec:
  addresses:
    - ${ip_range}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: doc-example
  namespace: metallb-system
EOF

echo "[8/8] MetalLB is fully configured with IP range: $ip_range"

