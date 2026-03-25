#!/bin/bash

set -euo pipefail

# Check exisiting job
PGID=$(ps -eo pgid,cmd | awk '/prow\/integ-suite-ocp.sh/ {print $1; exit}')

if [[ -n "${PGID:-}" ]]; then
  echo "Another prow run is active (PGID $PGID)"
  read -rp "Kill it and proceed? (Y/N): " a
  [[ $a =~ ^[yY]$ ]] || exit 1
  echo ""
  echo "Stopping run..."
  kill -TERM "-$PGID" 2>/dev/null || true
  sleep 3
  kill -0 "-$PGID" 2>/dev/null && kill -KILL "-$PGID" 2>/dev/null || true
  echo ""
fi

# Check OpenShift login
if ! oc whoami &>/dev/null; then
  echo "You are not logged into an OpenShift cluster."
  echo "Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  echo ""
  exit 1
fi

# OCP version
OCP_VERSION=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' | cut -d. -f1,2)

# OSSM version
OSSM_VERSION=$(oc get csv -n openshift-operators \
	  --no-headers \
	  -o custom-columns=NAME:.metadata.name,VERSION:.spec.version \
	  | awk '/servicemeshoperator3/ {print $2}')

if [[ -z "$OSSM_VERSION" ]]; then
  echo "OSSM is not installed, please install"
  echo ""
  exit 1
fi

printf '%s\n' 3.1 "$OSSM_VERSION" | sort -V -C || { echo "ERROR: OSSM >=3.1 required"; exit 1; }
echo ""
echo "OSSM installed version: $OSSM_VERSION"
echo ""

# FIPS mode
FIPS_MODE=$(oc debug node/$(oc get nodes -o jsonpath='{.items[0].metadata.name}') \
  -- chroot /host cat /proc/sys/crypto/fips_enabled 2>/dev/null \
  | grep -q '^1$' && echo fips || echo non-fips)

# Config script
RELEASE_VERSION="ossm_${OSSM_VERSION}_ocp_${OCP_VERSION}_${FIPS_MODE}"
SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TS="$(TZ=Asia/Kolkata date +"%d_%b_%Y_%I_%M_%P" | tr '[:upper:]' '[:lower:]')"
IBM_SKIP="${1:-}"

export GOPATH="$(go env GOPATH)"
export PATH="$PATH:$(go env GOPATH)/bin"
export CONTROL_PLANE_SOURCE="sail"
export TEST_HUB="quay.io/maistra"
export SKIP_SETUP="true"
export TEST_OUTPUT_FORMAT="junit"
export AMBIENT="false"
export IBM="true"
export INSTALL_METALLB="false"

if [[ "$(uname -m)" == "s390x" ]]; then
    export TAG="ibm-z"
else
    export TAG="ibm-p"
fi

read -rp "Enter ISTIO CR Version (ex. v1.28.4): " ISTIO_VERSION
echo ""
if [[ -z "$ISTIO_VERSION" ]]; then
  echo "ISTIO_VERSION cannot be empty"
  echo ""
  exit 1
fi

export ISTIO_VERSION="${ISTIO_VERSION}"
TEST_REPO_BRANCH="release-$(echo "$ISTIO_VERSION" | sed -E 's/^v([0-9]+\.[0-9]+).*/\1/')"

ALLOWED=$(printf '%s\n' 3.2 "$OSSM_VERSION" | sort -V -C && \
echo "ambient|pilot|security|telemetry" || echo "pilot|security|telemetry")

IFS="|" read -ra ALLOWED_PKGS <<< "$ALLOWED"

read -rp "Is this a smoke or full or single_test run? (smoke|full|single_test): " TEST_TYPE
echo ""
if [[ "$TEST_TYPE" != "smoke" && "$TEST_TYPE" != "full" && "$TEST_TYPE" != "single_test" ]]; then
  echo "Test type must be smoke or full or single_test "
  echo ""
  exit 1
fi

if [ "${TEST_TYPE}" = "single_test" ]; then
     read -rp "Enter Package from ($ALLOWED) or Sub-package: " PACKAGE
     #read -rp "Enter Tests to skip: " SKIP_TESTS
     #read -rp "Enter Sub-package to skip: " SKIP_SUBSUITES
     echo""
     read -rp "Enter Test Name: " RUN_TEST_ONLY
else

read -rp "Run all packages? (Y/N): " RUN_ALL
echo ""
if [[ "$RUN_ALL" =~ ^[Yy]$ ]]; then
  PACKAGE="$ALLOWED"

else
  while true; do

    if [[ "$TEST_TYPE" == "smoke" ]]; then
      read -rp "Enter Package from ($ALLOWED): " PACKAGE
    else
      read -rp "Enter Package from ($ALLOWED) or Sub-package: " PACKAGE
    fi

    ROOT="${PACKAGE%%/*}"
    VALID=false

    for a in "${ALLOWED_PKGS[@]}"; do
      [[ "$a" == "$ROOT" ]] && VALID=true && break
    done

    if ! $VALID; then
      echo "Invalid package, Allowed: $ALLOWED"
      echo ""
      continue
    fi

    if [[ "$TEST_TYPE" == "smoke" && "$PACKAGE" == */* ]]; then
      echo "Sub-packages are allowed only in FULL run"
      echo ""
      continue
    fi

    break
  done
fi
fi
echo ""

cd $SOURCE_ROOT/istio

FINAL_RC=0
IFS="|" read -ra PKGS <<< "$PACKAGE"

for TEST_PACKAGE in "${PKGS[@]}"; do

TEST_NAME="${TEST_PACKAGE//\//_}"

   # Clean stale Istio CRD's
   echo "Cleaning stale Istio CRD's..."
   for r in istiorevisions.sailoperator.io istiorevisiontags.sailoperator.io istios.sailoperator.io istiocnis.sailoperator.io ztunnels.sailoperator.io; do
     oc get crd "$r" &>/dev/null || continue
     oc get "$r" -A -o name 2>/dev/null | xargs -r oc delete
     oc wait --for=delete "$r" -A --timeout=5m 2>/dev/null || true
   done
   echo ""

   # Check stale projects
   echo "Cleaning stale Istio projects..."
   mapfile -t EXISTING_PROJECTS < <(oc get projects -o json | jq -r '
     .items[] |
     select(.metadata.annotations["openshift.io/requester"]==null) |
     select(.metadata.name|test("^(openshift|kube|default|metallb|node-vertical)")|not) |
     .metadata.name
   ')
   echo ""

   if (( ${#EXISTING_PROJECTS[@]} )); then
     echo "Deleting existing projects:"
     printf '  - %s\n' "${EXISTING_PROJECTS[@]}"
     oc delete project "${EXISTING_PROJECTS[@]}"
     echo ""
   fi

   git clean -f
   git stash

   if [ "${TEST_TYPE}" == "single_test" ]; then
      RUN_ALL=""
      SKIP_PARSER_SUITE="${TEST_PACKAGE}"
      SKIP_PARSER_SKIP_TESTS=""
      if [[ "$SKIP_PARSER_SUITE" == "ambient" ]]; then
      SKIP_PARSER_SKIP_SUBSUITES="ambient/cni|ambient/waypoint|ambient/pqc|ambient/cnirepair|ambient/cniupgrade|ambient/crl|ambient/untaint|ambient/waypoint"
      elif [[ "$SKIP_PARSER_SUITE" == "security" ]]; then
      SKIP_PARSER_SKIP_SUBSUITES="security/ca_custom_root|security/cacert_rotation|security/crl|security/ecc_signature_algorithm|security/external_ca|security/file_mounted_certs|security/filebased_tls_origination|security/fuzz|security/https_jwt|security/policy_attachment_only|security/pqc|security/remote_jwks|security/sds_ingress/quic"
      elif [[ "$SKIP_PARSER_SUITE" == "pilot" ]]; then
      SKIP_PARSER_SKIP_SUBSUITES="pilot/analysis|pilot/gie|pilot/mcs|pilot/autoexport|pilot/nftables|pilot/cni|pilot/forwardproxy|pilot/localwatcher|pilot/mcs|pilot/multiplecontrolplanes|pilot/proxyconfig|pilot/resourcefilter|pilot/revisions"
      else
      SKIP_PARSER_SKIP_SUBSUITES=""
      fi
      SKIP_PARSER_RUN_TESTS_ONLY="${RUN_TEST_ONLY}"
      export ARTIFACT_DIR="/root/artifacts_istio/${RELEASE_VERSION}_single_test/${TEST_PACKAGE}/${TEST_NAME}_artifacts_${TS}"
      LOG_DIR="/root/logs_istio/${RELEASE_VERSION}_single_test/${TEST_PACKAGE}"
      JUNIT_DIR="/root/junit_istio/${RELEASE_VERSION}_single_test/"
   else
   if [[ "$TEST_TYPE" == "smoke" ]]; then
     TEST_FILE_NAME="test-config-smoke.yaml"
     export ARTIFACT_DIR="/root/artifacts_istio/${RELEASE_VERSION}_smoke/${TEST_PACKAGE}/${TEST_NAME}_artifacts_${TS}"
     LOG_DIR="/root/logs_istio/${RELEASE_VERSION}_smoke/${TEST_PACKAGE}"
     JUNIT_DIR="/root/junit_istio/${RELEASE_VERSION}_smoke/"
   else
     TEST_FILE_NAME="test-config-full.yaml"
     export ARTIFACT_DIR="/root/artifacts_istio/${RELEASE_VERSION}/${TEST_PACKAGE}/${TEST_NAME}_artifacts_${TS}"
     LOG_DIR="/root/logs_istio/${RELEASE_VERSION}/${TEST_PACKAGE}"
     JUNIT_DIR="/root/junit_istio/${RELEASE_VERSION}/"
   fi
   
   curl -o config.yaml https://raw.githubusercontent.com/openshift-service-mesh/ci-utils/refs/heads/main/skip_tests/"${TEST_FILE_NAME}"
   curl -O https://raw.githubusercontent.com/openshift-service-mesh/ci-utils/refs/heads/main/skip_tests/parse-test-config.sh
   chmod +x ./parse-test-config.sh
   eval "$(./parse-test-config.sh config.yaml "$TEST_PACKAGE" downstream "$TEST_REPO_BRANCH")"

   skip_json="/root/ibm_skip_istio_test.json"

   if [[ "$TEST_TYPE" == "full" && "$IBM_SKIP" == "ibm" && -f "$skip_json" ]]; then
   skip_key="$(echo "$OSSM_VERSION" | awk -F. '{print $1 "." $2}')"

   ibm_skip_test=$(jq -r \
     --arg v "$skip_key" \
     --arg a "$(uname -m)" \
     --arg p "$TEST_PACKAGE" \
     '.[$v][$a][$p].skip_test // empty' \
     "$skip_json")

   if [[ -n "$ibm_skip_test" ]]; then
     SKIP_PARSER_SKIP_TESTS="${SKIP_PARSER_SKIP_TESTS}${ibm_skip_test}"
   fi

   ibm_skip_subsuite=$(jq -r \
     --arg v "$skip_key" \
     --arg a "$(uname -m)" \
     --arg p "$TEST_PACKAGE" \
     '.[$v][$a][$p].skip_subsuite // empty' \
     "$skip_json")

   if [[ -n "$ibm_skip_subsuite" ]]; then
     SKIP_PARSER_SKIP_SUBSUITES="${ibm_skip_subsuite}"
   fi

   fi

   fi
   
   if [[ "$TEST_PACKAGE" == *"ambient"* ]]; then
     export AMBIENT="true"
     export TRUSTED_ZTUNNEL_NAMESPACE="ztunnel"
   fi

   # Create log file
   mkdir -p "$LOG_DIR"
   LOG_FILE="$LOG_DIR/${TEST_NAME}_${TS}.log"

   #Create artifacts and junit folder
   mkdir -p "$ARTIFACT_DIR/junit"

   #Install go-junit-report
   go install github.com/jstemmer/go-junit-report/v2@latest

   # Execute script
   echo ""
   echo "[$TEST_PACKAGE] Test Execution Started"
   echo ""

   setsid prow/integ-suite-ocp.sh "${SKIP_PARSER_SUITE}" "${SKIP_PARSER_SKIP_TESTS}" "${SKIP_PARSER_SKIP_SUBSUITES}" "${SKIP_PARSER_RUN_TESTS_ONLY}" > "$LOG_FILE" 2>&1 &

   PID=$!
   tail -f "$LOG_FILE" &
   TAIL_PID=$!
   set +e
   wait "$PID"
   rc=$?
   set +e
   kill "$TAIL_PID" 2>/dev/null || true

   for _ in {1..60}; do
     [[ -s "$ARTIFACT_DIR/junit/junit.xml" ]] && break
     sleep 10
   done

oc delete mutatingwebhookconfigurations istio-revision-tag-tag || true

echo ""
echo "--------------------------------------------------------------------"
echo "[$TEST_PACKAGE] Test Execution Completed"
echo "--------------------------------------------------------------------"
echo ""
mkdir -p "$JUNIT_DIR"
cp "$ARTIFACT_DIR/junit/junit.xml" "$JUNIT_DIR/junit_${RELEASE_VERSION}_${TEST_NAME}_${TS}.xml"

sleep 10

((rc!=0)) && FINAL_RC=1

done

echo "--------------------------------------------------------------------"
echo "[$TEST_PACKAGE] Test Result"
echo "--------------------------------------------------------------------"
echo ""
$SOURCE_ROOT/generate_test_report.sh "$JUNIT_DIR/junit_${RELEASE_VERSION}_${TEST_NAME}_${TS}.xml"

echo "--------------------------------------------------------------------"

sleep 10

exit $FINAL_RC
