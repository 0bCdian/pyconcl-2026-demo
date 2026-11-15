# A Cloud Run job that prints what Python and gunicorn see inside a Cloud Run container with 1 vCPU, to compare with the pod and the VM.
locals {
  cpu_probe = <<-EOT
    import multiprocessing, os, pathlib
    def read(path):
        try:
            return pathlib.Path(path).read_text().strip()
        except OSError as error:
            return f"unavailable ({error.__class__.__name__})"
    cpus = multiprocessing.cpu_count()
    print(f"cpu-probe os.cpu_count={os.cpu_count()} os.process_cpu_count={os.process_cpu_count()} "
          f"cpu.max={read('/sys/fs/cgroup/cpu.max')!r} memory.max={read('/sys/fs/cgroup/memory.max')!r} "
          f"gunicorn_workers={cpus * 2 + 1}")
  EOT
}

resource "google_cloud_run_v2_job" "cpu_probe" {
  count = local.on && var.vm_and_cloud_run ? 1 : 0

  name                = "${var.name_prefix}-cpu-probe"
  location            = var.region
  deletion_protection = false

  template {
    template {
      service_account = google_service_account.vm.email
      max_retries     = 0

      containers {
        image   = "${google_artifact_registry_repository.images.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}/bad:latest"
        command = ["python", "-c", local.cpu_probe]

        resources {
          limits = { cpu = "1", memory = "2Gi" }
        }
      }
    }
  }
}

output "cpu_probe_job" {
  value = one(google_cloud_run_v2_job.cpu_probe[*].name)
}
