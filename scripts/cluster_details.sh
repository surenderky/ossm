#!/bin/bash

set -euo pipefail

# Check if the user is logged in
if ! oc whoami &>/dev/null; then
  echo " You are not logged into an OpenShift cluster."
  echo " Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  echo""
  exit 1
fi

# Cluster Name
echo "Cluster: $(oc whoami --show-server | awk -F'[.:]' '{print $3}')"
echo ""

# OCP Version
echo "OCP Version: $(oc get clusterversion version -o jsonpath='{.status.desired.version}' | cut -d. -f1,2)"
echo ""

# FIPS Mode
echo "FIPS Mode: $(oc debug node/$(oc get nodes -o jsonpath='{.items[0].metadata.name}') \
  -- chroot /host cat /proc/sys/crypto/fips_enabled 2>/dev/null \
  | grep -q '^1$' && echo FIPS || echo Non-FIPS)"
echo ""

# OSSM Version
OSSM_VERSION=$(oc get csv -n openshift-operators --no-headers -o custom-columns=NAME:.metadata.name,VERSION:.spec.version | awk '/servicemeshoperator3/ {print $2}')

if [[ -z "$OSSM_VERSION" ]]; then
  echo "OSSM is not installed"
else
  echo "OSSM installed version: $OSSM_VERSION"
fi
echo ""

# Kiali Version
if oc get ns istio-system &>/dev/null; then
  KIALI_VERSION=$(oc get kiali kiali -n istio-system -o jsonpath='{.spec.version}' 2>/dev/null)

  if [[ -z "$KIALI_VERSION" ]]; then
    echo "Kiali is not installed"
  else
    echo "Kiali installed version: $KIALI_VERSION"
  fi
else
  echo "Kiali is not installed"
fi
echo ""

if [[ "$(oc get node -o 'jsonpath={.items[0].status.nodeInfo.architecture}')" == "s390x" ]]; then
 echo "OC Login: oc login -u kubeadmin -p "$(grep -oP 'Password:\s+\K.{23}' "/root/$(oc whoami --show-server | awk -F'[.:]' '{print $3}').log" | tail -n 1)" --server="$(oc whoami --show-server)" --insecure-skip-tls-verify"
fi
echo ""

