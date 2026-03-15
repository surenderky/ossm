For OSSM 3.1.0 and later Versions.

1) Run ./config_istio_repo.sh and provide release branch to configure openshift-service-mesh/istio git repo for each OSSM version.

   - Ex:- For OSSM 3.2.2 release branch is release-1.27.

2) Run ./metallb_setup.sh and provide the Ip address range when asked.

3) Run ./setup_istio_itms_idms.sh to setup image registry.

4) Run below Jenkins job to install stage servicemesh operator using custom catalog.

   a)Add jenkins user - https://jenkins-csb-servicemesh-master.dno.corp.redhat.com/job/infra/job/add-jenkins-user/
   
   b)Install Servicemesh operator - https://jenkins-csb-servicemesh-master.dno.corp.redhat.com/job/main-pipelines/job/downstream-pipeline-3/

   - Note: please setup using INSTALL_OSSM_OPERATORS only, no istio Control plane.

6) In case we need to skip additonal test then make sure to set IBM_SKIP="true" then we can copy sample/ibm_skip_istio_test.json file to /root/ and add skip respective test.

7) Run ./integration_tests.sh then

   a) Select testsuite to run with Smoke or Full.
   
   b) Select Istio version (ex. v1.27.5/v1.26.8).
   
   c) Select All or single test suite/subsuite.

   - Note:
     - Logs stored at /root/logs_istio
     - Artifacts stored at /root/artifacts_istio
     - Junit report stored at /root/junit_istio
