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
  default     = "magenx"
}

locals {
  ssh_key = "${var.project}-admin"
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

# Create servers
resource "hcloud_server" "servers" {
  for_each    = var.server_types
  name        = each.key
  server_type = each.value
  image       = "debian-11"
  ssh_keys    = [local.ssh_key]
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

  provisioner "remote-exec" {
    inline = [
      "curl https://ifconfig.io",
      "export VAR1=value1",
      "export VAR2=value2",
    ]
  }
}

output "server_ips" {
  value = {
    for server_name, server in hcloud_server.servers :
    server_name => server.ipv4_address
  }
}
