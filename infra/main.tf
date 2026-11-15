data "google_project" "this" {}

locals {
  on            = var.stage == "on"
  workload_pool = "${var.project_id}.svc.id.goog"
}

resource "google_compute_network" "demo" {
  name                    = var.name_prefix
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "demo" {
  name          = "${var.name_prefix}-${var.region}"
  network       = google_compute_network.demo.id
  region        = var.region
  ip_cidr_range = "10.10.0.0/20"

  # Nodes and the VM have no public address; Google APIs and Artifact Registry stay reachable.
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/16"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20"
  }
}

resource "google_artifact_registry_repository" "images" {
  repository_id = var.name_prefix
  location      = var.region
  format        = "DOCKER"
}

resource "google_storage_bucket" "catalog" {
  name                        = "${var.project_id}-${var.name_prefix}-catalog"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}

resource "google_storage_bucket_object" "catalog" {
  bucket = google_storage_bucket.catalog.name
  name   = "catalog.csv"
  source = "${path.module}/catalog.csv"
}
