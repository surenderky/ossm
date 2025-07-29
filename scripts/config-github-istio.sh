#!/bin/bash
set -euo pipefail

SOURCE_ROOT="$(pwd)"

rm -rf istio/

read -rp "Enter ISTIO_GIT_BRANCH: " ISTIO_GIT_BRANCH

git clone https://github.com/istio/istio

cd istio

git checkout $ISTIO_GIT_BRANCH

git clone git@gitlab.cee.redhat.com:istio/servicemesh-qe/jenkins-csb-declaration.git

cd jenkins-csb-declaration/resources/ocp/templates/istio/

read -rp "Enter ISTIO_VERSION: " ISTIO_VERSION

for file in *.yaml; do
  echo "Processing $file"

  if [[ "$file" == "istio-ingressgateway.yaml" || "$file" == "istio-egressgateway.yaml" ]]; then
    sed -i -e 's|\${INGRESS_GATEWAY_SVC_NAMESPACE}|istio-system|g' "$file"
  else
    sed -i -e "s|\${INGRESS_GATEWAY_SVC_NAMESPACE}|ingress|g" \
           -e "s|\${ISTIO_VERSION}|$ISTIO_VERSION|g" "$file"
  fi
done


