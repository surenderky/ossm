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

echo "Removing Istio Ambient Mode Configuration"

echo "Deleting ZTunnel"
cat <<'EOF' | oc delete -f - --ignore-not-found
apiVersion: sailoperator.io/v1
kind: ZTunnel
metadata:
  name: default
spec:
  namespace: ztunnel
  profile: ambient
EOF

sleep 5

echo "Deleting IstioCNI"
cat <<'EOF' | oc delete -f - --ignore-not-found
apiVersion: sailoperator.io/v1
kind: IstioCNI
metadata:
  name: default
spec:
  namespace: istio-cni
  profile: ambient
  values:
    cni:
      ambient:
        reconcileIptablesOnStartup: true
EOF

sleep 5

echo "Deleting Istio control plane"
cat <<'EOF' | oc delete -f - --ignore-not-found
apiVersion: sailoperator.io/v1
kind: Istio
metadata:
  name: default
spec:
  namespace: istio-system
  profile: ambient
  values:
    pilot:
      trustedZtunnelNamespace: ztunnel
EOF

echo "Waiting for resources to terminate"
sleep 10

echo "Deleting namespaces"
oc delete namespace istio-system --ignore-not-found
oc delete namespace istio-cni --ignore-not-found
oc delete namespace ztunnel --ignore-not-found

echo "Ambient mode removal completed"
