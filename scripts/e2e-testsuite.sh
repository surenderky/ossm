#!/bin/bash

set -euo pipefail
SOURCE_ROOT="/root"

# Check if the user is logged in
if ! oc whoami &>/dev/null; then
  echo " You are not logged into an OpenShift cluster."
  echo " Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  exit 1
fi

# Show current user and cluster
echo " Logged in as: $(oc whoami)"
echo " Current cluster: $(oc whoami --show-server)"

REPO_NAME="sail-operator"

# Generate timestamped log file name
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOGFILE="$SOURCE_ROOT/e2e-log-$TIMESTAMP.log"

if [ -d "$REPO_NAME" ]; then
    echo "Repository '$REPO_NAME' already exists. Skipping clone."
    cd "$REPO_NAME"
else
    echo "Cloning repository..."
    read -rp "Enter REPO_BRANCH(Ex:release-3.x): " REPO_BRANCH
    REPO_URL="https://github.com/openshift-service-mesh/sail-operator.git"
    PATCH_PATH="${SOURCE_ROOT}/ossm/scripts/patch/$REPO_BRANCH.patch"
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL"
    cd "$REPO_NAME"
    echo "Applying patch..."
    git apply "$PATCH_PATH"
fi

# Export environment variables
echo "Setting environment variables..."
export SKIP_BUILD=true
export SKIP_DEPLOY=true
export NAMESPACE="openshift-operators"
export DEPLOYMENT_NAME="servicemesh-operator3"
export BUILD_WITH_CONTAINER=0

# Run the tests and log output
echo "Running E2E tests. Logging to $LOGFILE..."
if make test.e2e.ocp 2>&1 | tee "$LOGFILE"; then
    echo " E2E tests completed successfully. Log saved to $LOGFILE"
else
    echo " E2E tests failed. Check log at $LOGFILE"
    exit 1
fi
