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


echo "Setting up Istio Ambient Mode using Sail Operator"

ISTIO_NS="istio-system"
CNI_NS="istio-cni"
ZTUNNEL_NS="ztunnel"

echo "Creating required namespaces"
oc get namespace "$ISTIO_NS" >/dev/null 2>&1 || oc create namespace "$ISTIO_NS"
oc get namespace "$CNI_NS" >/dev/null 2>&1 || oc create namespace "$CNI_NS"
oc get namespace "$ZTUNNEL_NS" >/dev/null 2>&1 || oc create namespace "$ZTUNNEL_NS"

echo "Applying Istio Ambient profile"
cat <<'EOF' | oc apply -f -
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

sleep 10

echo "Applying Istio-CNI Ambient profile"
cat <<'EOF' | oc apply -f -
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

sleep 10

echo "Applying ZTunnel Ambient profile"
cat <<'EOF' | oc apply -f -
apiVersion: sailoperator.io/v1
kind: ZTunnel
metadata:
  name: default
spec:
  namespace: ztunnel
  profile: ambient
EOF

echo "Waiting for components to become ready"
sleep 10

echo "Status check"
oc get istio default -n istio-system
oc get pods -n istio-system
oc get pods -n istio-cni
oc get pods -n ztunnel

echo "Istio Ambient Mode setup completed"

