
For OSSM 3.0.X Versions.

1) Run ./legacy_config_istio_repo.sh and provide istio version to configure openshift-service-mesh/istio git repo .

   Ex:- For OSSM 3.0.8 istio version is v1.24.6.

2) Run ./metallb_setup.sh and provide the Ip address range if asked.

3) Run ./setup_istio_itms_idms.sh to setup image registry.

4) Run below Jenkins job to setup Servicemesh operator.

   a)Add jenkins user - https://jenkins-csb-servicemesh-master.dno.corp.redhat.com/job/infra/job/add-jenkins-user/

   b)Install Servicemesh operator - https://jenkins-csb-servicemesh-master.dno.corp.redhat.com/job/main-pipelines/job/downstream-pipeline-3/

   -  Note: please setup using INSTALL_OSSM_OPERATORS only, no istio Control plane.

5) Run ./legacy_integration_tests.sh and select test package to run with Smoke or Full test.

   - Note:
     - Logs stored at /root/logs_istio
     - Artifacts stored at /root/artifacts_istio
     - Junit report stored at /root/junit_istio

------------------------------------------------------------------------------------------------------------------------------------------------------------------------

For OSSM 3.1.0 and later Versions.

1) Run ./config_istio_repo.sh and provide release branch to configure openshift-service-mesh/istio git repo for each OSSM version.

   - Ex:- For OSSM 3.2.2 release branch is release-1.27.

2) Run ./metallb_setup.sh and provide the Ip address range if asked.

3) Run ./setup_istio_itms_idms.sh to setup image registry.

4) Run below Jenkins job to install stage servicemesh operator using custom catalog.

   a)Add jenkins user - https://jenkins-csb-servicemesh-master.dno.corp.redhat.com/job/infra/job/add-jenkins-user/
   
   b)Install Servicemesh operator - https://jenkins-csb-servicemesh-master.dno.corp.redhat.com/job/main-pipelines/job/downstream-pipeline-3/

   - Note: please setup using INSTALL_OSSM_OPERATORS only, no istio Control plane.

5) Run ./integration_tests.sh then

   a) Select Istio version (ex. v1.28.5/v1.27.8/v1.26.8).

   b) Select test mode to run with Smoke,Full or Single_test.

6) In case we need to skip additonal test then we need to run script with argument ibm, also we need to copy sample/ibm_skip_istio_test.json file to /root/ and add skip respective test.
   
   - Ex:- ./integration_tests.sh ibm
   
   - Note:
     - Logs stored at /root/logs_istio
     - Artifacts stored at /root/artifacts_istio
     - Junit report stored at /root/junit_istio
