# Mocked plans use the provider schema but never call Google Cloud.
mock_provider "google" {}

variables {
  project_id = "platform-test-project"
  admin_cidr = "203.0.113.10/32"
}

run "private_learning_cluster" {
  command = plan

  assert {
    condition     = google_container_cluster.platform.private_cluster_config[0].enable_private_nodes
    error_message = "Nodes must not receive public IP addresses."
  }
  assert {
    condition     = one(google_container_cluster.platform.master_authorized_networks_config[0].cidr_blocks).cidr_block == var.admin_cidr
    error_message = "Cluster API access must be limited to the administrator address."
  }
  assert {
    condition     = google_container_cluster.platform.deletion_protection && google_container_node_pool.platform.node_count == 1
    error_message = "Use a deletion-protected, single-node learning cluster."
  }
  assert {
    condition     = google_container_cluster.platform.workload_identity_config[0].workload_pool == "platform-test-project.svc.id.goog"
    error_message = "Workload Identity must be configured for the selected project."
  }
  assert {
    condition     = google_compute_router_nat.platform.source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS"
    error_message = "Outbound NAT must be scoped to the platform subnet."
  }
  assert {
    condition     = google_project_iam_member.nodes.role == "roles/container.defaultNodeServiceAccount" && google_artifact_registry_repository_iam_member.nodes.role == "roles/artifactregistry.reader"
    error_message = "Nodes need the minimum GKE role and repository-scoped image read access."
  }
}

run "reject_open_api" {
  command = plan
  variables {
    admin_cidr = "0.0.0.0/0"
  }
  expect_failures = [var.admin_cidr]
}

run "reject_region_mismatch" {
  command = plan
  variables {
    zone = "us-east1-b"
  }
  expect_failures = [google_container_cluster.platform]
}
