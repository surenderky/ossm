#!/bin/bash

set -euo pipefail

SOURCE_ROOT="/root"
cd "$SOURCE_ROOT"
HOSTNAME=$(hostname -s)
SCRIPT_DIR="${SOURCE_ROOT}/OCP-Setup-Automation"
CONFIG_FILE="${SCRIPT_DIR}/${HOSTNAME}.yaml"

# Cluster project type
while true; do
    read -p "Select cluster project type (ossm / other): " CLUSTER_PROJECT
    case "$CLUSTER_PROJECT" in
        ossm|other)
            break
            ;;
        *)
            echo " Invalid input. Please enter exactly 'ossm' or 'other'."
            ;;
    esac
done

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

# Promt for base domain
if [[ "$CLUSTER_PROJECT" == "ossm" ]]; then
    BASE_DOMAIN="maistra.upshift.redhat.com"
else    
    while true; do
    read -p "Enter base domain (e.g., maistra.upshift.redhat.com): " BASE_DOMAIN
    if [[ -n "$BASE_DOMAIN" ]]; then
        break
    else
        echo " Invalid input. Please enter a valid domain (e.g., maistra.upshift.redhat.com)."
    fi
done
fi

# Prompt for IPv6
while true; do
    read -p "Use IPv6? (True / False): " USE_IPV6
    case "$USE_IPV6" in
        True|False)
            break
            ;;
        *)
            echo " Invalid input. Please enter exactly 'True' or 'False'."
            ;;
    esac
done

# Prompt for FIPS
while true; do
    read -p "Enable FIPS? (True / False): " FIPS_ENABLED
    case "$FIPS_ENABLED" in
        True|False)
            break
            ;;
        *)
            echo " Invalid input. Please enter exactly 'True' or 'False'."
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
echo "You have entered:"
echo "   Cluster name     : $CLUSTER_NAME"
echo "   OpenShift version: $OCP_VERSION"
echo "   Base Domain      : $BASE_DOMAIN"
echo "   IPV6             : $USE_IPV6"
echo "   FIPS             : $FIPS_ENABLED"   
echo "   Nodes Profile    : $NODES_PROFILE"
echo "=========================================="

read -p "Do you want to continue with these settings? (yes/no): " CONFIRM
if [[ "$CONFIRM" = "yes" ]]; then
	setsid ./ossm/scripts/ocp_cluster_setup.sh $CLUSTER_NAME $OCP_VERSION $BASE_DOMAIN $USE_IPV6 $FIPS_ENABLED $NODES_PROFILE > $SOURCE_ROOT/$CLUSTER_NAME.log 2>&1 & tail -f $SOURCE_ROOT/$CLUSTER_NAME.log
else
       echo " Aborted by user."
       exit 1
fi



