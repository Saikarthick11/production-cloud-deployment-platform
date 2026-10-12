resource "google_service_account" "nodes" {
  account_id   = "cloud-platform-nodes"
  display_name = "Cloud Platform GKE nodes"
  depends_on   = [google_project_service.required]
}

# Google's minimum role for GKE node logging and monitoring; no Editor role.
resource "google_project_iam_member" "nodes" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

# Access to images is restricted to this repository, not every project registry.
resource "google_artifact_registry_repository_iam_member" "nodes" {
  project    = var.project_id
  location   = google_artifact_registry_repository.platform.location
  repository = google_artifact_registry_repository.platform.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.nodes.email}"
}
