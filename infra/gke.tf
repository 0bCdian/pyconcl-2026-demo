resource "google_service_account" "nodes" {
  account_id   = "${var.name_prefix}-nodes"
  display_name = "GKE nodes of the ${var.name_prefix} demo"
}

resource "google_project_iam_member" "nodes_default_role" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = google_service_account.nodes.member
}

resource "google_artifact_registry_repository_iam_member" "nodes_pull_images" {
  repository = google_artifact_registry_repository.images.name
  location   = google_artifact_registry_repository.images.location
  role       = "roles/artifactregistry.reader"
  member     = google_service_account.nodes.member
}

resource "google_container_cluster" "demo" {
  count = local.on ? 1 : 0

  name                     = var.name_prefix
  location                 = var.zone
  network                  = google_compute_network.demo.id
  subnetwork               = google_compute_subnetwork.demo.id
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = local.workload_pool
  }

  # Nodes get only internal addresses. The control plane keeps its public endpoint, which requires Google credentials.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = false
    }
  }

  node_config {
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Once the default pool is removed the API reports another pool's node_config here, and any difference would replace the cluster.
  lifecycle {
    ignore_changes = [node_config]
  }

  depends_on = [google_project_iam_member.nodes_default_role]
}

locals {
  node_pools = {
    tools = { machine_type = var.tools_machine_type, side = null }
    bad   = { machine_type = var.app_machine_type, side = "bad" }
    good  = { machine_type = var.app_machine_type, side = "good" }
  }
}

resource "google_container_node_pool" "demo" {
  for_each = local.on ? local.node_pools : {}

  name       = each.key
  cluster    = google_container_cluster.demo[0].id
  location   = var.zone
  node_count = 1

  node_config {
    machine_type = each.value.machine_type
    # Both versions on the same CPU platform; e2 machines can land on different ones.
    min_cpu_platform = each.value.side == null ? null : var.app_cpu_platform
    disk_size_gb     = 50
    spot             = var.spot
    service_account  = google_service_account.nodes.email
    oauth_scopes     = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    dynamic "taint" {
      for_each = each.value.side == null ? [] : [each.value.side]
      content {
        key    = "side"
        value  = taint.value
        effect = "NO_SCHEDULE"
      }
    }
  }
}
