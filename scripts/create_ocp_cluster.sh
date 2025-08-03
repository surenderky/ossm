#!/bin/bash

set -euo pipefail

SOURCE_ROOT="$(pwd)"

# Prompt for OCP version
read -p "Enter the OpenShift version (e.g., 4.14): " OCP_VERSION

# Prompt for OSSM version
while true; do
  read -p "Select the OSSM version from ('2.0' or '3.0'): " OSSM_VERSION
  if [[ "$OSSM_VERSION" == "2.0" || "$OSSM_VERSION" == "3.0" ]]; then
    break
  else
    echo " Invalid OSSM version. Please enter either 'OSSM2.0' or 'OSSM3.0'."
  fi
done

# Prompt for cluster name with validation
while true; do
	read -p "Select the cluster name from ('ocpz1-l4c' or 'ocpz2-l4c' or 'ocpz-standard' or 'ossm-zcluster2'): " CLUSTER_NAME
  if [[ "$CLUSTER_NAME" == "ocpz1-l4c" || "$CLUSTER_NAME" == "ocpz2-l4c" || "$CLUSTER_NAME" == "ocpz-standard" || "$CLUSTER_NAME" == "ossm-zcluster2" ]]; then
    break
  else
    echo " Invalid cluster name. Please enter either 'ocpz1-l4c' or 'ocpz2-l4c' or 'ocpz-standard' or 'ossm-zcluster2'."
  fi
done


# Confirm with before proceeding
echo
echo "=========================================="
echo "You have entered:"
echo "  ✅ OpenShift version: $OCP_VERSION"
echo "  ✅ OSSM version     : $OSSM_VERSION"
echo "  ✅ Cluster name     : $CLUSTER_NAME"
echo "=========================================="
read -p "Do you want to continue with these settings? (yes/no): " CONFIRM
if [[ "$CONFIRM" = "yes" ]]; then
       setsid ./ossm/scripts/ocp_cluster_setup.sh $OCP_VERSION $OSSM_VERSION $CLUSTER_NAME > $SOURCE_ROOT/$CLUSTER_NAME.log 2>&1 & tail -f $SOURCE_ROOT/$CLUSTER_NAME.log
else
       echo "❌ Aborted by user."
       exit 1
fi



