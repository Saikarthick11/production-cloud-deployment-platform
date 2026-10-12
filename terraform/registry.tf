resource "google_artifact_registry_repository" "platform" {
  location      = var.region
  repository_id = "cloud-platform"
  description   = "Container images for the cloud deployment platform"
  format        = "DOCKER"
  depends_on    = [google_project_service.required]
}
