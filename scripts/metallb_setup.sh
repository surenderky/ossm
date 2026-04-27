#!/bin/bash

set -euo pipefail

# Check if the user is logged in
if ! oc whoami &>/dev/null; then
  echo " You are not logged into an OpenShift cluster."
  echo " Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  echo ""
  exit 1
fi

# Cluster Name
echo "Cluster: $(oc whoami --show-server | awk -F'[.:]' '{print $3}')"
echo ""

# Step 0: Check and delete existing MetalLB Operator Subscription if it exists
echo "[1/8] Checking if MetalLB Operator is already installed..."
if oc get subscription -n metallb-system metallb >/dev/null 2>&1; then
  echo " Skipping setup as MetalLB Subscription exists"

else

echo "Creating 'metallb-system' namespace..."
oc create namespace metallb-system

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

echo "[3/8] Waiting for MetalLB Operator to be installed..."
while true; do
  CSV_STATUS=$(oc get csv -n metallb-system -o jsonpath='{.items[?(@.status.phase=="Succeeded")].metadata.name}' 2>/dev/null || echo "")
  if [[ "$CSV_STATUS" == *"metallb"* ]]; then
    break
  fi
  sleep 10
done
echo "Operator installed successfully."

echo "[4/8] Creating MetalLB instance..."
cat <<EOF | oc apply -f -
apiVersion: metallb.io/v1beta1
kind: MetalLB
metadata:
  name: metallb
  namespace: metallb-system
EOF

echo "[5/8] Waiting for MetalLB controller deployment to be ready..."
while true; do
  AVAILABLE=$(oc get deployment controller -n metallb-system -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "")
  if [[ "$AVAILABLE" == "1" ]]; then
    break
  fi
  sleep 5
done
echo "Controller is running."

echo "[6/8] Waiting for MetalLB speaker daemonset to be ready..."
while true; do
  DESIRED=$(oc get daemonset speaker -n metallb-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "")
  READY=$(oc get daemonset speaker -n metallb-system -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "")
  if [[ "$DESIRED" == "$READY" && "$DESIRED" != "" && "$DESIRED" != "0" ]]; then
    break
  fi
  sleep 5
done
echo "Speaker is running ($READY/$DESIRED pods ready)."

echo "[7/8] Setting up IPAddressPool..."

subnet=$(oc get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' | awk -F. '{print $1"."$2"."$3}')
ip_range="${subnet}.200-${subnet}.245"

sleep 10

echo "Configuring IP Range: $ip_range"

cat <<EOF | oc apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
    - ${ip_range}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF

echo "[8/8] MetalLB is fully configured"
fi
