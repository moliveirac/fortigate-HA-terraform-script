######################### VPCs #########################

resource "google_compute_network" "vpc_external" {
  name                    = "fgt-hac-vpc-external"
  auto_create_subnetworks = false
}

resource "google_compute_network" "vpc_internal" {
  name                    = "fgt-hac-vpc2-internal"
  auto_create_subnetworks = false
}

resource "google_compute_network" "vpc_ha" {
  name                    = "fgt-hac-vpc3-ha"
  auto_create_subnetworks = false
}

resource "google_compute_network" "vpc_mgmt" {
  name                    = "fgt-hac-vpc4-mgmt"
  auto_create_subnetworks = false
}


######################### Subnets #########################

### Public Subnet ###
resource "google_compute_subnetwork" "external_subnet" {
  name                     = "fgt-hac-vpc-external-subnet"
  region                   = var.region
  network                  = google_compute_network.vpc_external.name
  ip_cidr_range            = var.public_subnet
  private_ip_google_access = true
}

### Private Subnet ###
resource "google_compute_subnetwork" "internal_subnet" {
  name          = "fgt-hac-vpc2-internal-subnet"
  region        = var.region
  network       = google_compute_network.vpc_internal.name
  ip_cidr_range = var.protected_subnet
}

### HA Sync Subnet ###
resource "google_compute_subnetwork" "ha_subnet" {
  name          = "fgt-hac-vpc3-ha-subnet"
  region        = var.region
  network       = google_compute_network.vpc_ha.name
  ip_cidr_range = var.ha_subnet
}

### HA MGMT Subnet ###
resource "google_compute_subnetwork" "mgmt_subnet" {
  name          = "fgt-hac-vpc4-mgmt-subnet"
  region        = var.region
  network       = google_compute_network.vpc_mgmt.name
  ip_cidr_range = var.mgmt_subnet
}

### HA Proxy-only Subnet ###
resource "google_compute_subnetwork" "proxy_subnet" {
  name          = "fgt-hac-vpc4-proxy-subnet"
  region        = var.region
  network       = google_compute_network.vpc_mgmt.name
  ip_cidr_range = var.proxy_subnet
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

######################### Static IPs #########################

resource "google_compute_address" "static_elb" {
  name                  = "static-elb"
  region                = var.region
  address_type          = "EXTERNAL"  
}

######################### Modulo con despliegue #########################

# Importar modulo HA con LBs
module "fgt-ha" {  
  source        = "git::github.com/40net-cloud/fortigate-gcp-ha-ap-lb-terraform"

  region        = var.region
  subnets       = [ google_compute_subnetwork.external_subnet.name, google_compute_subnetwork.internal_subnet.name, google_compute_subnetwork.ha_subnet.name, google_compute_subnetwork.mgmt_subnet.name ]
  image_family  = var.image_family
  frontends     = [ 
    {
      name      = google_compute_address.static_elb.name
      address   = google_compute_address.static_elb.address
      region    = google_compute_address.static_elb.region
    }
   ]

  depends_on    = [
    google_compute_subnetwork.external_subnet,
    google_compute_subnetwork.internal_subnet,
    google_compute_subnetwork.ha_subnet,
    google_compute_subnetwork.mgmt_subnet,
    google_compute_subnetwork.proxy_subnet
  ]
}
