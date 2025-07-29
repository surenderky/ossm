#!/bin/bash

# Check if the user is logged in
if ! oc whoami &>/dev/null; then
  echo " You are not logged into an OpenShift cluster."
  echo " Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  exit 1
fi

# Show current user and cluster
echo " Logged in as: $(oc whoami)"
echo " Current cluster: $(oc whoami --show-server)"

read -p "Enter the stuck project (namespace) name to force delete: " PROJECT

if [[ -z "$PROJECT" ]]; then
  echo " Project name cannot be empty."
  exit 1
fi

echo " Checking if project '$PROJECT' exists..."
if ! oc get namespace "$PROJECT" &>/dev/null; then
  echo " Project '$PROJECT' not found."
  exit 1
fi

echo " Fetching project JSON and removing finalizers..."
oc get namespace "$PROJECT" -o json | jq '.spec.finalizers = []' > /tmp/force-delete-ns.json

echo " Forcing deletion of project '$PROJECT'..."

curl -k -H "Content-Type: application/json" \
     -H "Authorization: Bearer $(oc whoami -t)" \
     -X PUT --data-binary @/tmp/force-delete-ns.json \
     https://$(oc whoami --show-server | sed 's|https://||')/api/v1/namespaces/$PROJECT/finalize \
     && echo " Project '$PROJECT' force deleted." \
     || echo " Failed to delete project. Check manually."

# Clean up
rm -f /tmp/force-delete-ns.json

