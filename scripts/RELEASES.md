To Run Istio Integration Test Suite

1) Run ./ossm/scripts/config-github-istio.sh to configure istio locally to run tests
2) Need to run ./ossm/scripts/metallb-setup.sh and provide the Ip address range when asked.
3) Run Jenkins downstream-pipeline-3 to setup Servicemesh and Kiali.
4) Run ./ossm/scripts/setup-itms-idms.sh to setup images for Z&P.
5) Run ./ossm/scripts/integration-testsuite.sh  and select the test suite number listed.
