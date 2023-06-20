# Define variables
variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
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

## HCL type variable in terraform cloud
variable "servers" {
  description = "A map of server types"
  type        = map(string)
  default     = {}
}
