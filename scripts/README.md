To Run Istio Integration Test Suite

1) Run ./config-github-istio.sh to configure istio git repo branch and istio version for each different OSSM version.

	 - Example: OSSM 3.2.2 release branch is release-1.27 and istio version is v1.27.5
	 - Note: Need to configure istio git repo branch each time for every different ISTIO version. 

2) Run ./metallb-setup.sh and provide the Ip address range when asked.

3) Run ./setup-itms-idms.sh to setup images.

4) Run Jenkins downstream-pipeline-3 job to setup Servicemesh with below configuration.

     a) For 3.1.X and older version select INSTALL_OSSM_OPERATORS and INSTALL_ISTIO and run step 6.

     b) For 3.2.X and later version select INSTALL_OSSM_OPERATORS only and post job run below script to setup Ambient/Sidecar mode.

	 - For setup Ambient mode run ./ambient_mode_setup.sh and post testing ./remove_ambient_mode.sh 

	 - For setup Sidecar mode run ./sidecar_mode_setup.sh and post testing ./remove_sidecar_mode.sh

6) Run ./integration-testsuite.sh and select single or ALL to run the desired test suite.
