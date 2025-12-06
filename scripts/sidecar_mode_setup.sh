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

TIMEOUT="3m"

echo "Creating namespace for Istio in sidecar mode"
oc create namespace istio-system || echo "namespace istio-system may already exist"

cat <<EOF > istio.yaml
apiVersion: sailoperator.io/v1
kind: Istio
metadata:
  name: default
spec:
  namespace: istio-system
  profile: default
EOF

echo "Applying Istio CR"
oc apply -f istio.yaml

echo "Waiting for Istio control plane to become Ready"
oc wait --for=condition=Ready istios/default --timeout=${TIMEOUT}

echo "Creating namespace for Istio CNI in sidecar mode"
oc create namespace istio-cni || echo "namespace istio-cni may already exist"

cat <<EOF > istio-cni.yaml
apiVersion: sailoperator.io/v1
kind: IstioCNI
metadata:
  name: default
spec:
  namespace: istio-cni
  profile: default
EOF

echo "Applying IstioCNI CR"
oc apply -f istio-cni.yaml

echo "Waiting for IstioCNI pods to become Ready"
oc wait --for=condition=Ready istios/default --timeout=${TIMEOUT}

echo "Sidecar mode setup complete."
