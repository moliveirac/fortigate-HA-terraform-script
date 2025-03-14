# mapping fortigate instances
locals {
  fgt_map = { for idx, inst in module.fgt-ha.fgt_array: idx => inst}
}

resource "google_compute_network_endpoint_group" "http_neg_mgmt" {
  for_each                = local.fgt_map

  name                    = "http-neg${each.key}-mgmt"
  zone                    = each.value.zone
  network_endpoint_type   = "GCE_VM_IP_PORT"
  network                 = each.value.network_interface[3].network
  subnetwork              = each.value.network_interface[3].subnetwork
}

resource "google_compute_network_endpoint" "http_neg_mgmt_assignment" {
  for_each                = local.fgt_map

  network_endpoint_group  = google_compute_network_endpoint_group.http_neg_mgmt[each.key].self_link

  instance                = each.value.self_link
  port                    = 80
  ip_address              = each.value.network_interface[3].network_ip
  zone                    = each.value.zone

  depends_on              = [ google_compute_network_endpoint_group.http_neg_mgmt ]
}

locals {
  fgt_neg_map = { for idx, neg in google_compute_network_endpoint_group.http_neg_mgmt : idx => neg.self_link }
}

# Common Load Balancer resources
resource "google_compute_region_health_check" "http_elb_mgmt_health_check" {
  name                   = "http-elb-mgmt-healthcheck-8008"
  region                 = var.region
  timeout_sec            = 2
  check_interval_sec     = 2

  tcp_health_check {
    port                 = 8008
  }
}

# reserved IP address
resource "google_compute_address" "http_elb_mgmt_addr" {
  name                  = "http-elb-mgmt-addr"
  region                = var.region
  address_type          = "EXTERNAL"
  network_tier          = "STANDARD"
}

# forwarding rule
resource "google_compute_forwarding_rule" "http_elb_mgmt_fwdr" {
  name                  = "http-elb-mgmt-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  region                = var.region
  network               = google_compute_network.vpc_mgmt.name
  network_tier          = "STANDARD"
  target                = google_compute_region_target_http_proxy.http_elb_mgmt_proxy.id
  ip_address            = google_compute_address.http_elb_mgmt_addr.id
  depends_on            = [ google_compute_subnetwork.proxy_subnet ]
}

# firewall rules
resource "google_compute_firewall" "allow_http_elb_healthchecks" {
  name                  = "http-elb-allow-healthchecks"
  network               = google_compute_network.vpc_mgmt.name
  source_ranges         = ["130.211.0.0/22","35.191.0.0/16"]
  target_tags           = ["fgt"]

  allow {
    protocol            = "tcp"
    ports               = ["8008"]
  }

  depends_on            = [
    google_compute_subnetwork.proxy_subnet
  ]
}

resource "google_compute_firewall" "allow_http_elb_proxies" {
  name                  = "http-elb-allow-proxies"
  network               = google_compute_network.vpc_mgmt.name
  source_ranges         = ["172.25.5.0/24"]
  target_tags           = ["fgt"]

  allow {
    protocol            = "tcp"
    ports               = ["80","443","8080"]
  }

  depends_on            = [
    google_compute_subnetwork.proxy_subnet
  ]
}

# http proxy
resource "google_compute_region_target_http_proxy" "http_elb_mgmt_proxy" {
  name                  = "http-elb-mgmt-proxy"
  region                = var.region
  url_map               = google_compute_region_url_map.http_elb_mgmt_url_map.id
}

# url map
resource "google_compute_region_url_map" "http_elb_mgmt_url_map" {
  name                  = "http-elb-mgmt-url-map"
  region                = var.region
  default_service       = lookup(google_compute_region_backend_service.http_elb_mgmt_bes, "0", null).id

  host_rule {
    hosts               = ["fgt1"]
    path_matcher         = "path-matcher-1"
  }
  host_rule {
    hosts               = ["fgt2"]
    path_matcher         = "path-matcher-2"
  }

  path_matcher {
    name                = "path-matcher-1"
    default_service     = lookup(google_compute_region_backend_service.http_elb_mgmt_bes, "0", null).id
  }
  path_matcher {
    name                = "path-matcher-2"
    default_service     = lookup(google_compute_region_backend_service.http_elb_mgmt_bes, "1", null).id
  }
}

# backend services
resource "google_compute_region_backend_service" "http_elb_mgmt_bes" {
  for_each                = local.fgt_neg_map
  
  name                    = "http-elb-mgmt-${each.key}-bes"
  protocol                = "HTTP"
  port_name               = "http"
  region                  = var.region
  load_balancing_scheme   = "EXTERNAL_MANAGED"
  timeout_sec             = 30
  health_checks           = [ google_compute_region_health_check.http_elb_mgmt_health_check.self_link ]

  backend {
    group                 = each.value
    balancing_mode        = "RATE"
    max_rate              = 100
    capacity_scaler       = 1.0
  }
}