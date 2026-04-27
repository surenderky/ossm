Steps for Integration Testing


1) Run ./config_istio_repo.sh and provide release branch to configure openshift-service-mesh/istio git repo for each OSSM version.

   - Ex: For OSSM 3.0.8 release branch is release-1.24 and provide the Istio version ex. v1.24.6.
   - Ex: For OSSM 3.2.2 release branch is release-1.27.

2) Run ./metallb_setup.sh to setup metal load balancer with ipaddresspool & L2 advertisement.

3) Run ./setup_istio_itms_idms.sh to setup istio itms/idms image registry.

4) Run below Jenkins job to setup Servicemesh operator.

   a) Add jenkins user - https://jenkins-csb-servicemesh-master.dno.corp.redhat.com/job/infra/job/add-jenkins-user/

   b) Install Servicemesh operator - https://jenkins-csb-servicemesh-master.dno.corp.redhat.com/job/main-pipelines/job/downstream-pipeline-3/

   c) Please setup using INSTALL_OSSM_OPERATORS only, no need to setup istio Control plane.

Note:
- Logs stored at /root/logs_istio
- Artifacts stored at /root/artifacts_istio
- Junit report stored at /root/junit_istio


***For OSSM 3.0.X Versions***

1) Run ./legacy_integration_tests.sh and select test package to run Smoke test.


***For OSSM 3.1.0 and later Versions***

1) Run ./integration_tests.sh then

   a) Select Istio version (ex. v1.28.5/v1.27.8/v1.26.8).

   b) Select test mode to run with Smoke,Full or Single_test.
