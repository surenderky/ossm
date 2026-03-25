CLUSTER_API="https://api.ocpz3-l4c.maistra.upshift.redhat.com:6443"

for i in {1..30}; do
  if curl -k --silent --fail "$CLUSTER_API/readyz" >/dev/null; then
    echo "API Ready"
    break
  fi
  echo "Retry $i/30 : API not ready yet"
  sleep 20
done
