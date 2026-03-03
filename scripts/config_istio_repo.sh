#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SOURCE_ROOT"

ISTIO_REPO=git@github.com:openshift-service-mesh/istio.git
ISTIO_DIR=istio
read -rp "Enter ISTIO_GIT_BRANCH (ex. release-1.27): " ISTIO_GIT_BRANCH
ISTIO_FRESH_CLONE=false

CSB_REPO=git@gitlab.cee.redhat.com:istio/servicemesh-qe/jenkins-csb-declaration.git
CSB_DIR=jenkins-csb-declaration

if [[ ! -d "$ISTIO_DIR/.git" ]]; then
  echo "Cloning Istio..."
  git clone "$ISTIO_REPO" "$ISTIO_DIR"
  cd "$ISTIO_DIR"
  git checkout "$ISTIO_GIT_BRANCH" 2>/dev/null || true
  git apply $SOURCE_ROOT/patch/ibm_tproxy.patch
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
