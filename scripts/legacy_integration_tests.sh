#!/bin/bash

set -euo pipefail

# Check OpenShift login
if ! oc whoami &>/dev/null; then
  echo "You are not logged into an OpenShift cluster."
  echo "Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  exit 1
fi

# OCP version
OCP_VERSION=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' | cut -d. -f1,2)
echo ""

# OSSM version
OSSM_VERSION=$(oc get csv -n openshift-operators \
          --no-headers \
          -o custom-columns=NAME:.metadata.name,VERSION:.spec.version \
          | awk '/servicemeshoperator3/ {print $2}')

if [[ -z "$OSSM_VERSION" ]]; then
  echo "OSSM is not installed, please install"
  exit 1
fi

printf '%s\n' 3.0 "$OSSM_VERSION" | sort -V -C && printf '%s\n' "$OSSM_VERSION" 3.1 | sort -V -C || { echo "ERROR: Only OSSM 3.0.x supported"; exit 1; }

echo "OSSM installed version: $OSSM_VERSION"
echo ""

# FIPS mode
FIPS_MODE=$(oc debug node/$(oc get nodes -o jsonpath='{.items[0].metadata.name}') \
  -- chroot /host cat /proc/sys/crypto/fips_enabled 2>/dev/null \
  | grep -q '^1$' && echo fips || echo non-fips)

RELEASE_VERSION="ossm_${OSSM_VERSION}_ocp_${OCP_VERSION}_${FIPS_MODE}"
SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TS="$(TZ=Asia/Kolkata date +"%d_%b_%Y_%I_%M_%P" | tr '[:upper:]' '[:lower:]')"

#read -rp "Is this a smoke or full run? (smoke|full): " TEST_TYPE
#echo ""
#if [[ "$TEST_TYPE" != "smoke" && "$TEST_TYPE" != "full" ]]; then
#  echo "Test type  must be smoke or full"
#  exit 1
#fi

TEST_TYPE="smoke"
echo "Running Smoke Tests"
echo ""

TEMPLATE_PATH="${SOURCE_ROOT}/jenkins-csb-declaration/resources/ocp/templates/istio"

export GOPATH="$(go env GOPATH)"
export SKIP_WORKLOADS="tproxy,vm"
export PATH=$PATH:$(go env GOPATH)/bin
export HUB=quay.io/maistra

#Install gotestsum
go install gotest.tools/gotestsum@latest

if [[ "$(oc get node -o 'jsonpath={.items[0].status.nodeInfo.architecture}')" == "s390x" ]]; then
    export TAG="ibm-z"
else
    export TAG="ibm-p"
fi

extract_extra_test_args() {
  local block_name="$1"
  local test_args="$2"
  local groovy_file="${SOURCE_ROOT}/jenkins-csb-declaration/vars/istioIntegrationTestData.groovy"

  awk -v block_name="$block_name" -v test_args="$test_args" '
  BEGIN {
    in_block=0
    in_extra=0
  }

  {
    if ($0 ~ "^[[:space:]]*'\''" block_name "'\''[[:space:]]*:[[:space:]]*\\{[[:space:]]*\\[") {
      in_block=1
      next
    }

    if (in_block && $0 ~ /\][[:space:]]*\},?/) {
      in_block=0
    }

    if (in_block && index($0, "'"'"'" test_args "'"'"'") > 0) {
      sub(/^.*:[[:space:]]*'\''/, "", $0)
      extra=$0
      in_extra=1
    }

    if (in_extra) {
      if ($0 ~ /'\''[[:space:]]*,?[[:space:]]*$/) {
        sub(/'\''[[:space:]]*,?[[:space:]]*$/, "", extra)
        print extra
        exit
      }
      getline
      extra = extra "\n" $0
    }
  }
  ' "$groovy_file"
}

# Add test suite for template mapping
declare -A TEMPLATE_MAP=(
  # telemetry
  ["telemetry/api"]="istio-telemetry-api.yaml"
  ["telemetry/policy"]="istio-telemetry-policy.yaml"
#  ["telemetry/tracing/zipkin"]="istio-telemetry-tracing-zipkin.yaml"
#  ["telemetry/tracing/otelcollector"]="istio-telemetry-tracing-otelcollector.yaml"

  # security
  ["security"]="istio-security.yaml"
  ["security/policy_attachment_only"]="istio-security-policy-attachment-only.yaml"
  ["security/remote_jwks"]="istio-security-remote-jwks.yaml"
  ["security/https_jwt"]="istio-security-https-jwt.yaml"
  ["security/filebased_tls_origination"]="istio-security-filebased-tls-origination.yaml"
  ["security/ecc_signature_algorithm"]="istio-security-ecc-signature-algorithm.yaml"
  ["security/ca_custom_root"]="istio-security-ca-custom-root.yaml"
  ["security/cacert_rotation"]="istio-security-cacert-rotation.yaml"

  # pilot
  ["pilot"]="istio-pilot.yaml"
  ["pilot/analysis"]="istio-pilot-analysis.yaml"
)

SUITES=("${!TEMPLATE_MAP[@]}")
mapfile -t SUITES_SORTED < <(printf '%s\n' "${SUITES[@]}" | sort)

run_test_suite() {
	
  local test_path="$1"
 
  echo ""
  echo "[${test_path}] Test Execution Started"
  echo ""

  local template_file="${TEMPLATE_MAP[$test_path]}"
  local testsuite_file="${test_path//\//-}"
  local timestamp="$(TZ=Asia/Kolkata date +"%d_%b_%Y_%I_%M_%P" | tr '[:upper:]' '[:lower:]')"
  local get_extra_test_args

  if [[ "$TEST_TYPE" == "smoke" ]]; then
   ARTIFACT_DIR="/root/artifacts_istio/${RELEASE_VERSION}_smoke"
   LOG_DIR="/root/logs_istio/${RELEASE_VERSION}_smoke/${test_path}"
   JUNIT_DIR="/root/junit_istio/${RELEASE_VERSION}_smoke/"
   get_extra_test_args=$(extract_extra_test_args "$test_path" extraSmokeTestArgs)
   if [[ -z "$get_extra_test_args" ]]; then
    echo "Skipping [${test_path}], No smoke tests to run"
    echo ""
    echo "------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
    return 0
  fi 
 else
   ARTIFACT_DIR="/root/artifacts_istio/${RELEASE_VERSION}"
   LOG_DIR="/root/logs_istio/${RELEASE_VERSION}/${test_path}"
   JUNIT_DIR="/root/junit_istio/${RELEASE_VERSION}/"
   get_extra_test_args=$(extract_extra_test_args "$test_path" extraTestArgs)
  fi
  
  export EXTRA_TEST_ARGS="$get_extra_test_args"
  
  mkdir -p "$ARTIFACT_DIR"
  mkdir -p "$LOG_DIR"

  local logfile="$LOG_DIR/${testsuite_file}_${TS}.log"
  local report_dir="$ARTIFACT_DIR/${test_path}"

  cd ${SOURCE_ROOT}/istio

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
  .metadata.name')

  if (( ${#EXISTING_PROJECTS[@]} )); then
  printf '  - %s\n' "${EXISTING_PROJECTS[@]}"
  oc delete project "${EXISTING_PROJECTS[@]}"
  fi 
  echo ""
  
  echo "Creating istio-system & istio-cni namespaces"
  oc get namespace istio-system >/dev/null 2>&1 || oc create namespace istio-system
  oc get namespace istio-cni >/dev/null 2>&1 || oc create namespace istio-cni
  echo "" 

  echo "Configuring Istio CNI"
  oc apply -f "${TEMPLATE_PATH}/istioCNI-cr.yaml"
  sleep 20
  echo ""

  echo "Configuring Istio using ${test_path}.yaml"
  oc apply -f "${TEMPLATE_PATH}/${template_file}"
  sleep 20
  echo ""

  echo "Configuring istio ingressgateway & egressgateway"
  oc delete -f "${TEMPLATE_PATH}/istio-ingressgateway.yaml" --ignore-not-found
  sleep 5
  oc delete -f "${TEMPLATE_PATH}/istio-egressgateway.yaml" --ignore-not-found
  sleep 5
  oc apply -f "${TEMPLATE_PATH}/istio-ingressgateway.yaml"
  sleep 5
  oc apply -f "${TEMPLATE_PATH}/istio-egressgateway.yaml"
  sleep 5
  echo ""

  echo "Clean pilot patches if exists"
  git restore tests/integration/pilot/gateway_conformance_test.go 2>/dev/null || true
  git restore tests/integration/pilot/testdata/gateway-conformance-manifests.yaml 2>/dev/null || true  
  echo ""

  if [[ "" == "pilot" ]]; then
  echo "apply patch until https://github.com/kubernetes-sigs/gateway-api/pull/3389 is merged"
  git apply ${SOURCE_ROOT}/jenkins-csb-declaration/resources/patches/istio-gw-api-coredns-fix.patch
  echo ""
  fi

  export STD_ARGS="-f testname --junitfile-project-name istio --junitfile ${report_dir}/junit_${RELEASE_VERSION}_${testsuite_file}_${TS}.xml --packages=./tests/integration/${test_path} --rerun-fails-max-failures=30 --debug -- -tags=integ -timeout 180m"

  export TEST_ARGS="-args -istio.test.skipWorkloads=${SKIP_WORKLOADS} -istio.test.openshift -istio.test.kube.helm.values=global.platform=openshift -istio.test.istio.enableCNI=true -istio.test.ci=true -istio.test.env=kube -istio.test.kube.deploy=false -istio.test.stableNamespaces=true -istio.test.kube.deployGatewayAPI=false -istio.test.gatewayConformance.maxTimeToConsistency=180s -istio.test.work_dir=${report_dir}/artifacts"
  
  gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$logfile" || true
  rc=${PIPESTATUS[0]}

  for _ in {1..60}; do
  [[ -s "${report_dir}/junit_${RELEASE_VERSION}_${testsuite_file}_${TS}.xml" ]] && break
  sleep 1
  done

  echo ""
  echo "[${test_path}] Test Execution Completed"
  
  mkdir -p "$JUNIT_DIR"
  cp ${report_dir}/junit_${RELEASE_VERSION}_${testsuite_file}_${TS}.xml $JUNIT_DIR/

  echo ""
  echo "------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

  return 0
}

while true; do
  read -rp "Package (pilot|security|telemetry): " GROUP
  echo ""
  [[ "$GROUP" =~ ^(pilot|security|telemetry)$ ]] && break
done

# Filter suites
GROUP_SUITES=()
for s in "${SUITES_SORTED[@]}"; do
  [[ "$s" == "$GROUP"* ]] && GROUP_SUITES+=("$s")
done
(( ${#GROUP_SUITES[@]} == 0 )) && { echo "No suites for $GROUP"; exit 1; }

# Run all?
#read -rp "Run ALL Tests Under Package '$GROUP'? (all|single): " RUN_ALL
RUN_ALL="all"

if [[ "$RUN_ALL" = "all" ]]; then
  for SUITE in "${GROUP_SUITES[@]}"; do
    run_test_suite "$SUITE"
  done
else
  echo ""
  for i in "${!GROUP_SUITES[@]}"; do
    printf "%2d) %s\n" $((i+1)) "${GROUP_SUITES[$i]}"
  done
  echo ""

  while true; do
    read -rp "Select the package test number: " n
    [[ "$n" =~ ^[0-9]+$ && n -ge 1 && n -le ${#GROUP_SUITES[@]} ]] && break
  done

  run_test_suite "${GROUP_SUITES[$((n-1))]}"
fi
