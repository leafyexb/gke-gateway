# Enable GKE Hub API in the Service Project
resource "google_project_service" "service_gkehub" {
  project            = var.service_project_id
  service            = "gkehub.googleapis.com"
  disable_on_destroy = false
}

# Enable APIs for Multi-Cluster Services and Multi-Cluster Ingress
resource "google_project_service" "service_mcs" {
  project            = var.service_project_id
  service            = "multiclusterservicediscovery.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "service_mci" {
  project            = var.service_project_id
  service            = "multiclusteringress.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "service_trafficdirector" {
  project            = var.service_project_id
  service            = "trafficdirector.googleapis.com"
  disable_on_destroy = false
}




# Register Primary GKE Cluster to the Fleet (GKE Hub)
resource "google_gke_hub_membership" "primary_membership" {
  provider      = google-beta
  project       = var.service_project_id
  membership_id = google_container_cluster.primary.name
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.primary.id}"
    }
  }
  depends_on = [
    google_project_service.service_gkehub,
    google_container_node_pool.primary_nodes
  ]
}

# Register Secondary GKE Cluster to the Fleet (GKE Hub)
resource "google_gke_hub_membership" "secondary_membership" {
  provider      = google-beta
  project       = var.service_project_id
  membership_id = google_container_cluster.secondary.name
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.secondary.id}"
    }
  }
  depends_on = [
    google_project_service.service_gkehub,
    google_container_node_pool.secondary_nodes
  ]
}

# Enable Multi-Cluster Services (MCS) feature in Fleet
resource "google_gke_hub_feature" "mcs_feature" {
  provider = google-beta
  project  = var.service_project_id
  name     = "multiclusterservicediscovery"
  location = "global"

  depends_on = [
    google_project_service.service_mcs,
    google_project_service.service_trafficdirector,
    google_gke_hub_membership.primary_membership,
    google_gke_hub_membership.secondary_membership
  ]
}

# Enable Multi-Cluster Ingress (MCI / Gateway) feature in Fleet with primary cluster as config membership
resource "google_gke_hub_feature" "mci_feature" {
  provider = google-beta
  project  = var.service_project_id
  name     = "multiclusteringress"
  location = "global"

  spec {
    multiclusteringress {
      config_membership = "projects/${data.google_project.service_project.number}/locations/global/memberships/${google_gke_hub_membership.primary_membership.membership_id}"
    }
  }

  depends_on = [
    google_project_service.service_mci,
    google_gke_hub_membership.primary_membership,
    google_gke_hub_membership.secondary_membership
  ]
}

# Enable GKE Hub Config Management (Config Sync) API in the Service Project
resource "google_project_service" "service_configmanagement" {
  project            = var.service_project_id
  service            = "anthosconfigmanagement.googleapis.com"
  disable_on_destroy = false
}

# Enable Config Management (Config Sync) feature in Fleet
resource "google_gke_hub_feature" "configmanagement_feature" {
  provider = google-beta
  project  = var.service_project_id
  name     = "configmanagement"
  location = "global"

  depends_on = [
    google_project_service.service_configmanagement,
    google_gke_hub_membership.primary_membership,
    google_gke_hub_membership.secondary_membership
  ]
}

# Configure Config Sync feature membership for Primary Cluster (Config Cluster)
resource "google_gke_hub_feature_membership" "configsync_primary" {
  provider   = google-beta
  project    = var.service_project_id
  location   = "global"
  feature    = google_gke_hub_feature.configmanagement_feature.name
  membership = google_gke_hub_membership.primary_membership.membership_id

  configmanagement {
    config_sync {
      enabled       = true
      source_format = "unstructured"
      git {
        sync_repo   = var.gitops_repo_url
        sync_branch = var.gitops_repo_branch
        secret_type = "none"
        policy_dir  = "gitops/clusters/primary"
      }
    }
  }
}

# Configure Config Sync feature membership for Secondary Cluster
resource "google_gke_hub_feature_membership" "configsync_secondary" {
  provider   = google-beta
  project    = var.service_project_id
  location   = "global"
  feature    = google_gke_hub_feature.configmanagement_feature.name
  membership = google_gke_hub_membership.secondary_membership.membership_id

  configmanagement {
    config_sync {
      enabled       = true
      source_format = "unstructured"
      git {
        sync_repo   = var.gitops_repo_url
        sync_branch = var.gitops_repo_branch
        secret_type = "none"
        policy_dir  = "gitops/clusters/secondary"
      }
    }
  }
}

