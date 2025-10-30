#!/bin/bash
set -e

rm -rf ibm-images/istio
read -p "Enter branch name: " BRANCH
git clone --branch "$BRANCH" https://github.com/istio/istio.git ibm-images/istio

cd ibm-images/istio/
git apply /root/ossm/scripts/patch/istio-app-$BRANCH.patch

cp tests/testdata/certs/cert.crt pkg/test/echo/docker/
cp tests/testdata/certs/cert.key pkg/test/echo/docker/

go build -o pkg/test/echo/docker/ istio.io/istio/pkg/test/echo/cmd/client
go build -o pkg/test/echo/docker/ istio.io/istio/pkg/test/echo/cmd/server

podman build -f pkg/test/echo/docker/Dockerfile.app -t quay.io/maistra/app:ibm-z pkg/test/echo/docker
#podman push quay.io/maistra/app:ibm-z
