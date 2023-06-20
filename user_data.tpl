#!/bin/bash

SERVER_NAME="${server_name}"
PRIVATE_IP=$(curl -s http://169.254.169.254/hetzner/v1/metadata/private-networks | grep -m1 ip: | awk '{print $NF}')

%{ if server_name != "frontend" ~}
  INSTALL_$${SERVER_NAME^^}='y'
  $${SERVER_NAME^^}_SERVER_IP='$${PRIVATE_IP}'
%{ endif ~}

%{ if server_name == "frontend" ~}
  MARIADB_SERVER_IP="${hcloud_server.this["mariadb"].network.*.ip[0]}"
  REDIS_SERVER_IP="${hcloud_server.this["redis"].network.*.ip[0]}"
  RABBITMQ_SERVER_IP="${hcloud_server.this["rabbitmq"].network.*.ip[0]}"
  VARNISH_SERVER_IP="${hcloud_server.this["varnish"].network.*.ip[0]}"
  ELASTICSEARCH_SERVER_IP="${hcloud_server.this["elasticsearch"].network.*.ip[0]}"
%{ endif ~}
