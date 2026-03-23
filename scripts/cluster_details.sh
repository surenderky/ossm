#!/bin/bash

set -euo pipefail

# Check if the user is logged in
if ! oc whoami &>/dev/null; then
  echo " You are not logged into an OpenShift cluster."
  echo " Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  exit 1
fi
echo""
CURRENT_CLUSTER="$(oc whoami --show-server)"

if [[ "$(uname -m)" == "s390x" ]]; then
 echo "Cluster API: $CURRENT_CLUSTER"
 CURRENT_CLUSTER="$(echo "$CURRENT_CLUSTER" | awk -F'[.:]' '{print $3}')"
 echo "Cluster Console = https://console-openshift-console.apps.$CURRENT_CLUSTER.maistra.upshift.redhat.com"
 KUBEADMIN_PASSWORD=$(grep -oP 'Password:\s+\K.{23}' "/root/$CURRENT_CLUSTER.log" | tail -n 1)
 echo "Kubeadmin Password: $KUBEADMIN_PASSWORD"
fi 

# OCP version
OCP_VERSION=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' | cut -d. -f1,2)
echo "OCP Version: $OCP_VERSION"
# FIPS mode
FIPS_MODE=$(oc debug node/$(oc get nodes -o jsonpath='{.items[0].metadata.name}') \
  -- chroot /host cat /proc/sys/crypto/fips_enabled 2>/dev/null \
  | grep -q '^1$' && echo FIPS || echo Non-FIPS)
echo "FIPS Mode: $FIPS_MODE"
# OSSM version
OSSM_VERSION=$(oc get csv -n openshift-operators \
  --no-headers \
  -o custom-columns=NAME:.metadata.name,VERSION:.spec.version \
  | grep servicemeshoperator3 \
  | awk '{print $2}')
echo "OSSM version: $OSSM_VERSION"
echo ""
