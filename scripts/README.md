To Run Istio Integration Test Suite

1) Run ./config_istio_repo.sh to configure openshift-service-mesh/istio git repo.

2) Run ./metallb_setup.sh and provide the Ip address range when asked.

3) Run ./setup_istio_itms_idms.sh to setup images.

4) Run Jenkins downstream-pipeline-3(https://jenkins-csb-servicemesh-master.dno.corp.redhat.com/job/main-pipelines/job/downstream-pipeline-3/) job to setup Servicemesh operator only.

5) Run ./integration_tests.sh and select Istio version (ex. v1.27.5) and then select suite to run with Smoke or Full test.

   - Note: Istio test logs will be stored at /root/logs_istio and Junit report will be stored at /root/artifacts_istio.
