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

SOURCE_ROOT="/root"

export PATH=$PATH:$(go env GOPATH)/bin
export TAG=ibm-z
export HUB=quay.io/maistra

echo "Configuring istio ingressgateway & egressgateway"
oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-ingressgateway.yaml
oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-egressgateway.yaml

cd ${SOURCE_ROOT}/istio

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
        echo " You selected suite: $TEST_PATH & Log will be saved at ${SOURCE_ROOT}/istio/tests/integration/$LOGFILE"
	
       #export STD_ARGS="--format short-verbose --junitfile $TESTSUITEFILE-$TIMESTAMP.xml -- -tags=integ -timeout 180m"
	
       # export STD_ARGS="-f testname --junitfile-project-name istio --junitfile /home/jenkins/workspace/sail/istio-integration-tests-suites/${TEST_PATH}/junit-$TESTSUITEFILE-$TIMESTAMP.xml --rerun-fails --packages=./tests/integration/${TEST_PATH} --rerun-fails-max-failures=30 --debug -- -tags=integ -timeout 180m"	
        export STD_ARGS="-f testname --junitfile-project-name istio --junitfile /home/jenkins/workspace/sail/istio-integration-tests-suites/${TEST_PATH}/junit-$TESTSUITEFILE-$TIMESTAMP.xml --packages=./tests/integration/${TEST_PATH} -- -tags=integ -timeout 180m"
	export TEST_ARGS="-args -istio.test.skipWorkloads=tproxy,vm -istio.test.openshift -istio.test.kube.helm.values=global.platform=openshift -istio.test.istio.enableCNI=true -istio.test.ci=true -istio.test.env=kube -istio.test.kube.deploy=false -istio.test.stableNamespaces=true -istio.test.work_dir=/home/jenkins/workspace/sail/istio-integration-tests-suites/${TEST_PATH}/artifacts"

	if [[ " ${TEST_PATH} " = " telemetry/api " ]]; then

		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-telemetry-api.yaml  
		
		export EXTRA_TEST_ARGS="-test.skip TestCustomizeMetrics|TestDashboard/pilot-dashboard.json|TestStatsGatewayServerTCPFilter|TestImagePullPolicy/OCI_initial_creation_with_0.0.1|TestImagePullPolicy/OCI_upstream_is_upgraded_to_0.0.2,_but_0.0.1_is_already_present_and_policy_is_IfNotPresent|TestImagePullPolicy/OCI_upstream_is_upgraded_to_0.0.2,_but_0.0.1_is_already_present_and_policy_is_default|TestImagePullPolicy/OCI_upstream_is_upgraded_to_0.0.2._0.0.1_is_already_present_but_policy_is_Always,_so_pull_0.0.2|TestGatewaySelection/OCI_initial_creation_with_latest_for_a_gateway|TestGatewaySelection/OCI_initial_creation_with_latest_for_a_gateway|TestImagePullPolicyWithHTTP"
  
		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " telemetry/policy " ]]; then
 
		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-telemetry-policy.yaml

		export EXTRA_TEST_ARGS=""

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " telemetry/tracing/zipkin " ]]; then

		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-telemetry-tracing-zipkin.yaml

		export EXTRA_TEST_ARGS=""

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " telemetry/tracing/otelcollector " ]]; then

		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-telemetry-tracing-otelcollector.yaml

		export EXTRA_TEST_ARGS=""

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security " ]]; then

		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-security.yaml

		export EXTRA_TEST_ARGS="-test.skip TestAuthz_CustomServer|TestMultiMtlsGateway|TestMultiTlsGateway|TestNormalization"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/policy_attachment_only " ]]; then

		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-security-policy-attachment-only.yaml

		export EXTRA_TEST_ARGS=""

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/remote_jwks " ]]; then
	
		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-security-remote-jwks.yaml

		export EXTRA_TEST_ARGS=""

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/https_jwt " ]]; then

		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-security-https-jwt.yaml

		export EXTRA_TEST_ARGS=""

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/filebased_tls_origination " ]]; then

		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-security-filebased-tls-origination.yaml

		export EXTRA_TEST_ARGS="-test.skip TestEgressGatewayTls/Mutual_TLS_origination_from_egress_gateway_to_https_endpoint|TestEgressGatewayTls/SIMPLE_TLS_origination_from_egress_gateway_to_https_endpoint"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/ecc_signature_algorithm " ]]; then

		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-security-ecc-signature-algorithm.yaml

		export EXTRA_TEST_ARGS=""

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/ca_custom_root " ]]; then

		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-security-ca-custom-root.yaml

		export EXTRA_TEST_ARGS=""

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " security/cacert_rotation " ]]; then

		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-security-cacert-rotation.yaml

		export EXTRA_TEST_ARGS=""

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " pilot " ]]; then

		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-pilot.yaml

		export EXTRA_TEST_ARGS="-test.skip TestCustomGateway/helm.*|TestCNIRaceRepair|TestValidation|TestWebhook|TestTraffic/gateway/cipher_suite|TestGatewayConformance"

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	elif [[ " ${TEST_PATH} " = " pilot/analysis " ]]; then

		oc apply -f ${SOURCE_ROOT}/istio/jenkins-csb-declaration/resources/ocp/templates/istio/istio-pilot-analysis.yaml

		export EXTRA_TEST_ARGS=""

		gotestsum ${STD_ARGS} ${TEST_ARGS} ${EXTRA_TEST_ARGS} 2>&1 | tee "$LOGFILE"

	fi
	break
  
else
    	echo " Invalid selection. Try again."
fi
done

