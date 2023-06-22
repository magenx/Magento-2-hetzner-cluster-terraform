# Define variables
variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
}

variable "network_zone" {
  description = "Name of network zone"
  type        = string
  default     = "eu-central"
}

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

variable "protection" {
  description = "Enable or disable delete protection"
  type        = bool
}

locals {
  labels = {
    "project" = var.project
    "app"     = var.app
    "env"     = var.env
  }
}

## HCL type variable in Terraform Cloud
## { mariadb = "cax11", elasticsearch = "cax11", redis = "cax11", rabbitmq = "cax11", media = "cax11", varnish = "cax11", frontend = "cax11" }
variable "servers" {
  description = "A map of server types"
  type        = map(string)
  default     = {}
}

variable "general_user_data" {
  type    = string
  default = "# General configuration"
}

variable "frontend_user_data" {
  type    = string
  default = "# Frontend server specific configuration"
}

variable "other_user_data" {
  type    = string
  default = "# Non-frontend server specific configuration"
}
