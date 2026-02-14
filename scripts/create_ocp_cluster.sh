#!/bin/bash

set -euo pipefail

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

# Prompt for OCP version
while true; do
    read -p "Enter the OpenShift version (e.g., 4.yy): " OCP_VERSION
    if [[ -n "$OCP_VERSION" ]]; then
        break
    else
        echo " Invalid input. Please enter a valid version (e.g., 4.18)."
    fi
done

# Promt for Disconnected Mode
while true; do
    read -p "Enable Disconnected mode? (True / False) : " DISCONNECTED_ENABLED

    # If user presses Enter, set default
    DISCONNECTED_ENABLED=${DISCONNECTED_ENABLED:-False}

    case "$DISCONNECTED_ENABLED" in
        True|False)
            break
            ;;
        *)
            echo "❌ Invalid input. Please enter exactly 'True' or 'False', or press Enter for default."
            ;;
    esac
done

# Prompt for IPv6
#while true; do
#    read -p "Enable IPv6? (True / False) : " IPV6_ENABLED
#    # Default to False if no input is provided
#    IPV6_ENABLED=${IPV6_ENABLED:-False}
#    case "$IPV6_ENABLED" in
#        True|False)
#            break
#            ;;
#        *)
#            echo " Invalid input. Please enter exactly 'True' or 'False'."
#            ;;
#    esac
#done

# Prompt for FIPS
while true; do
    read -p "Enable FIPS? (True / False) : " FIPS_ENABLED

    # Default to False if no input is provided
    FIPS_ENABLED=${FIPS_ENABLED:-False}

    case "$FIPS_ENABLED" in
        True|False)
            break
            ;;
        *)
            echo "❌ Invalid input. Please enter exactly 'True' or 'False', or press Enter for default."
            ;;
    esac
done

# Prompt for cluster nodes profile
while true; do
    read -p "Enter cluster nodes profile (x-small / x-small-with-infra / small / medium / large): " NODES_PROFILE
    case "$NODES_PROFILE" in
        x-small|x-small-with-infra|small|medium|large)
            break
            ;;
        *)
            echo " Invalid input. Please enter one of: x-small, x-small-with-infra, small, medium, large."
            ;;
    esac
done

# Confirm with before proceeding

echo "=========================================="
echo "You have selected:"
echo "   Cluster name         : $CLUSTER_NAME"
echo "   OpenShift version    : $OCP_VERSION"
echo "   Disconnected Enabled : $DISCONNECTED_ENABLED"
#echo "   IPV6 Enabled        : $IPV6_ENABLED"
echo "   FIPS Enabled         : $FIPS_ENABLED"   
echo "   Nodes Profile        : $NODES_PROFILE"
echo "=========================================="

read -p "Do you want to continue with these settings? (yes/no): " CONFIRM
if [[ "$CONFIRM" = "yes" ]]; then
        setsid ./ossm/scripts/ocp_cluster_setup.sh $CLUSTER_NAME $OCP_VERSION $DISCONNECTED_ENABLED $FIPS_ENABLED $NODES_PROFILE > $SOURCE_ROOT/$CLUSTER_NAME.log 2>&1 & tail -f $SOURCE_ROOT/$CLUSTER_NAME.log
else
       echo " Aborted by user."
       exit 1
fi
