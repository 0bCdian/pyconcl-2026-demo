# The same shop running directly on a VM of the node's machine type, with no container, to contrast it with the pod.
resource "google_service_account" "vm" {
  account_id   = "${var.name_prefix}-vm"
  display_name = "VM that runs the shop without a container in the ${var.name_prefix} demo"
}

resource "google_storage_bucket_iam_member" "vm_reads_catalog" {
  bucket = google_storage_bucket.catalog.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.vm.member
}

locals {
  vm_tag = "${var.name_prefix}-vm"
}

resource "google_compute_instance" "vm" {
  count = local.on && var.vm_and_cloud_run ? 1 : 0

  name         = "${var.name_prefix}-vm"
  machine_type = var.app_machine_type
  zone         = var.zone
  tags         = [local.vm_tag]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-13"
      size  = 20
    }
  }

  # No public address: apt and pip go out through Cloud NAT, SSH comes in through IAP.
  network_interface {
    subnetwork = google_compute_subnetwork.demo.id
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  scheduling {
    provisioning_model          = var.spot ? "SPOT" : "STANDARD"
    preemptible                 = var.spot
    automatic_restart           = !var.spot
    instance_termination_action = var.spot ? "STOP" : null
  }

  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys       = "${var.vm_ssh_user}:${trimspace(file(pathexpand(var.vm_ssh_public_key_file)))}"
  }
}

resource "google_compute_firewall" "vm_from_cluster" {
  name          = "${var.name_prefix}-vm-from-cluster"
  network       = google_compute_network.demo.id
  source_ranges = [for range in concat([google_compute_subnetwork.demo.ip_cidr_range], google_compute_subnetwork.demo.secondary_ip_range[*].ip_cidr_range) : range]
  target_tags   = [local.vm_tag]

  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }
}

resource "google_compute_firewall" "vm_ssh_from_iap" {
  name          = "${var.name_prefix}-vm-ssh-from-iap"
  network       = google_compute_network.demo.id
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [local.vm_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

output "vm_name" {
  value = one(google_compute_instance.vm[*].name)
}

output "vm_address" {
  value = one(google_compute_instance.vm[*].network_interface[0].network_ip)
}
