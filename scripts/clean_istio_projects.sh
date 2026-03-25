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

# 1. Gather targets based on your Requester/System logic
TARGETS=$(oc get projects -o json | jq -r '.items[] |
  select(.metadata.annotations["openshift.io/requester"] == null) |
  select(.metadata.name | test("^(openshift|kube|default|metallb|node-vertical)") | not) |
  .metadata.name')

# 2. Check if list is empty
if [ -z "$TARGETS" ]; then
    echo "No projects found."
else
    echo
    echo "$TARGETS"
    echo
    # 3. Iterate and confirm each
    for ns in $TARGETS; do
        read -p "Delete project '$ns'? (y/n): " confirm
        if [[ $confirm == [yY] ]]; then
            oc delete project "$ns"
        else
            echo "Skipping '$ns'..."
        fi
    done
    echo "Done."
fi
