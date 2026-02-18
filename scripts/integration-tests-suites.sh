#!/bin/bash

set -euo pipefail

# Check OpenShift login
if ! oc whoami &>/dev/null; then
  echo "You are not logged into an OpenShift cluster."
  echo "Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  exit 1
fi

echo "Logged in as: $(oc whoami)"
echo "Current cluster: $(oc whoami --show-server)"

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
  | grep -q '^1$' && echo FIPS || echo Non-FIPS)

RELEASE_VERSION="OSSM-$OSSM_VERSION-OCP-$OCP_VERSION-$FIPS_MODE"

SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

TEMPLATE_PATH="${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio"

export PATH=$PATH:$(go env GOPATH)/bin
export HUB=quay.io/maistra

if [[ "$(uname -m)" == "s390x" ]]; then
    export TAG="ibm-z"
else
    export TAG="ibm-p"
fi

cd "${SOURCE_ROOT}/istio"

JUNIT_FOLDER="/root/junit_report_istio/istio-integration-tests-suites/$RELEASE_VERSION"
mkdir -p "$JUNIT_FOLDER"
LOG_FOLDER="/root/istio_test_logs/$RELEASE_VERSION"
mkdir -p "$LOG_FOLDER"

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
#  ["telemetry/tracing/zipkin"]="istio-telemetry-tracing-zipkin.yaml"
#  ["telemetry/tracing/otelcollector"]="istio-telemetry-tracing-otelcollector.yaml"

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
#  ["ambient/cnirepair"]="istio-ambient-cnirepair.yaml"
#  ["ambient/cniupgrade"]="istio-ambient-cniupgrade.yaml"
#  ["ambient/untaint"]="istio-ambient-untaint.yaml"
#  ["ambient/waypoint"]="istio-ambient-waypoint.yaml"
)

SUITES=("${!TEMPLATE_MAP[@]}")
SUITES_SORTED=($(printf '%s\n' "${SUITES[@]}" | sort))

cat <<EOF > istio.yaml 
  apiVersion: sailoperator.io/v1
  kind: Istio
  metadata:
    name: default
  spec:
    namespace: istio-system
    profile: default
EOF

cat <<EOF > istio-ambient.yaml
apiVersion: sailoperator.io/v1
kind: Istio
metadata:
  name: default
spec:
  namespace: istio-system
  profile: ambient
  values:
    pilot:
      trustedZtunnelNamespace: ztunnel
EOF

run_test_suite() {
  local test_path="$1"
  local template_file="${TEMPLATE_MAP[$test_path]}"
  local testsuite_file="${test_path//\//-}"
  local timestamp=$(date +"%Y%m%d-%H%M%S")
  local logfile="$LOG_FOLDER/${testsuite_file}-${timestamp}.log"
  local report_dir="$JUNIT_FOLDER/${test_path}"

  echo -e "\n==> Running test suite: $test_path"
  echo "    Log will be saved at $logfile"
  
  echo "Configuring ${test_path}.yaml"
  if [[ "$test_path" == *"ambient"* ]]; then
	  oc delete -f istio-ambient.yaml --ignore-not-found
  else
          oc delete -f istio.yaml --ignore-not-found
  fi
  sleep 5
  oc apply -f "${TEMPLATE_PATH}/${template_file}"
  sleep 20
  
  echo "Configuring istio ingressgateway & egressgateway"
  oc delete -f "${TEMPLATE_PATH}/istio-ingressgateway.yaml" --ignore-not-found
  sleep 5
  oc delete -f "${TEMPLATE_PATH}/istio-egressgateway.yaml" --ignore-not-found
  sleep 5
  oc apply -f "${TEMPLATE_PATH}/istio-ingressgateway.yaml"
  sleep 5
  oc apply -f "${TEMPLATE_PATH}/istio-egressgateway.yaml"
  sleep 5

  local get_extra_test_args
  get_extra_test_args=$(extract_extra_test_args "$test_path")
  export EXTRA_TEST_ARGS="$get_extra_test_args"

  export STD_ARGS="-f testname --junitfile-project-name istio --junitfile ${report_dir}/$RELEASE_VERSION-junit-${testsuite_file}-${timestamp}.xml --packages=./tests/integration/${test_path} -- -tags=integ -timeout 180m"
  
  ISTIO_VERSION=$(oc get istio -A -o jsonpath='{.items[0].spec.version}' 2>/dev/null)
  ISTIO_VERSION_NUM="${ISTIO_VERSION#v}"  
  ISTIO_VERSION_NUM=$(oc get istio -A -o jsonpath='{.items[0].spec.version}' 2>/dev/null | sed 's/^v//')

  if [ "$(printf '%s\n' "$ISTIO_VERSION_NUM" "1.24.6" | sort -V | head -n1)" = "$ISTIO_VERSION_NUM" ]; then
  # ISTIO_VERSION_NUM is <= 1.24.6
  SKIP_WORKLOADS="tproxy,vm"
  else
  # ISTIO_VERSION_NUM is > 1.24.6
  SKIP_WORKLOADS="tproxy,vm"
  fi

export TEST_ARGS=""

if [[ "$test_path" == *"ambient"* ]]; then
   export TEST_ARGS="-args -istio.test.skipWorkloads=${SKIP_WORKLOADS} -istio.test.openshift -istio.test.kube.helm.values=global.platform=openshift,pilot.trustedZtunnelNamespace=ztunnel -istio.test.istio.enableCNI=true -istio.test.ci=true -istio.test.env=kube -istio.test.kube.deploy=false -istio.test.stableNamespaces=true -istio.test.kube.deployGatewayAPI=false -istio.test.gatewayConformance.maxTimeToConsistency=180s -istio.test.work_dir=${report_dir}/artifacts -istio.test.ambient"
else
   export TEST_ARGS="-args -istio.test.skipWorkloads=${SKIP_WORKLOADS} -istio.test.openshift -istio.test.kube.helm.values=global.platform=openshift -istio.test.istio.enableCNI=true -istio.test.ci=true -istio.test.env=kube -istio.test.kube.deploy=false -istio.test.stableNamespaces=true -istio.test.kube.deployGatewayAPI=false -istio.test.gatewayConformance.maxTimeToConsistency=180s -istio.test.work_dir=${report_dir}/artifacts"
fi

  echo "Using this Args = gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS}"
 
  gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$logfile"

}

unset GROUP
unset GROUP_LIST

GROUP_LIST=("telemetry" "pilot" "security" "ambient")

echo "Select a group:"
select GROUP in "${GROUP_LIST[@]}"; do
  [[ -n "$GROUP" ]] && break
  echo "Invalid selection. Try again."
done

# Build suite list for the selected group
GROUP_SUITES=()
for s in "${SUITES[@]}"; do
  [[ "$s" == "$GROUP"* ]] && GROUP_SUITES+=("$s")
done

if [[ ${#GROUP_SUITES[@]} -eq 0 ]]; then
  echo "No test suites found for group: $GROUP"
  exit 1
fi

echo "Select a test suite:"
select SUITE in "${GROUP_SUITES[@]}"; do
  [[ -z "$SUITE" ]] && echo "Invalid selection" && continue
  run_test_suite "$SUITE"
  break
done
