# Multi-Cluster GKE Standard Setup with Shared VPC Terraform Configuration

This repository contains the Terraform configurations and Kubernetes manifests to deploy a multi-region, standard GKE cluster architecture (version 1.36+) in a Service Project, connected to a Shared VPC network in a Host Project. It incorporates GKE Hub Fleet registration, Multi-Cluster Services (MCS), Multi-Cluster Gateway API routing, and workload management.

## Architecture Diagram

![GKE Shared VPC Architecture](assets/gke_shared_vpc_topology.png)

## GKE & Infrastructure Overview

- **Shared VPC Architecture**: Host project manages network infrastructure (VPC, subnets, firewall rules, NAT), while GKE cluster resources reside securely in the Service Project.
- **Multi-Region Clusters**:
  - **Primary Cluster**: `gke-shared-vpc-cluster` located in `us-central1` (Subnet: `10.10.0.0/18`, Pods: `240.0.0.0/16`).
  - **Secondary Cluster**: `gke-shared-vpc-cluster-2` located in `us-west1` (Subnet: `10.20.0.0/18`, Pods: `240.0.0.0/16`).
- **Fleet & Multi-Cluster Features**:
  - Both clusters are registered to GKE Hub (Fleet).
  - **Multi-Cluster Services (MCS)** (`multiclusterservicediscovery`) enabled for cross-cluster service discovery (`.clusterset.local`).
  - **Multi-Cluster Gateway / Ingress** (`multiclusteringress`) enabled with the primary cluster configured as the Fleet config membership.
- **Security Hardening**: Private nodes, dedicated least-privilege node service accounts, Shielded VMs, Secure Boot, Workload Identity (`.svc.id.goog`), and legacy metadata endpoints disabled.

## File Structure

### Terraform Configurations
- [providers.tf](providers.tf) - Configures Terraform providers (`google`, `google-beta`, `kubernetes` for primary & secondary clusters).
- [variables.tf](variables.tf) - Defines input variables including project IDs, regions (`us-central1` & `us-west1`), and CIDR blocks.
- [vpc.tf](vpc.tf) - Provisions Shared VPC, subnets, proxy-only subnets for regional ILBs, Cloud NAT gateways, and firewall rules in the Host Project.
- [iam.tf](iam.tf) - Configures IAM permissions for cross-project Shared VPC attachment and GKE service agents.
- [gke.tf](gke.tf) - Deploys primary and secondary GKE clusters and custom node pools in the Service Project.
- [fleet.tf](fleet.tf) - Registers GKE clusters to GKE Hub Fleet and enables MCS and MCI features.
- [workloads.tf](workloads.tf) - Deploys namespaces, store application workloads, ServiceExports, and Gateway API routing.
- [custom_lb_option1a.tf](custom_lb_option1a.tf) - Optional Terraform configuration for deploying an internal application load balancer targeting GKE Network Endpoint Groups (NEGs).
- [outputs.tf](outputs.tf) - Exports cluster endpoints, names, and Fleet membership details.

### Kubernetes Manifests & Routing
- [store-deployment.yaml](store-deployment.yaml) - Sample store microservice application deployment.
- [store-service.yaml](store-service.yaml) - Standard Kubernetes cluster-local Service definition.
- [store-service-export-central1.yaml](store-service-export-central1.yaml) & [store-service-export-west1.yaml](store-service-export-west1.yaml) - Multi-Cluster ServiceExports for cross-region Fleet discovery.
- [internal-cross-region-gateway.yaml](internal-cross-region-gateway.yaml) & [store-gateway-preferred.yaml](store-gateway-preferred.yaml) - Gateway API specifications for multi-cluster ingress traffic.
- [internal-store-route.yaml](internal-store-route.yaml) & [store-route-preferred.yaml](store-route-preferred.yaml) - HTTPRoute rules directing external/internal traffic to store backends.
- [store-backend-policy.yaml](store-backend-policy.yaml) - GCPBackendPolicy defining load balancing and health check policies.
- [ip-masq-agent-config.yaml](ip-masq-agent-config.yaml) - IP masquerade agent configuration for custom pod egress routing.
- [ssh-client-deployment.yaml](ssh-client-deployment.yaml) - Utility debugging client deployment.

## Prerequisites

Before running Terraform:
1. Ensure you have two Google Cloud projects:
   - **Host Project** (e.g., `gke-host-project-499816`)
   - **Service Project** (e.g., `gke-service-project-499816`)
2. Have active GCP credentials with appropriate permissions in both projects (e.g., Project Owner or Network Admin in Host project, Kubernetes Engine Admin & GKE Hub Admin in Service project).
3. Install the Terraform CLI (v1.3.0+) and `kubectl`.

## How to Deploy

1. Clone or open this repository.
2. Initialize Terraform working directory:
   ```bash
   terraform init
   ```
3. Verify or update `terraform.tfvars` with your GCP Project IDs:
   ```hcl
   host_project_id    = "gke-host-project-499816"
   service_project_id = "gke-service-project-499816"
   ```
4. Preview infrastructure changes:
   ```bash
   terraform plan
   ```
5. Apply configuration to provision network, clusters, fleet memberships, and workloads:
   ```bash
   terraform apply
   ```

