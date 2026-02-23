#!/bin/bash

set -euo pipefail

# Check exisiting integ-suite-ocp.sh job
LOCK_DIR=/tmp/integ-suite-ocp.sh.lock
PID_FILE="$LOCK_DIR/pid"
LOCK_OWNED=false

trap 'echo; echo "Interrupted. Exiting."; $LOCK_OWNED && rm -rf "$LOCK_DIR"; exit 130' INT
trap '$LOCK_OWNED && rm -rf "$LOCK_DIR"' EXIT TERM

if [[ -f "$PID_FILE" ]] && kill -0 -- "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Another run is active (PGID $(sed 's/^-//' "$PID_FILE"))"
  read -rp "Kill running job and continue? (Y/N): " a
  [[ $a =~ ^[yY]$ ]] || exit 1
  echo "Killing running job..."
  kill -- "$(cat "$PID_FILE")"
  sleep 2
fi

mkdir "$LOCK_DIR" 2>/dev/null && LOCK_OWNED=true

# Check OpenShift login
if ! oc whoami &>/dev/null; then
  echo "You are not logged into an OpenShift cluster."
  echo "Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  exit 1
fi

# Clean stale Istio CRD's
echo "Checking for stale Istio CRD's, will delete if found."
for r in istiorevisions.sailoperator.io istiorevisiontags.sailoperator.io istios.sailoperator.io istiocnis.sailoperator.io ztunnels.sailoperator.io; do
  oc get crd "$r" &>/dev/null || continue
  oc get "$r" -A -o name 2>/dev/null | xargs -r oc delete
  oc wait --for=delete "$r" -A --timeout=5m 2>/dev/null || true
done

# Check stale projects
echo "Checking for stale projects, will delete if found."
mapfile -t EXISTING_PROJECTS < <(oc get projects -o json | jq -r '
  .items[] |
  select(.metadata.annotations["openshift.io/requester"]==null) |
  select(.metadata.name|test("^(openshift|kube|default|metallb|node-vertical)")|not) |
  .metadata.name
')

if (( ${#EXISTING_PROJECTS[@]} )); then
  echo "Deleting existing projects:"
  printf '  - %s\n' "${EXISTING_PROJECTS[@]}"
  oc delete project "${EXISTING_PROJECTS[@]}"
fi

# OSSM version
OSSM_VERSION=$(oc get csv -n openshift-operators \
  --no-headers \
  -o custom-columns=NAME:.metadata.name,VERSION:.spec.version \
  | grep servicemeshoperator3 \
  | awk '{print $2}')

# OCP version
OCP_VERSION=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' | cut -d. -f1,2)

# FIPS mode
FIPS_MODE=$(oc debug node/$(oc get nodes -o jsonpath='{.items[0].metadata.name}') \
  -- chroot /host cat /proc/sys/crypto/fips_enabled 2>/dev/null \
  | grep -q '^1$' && echo fips || echo non-fips)

# Config script
RELEASE_VERSION="ossm_${OSSM_VERSION}_ocp_${OCP_VERSION}_${FIPS_MODE}"
SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GROOVYFILE="$SOURCE_ROOT/istio/jenkins-csb-declaration/jobs/sail/istio-integration-tests.groovy"
JENKINSFILE="$SOURCE_ROOT/istio/jenkins-csb-declaration/jenkinsfiles/sail/istio-integration-tests.jenkinsfile"
TS="$(date +"%Y%m%d_%H%M%S")"
LOG_DIR="/root/logs_istio/${RELEASE_VERSION}"

export GOPATH="$(go env GOPATH)"
export PATH="$PATH:$(go env GOPATH)/bin"
export CONTROL_PLANE_SOURCE="sail"
export TEST_HUB="quay.io/maistra"
export SKIP_SETUP="true"
export TEST_OUTPUT_FORMAT="junit"
export AMBIENT="false"
export IBM="true"
export INSTALL_METALLB="true"

if [[ "$(uname -m)" == "s390x" ]]; then
    export TAG="ibm-z"
else
    export TAG="ibm-p"
fi

extract_param_default() {
  awk "
    /name\\('$1'\\)/ {f=1}
    f && /defaultValue/ {
      gsub(/.*defaultValue\\('|'.*/, \"\", \$0)
      print; exit
    }
  " "$GROOVYFILE"
}

getSmokeTests() {
  awk -v suite="$1" '
    /def getSmokeTests/ {f=1}
    f && $0 ~ "case '\''" suite "'\''" {p=1}
    f && p && /return/ {
      gsub(/.*return '\''|'\''.*/, "", $0)
      print; exit
    }
  ' "$JENKINSFILE"
}

getIgnoredSuitesForSmoke() {
  awk -v suite="$1" '
    /def getIgnoredSuitesForSmoke/ {f=1}
    f && $0 ~ "case '\''" suite "'\''" {p=1}
    f && p && /return/ {
      gsub(/.*return '\''|'\''.*/, "", $0)
      print; exit
    }
  ' "$JENKINSFILE"
}

echo ""

read -rp "Enter ISTIO_VERSION (e.g. v1.27.5): " ISTIO_VERSION
if [[ -z "$ISTIO_VERSION" ]]; then
  echo "ISTIO_VERSION cannot be empty"
  exit 1
fi

export ISTIO_VERSION="${ISTIO_VERSION}"

while true; do
  read -rp "Enter test package (ambient|pilot|security|telemetry): " TEST_PACKAGE
  case "$TEST_PACKAGE" in
    ambient|pilot|security|telemetry) break ;;
    *) echo "Invalid input. Please enter a valid test package." ;;
  esac
done

if [[ "$TEST_PACKAGE" == "ambient" && "$FIPS_MODE" == "fips" ]]; then
  echo "ERROR: Ambient mode is not supported when FIPS is enabled."
  exit 1
fi

TEST_NAME="$(tr '[:lower:]' '[:upper:]' <<<"$TEST_PACKAGE")"

read -rp "Is this a smoke run? (true|false): " IS_SMOKE
IS_SMOKE="${IS_SMOKE:-false}"

if [[ "$IS_SMOKE" != "true" && "$IS_SMOKE" != "false" ]]; then
  echo "IS_SMOKE must be true or false"
  exit 1
fi

# Execute script

echo "[$TEST_NAME] Test Execution Started At $TS"

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${TEST_PACKAGE}_${TS}.log"

skip_test="$(extract_param_default "SKIP_TESTS_${TEST_NAME}")"

if [[ "$IS_SMOKE" == "true" ]]; then
  export ARTIFACT_DIR="/root/artifacts_istio/${RELEASE_VERSION}_smoke/${TEST_PACKAGE}/${TEST_PACKAGE}_artifacts_${TS}"
  skip_suite="$(getIgnoredSuitesForSmoke "$TEST_PACKAGE")"
  smoke_test="$(getSmokeTests "$TEST_PACKAGE")"
else
  export ARTIFACT_DIR="/root/artifacts_istio/${RELEASE_VERSION}/${TEST_PACKAGE}/${TEST_PACKAGE}_artifacts_${TS}"
  skip_suite="$(extract_param_default "SKIP_SUITES_${TEST_NAME}")"
  smoke_test=""
fi

mkdir -p "$ARTIFACT_DIR/junit"

if [[ "$TEST_PACKAGE" == "ambient" ]]; then
  export AMBIENT="true"
  export TRUSTED_ZTUNNEL_NAMESPACE="ztunnel"
fi

cd "$SOURCE_ROOT/istio"

go install github.com/jstemmer/go-junit-report/v2@latest

setsid prow/integ-suite-ocp.sh "$TEST_PACKAGE" "$skip_test" "$skip_suite" "$smoke_test" > "$LOG_FILE" 2>&1 &

PID=$!
PGID="$(ps -o pgid= "$PID" | tr -d ' ')"
echo "-$PGID" > "$PID_FILE"

tail -f "$LOG_FILE" &
TAIL_PID=$!

wait "$PID"
rc=$?

kill "$TAIL_PID" 2>/dev/null || true

echo "[${TEST_NAME}] Test Execution Completed At $TS"
exit $rc
