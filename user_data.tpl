chpasswd:
  list: |
    root:${ssh_password}
  expire: false
runcmd:
    - |
      curl -sSL -header "X-Config-Type: Cloud" "https://magenx.sh" | env \
      PRIVATE_IP=$(curl -s http://169.254.169.254/hetzner/v1/metadata/private-networks | grep -m1 ip: | awk '{print $NF}') \
      SERVER_NAME="${server_name}" \
      DEBIAN_FRONTEND=noninteractive \
      TERMS="y" \
      ENV="${env}" \
      DOMAIN="${domain}" \
      DOWNLOAD_MAGENTO="${download_magento}" \
      VERSION_INSTALLED="${version_installed}" \
      APPLY_MAGENTO_CONFIG="${apply_magento_config}" \
      PHP_VERSION="${php_version}" \
      TIMEZONE="${timezone}" \
      LOCALE="${locale}" \
      CURRENCY="${currency}" \
      ADMIN_FIRST_NAME="${admin_first_name}" \
      ADMIN_LAST_NAME="${admin_last_name}" \
      ADMIN_LOGIN="${admin_login}" \
      ADMIN_EMAIL="${admin_email}" \
%{ if server_name != "frontend" ~}
      INSTALL_$${SERVER_NAME^^}="y" \
      $${SERVER_NAME^^}_SERVER_IP="$${PRIVATE_IP}" \
      bash -s -- lemp media firewall
%{ else ~}
      INSTALL_NGINX="y" \
      INSTALL_PHP="y" \
      MARIADB_SERVER_IP="${hcloud_server.this[each.key].network[*].ip}" \
      REDIS_SERVER_IP="a" \
      RABBITMQ_SERVER_IP="a" \
      VARNISH_SERVER_IP="a" \
      ELASTICSEARCH_SERVER_IP="a" \
      MEDIA_SERVER_IP="a" \
      bash -s -- lemp magento install config firewall
%{ endif ~}
