#!/bin/bash

read -p "Enter the cluster name (e.g., ocpz1-l4c,ocpz2-l4c): " CLUSTER

if [[ -z "$CLUSTER" ]]; then
  echo "Cluster name is required."
  exit 1
fi

MATCHING_VMS=$(virsh list --all --name | grep "$CLUSTER")

if [[ -z "$MATCHING_VMS" ]]; then
  echo "No VMs found matching cluster: $CLUSTER"
  exit 0
fi

echo "Forcefully destroying and undefining the following VMs:"
echo "$MATCHING_VMS"
echo

for VM in $MATCHING_VMS; do
  echo "Destroying $VM..."
  virsh destroy "$VM" 2>/dev/null

  echo "Undefining $VM..."
  virsh undefine "$VM" 2>/dev/null

  echo "$VM destroyed and undefined."
  echo "-------------------------------"
done

