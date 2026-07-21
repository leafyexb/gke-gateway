# Dedicated Service Account for GKE Nodes in the Service Project
resource "google_service_account" "gke_nodes" {
  project      = var.service_project_id
  account_id   = "gke-nodes-sa"
  display_name = "GKE Node Pool Service Account"
}

# IAM roles for the GKE nodes service account (least privilege)
resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.service_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_metric_writer" {
  project = var.service_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.service_project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_resource_metadata" {
  project = var.service_project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# GKE Cluster in the Service Project
resource "google_container_cluster" "primary" {
  provider = google-beta
  project  = var.service_project_id
  name     = "gke-shared-vpc-cluster"
  location = var.region

  # Disable deletion protection for evaluation/demo environment
  deletion_protection = false

  # Use GKE version 1.36+ (Rapid channel support or min_master_version)
  min_master_version = var.kubernetes_version

  # Networking
  network    = "projects/${var.host_project_id}/global/networks/${var.vpc_name}"
  subnetwork = "projects/${var.host_project_id}/regions/${var.region}/subnetworks/${var.subnet_name}"

  ip_allocation_policy {
    cluster_secondary_range_name = "gke-pods"
  }

  # Security Hardening Best Practices
  enable_shielded_nodes = true

  workload_identity_config {
    workload_pool = "${var.service_project_id}.svc.id.goog"
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  # Private Cluster Configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Access control plane over public internet with authorized networks
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Recommendations: We remove the default node pool and create a custom one.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Explicit dependency on IAM role bindings to prevent "403 Forbidden" errors
  depends_on = [
    google_project_service.service_container,
    google_project_service.host_container,
    google_project_iam_member.gke_host_service_agent,
    google_project_iam_member.gke_host_security_admin,
    google_compute_subnetwork_iam_member.gke_subnet_network_user,
    google_compute_subnetwork_iam_member.apis_subnet_network_user,
    google_compute_shared_vpc_service_project.service
  ]
}

# Custom Node Pool A in the Service Project
resource "google_container_node_pool" "primary_nodes_a" {
  project        = var.service_project_id
  name           = "primary-node-pool-a"
  location       = var.region
  node_locations = ["us-central1-a"]
  cluster        = google_container_cluster.primary.name
  node_count     = 1

  management {
    auto_upgrade = true
    auto_repair  = true
  }

  node_config {
    preemptible  = false
    machine_type = "e2-medium"

    # Dedicated IAM service account with minimal scopes
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Security: Disable legacy metadata endpoints
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Security: Shielded Instance Config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      "node-weight-group" = "three-pods"
    }
  }
}

# Custom Node Pool B in the Service Project
resource "google_container_node_pool" "primary_nodes_b" {
  project        = var.service_project_id
  name           = "primary-node-pool-b"
  location       = var.region
  node_locations = ["us-central1-a"]
  cluster        = google_container_cluster.primary.name
  node_count     = 1

  management {
    auto_upgrade = true
    auto_repair  = true
  }

  node_config {
    preemptible  = false
    machine_type = "e2-medium"

    # Dedicated IAM service account with minimal scopes
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Security: Disable legacy metadata endpoints
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Security: Shielded Instance Config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      "node-weight-group" = "one-pod"
    }
  }
}

# GKE Cluster 2 in the Service Project (us-west1)
resource "google_container_cluster" "secondary" {
  provider = google-beta
  project  = var.service_project_id
  name     = "gke-shared-vpc-cluster-2"
  location = var.region_2

  # Disable deletion protection for evaluation/demo environment
  deletion_protection = false

  # Use GKE version 1.36+ (Rapid channel support or min_master_version)
  min_master_version = var.kubernetes_version

  # Networking
  network    = "projects/${var.host_project_id}/global/networks/${var.vpc_name}"
  subnetwork = "projects/${var.host_project_id}/regions/${var.region_2}/subnetworks/${var.subnet_name_2}"

  ip_allocation_policy {
    cluster_secondary_range_name = "gke-pods"
  }

  # Security Hardening Best Practices
  enable_shielded_nodes = true

  workload_identity_config {
    workload_pool = "${var.service_project_id}.svc.id.goog"
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  # Private Cluster Configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false           # Access control plane over public internet with authorized networks
    master_ipv4_cidr_block  = "172.16.1.0/28" # Must not overlap with the first cluster's master CIDR (172.16.0.0/28)
  }

  # Recommendations: We remove the default node pool and create a custom one.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Explicit dependency on IAM role bindings to prevent "403 Forbidden" errors
  depends_on = [
    google_project_service.service_container,
    google_project_service.host_container,
    google_project_iam_member.gke_host_service_agent,
    google_project_iam_member.gke_host_security_admin,
    google_compute_subnetwork_iam_member.gke_subnet_2_network_user,
    google_compute_subnetwork_iam_member.apis_subnet_2_network_user,
    google_compute_shared_vpc_service_project.service
  ]
}

# Custom Node Pool for Cluster 2 in the Service Project (us-west1)
resource "google_container_node_pool" "secondary_nodes" {
  project    = var.service_project_id
  name       = "secondary-node-pool"
  location   = var.region_2
  cluster    = google_container_cluster.secondary.name
  node_count = 2

  management {
    auto_upgrade = true
    auto_repair  = true
  }

  node_config {
    preemptible  = false
    machine_type = "e2-medium"

    # Dedicated IAM service account with minimal scopes
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Security: Disable legacy metadata endpoints
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Security: Shielded Instance Config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}

