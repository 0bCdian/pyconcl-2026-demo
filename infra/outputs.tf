output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "zone" {
  value = var.zone
}

output "cluster_name" {
  value = local.on ? google_container_cluster.demo[0].name : null
}

output "registry" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "catalog_uri" {
  value = "gs://${google_storage_bucket.catalog.name}/${google_storage_bucket_object.catalog.name}"
}

output "build_service_account" {
  value = google_service_account.build.id
}

output "build_staging_dir" {
  value = "gs://${google_storage_bucket.build_staging.name}/source"
}
