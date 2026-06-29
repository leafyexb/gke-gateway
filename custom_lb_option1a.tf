# Option 1A: Custom GCP Backend Service with Preferred vs Default Backend Preference across all zonal NEGs

# 1. Health Check for Store Service
resource "google_compute_health_check" "custom_lb_hc" {
  name               = "custom-lb-store-hc"
  project            = var.service_project_id
  check_interval_sec = 5
  timeout_sec        = 5

  http_health_check {
    port = 8080
  }
}

# 2. Global Backend Service implementing Option 1A with all zonal backends
resource "google_compute_backend_service" "custom_lb_backend_service" {
  name                  = "custom-lb-store-backend-service"
  project               = var.service_project_id
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.custom_lb_hc.id]

  # --- PRIMARY CLUSTER BACKENDS (us-central1) - PREFERRED ---
  backend {
    group                 = "https://www.googleapis.com/compute/v1/projects/${var.service_project_id}/zones/${var.region}-a/networkEndpointGroups/k8s1-289fc8a3-store-store-central-1-8080-7281d060"
    preference            = "PREFERRED"
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
  }

  backend {
    group                 = "https://www.googleapis.com/compute/v1/projects/${var.service_project_id}/zones/${var.region}-b/networkEndpointGroups/k8s1-289fc8a3-store-store-central-1-8080-7281d060"
    preference            = "PREFERRED"
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
  }

  backend {
    group                 = "https://www.googleapis.com/compute/v1/projects/${var.service_project_id}/zones/${var.region}-f/networkEndpointGroups/k8s1-289fc8a3-store-store-central-1-8080-7281d060"
    preference            = "PREFERRED"
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
  }

  # --- STANDBY CLUSTER BACKENDS (us-west1) - DEFAULT ---
  backend {
    group                 = "https://www.googleapis.com/compute/v1/projects/${var.service_project_id}/zones/${var.region_2}-a/networkEndpointGroups/k8s1-c0e03206-store-store-west-1-8080-bdf930bc"
    preference            = "DEFAULT"
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
  }

  backend {
    group                 = "https://www.googleapis.com/compute/v1/projects/${var.service_project_id}/zones/${var.region_2}-b/networkEndpointGroups/k8s1-c0e03206-store-store-west-1-8080-bdf930bc"
    preference            = "DEFAULT"
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
  }

  backend {
    group                 = "https://www.googleapis.com/compute/v1/projects/${var.service_project_id}/zones/${var.region_2}-c/networkEndpointGroups/k8s1-c0e03206-store-store-west-1-8080-bdf930bc"
    preference            = "DEFAULT"
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
  }
}

# 3. URL Map directing default traffic to the Backend Service
resource "google_compute_url_map" "custom_lb_url_map" {
  name            = "custom-lb-store-url-map"
  project         = var.service_project_id
  default_service = google_compute_backend_service.custom_lb_backend_service.id
}

# 4. Target HTTP Proxy
resource "google_compute_target_http_proxy" "custom_lb_target_proxy" {
  name    = "custom-lb-store-target-proxy"
  project = var.service_project_id
  url_map = google_compute_url_map.custom_lb_url_map.id
}

# 5. Global Internal Forwarding Rule for Primary Region (us-central1)
resource "google_compute_global_forwarding_rule" "custom_lb_forwarding_rule_central" {
  name                  = "custom-lb-store-forwarding-rule-central"
  project               = var.service_project_id
  target                = google_compute_target_http_proxy.custom_lb_target_proxy.id
  port_range            = "80"
  load_balancing_scheme = "INTERNAL_MANAGED"
  network               = google_compute_network.shared_vpc.self_link
  subnetwork            = google_compute_subnetwork.gke_subnet.self_link
}

# 6. Global Internal Forwarding Rule for Secondary Region (us-west1)
resource "google_compute_global_forwarding_rule" "custom_lb_forwarding_rule_west" {
  name                  = "custom-lb-store-forwarding-rule-west"
  project               = var.service_project_id
  target                = google_compute_target_http_proxy.custom_lb_target_proxy.id
  port_range            = "80"
  load_balancing_scheme = "INTERNAL_MANAGED"
  network               = google_compute_network.shared_vpc.self_link
  subnetwork            = google_compute_subnetwork.gke_subnet_2.self_link
}
