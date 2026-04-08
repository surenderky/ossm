if [[ "$(oc get node -o 'jsonpath={.items[0].status.nodeInfo.architecture}')" == "390x" ]]; then
  subnet=$(oc get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' | awk -F. '{print $1"."$2"."$3}')
  ip_range="${subnet}.200-${subnet}.245"
else
  while :; do
    read -p "Enter IP range: " ip_range
    [[ -z "$ip_range" ]] && { echo "Empty range, try again."; continue; }
    read -p "Confirm '$ip_range'? (Y/N): " ok
    [[ $ok == [Yy] ]] && break
  done
fi
echo "ip_range is $ip_range"
