#!/bin/bash

set -euo pipefail

# Check if the user is logged in
if ! oc whoami &>/dev/null; then
  echo " You are not logged into an OpenShift cluster."
  echo " Please log in using: oc login -u kubeadmin -p <password> --server=https://api.clustername.maistra.upshift.redhat.com:6443 --insecure-skip-tls-verify"
  exit 1
fi

# Show current user and cluster
echo " Logged in as: $(oc whoami)"
echo " Current cluster: $(oc whoami --show-server)"

SOURCE_ROOT="$(pwd)"
TEMPLATE_PATH="/istio/jenkins-csb-declaration/resources/ocp/templates/istio"
export PATH=$PATH:$(go env GOPATH)/bin
export TAG=ibm-z
export HUB=quay.io/maistra

echo "Configuring istio ingressgateway & egressgateway"
oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-ingressgateway.yaml
oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-egressgateway.yaml

cd ${SOURCE_ROOT}/istio

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

      # extraTestArgs line
      if (in_block && match($0, /'\''extraTestArgs'\''[[:space:]]*:[[:space:]]*'\''(.*)/, m)) {
        in_extra = 1
        extra = m[1]
        if ($0 ~ /'\''[[:space:]]*$/) {
          in_extra = 0
          sub(/'\''[[:space:]]*$/, "", extra)
          print extra
          exit
        }
        next
      }

      # multi-line continuation
      if (in_extra) {
        extra = extra "\n" $0
        if ($0 ~ /'\''[[:space:]]*$/) {
          in_extra = 0
          sub(/'\''[[:space:]]*$/, "", extra)
          print extra
          exit
        }
      }
    }
  ' "$groovy_file"
}


SUITES=(
  "telemetry/api"
  "telemetry/policy"
  "telemetry/tracing/zipkin"
  "telemetry/tracing/otelcollector"
  "security"
  "security/policy_attachment_only"
  "security/remote_jwks"
  "security/https_jwt"
  "security/filebased_tls_origination"
  "security/ecc_signature_algorithm"
  "security/ca_custom_root"
  "security/cacert_rotation"
  "pilot"
  "pilot/analysis"
)

#echo "Checking for 'ingress' namespace..."
#if oc get ns ingress >/dev/null 2>&1; then
#  echo "  -> Namespace 'ingress' exists. Deleting..."
#  oc delete ns ingress
#  echo "  -> Waiting for namespace to terminate..."
#  while oc get ns ingress >/dev/null 2>&1; do
#    sleep 5
#  done
#fi

#echo "  -> Creating 'ingress' namespace..."
#oc create namespace ingress


echo " Select a test suite to run:"
select TEST_PATH in "${SUITES[@]}"; do

if [[ -n "$TEST_PATH" ]]; then
    
        TESTSUITEFILE=$(echo "$TEST_PATH" | sed 's|/|-|g')
	TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
	LOGFILE="$TESTSUITEFILE-$TIMESTAMP.log"
        echo " You selected suite: $TEST_PATH & Log will be saved at ${SOURCE_ROOT}/$LOGFILE"
	
        export STD_ARGS="-f testname --junitfile-project-name istio --junitfile /home/jenkins/workspace/sail/istio-integration-tests-suites/${TEST_PATH}/junit-$TESTSUITEFILE-$TIMESTAMP.xml --packages=./tests/integration/${TEST_PATH} -- -tags=integ -timeout 180m"
	export TEST_ARGS="-args -istio.test.skipWorkloads=tproxy,vm -istio.test.openshift -istio.test.kube.helm.values=global.platform=openshift -istio.test.istio.enableCNI=true -istio.test.ci=true -istio.test.env=kube -istio.test.kube.deploy=false -istio.test.stableNamespaces=true -istio.test.work_dir=/home/jenkins/workspace/sail/istio-integration-tests-suites/${TEST_PATH}/artifacts"


	if [[ " ${TEST_PATH} " = " telemetry/api " ]]; then

		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-telemetry-api.yaml  

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"
	
		echo "$GET_EXTRA_TEST_ARGS"
		
		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " telemetry/policy " ]]; then
 
		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-telemetry-policy.yaml

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"
		
		echo "$GET_EXTRA_TEST_ARGS"		

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " telemetry/tracing/zipkin " ]]; then

		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-telemetry-tracing-zipkin.yaml

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"

		echo "$GET_EXTRA_TEST_ARGS"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " telemetry/tracing/otelcollector " ]]; then

		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-telemetry-tracing-otelcollector.yaml

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"

		echo "$GET_EXTRA_TEST_ARGS"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security " ]]; then

		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-security.yaml

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"
		
		echo "$GET_EXTRA_TEST_ARGS"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/policy_attachment_only " ]]; then

		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-security-policy-attachment-only.yaml

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"

		echo "$GET_EXTRA_TEST_ARGS"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/remote_jwks " ]]; then
	
		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-security-remote-jwks.yaml

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"

		echo "$GET_EXTRA_TEST_ARGS"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/https_jwt " ]]; then

		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-security-https-jwt.yaml

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"

		echo "$GET_EXTRA_TEST_ARGS"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/filebased_tls_origination " ]]; then

		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-security-filebased-tls-origination.yaml

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"

		echo "$GET_EXTRA_TEST_ARGS"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/ecc_signature_algorithm " ]]; then

		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-security-ecc-signature-algorithm.yaml

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"

		echo "$GET_EXTRA_TEST_ARGS"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/ca_custom_root " ]]; then

		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-security-ca-custom-root.yaml

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"

		echo "$GET_EXTRA_TEST_ARGS"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/cacert_rotation " ]]; then

		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-security-cacert-rotation.yaml

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

		export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"

		echo "$GET_EXTRA_TEST_ARGS"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " pilot " ]]; then

		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-pilot.yaml
		
		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"

		echo "$GET_EXTRA_TEST_ARGS"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " pilot/analysis " ]]; then

		oc apply -f ${SOURCE_ROOT}${TEMPLATE_PATH}/istio-pilot-analysis.yaml

		GET_EXTRA_TEST_ARGS="$(extract_extra_test_args ${TEST_PATH})"

                export EXTRA_TEST_ARGS="$GET_EXTRA_TEST_ARGS"

		echo "$GET_EXTRA_TEST_ARGS"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	fi
	break
  
else
    	echo " Invalid selection. Try again."
fi
done

