resource "google_container_cluster" "platform" {
  name                     = "cloud-platform"
  location                 = var.zone
  network                  = google_compute_network.platform.id
  subnetwork               = google_compute_subnetwork.platform.id
  networking_mode          = "VPC_NATIVE"
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = var.deletion_protection
  enable_shielded_nodes    = true

  release_channel {
    channel = "REGULAR"
  }
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.admin_cidr
      display_name = "developer"
    }
  }
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  # Even the temporary default node pool uses the dedicated identity.
  node_config {
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }
  lifecycle {
    precondition {
      condition     = startswith(var.zone, "${var.region}-")
      error_message = "The cluster zone must belong to the subnet region."
    }
  }
  depends_on = [google_project_iam_member.nodes, google_compute_router_nat.platform]
}

resource "google_container_node_pool" "platform" {
  name       = "platform"
  location   = var.zone
  cluster    = google_container_cluster.platform.name
  node_count = 1

  management {
    auto_repair  = true
    auto_upgrade = true
  }
  node_config {
    machine_type    = "e2-standard-2"
    disk_size_gb    = 30
    disk_type       = "pd-balanced"
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
  depends_on = [google_artifact_registry_repository_iam_member.nodes]
}
