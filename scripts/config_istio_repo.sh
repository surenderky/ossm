#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

ISTIO_REPO=git@github.com:openshift-service-mesh/istio.git
ISTIO_DIR=istio

CSB_REPO=git@gitlab.cee.redhat.com:istio/servicemesh-qe/jenkins-csb-declaration.git
CSB_DIR=jenkins-csb-declaration

read -rp "Enter ISTIO_GIT_BRANCH (ex. release-1.2x): " ISTIO_GIT_BRANCH

cd "$SOURCE_ROOT"
if [[ ! -d "$ISTIO_DIR/.git" ]]; then
  echo "Cloning Istio..."
  git clone "$ISTIO_REPO" "$ISTIO_DIR"
  cd "$ISTIO_DIR"
  git checkout "$ISTIO_GIT_BRANCH" 2>/dev/null || true
else
  echo "Updating Istio..."
  cd "$ISTIO_DIR"
  git stash push -u -m auto-stash || true
  git fetch origin
  git checkout "$(git symbolic-ref --short refs/remotes/origin/HEAD | cut -d/ -f2)"
  git reset --hard origin/"$(git symbolic-ref --short refs/remotes/origin/HEAD | cut -d/ -f2)"
  git checkout "$ISTIO_GIT_BRANCH" 2>/dev/null \
    || git checkout -b "$ISTIO_GIT_BRANCH" origin/"$ISTIO_GIT_BRANCH" \
    || git checkout -b "$ISTIO_GIT_BRANCH"
  git pull --rebase origin "$ISTIO_GIT_BRANCH" 2>/dev/null || true
fi

cd "$SOURCE_ROOT"
if [[ ! -d "$CSB_DIR/.git" ]]; then
    echo "Cloning jenkins-csb-declaration..."
    git clone "$CSB_REPO" "$CSB_DIR"
else
    echo "Updating CSB..."
    cd "$CSB_DIR"
    git stash push -u -m auto-stash || true
    git fetch origin
    git checkout "$(git symbolic-ref --short refs/remotes/origin/HEAD | cut -d/ -f2)"
    git pull --rebase origin "$(git symbolic-ref --short refs/remotes/origin/HEAD | cut -d/ -f2)"
    cd ..
fi

if [[ "$ISTIO_GIT_BRANCH" == "release-1.24" ]]; then
ISTIO_CR_VERSION="v1.24.6"
echo "Setting ISTIO_CR_VERSION to $ISTIO_CR_VERSION, if it is different version, please change in this file"
cd "$CSB_DIR/resources/ocp/templates/istio"

for file in *.yaml; do
  echo "Processing $file"
  if [[ "$file" == "istio-ingressgateway.yaml" || "$file" == "istio-egressgateway.yaml" ]]; then
    sed -i -e 's|\${INGRESS_GATEWAY_SVC_NAMESPACE}|istio-system|g' "$file"
  else
    sed -i -e "s|\${INGRESS_GATEWAY_SVC_NAMESPACE}|ingress|g" \
           -e "s|\${ISTIO_VERSION}|$ISTIO_CR_VERSION|g" \
           -e "s|\${ISTIO_PROFILE}|default|g" "$file"
  fi
done
fi
