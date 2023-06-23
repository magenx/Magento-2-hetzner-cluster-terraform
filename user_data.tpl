chpasswd:
  list: |
    root:${ssh_password}
  expire: false
runcmd:
    - |
      curl -sSL -header "X-Config-Type: Cloud" "https://magenx.sh" | env \
      SERVER_NAME="${server_name}"
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
      $${SERVER_NAME^^}_SERVER_IP="${private_ip}" \
      bash -s -- lemp media firewall
%{ else ~}
      INSTALL_NGINX="y" \
      INSTALL_PHP="y" \
      MARIADB_SERVER_IP="${mariadb_server_ip}" \
      REDIS_SERVER_IP="${redis_server_ip}" \
      RABBITMQ_SERVER_IP="${rabbitmq_server_ip}" \
      VARNISH_SERVER_IP="${varnish_server_ip}" \
      ELASTICSEARCH_SERVER_IP="${elasticsearch_server_ip}" \
      MEDIA_SERVER_IP="${media_server_ip}" \
      bash -s -- lemp magento install config firewall
%{ endif ~}
