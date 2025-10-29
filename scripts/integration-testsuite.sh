#!/bin/bash

set -euo pipefail

# Check OpenShift login
if ! oc whoami &>/dev/null; then
  echo " You are not logged into an OpenShift cluster."
  echo " Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  exit 1
fi

echo " Logged in as: $(oc whoami)"
echo " Current cluster: $(oc whoami --show-server)"

SOURCE_ROOT="/root"
TEMPLATE_PATH="${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio"
export PATH=$PATH:$(go env GOPATH)/bin
export TAG=ibm-z
export HUB=quay.io/maistra

echo "Configuring istio ingressgateway & egressgateway"
oc apply -f "${TEMPLATE_PATH}/istio-ingressgateway.yaml"
oc apply -f "${TEMPLATE_PATH}/istio-egressgateway.yaml"

cd "${SOURCE_ROOT}/istio"

extract_extra_test_args() {
  local block_name="$1"
  local groovy_file="$SOURCE_ROOT/istio/jenkins-csb-declaration/vars/istioIntegrationTestData.groovy"

  awk -v block_name="$block_name" '
    BEGIN {
      in_block = 0
      in_extra = 0
      extra = ""
      pattern = "^[[:space:]]*'\''" block_name "'\''[[:space:]]*:[[:space:]]*\\{[[:space:]]*\\["
    }

    {
      # Start of block
      if ($0 ~ pattern) {
        in_block = 1
        next
      }

      # End of block
      if (in_block && $0 ~ /\][[:space:]]*\},?/) {
        in_block = 0
      }

      # Start of extraTestArgs
      if (in_block && match($0, /'\''extraTestArgs'\''[[:space:]]*:[[:space:]]*'\''(.*)/, m)) {
        in_extra = 1
        extra = m[1]
        if ($0 ~ /'\''[[:space:]]*,?[[:space:]]*$/) {
          in_extra = 0
          sub(/'\''[[:space:]]*,?[[:space:]]*$/, "", extra)
          print extra
          exit
        }
        next
      }

      # Multiline continuation
      if (in_extra) {
        extra = extra "\n" $0
        if ($0 ~ /'\''[[:space:]]*,?[[:space:]]*$/) {
          in_extra = 0
          sub(/'\''[[:space:]]*,?[[:space:]]*$/, "", extra)
          print extra
          exit
        }
      }
    }
  ' "$groovy_file"
}

# Add test suite for template mapping
declare -A TEMPLATE_MAP=(
  # Telemetry
  ["telemetry/api"]="istio-telemetry-api.yaml"
  ["telemetry/policy"]="istio-telemetry-policy.yaml"
  ["telemetry/tracing/zipkin"]="istio-telemetry-tracing-zipkin.yaml"
  ["telemetry/tracing/otelcollector"]="istio-telemetry-tracing-otelcollector.yaml"

  # Security
  ["security"]="istio-security.yaml"
  ["security/policy_attachment_only"]="istio-security-policy-attachment-only.yaml"
  ["security/remote_jwks"]="istio-security-remote-jwks.yaml"
  ["security/https_jwt"]="istio-security-https-jwt.yaml"
  ["security/filebased_tls_origination"]="istio-security-filebased-tls-origination.yaml"
  ["security/ecc_signature_algorithm"]="istio-security-ecc-signature-algorithm.yaml"
  ["security/ca_custom_root"]="istio-security-ca-custom-root.yaml"
  ["security/cacert_rotation"]="istio-security-cacert-rotation.yaml"

  # Pilot
  ["pilot"]="istio-pilot.yaml"
  ["pilot/analysis"]="istio-pilot-analysis.yaml"

  # Ambient
  ["ambient"]="istio-ambient.yaml"
  ["ambient/cni"]="istio-ambient-cni.yaml"
  ["ambient/cnirepair"]="istio-ambient-cnirepair.yaml"
  ["ambient/cniupgrade"]="istio-ambient-cniupgrade.yaml"
  ["ambient/untaint"]="istio-ambient-untaint.yaml"
  ["ambient/waypoint"]="istio-ambient-waypoint.yaml"
)

SUITES=("${!TEMPLATE_MAP[@]}")
SUITES_SORTED=($(printf '%s\n' "${SUITES[@]}" | sort))

run_test_suite() {
  local test_path="$1"
  local template_file="${TEMPLATE_MAP[$test_path]}"
  local testsuite_file="${test_path//\//-}"
  local timestamp=$(date +"%Y%m%d-%H%M%S")
  local logfile="${SOURCE_ROOT}/${testsuite_file}-${timestamp}.log"
  local report_dir="/home/jenkins/workspace/sail/istio-integration-tests-suites/${test_path}"

  echo -e "\n==> Running test suite: $test_path"
  echo "    Log will be saved at $logfile"

  oc apply -f "${TEMPLATE_PATH}/${template_file}"

  local get_extra_test_args
  get_extra_test_args=$(extract_extra_test_args "$test_path")
  export EXTRA_TEST_ARGS="$get_extra_test_args"
  echo "$get_extra_test_args"

  export STD_ARGS="-f testname --junitfile-project-name istio --junitfile ${report_dir}/junit-${testsuite_file}-${timestamp}.xml --packages=./tests/integration/${test_path} -- -tags=integ -timeout 180m"
  export TEST_ARGS="-args -istio.test.skipWorkloads=tproxy,vm -istio.test.openshift -istio.test.kube.helm.values=global.platform=openshift -istio.test.istio.enableCNI=true -istio.test.ci=true -istio.test.env=kube -istio.test.kube.deploy=false -istio.test.stableNamespaces=true -istio.test.work_dir=${report_dir}/artifacts"

  gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$logfile"
}

# Prompt user to select test suite
echo "Choose an option:"
options=("Run Single Test Suites" "Run All Test Suite")
select opt in "${options[@]}"; do
  case $REPLY in
    2)
      for suite in "${SUITES_SORTED[@]}"; do
        run_test_suite "$suite"
      done
      break
      ;;
    1)
      echo "Select a test suite:"
      select TEST_PATH in "${SUITES_SORTED[@]}"; do
        if [[ -n "$TEST_PATH" ]]; then
          run_test_suite "$TEST_PATH"
          break 2
        else
          echo "Invalid selection. Try again."
        fi
      done
      ;;
    *)
      echo "Invalid option. Try again."
      ;;
  esac
done

