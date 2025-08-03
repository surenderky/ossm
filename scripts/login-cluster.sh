#!/bin/bash

SOURCE_ROOT="$(pwd)"

# Prompt for cluster name with validation
while true; do
        read -p "Select the cluster name from ('ocpz1-l4c' or 'ocpz2-l4c' or 'ocpz-standard' or 'ossm-zcluster2'): " CLUSTER_NAME
  if [[ "$CLUSTER_NAME" == "ocpz1-l4c" || "$CLUSTER_NAME" == "ocpz2-l4c" || "$CLUSTER_NAME" == "ocpz-standard" || "$CLUSTER_NAME" == "ossm-zcluster2" ]]; then
    break
  else
    echo " Invalid cluster name. Please enter either 'ocpz1-l4c' or 'ocpz2-l4c' or 'ocpz-standard' or 'ossm-zcluster2'."
  fi
done

# Extract the password from the $CLUSTER_NAME.log file
KUBEADMIN_PASSWORD=$(grep -oP 'Password:\s+\K.{23}' "$SOURCE_ROOT/$CLUSTER_NAME.log" | tail -n 1)

if [[ -z "$KUBEADMIN_PASSWORD" ]]; then
  echo "❌ Failed to extract kubeadmin password from $CLUSTER_NAME.log"
  exit 1
fi

# Construct the cluster API URL
CLUSTER_API="https://api.$CLUSTER_NAME.maistra.upshift.redhat.com:6443"

# Attempt login
oc login -u kubeadmin -p "$KUBEADMIN_PASSWORD" --server="$CLUSTER_API" --insecure-skip-tls-verify

if [[ $? -ne 0 ]]; then
  echo "❌ Failed to login to cluster using kubeadmin credentials."
  exit 1
fi

echo "✅ Successfully logged into cluster $CLUSTER_NAME"
