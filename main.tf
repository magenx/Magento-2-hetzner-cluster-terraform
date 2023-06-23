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

# Floating IP
resource "hcloud_floating_ip" "this" {
  name      = "${var.project}-varnish-ip"
  description = "Floating IP for varnish server"
  type      = "ipv4"
  server_id = hcloud_server.this["varnish"].id
  delete_protection = var.protection
  labels    = local.labels
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
    ip         = hcloud_network.this.ip_range
  }
  depends_on = [
    hcloud_network_subnet.this
  ]
  user_data = <<-EOF
    #cloud-config
    ${var.general_user_data}
    ${each.key == "frontend" ? var.frontend_user_data : var.other_user_data}
  EOF
}

output "ip2" {
value = hcloud_server.this
}
