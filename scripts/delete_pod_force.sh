#!/bin/bash

# Prompt for namespace
read -p "Enter namespace: " NS
if [[ -z "$NS" ]]; then
  echo "Namespace cannot be empty."
  exit 1
fi

echo "Checking for terminating pods in namespace: $NS"

# Get pods stuck in Terminating
TERMINATING_PODS=$(oc get pods -n "$NS" | grep Terminating | awk '{print $1}')

if [[ -z "$TERMINATING_PODS" ]]; then
  echo " No terminating pods found in $NS."
  exit 0
fi

echo " Force deleting terminating pods in $NS..."
for POD in $TERMINATING_PODS; do
  echo "Deleting pod: $POD"
  oc delete pod "$POD" -n "$NS" --grace-period=0 --force --ignore-not-found=true
done

echo " Force deletion completed."

