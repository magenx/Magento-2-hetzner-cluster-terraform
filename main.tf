# Configure the Hetzner Cloud provider
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.40.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# Generate ED25519 ssh key
resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

# Add public ssh key to Hetzner
resource "hcloud_ssh_key" "this" {
  name       = "${var.project}-${var.app}-ssh"
  public_key = tls_private_key.this.public_key_openssh
  labels     = local.labels
}

# Generate ssh password for debug
resource "random_password" "this" {
  length = 16
}

# Floating IP
resource "hcloud_floating_ip" "this" {
  name      = "${var.project}-varnish-ip"
  description = "Floating IP for varnish server"
  type      = "ipv4"
  server_id = hcloud_server.this["varnish"].id
  delete_protection = var.protection
  labels    = local.labels
}

# Configure network route
resource "hcloud_network_route" "this" {
  network_id  = hcloud_network.this.id
  destination = "0.0.0.0/0"
  gateway     = tolist(hcloud_server.this["varnish"].network[*].ip)[0]
}

# Change rDNS for floating ip
resource "hcloud_rdns" "this" {
  floating_ip_id = hcloud_floating_ip.this.id
  ip_address     = hcloud_floating_ip.this.ip_address
  dns_ptr        = var.domain
}

# Create network with public IPv4 and private CIDR block
resource "hcloud_network" "this" {
  name           = "${var.project}-network"
  ip_range       = "10.0.0.0/16"
  delete_protection = var.protection
  labels         = local.labels
}

# Create network subnet
resource "hcloud_network_subnet" "this" {
  network_id   = hcloud_network.this.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = "10.0.0.0/24"
}

# Create placement group
resource "hcloud_placement_group" "this" {
  name        = "${var.project}-placement-group"
  type        = "spread"
  labels      = local.labels
}

# Create load balancer
resource "hcloud_load_balancer" "this" {
  name   = "${var.project}-load-balancer"
  load_balancer_type = "lb11"
  location           = hcloud_server.this["frontend"].location
  delete_protection  = var.protection
  algorithm  {
    type = "round_robin"
  }
  labels = local.labels
}

# Configure load balancer network
resource "hcloud_load_balancer_network" "this" {
  load_balancer_id = hcloud_load_balancer.this.id
  network_id       = hcloud_network.this.id
  ip               = cidrhost(hcloud_network_subnet.this.ip_range, 100)
  enable_public_interface = false
}

# Add load balancer target
resource "hcloud_load_balancer_target" "this" {
  load_balancer_id = hcloud_load_balancer.this.id
  type             = "label_selector"
  label_selector   = "name=frontend"
  use_private_ip   = true
  depends_on = [
    hcloud_network_subnet.this
  ]
}

# Add load balancer service
resource "hcloud_load_balancer_service" "this" {
  load_balancer_id = hcloud_load_balancer.this.id
  protocol         = "http"
  health_check {
    protocol = "http"
    port     = 80
    interval = 5
    timeout  = 5
    retries  = 2
    http {
      path         = "/"
      status_codes = ["2??", "3??"]
    }
   }
}

# Create servers
resource "hcloud_server" "this" {
  for_each    = var.servers
  name        = each.key
  server_type = each.value
  image       = "debian-11"
  keep_disk   = true
  ssh_keys    = [hcloud_ssh_key.this.name]
  placement_group_id = hcloud_placement_group.this.id
  delete_protection  = var.protection
  rebuild_protection = var.protection
  labels      = merge(local.labels, {
    "name" = each.key
  })
  public_net {
    ipv4_enabled = each.key == "varnish" ? true : false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.this.id
    ip         = cidrhost(hcloud_network_subnet.this.ip_range, index(keys(var.servers), each.key) + 1)
  }
  depends_on = [
    hcloud_network_subnet.this
  ]
  user_data = <<-EOF
#cloud-config
{% if each.key == "varnish" ~}
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
write_files:
  - path: /etc/sysctl.d/99-ip-forward.conf
    content: |
      net.ipv4.ip_forward = 1
runcmd:
  - sysctl -p /etc/sysctl.d/99-ip-forward.conf
  - iptables -t nat -A POSTROUTING -s 10.0.0.0/16 -o eth0 -j MASQUERADE
{% else ~}
network:
  version: 2
  ethernets:
    eth0:
      routes:
        - to: 0.0.0.0/0
          via: ${cidrhost(hcloud_network_subnet.this.ip_range, index(keys(var.servers), "varnish") + 1)}
{% endif ~}
chpasswd:
  list: |
    root:${random_password.this.result}
  expire: false
runcmd:
    - |
      curl -sSL -H "X-Config-Type: Cloud" "https://magenx.sh" | env \
      PRIVATE_IP=$(curl -s http://169.254.169.254/hetzner/v1/metadata/private-networks | grep -m1 ip: | awk '{print $NF}') \
      SERVER_NAME="${each.key}" \
      DEBIAN_FRONTEND=noninteractive \
      TERMS="y" \
      ENV="${var.env}" \
      DOMAIN="${var.domain}" \
      DOWNLOAD_MAGENTO="${var.download_magento}" \
      VERSION_INSTALLED="${var.version_installed}" \
      APPLY_MAGENTO_CONFIG="${var.apply_magento_config}" \
      PHP_VERSION="${var.php_version}" \
      TIMEZONE="${var.timezone}" \
      LOCALE="${var.locale}" \
      CURRENCY="${var.currency}" \
      ADMIN_FIRST_NAME="${var.admin_first_name}" \
      ADMIN_LAST_NAME="${var.admin_last_name}" \
      ADMIN_LOGIN="${var.admin_login}" \
      ADMIN_EMAIL="${var.admin_email}" \
%{ if each.key != "frontend" ~}
      INSTALL_$${SERVER_NAME^^}="y" \
      $${SERVER_NAME^^}_SERVER_IP="$${PRIVATE_IP}" \
      bash -s -- lemp ${each.key} firewall
%{ else ~}
      INSTALL_NGINX="y" \
      INSTALL_PHP="y" \
      MARIADB_SERVER_IP="${cidrhost(hcloud_network_subnet.this.ip_range, index(keys(var.servers), "mariadb") + 1)}" \
      REDIS_SERVER_IP="${cidrhost(hcloud_network_subnet.this.ip_range, index(keys(var.servers), "redis") + 1)}" \
      RABBITMQ_SERVER_IP="${cidrhost(hcloud_network_subnet.this.ip_range, index(keys(var.servers), "rabbitmq") + 1)}" \
      VARNISH_SERVER_IP="${cidrhost(hcloud_network_subnet.this.ip_range, index(keys(var.servers), "varnish") + 1)}" \
      ELASTICSEARCH_SERVER_IP="${cidrhost(hcloud_network_subnet.this.ip_range, index(keys(var.servers), "elasticsearch") + 1)}" \
      MEDIA_SERVER_IP="${cidrhost(hcloud_network_subnet.this.ip_range, index(keys(var.servers), "media") + 1)}" \
      bash -s -- lemp magento install config firewall
%{ endif ~}
EOF
}
