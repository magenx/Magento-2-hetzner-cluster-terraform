#!/bin/bash

SERVER_NAME="${server_name}"
PRIVATE_IP=$(curl -s http://169.254.169.254/hetzner/v1/metadata/private-networks | grep -m1 ip: | awk '{print $NF}')

%{ if server_name != "frontend" ~}
  INSTALL_$${SERVER_NAME^^}='y'
  $${SERVER_NAME^^}_SERVER_IP='$${PRIVATE_IP}'
%{ endif ~}

%{ if server_name == "frontend" ~}
  MARIADB_SERVER_IP="${mariadb_server_ip}"
  REDIS_SERVER_IP="${redis_server_ip}"
  RABBITMQ_SERVER_IP="${rabbitmq_server_ip}"
  VARNISH_SERVER_IP="${varnish_server_ip}"
  ELASTICSEARCH_SERVER_IP="${elasticsearch_server_ip}"
  MEDIA_SERVER_IP="${media_server_ip}"
%{ endif ~}
