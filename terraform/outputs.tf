output "cluster_name" {
  description = "Cluster name; this output alone does not deploy the app."
  value       = google_container_cluster.platform.name
}

output "registry_url" {
  description = "Future image repository prefix. Existing CI still publishes to GHCR."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.platform.repository_id}"
}

output "node_service_account" {
  description = "Identity used by the GKE machines; no JSON keys are created."
  value       = google_service_account.nodes.email
}
