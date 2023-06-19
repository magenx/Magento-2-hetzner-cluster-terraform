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

variable "env" {
  description = "Environment name"
  type        = string
}

variable "app" {
  description = "Application name"
  type        = string
}

locals {
  labels = {
    "project" = var.project
    "app"     = var.app
    "env"     = var.env
  }
}

# Generate ED25519 ssh key
resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

# Add public ssh key to Hetzner
resource "hcloud_ssh_key" "this" {
  name       = "${var.project}-${var.app}"
  public_key = tls_private_key.this.public_key_openssh
  labels     = local.labels
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
  labels         = local.labels
}

# Create placement group
resource "hcloud_placement_group" "this" {
  name        = "${var.project}-placement-group"
  type        = "spread"
  labels      = local.labels
}

# Create load balancer
resource "hcloud_load_balancer" "this" {
  name        = "${var.project}-load-balancer"
  load_balancer_type = "lb11"
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
  label_selector   = "type=frontend"
  use_private_ip   = true
}

# Add load balancer service
resource "hcloud_load_balancer_service" "this" {
    load_balancer_id = hcloud_load_balancer.this.id
    protocol         = "http"
}

# Create servers
resource "hcloud_server" "this" {
  for_each    = var.server_types
  name        = each.key
  server_type = each.value
  image       = "debian-11"
  keep_disk   = true
  ssh_keys    = [hcloud_ssh_key.this.name]
  placement_group_id = hcloud_placement_group.this.id
  #delete_protection  = true
  #rebuild_protection = true
  labels      = merge(local.labels, {
    "type" = each.key
  })
  network {
    network_id = hcloud_network.this.id
    ip         = hcloud_network.this.ip_range
  }
  user_data = ""
}

output "ips" {
  value = {
    for server_name, server in hcloud_server.this :
    server_name => server.ipv4_address
  }
}
