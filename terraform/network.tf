# Enabling APIs is a cloud change and only happens with a future apply.
resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "platform" {
  name                    = "cloud-platform"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required]
}

resource "google_compute_subnetwork" "platform" {
  name                     = "cloud-platform"
  region                   = var.region
  network                  = google_compute_network.platform.id
  ip_cidr_range            = "10.10.0.0/20"
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/16"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20"
  }
}

# Private nodes need outbound access to pull images from GHCR.
resource "google_compute_router" "platform" {
  name    = "cloud-platform"
  region  = var.region
  network = google_compute_network.platform.id
}

resource "google_compute_router_nat" "platform" {
  name                               = "cloud-platform"
  router                             = google_compute_router.platform.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.platform.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
