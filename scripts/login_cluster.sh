#!/bin/bash

SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SOURCE_ROOT"
HOSTNAME=$(hostname -s)
SCRIPT_DIR="/root/OCP-Setup-Automation"
CONFIG_FILE="${SCRIPT_DIR}/${HOSTNAME}.yaml"

# Select cluster name
echo "Available clusters:"
grep -E '^[[:space:]]{2}-[[:space:]]+name:' "$CONFIG_FILE" | awk '{print $3}'
echo ""
read -p "Enter cluster name: " CLUSTER_NAME
echo ""
# Prompt for cluster name with validation
if ! grep -qE "^[[:space:]]{2}-[[:space:]]+name:[[:space:]]+$CLUSTER_NAME\$" "$CONFIG_FILE"; then
  echo " Cluster '$CLUSTER_NAME' not found in $CONFIG_FILE"
  echo ""
  exit 1
fi

# Extract the password from the $CLUSTER_NAME.log file
KUBEADMIN_PASSWORD=$(grep -oP 'Password:\s+\K.{23}' "/root/$CLUSTER_NAME.log" | tail -n 1)

if [[ -z "$KUBEADMIN_PASSWORD" ]]; then
  echo "Failed to extract kubeadmin password from $CLUSTER_NAME.log"
  echo ""
  exit 1
fi

# Construct the cluster API URL
CLUSTER_API="https://api.$CLUSTER_NAME.maistra.upshift.redhat.com:6443"

# Attempt login
oc login -u kubeadmin -p "$KUBEADMIN_PASSWORD" --server="$CLUSTER_API" --insecure-skip-tls-verify
echo ""
if [[ $? -ne 0 ]]; then
  echo "Failed to login to cluster using kubeadmin credentials."
  echo ""
  exit 1
fi

./cluster_details.sh
