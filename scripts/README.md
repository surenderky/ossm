To Run Istio Integration Test Suite

1) Run ./ossm/scripts/config-github-istio.sh to configure istio git repo branch and istio version for each different OSSM version.

	Example: OSSM 3.2.X release branch is release-1.27
		            istio version is v1.27.3

2) Run ./ossm/scripts/metallb-setup.sh and provide the Ip address range when asked.

3) Run ./ossm/scripts/setup-itms-idms.sh to setup images.

4) Run Jenkins downstream-pipeline-3 to setup Servicemesh.

        For Ambient INSTALL_OSSM_OPERATORS and INSTALL_ISTIO.
        For Sidecar select INSTALL_OSSM_OPERATORS only.

5) From 3.2.X the default mode is Ambient so Run ./ossm/scripts/sidecar_mode_setup.sh to setup sidecar mode.

6) Run ./ossm/scripts/integration-testsuite.sh and select single or group test suite to run the test suite.
