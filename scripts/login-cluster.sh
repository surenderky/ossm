#!/bin/bash

SOURCE_ROOT="/root"
cd "$SOURCE_ROOT"
HOSTNAME=$(hostname -s)
SCRIPT_DIR="${SOURCE_ROOT}/OCP-Setup-Automation"
CONFIG_FILE="${SCRIPT_DIR}/${HOSTNAME}.yaml"

# Select cluster name
echo "Available clusters:"
grep -E '^[[:space:]]{2}-[[:space:]]+name:' "$CONFIG_FILE" | awk '{print $3}'
read -p "Enter cluster name: " CLUSTER_NAME
# Prompt for cluster name with validation
if ! grep -qE "^[[:space:]]{2}-[[:space:]]+name:[[:space:]]+$CLUSTER_NAME\$" "$CONFIG_FILE"; then
  echo " Cluster '$CLUSTER_NAME' not found in $CONFIG_FILE"
  exit 1
fi

# Extract the password from the $CLUSTER_NAME.log file
KUBEADMIN_PASSWORD=$(grep -oP 'Password:\s+\K.{23}' "$SOURCE_ROOT/$CLUSTER_NAME.log" | tail -n 1)

if [[ -z "$KUBEADMIN_PASSWORD" ]]; then
  echo "Failed to extract kubeadmin password from $CLUSTER_NAME.log"
  exit 1
fi

# Construct the cluster API URL
CLUSTER_API="https://api.$CLUSTER_NAME.maistra.upshift.redhat.com:6443"

# Attempt login
oc login -u kubeadmin -p "$KUBEADMIN_PASSWORD" --server="$CLUSTER_API" --insecure-skip-tls-verify

if [[ $? -ne 0 ]]; then
  echo "Failed to login to cluster using kubeadmin credentials."
  exit 1
fi

echo "Cluster Console = https://console-openshift-console.apps.$CLUSTER_NAME.maistra.upshift.redhat.com"
echo "Cluster API = https://api.$CLUSTER_NAME.maistra.upshift.redhat.com:6443"
echo "Cluster Password = $KUBEADMIN_PASSWORD "
echo "Successfully logged into cluster $CLUSTER_NAME"
