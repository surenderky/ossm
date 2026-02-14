#!/bin/bash

set -euo pipefail

HOSTNAME=$(hostname -s)
SOURCE_ROOT="/root"
SCRIPT_DIR="${SOURCE_ROOT}/OCP-Setup-Automation"
CONFIG_FILE="${SCRIPT_DIR}/${HOSTNAME}.yaml"

cd "$SCRIPT_DIR"

# Select cluster name
echo "Available clusters:"
grep -E '^[[:space:]]{2}-[[:space:]]+name:' "$CONFIG_FILE" | awk '{print $3}'
read -p "Enter cluster name: " CLUSTER_NAME
# Prompt for cluster name with validation
if ! grep -qE "^[[:space:]]{2}-[[:space:]]+name:[[:space:]]+$CLUSTER_NAME\$" "$CONFIG_FILE"; then
  echo " Cluster '$CLUSTER_NAME' not found in $CONFIG_FILE"
  exit 1
fi

CLUSTER_DIR="/opt/ocp-clusters/$CLUSTER_NAME/install"
if [ -d "$CLUSTER_DIR" ]; then
  echo " Destroying cluster..."
  ./kvm_single_lpar.py -l "$CONFIG_FILE" -c "$CLUSTER_NAME" cluster-destroy
else
  echo " Skipping destroy step — directory $CLUSTER_DIR not found"
fi
