#!/usr/bin/env bash
set -euo pipefail

# Check OpenShift login
if ! oc whoami &>/dev/null; then
  echo "You are not logged into an OpenShift cluster."
  echo "Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  echo ""
  exit 1
fi

PKG="servicemeshoperator3"
NS="openshift-operators"

echo "Uninstalling ServiceMesh3 if present..."

# Delete Subscription
oc get subscription "$PKG" -n "$NS" &>/dev/null && \
oc delete subscription "$PKG" -n "$NS" --wait=true

# Delete CSVs
oc get csv -n "$NS" -o name | grep servicemeshoperator3 | xargs -r oc delete -n "$NS"

# Delete Sail CRs
for r in istiocni istio istiorevision istiorevisiontag ztunnel; do
  oc get "$r" -A -o name 2>/dev/null | xargs -r oc delete --wait=false
done

# Clear finalizers on any stuck CRs
for crd in istiocnis istiorevisions istiorevisiontags istios ztunnels; do
  oc get ${crd}.sailoperator.io -A -o name 2>/dev/null | \
    xargs -r oc patch --type=merge -p '{"metadata":{"finalizers":[]}}'
done

# Delete Sail CRDs
for crd in istios.sailoperator.io \
           istiocnis.sailoperator.io \
           istiorevisions.sailoperator.io \
           istiorevisiontags.sailoperator.io \
           ztunnels.sailoperator.io
do
  oc get crd "$crd" &>/dev/null && oc delete crd "$crd"
done

echo "ServiceMesh3 operator removed"
echo ""
