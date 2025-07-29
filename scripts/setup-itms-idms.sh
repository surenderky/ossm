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

SOURCE_ROOT="/root"

oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/olm/custom/mirrorSets/ibm/istio-integration-registry-itms-idms.yaml
#oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/olm/custom/mirrorSets/ibm/sail-e2e-registry-itms-idms.yaml

sleep 30

echo "Waiting for all MachineConfigPools to be updated..."

for mcp in $(oc get mcp -o name); do
  echo "Waiting for $mcp..."
  until oc get $mcp -o jsonpath='{.status.conditions[?(@.type=="Updated")].status}' | grep -q True; do
    sleep 10
  done
  echo "$mcp is updated."
done

echo "All MCPs updated successfully."

