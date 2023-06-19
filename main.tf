# Configure the Hetzner Cloud provider
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.39.0"
    }
  }
}

# Declare the hcloud_token variable
variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
}

provider "hcloud" {
  token = var.hcloud_token
}

# Define variables
variable "project" {
  description = "The name of the project"
  type        = string
}

# Generate ED25519 ssh key
resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

# Add public ssh key to Hetzner
resource "hcloud_ssh_key" "this" {
  name       = "${var.project}-admin"
  public_key = tls_private_key.this.public_key_openssh
}

# Define server types
variable "server_types" {
  description = "A map of server types"
  type        = map
  default = {
    mariadb       = "cax11"
    elasticsearch = "cax11"
    redis         = "cax11"
    rabbitmq      = "cax11"
    media         = "cax11"
    varnish       = "cax11"
    frontend      = "cax11"
  }
}

# Create network with public IPv4 and private CIDR block
resource "hcloud_network" "this" {
  name           = "${var.project}-network"
  ip_range       = "10.0.0.0/16"
  labels         = {
    "project" = "${var.project}"
    "app"     = "magento"
    "env"     = "developer"
  }
}

# Create placement group
resource "hcloud_placement_group" "this" {
  name        = "${var.project}-placement-group"
  type        = "spread"
  labels      = {
    "project" = "${var.project}"
    "app"     = "magento"
    "env"     = "developer"
  }
}

# Create load balancer
resource "hcloud_load_balancer" "this" {
  name        = "${var.project}-load-balancer"
  load_balancer_type = "lb11"
  algorithm  {
    type = "round_robin"
  }
  labels  = {
    "project" = "${var.project}"
    "app"     = "magento"
    "env"     = "developer"
  }
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
  label_selector   = "type=frontend"
  use_private_ip   = true
}

# Add load balancer service
resource "hcloud_load_balancer_service" "load_balancer_service" {
    load_balancer_id = hcloud_load_balancer.this.id
    protocol         = "http"
}

# Create servers
resource "hcloud_server" "this" {
  for_each    = var.server_types
  name        = each.key
  server_type = each.value
  image       = "debian-11"
  ssh_keys    = ["${var.project}-admin"]
  placement_group_id = hcloud_placement_group.this.id
  labels      = {
    "type" = each.key
    "app"  = "magento"
    "env"  = "developer"
  }
  network {
    network_id = hcloud_network.this.id
    ip         = hcloud_network.this.ip_range
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = tls_private_key.this.private_key_openssh
  }

  provisioner "remote-exec" {
    inline = [
      "curl https://ifconfig.io",
      "export VAR1=value1",
      "export VAR2=value2",
    ]
  }
}

output "ips" {
  value = {
    for server_name, server in hcloud_server.this :
    server_name => server.ipv4_address
  }
}
