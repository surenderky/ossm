Integration Test Suite (Supported from OSSM 3.1+ Versions).

1) Run ./config_istio_repo.sh to configure Matej's forked openshift-service-mesh/istio git repo.

2) Run ./metallb_setup.sh and provide the Ip address range when asked.

3) Run ./setup_istio_itms_idms.sh to setup image registry.

4) Run below Jenkins job to setup Servicemesh operator.
   
   a)Add jenkins user - https://jenkins-csb-servicemesh-master.dno.corp.redhat.com/job/infra/job/add-jenkins-user/
   
   b)Install Servicemesh operator - https://jenkins-csb-servicemesh-master.dno.corp.redhat.com/job/main-pipelines/job/downstream-pipeline-3/
     
   -  Note: please setup using INSTALL_OSSM_OPERATORS only, no istio Control plane.

5) Run ./integration_tests.sh and select Istio version (ex. v1.27.5/v1.26.8) and then select testsuite to run with Smoke or Full test.

   - Note:
     - Logs stored at /root/logs_istio
     - Artifacts stored at /root/artifacts_istio
     - Junit report stored at /root/junit_istio
