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

variable "domain" {
  description = "Domain"
  type        = string
}

variable "download_magento" {
  description = "Download Magento"
  type        = bool
}

variable "version_installed" {
  description = "Magento Version Installed"
  type        = string
}

variable "apply_magento_config" {
  description = "Apply Magento Configuration"
  type        = bool
}

variable "php_version" {
  description = "PHP Version"
  type        = string
}

variable "timezone" {
  description = "Timezone"
  type        = string
}

variable "locale" {
  description = "Locale"
  type        = string
}

variable "currency" {
  description = "Currency"
  type        = string
}

variable "admin_first_name" {
  description = "Admin First Name"
  type        = string
}

variable "admin_last_name" {
  description = "Admin Last Name"
  type        = string
}

variable "admin_login" {
  description = "Admin Login"
  type        = string
}

variable "admin_email" {
  description = "Admin Email"
  type        = string
}

