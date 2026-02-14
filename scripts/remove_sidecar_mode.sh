#!/usr/bin/env bash
set -euo pipefail

# Check if the user is logged in
if ! oc whoami &>/dev/null; then
  echo " You are not logged into an OpenShift cluster."
  echo " Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  exit 1
fi

# Show current user and cluster
echo " Logged in as: $(oc whoami)"
echo " Current cluster: $(oc whoami --show-server)"

echo "Removing Istio Sidecar Mode configuration"

echo "Deleting IstioCNI"
cat <<'EOF' | oc delete -f - --ignore-not-found
apiVersion: sailoperator.io/v1
kind: IstioCNI
metadata:
  name: default
spec:
  namespace: istio-cni
  profile: default
EOF

echo "Deleting Istio control plane"
cat <<'EOF' | oc delete -f - --ignore-not-found
apiVersion: sailoperator.io/v1
kind: Istio
metadata:
  name: default
spec:
  namespace: istio-system
  profile: default
EOF

echo "Waiting for resources to terminate"
sleep 10

echo "Deleting namespaces"
oc delete namespace istio-system --ignore-not-found
oc delete namespace istio-cni --ignore-not-found

echo "Sidecar mode removal completed"
