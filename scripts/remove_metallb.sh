#!/bin/bash

set -euo pipefail

# Check if the user is logged in
if ! oc whoami &>/dev/null; then
  echo " You are not logged into an OpenShift cluster."
  echo " Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  exit 1
fi


if oc get subscription -n metallb-system metallb >/dev/null 2>&1; then
  echo "MetalLB Subscription found. Deleting..."
  oc delete subscription -n metallb-system metallb

  CSV_NAME=$(oc get csv -n metallb-system -o name | grep metallb || true)
  if [ -n "$CSV_NAME" ]; then
    echo "Deleting CSV: $CSV_NAME"
    oc delete -n metallb-system "$CSV_NAME"
  fi

if oc get ns metallb-system >/dev/null 2>&1; then
  echo "Namespace 'metallb-system' exists. Deleting..."
  oc delete ns metallb-system
  while oc get ns metallb-system >/dev/null 2>&1; do
    sleep 5
  done
fi

else

echo "MetalLB Subscription not found. Deleting"

fi
