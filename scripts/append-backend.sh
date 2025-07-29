#!/bin/bash

CONFIG_HAPROXY_HTTP="/etc/haproxy/conf.d/00-openshift-http.cfg"
CONFIG_HAPROXY_HTTPS="/etc/haproxy/conf.d/00-openshift-https.cfg"

# Ask user for cluster name
read -p "Enter the cluster name: " CLUSTER_NAME

# Append the backend line to the bottom of the file
echo "    use_backend ${CLUSTER_NAME}-http if example" >> "$CONFIG_HAPROXY_HTTP"
echo "    use_backend ${CLUSTER_NAME}-https if example" >> "$CONFIG_HAPROXY_HTTPS"

systemctl reload haproxy

systemctl status haproxy
