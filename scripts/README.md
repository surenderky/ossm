To Run Istio Integration Test Suite

1) Run ./config_istio_repo.sh to configure istio git repo branch and istio version for each different OSSM version.

	 - Example: OSSM 3.2.2 release branch is 1.27 and istio version is v1.27.5
	 - Note: Need to configure istio git repo branch each time for every different ISTIO version. 

2) Run ./metallb_setup.sh and provide the Ip address range when asked.

3) Run ./setup_istio_itms_idms.sh to setup images.

4) Run Jenkins downstream-pipeline-3 job to setup Servicemesh operator only.

5) Run ./integration-tests.sh and select suite to run with Smoke or Full test.

	- Note: Istio test logs will be stored at /root/logs_istio and Junit report will be stored at /root/artifacts_istio.
