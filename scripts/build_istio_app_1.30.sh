cd ~

rm -rf ibm-images/istio

git clone --branch release-1.30 https://github.com/istio/istio.git ibm-images/istio
cd ibm-images/istio/

cd /tmp
curl -LO https://go.dev/dl/go1.25.9.linux-s390x.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.25.9.linux-s390x.tar.gz
export PATH=/usr/local/go/bin:$PATH
go version          # go1.25.9 linux/s390x
cd ~/ibm-images/istio

go build -o pkg/test/echo/docker/ istio.io/istio/pkg/test/echo/cmd/client
go build -o pkg/test/echo/docker/ istio.io/istio/pkg/test/echo/cmd/server

mkdir -p pkg/test/echo/docker/s390x
mv pkg/test/echo/docker/client pkg/test/echo/docker/s390x/
mv pkg/test/echo/docker/server pkg/test/echo/docker/s390x/

mkdir -p pkg/test/echo/docker/dns
cp tests/testdata/certs/dns/cert-chain.pem pkg/test/echo/docker/dns/
cp tests/testdata/certs/dns/key.pem        pkg/test/echo/docker/dns/
ls pkg/test/echo/docker/dns/

python3 - <<'EOF'
import pathlib
p = pathlib.Path("pkg/test/echo/docker/Dockerfile.app")
t = p.read_text()
t = t.replace("FROM ${ISTIO_BASE_REGISTRY}/base:${BASE_VERSION}", "FROM ubuntu:noble-s390x")
p.write_text(t)
print("done")
EOF

podman build -f pkg/test/echo/docker/Dockerfile.app -t quay.io/maistra/app:ibm-z-3-4 pkg/test/echo/docker

podman image inspect quay.io/maistra/app:ibm-z-3-4 --format '{{.Architecture}}'   # s390x
#podman run --rm quay.io/maistra/app:ibm-z-3-4   # Ctrl-C after "Echo server is now ready"

#podman push quay.io/maistra/app:ibm-z-3-4
