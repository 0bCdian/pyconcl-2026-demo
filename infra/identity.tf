# Both sides read the catalog through Workload Identity: the Kubernetes service accounts demo/bad and
# demo/good get the role directly, with no Google service account and no key.
# The pool <project>.svc.id.goog only exists once a cluster with Workload Identity does.
resource "google_storage_bucket_iam_member" "shop_reads_catalog" {
  for_each = local.on ? toset(["bad", "good"]) : toset([])

  bucket = google_storage_bucket.catalog.name
  role   = "roles/storage.objectViewer"
  member = "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${local.workload_pool}/subject/ns/demo/sa/${each.key}"

  depends_on = [google_container_cluster.demo]
}
