locals {
  eip_map = { for addr in var.frontends : addr.name => addr}
}

resource "google_compute_forwarding_rule" "frontends" {
  for_each              = local.eip_map

  name                  = "${local.prefix}fr-${each.key}"
  region                = each.value.region
  ip_address            = each.value.address
  ip_protocol           = "L3_DEFAULT"
  all_ports             = true
  load_balancing_scheme = "EXTERNAL"
  backend_service       = google_compute_region_backend_service.elb_bes.self_link
  labels                = var.labels
}

locals {
  eip_all = [ for frontend in var.frontends : frontend.address ]
}

resource "google_compute_region_backend_service" "elb_bes" {
  provider               = google-beta
  name                   = "${local.prefix}bes-elb-${local.region_short}"
  region                 = var.region
  load_balancing_scheme  = "EXTERNAL"
  protocol               = "UNSPECIFIED"

  backend {
    group                = google_compute_instance_group.fgt-umigs[0].self_link
    balancing_mode       = "CONNECTION"
  }
  backend {
    group                = google_compute_instance_group.fgt-umigs[1].self_link
    balancing_mode       = "CONNECTION"
  }

  health_checks          = [google_compute_region_health_check.health_check.self_link]
  connection_tracking_policy {
    connection_persistence_on_unhealthy_backends = "NEVER_PERSIST"
  }
}
