#!/bin/bash

set -euo pipefail

read -p "Enter OSSM version: " OSSM_VERSION

SEARCH_DIR="/root/artifacts_istio/"
DEST_DIR="/root/junit_report_istio/$OSSM_VERSION"
mkdir -p "$DEST_DIR"

copied_files=$(
  find "$SEARCH_DIR" -type f \
    \( -name "*junit*" -a -name "*OSSM-$OSSM_VERSION-*" \) \
    -exec cp -vn {} "$DEST_DIR" \; 2>/dev/null
)

if [[ -n "$copied_files" ]]; then
  echo "$copied_files"
  copied_count=$(echo "$copied_files" | grep -c " -> ")
else
  echo "No new files copied."
  copied_count=0
fi
echo "Total files copied: $copied_count"
