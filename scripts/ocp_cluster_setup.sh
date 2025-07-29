#!/bin/bash

set -euo pipefail

# OCP version
OCP_VERSION="$1"
# Cluster name
CLUSTER_NAME="$2"

HOSTNAME=$(hostname -s)
SCRIPT_DIR="/root/OCP-Setup-Automation"
CONFIG_FILE="$HOSTNAME.yaml"

cd "$SCRIPT_DIR"

echo "Using OpenShift version: $OCP_VERSION"
echo "Using cluster name: $CLUSTER_NAME"
echo "Using location file: $CONFIG_FILE"

# Step 1: Destroy existing cluster (only if directory exists)
CLUSTER_DIR="/opt/ocp-clusters/$CLUSTER_NAME/install"
if [ -d "$CLUSTER_DIR" ]; then
  echo " Destroying cluster..."
  ./kvm_single_lpar.py -l "$CONFIG_FILE" -c "$CLUSTER_NAME" cluster-destroy
else
  echo " Skipping destroy step — directory $CLUSTER_DIR not found"
fi

# Step 2: Update cluster_version_profile only for the given cluster
echo " Updating OpenShift version for cluster '$CLUSTER_NAME' in YAML..."
sed -i "/- name: $CLUSTER_NAME/,/cluster_version_profile:/ s/cluster_version_profile: \".*\"/cluster_version_profile: \"$OCP_VERSION\"/" "$CONFIG_FILE"

# Step 3: Generate the new cluster configuration
echo " Generating cluster configuration..."
./kvm_single_lpar.py -l "$CONFIG_FILE" -c "$CLUSTER_NAME" generate

# Step 4: Start cluster creation
echo " Starting cluster creation (running in background)..."
./kvm_single_lpar.py -l "$CONFIG_FILE" -c "$CLUSTER_NAME" cluster-create

# Step 5: Extract kubeadmin password and login
echo " Logging in to $CLUSTER_NAME..."
# Extract the password from the $CLUSTER_NAME.log file
KUBEADMIN_PASSWORD=$(grep -oP 'Password:\s+\K.{23}' "/root/ocpz1-l4c.log" | tail -n 1)

if [[ -z "$KUBEADMIN_PASSWORD" ]]; then
  echo "❌ Failed to extract kubeadmin password from ocpz1-l4c.log"
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

# Step 6: Install NFS
echo " Installing NFS..."
./install_nfs.sh -l "$CONFIG_FILE" -c "$CLUSTER_NAME"
NFS_STATUS=$?

if [ $NFS_STATUS -ne 0 ]; then
  echo "❌ NFS installation failed. Exit code: $NFS_STATUS"
  exit 1
else
  echo "✅ NFS installation completed successfully."
fi

# Step 7: Update pull secrets
echo " Updating pull secret..."
oc set data secret/pull-secret -n openshift-config --from-file=/root/.dockerconfigjson
sleep 10
oc get secret/pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq

# Step 8: Configure Haproxy for http & https
echo " Updating Haproxy..."
CONFIG_HAPROXY_HTTP="/etc/haproxy/conf.d/00-openshift-http.cfg"
CONFIG_HAPROXY_HTTPS="/etc/haproxy/conf.d/00-openshift-https.cfg"

# Append the backend line to the bottom of the file
echo "    use_backend ${CLUSTER_NAME}-http if example" >> "$CONFIG_HAPROXY_HTTP"
echo "    use_backend ${CLUSTER_NAME}-https if example" >> "$CONFIG_HAPROXY_HTTPS"

echo "----- Updated $CONFIG_HAPROXY_HTTP -----"
cat "$CONFIG_HAPROXY_HTTP"

echo "----- Updated $CONFIG_HAPROXY_HTTPS -----"
cat "$CONFIG_HAPROXY_HTTPS"

# Step 9: Final Success Message
echo "✅ Succesfuly created & configured OCP $OCP_VERSION inside '$CLUSTER_NAME'."

