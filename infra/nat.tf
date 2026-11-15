# Outbound internet for machines without a public address: images from Docker Hub and ghcr.io, Helm charts, apt and pip.
resource "google_compute_router" "demo" {
  count = local.on ? 1 : 0

  name    = var.name_prefix
  network = google_compute_network.demo.id
  region  = var.region
}

resource "google_compute_router_nat" "demo" {
  count = local.on ? 1 : 0

  name                               = var.name_prefix
  router                             = google_compute_router.demo[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
