# GCP region
variable "region" {
  type    = string
  default = "europe-west4" #Default Region
}
# Las zonas se seleccionan automaticamente

# GCP project name
variable "project" {
  type    = string
  default = "linear-archway-448817-e9"
}

# Imagenes a emplear
variable "image_family" {
  type    = string
  default = "fortigate-74-byod"
}

# Public Subnet CIDR
variable "public_subnet" {
  type    = string
  default = "172.25.0.0/24"
}
# Private Subnet CIDR
variable "protected_subnet" {
  type    = string
  default = "172.25.1.0/24"
}
# HA Subnet CIDR
variable "ha_subnet" {
  type    = string
  default = "172.25.2.0/24"
}
# MGMT Subnet CIDR
variable "mgmt_subnet" {
  type    = string
  default = "172.25.3.0/24"
}
# Proxy-only Subnet CIDR
variable "proxy_subnet" {
  type    = string
  default = "172.25.5.0/24"
}
# Default Subnet CIDR
variable "default_subnet" {
  type    = string
  default = "172.25.10.0/24"
}