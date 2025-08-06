#!/bin/bash

# Prompt for cluster name with validation
while true; do
	read -p "Select the cluster name from ('ocpz1-l4c' or 'ocpz2-l4c' or 'ocpz-standard' or 'ossm-zcluster2'): " CLUSTER_NAME
  if [[ "$CLUSTER_NAME" == "ocpz1-l4c" || "$CLUSTER_NAME" == "ocpz2-l4c" || "$CLUSTER_NAME" == "ocpz-standard" || "$CLUSTER_NAME" == "ossm-zcluster2" ]]; then
    break
  else
    echo " Invalid cluster name. Please enter either 'ocpz1-l4c' or 'ocpz2-l4c' or 'ocpz-standard' or 'ossm-zcluster2'."
  fi
done

echo " Updating HAproxy..."
CONFIG_HAPROXY_HTTP="/etc/haproxy/conf.d/00-openshift-http.cfg"
CONFIG_HAPROXY_HTTPS="/etc/haproxy/conf.d/00-openshift-https.cfg"

        # Append the backend line to the bottom of the file
        echo "    use_backend ${CLUSTER_NAME}-http if example" >> "$CONFIG_HAPROXY_HTTP"
        echo "    use_backend ${CLUSTER_NAME}-https if example" >> "$CONFIG_HAPROXY_HTTPS"

        cat "$CONFIG_HAPROXY_HTTP"

        cat "$CONFIG_HAPROXY_HTTPS"

echo " Restarting HAproxy..."
    	systemctl restart haproxy
    	if systemctl is-active --quiet haproxy; then
        	echo "HAProxy has been successfully restarted."
    	else
        	echo "Failed to restart HAProxy."
    	fi
