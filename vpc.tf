# Enable APIs in the Host Project
resource "google_project_service" "host_compute" {
  project            = var.host_project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "host_container" {
  project            = var.host_project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# Enable APIs in the Service Project
resource "google_project_service" "service_compute" {
  project            = var.service_project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "service_container" {
  project            = var.service_project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# Enable Shared VPC Host Project
resource "google_compute_shared_vpc_host_project" "host" {
  project    = var.host_project_id
  depends_on = [google_project_service.host_compute]
}

# Associate Service Project with Shared VPC Host
resource "google_compute_shared_vpc_service_project" "service" {
  host_project    = var.host_project_id
  service_project = var.service_project_id

  depends_on = [
    google_compute_shared_vpc_host_project.host,
    google_project_service.service_compute
  ]
}

# Create VPC Network in Host Project
resource "google_compute_network" "shared_vpc" {
  name                    = var.vpc_name
  project                 = var.host_project_id
  auto_create_subnetworks = false

  depends_on = [google_project_service.host_compute]
}

# Create Subnet in Host Project
resource "google_compute_subnetwork" "gke_subnet" {
  name                     = var.subnet_name
  project                  = var.host_project_id
  network                  = google_compute_network.shared_vpc.self_link
  region                   = var.region
  ip_cidr_range            = var.node_cidr # Node IP CIDR: 10.10.0.0/18
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.pod_cidr # Pod IP CIDR: 240.0.0.0/16
  }


  depends_on = [google_compute_network.shared_vpc]
}

# Create Second Subnet in Host Project (us-west1)
resource "google_compute_subnetwork" "gke_subnet_2" {
  name                     = var.subnet_name_2
  project                  = var.host_project_id
  network                  = google_compute_network.shared_vpc.self_link
  region                   = var.region_2
  ip_cidr_range            = var.node_cidr_2 # Node IP CIDR: 10.10.64.0/18
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.pod_cidr_2 # Pod IP CIDR: 240.1.0.0/16
  }

  depends_on = [google_compute_network.shared_vpc]
}


# Create Cloud Router in Host Project
resource "google_compute_router" "router" {
  name    = "shared-vpc-router"
  project = var.host_project_id
  region  = var.region
  network = google_compute_network.shared_vpc.self_link

  depends_on = [google_compute_network.shared_vpc]
}

# Create Cloud NAT in Host Project
resource "google_compute_router_nat" "nat" {
  name                               = "shared-vpc-nat"
  project                            = var.host_project_id
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke_subnet.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"] # NATs both GKE nodes (primary range) and GKE pods (secondary ranges)
  }

  depends_on = [google_compute_router.router, google_compute_subnetwork.gke_subnet]
}

# Create Second Cloud Router in Host Project (us-west1)
resource "google_compute_router" "router_2" {
  name    = "shared-vpc-router-2"
  project = var.host_project_id
  region  = var.region_2
  network = google_compute_network.shared_vpc.self_link

  depends_on = [google_compute_network.shared_vpc]
}

# Create Second Cloud NAT in Host Project (us-west1)
resource "google_compute_router_nat" "nat_2" {
  name                               = "shared-vpc-nat-2"
  project                            = var.host_project_id
  router                             = google_compute_router.router_2.name
  region                             = var.region_2
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke_subnet_2.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  depends_on = [google_compute_router.router_2, google_compute_subnetwork.gke_subnet_2]
}


# Create Global Network Firewall Policy in Host Project
resource "google_compute_network_firewall_policy" "iap_policy" {
  name        = "shared-vpc-firewall-policy"
  project     = var.host_project_id
  description = "Network firewall policy for Shared VPC"
}

# Create Ingress Firewall Rule allowing IAP SSH (35.235.240.0/20) on port 22 to all instances
resource "google_compute_network_firewall_policy_rule" "allow_iap_ssh" {
  project         = var.host_project_id
  firewall_policy = google_compute_network_firewall_policy.iap_policy.name

  description = "Allow ingress SSH from Identity-Aware Proxy to all instances"
  priority    = 1000
  action      = "allow"
  direction   = "INGRESS"

  match {
    src_ip_ranges = [
      "35.235.240.0/20", # Google IAP TCP forwarding CIDR range
      var.node_cidr      # GKE Nodes primary subnet CIDR range
    ]
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["22"]
    }
  }
}

# Create Ingress Firewall Rule allowing Traffic from Proxy-Only Subnets to GKE Nodes
resource "google_compute_network_firewall_policy_rule" "allow_proxy_ingress" {
  project         = var.host_project_id
  firewall_policy = google_compute_network_firewall_policy.iap_policy.name

  description = "Allow ingress from proxy-only subnets to GKE nodes"
  priority    = 1010
  action      = "allow"
  direction   = "INGRESS"

  match {
    src_ip_ranges = [
      "10.129.0.0/23", # us-central1 proxy-only subnet
      "10.130.0.0/23"  # us-west1 proxy-only subnet
    ]
    layer4_configs {
      ip_protocol = "tcp"
    }
  }
}

# Associate the Firewall Policy with the VPC Network
resource "google_compute_network_firewall_policy_association" "iap_policy_association" {
  name              = "shared-vpc-firewall-association"
  project           = var.host_project_id
  attachment_target = google_compute_network.shared_vpc.self_link
  firewall_policy   = google_compute_network_firewall_policy.iap_policy.id

  depends_on = [
    google_compute_network.shared_vpc,
    google_compute_network_firewall_policy.iap_policy
  ]
}

# Proxy-Only Subnet for us-central1 (required for cross-region internal load balancer / MCG)
resource "google_compute_subnetwork" "proxy_subnet_us_central1" {
  name          = "proxy-subnet-us-central1"
  project       = var.host_project_id
  region        = var.region
  network       = google_compute_network.shared_vpc.self_link
  ip_cidr_range = "10.129.0.0/23"
  purpose       = "GLOBAL_MANAGED_PROXY"
  role          = "ACTIVE"

  depends_on = [google_compute_network.shared_vpc]
}

# Proxy-Only Subnet for us-west1 (required for cross-region internal load balancer / MCG)
resource "google_compute_subnetwork" "proxy_subnet_us_west1" {
  name          = "proxy-subnet-us-west1"
  project       = var.host_project_id
  region        = var.region_2
  network       = google_compute_network.shared_vpc.self_link
  ip_cidr_range = "10.130.0.0/23"
  purpose       = "GLOBAL_MANAGED_PROXY"
  role          = "ACTIVE"

  depends_on = [google_compute_network.shared_vpc]
}



