#!/usr/bin/env bash
set -euo pipefail

# ---- Resolve script location ----
SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SOURCE_ROOT"

# ---- User input ----
read -rp "Enter ISTIO GIT RELEASE VERSION (e.g. 1.2X): " ISTIO_GIT_RELEASE_VERSION
read -rp "Enter ISTIO VERSION (eg v1.2X.X): " ISTIO_CR_VERSION

ISTIO_GIT_BRANCH="release-${ISTIO_GIT_RELEASE_VERSION}"

# ---- Repos ----
ISTIO_REPO=git@github.com:istio/istio.git
ISTIO_DIR=istio

CSB_REPO=git@gitlab.cee.redhat.com:istio/servicemesh-qe/jenkins-csb-declaration.git
CSB_DIR=jenkins-csb-declaration

ISTIO_FRESH_CLONE=false

# ---- Istio ----
if [[ ! -d "$ISTIO_DIR/.git" ]]; then
  echo "Cloning Istio..."
  git clone "$ISTIO_REPO" "$ISTIO_DIR"
  cd "$ISTIO_DIR"
  git checkout "$ISTIO_GIT_BRANCH" 2>/dev/null || true
  ISTIO_FRESH_CLONE=true
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

# ---- Jenkins CSB (inside istio/) ----
if [[ "$ISTIO_FRESH_CLONE" == "true" ]]; then
  echo "Fresh Istio clone → cloning CSB..."
  git clone "$CSB_REPO" "$CSB_DIR"
else
  if [[ ! -d "$CSB_DIR/.git" ]]; then
    echo "CSB not found → cloning..."
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
fi

# ---- Post-process CSB templates ----
cd "$CSB_DIR/resources/ocp/templates/istio"

for file in *.yaml; do
  echo "Processing $file"
  if [[ "$file" == "istio-ingressgateway.yaml" || "$file" == "istio-egressgateway.yaml" ]]; then
    sed -i -e 's|\${INGRESS_GATEWAY_SVC_NAMESPACE}|istio-system|g' "$file"
  else
    sed -i -e "s|\${INGRESS_GATEWAY_SVC_NAMESPACE}|ingress|g" \
           -e "s|\${ISTIO_VERSION}|$ISTIO_CR_VERSION|g" "$file"
  fi
done

