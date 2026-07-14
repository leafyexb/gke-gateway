# Multi-Cluster GKE Standard Setup with Shared VPC Terraform Configuration

This repository contains the Terraform configurations and Kubernetes manifests to deploy a multi-region, standard GKE cluster architecture (version 1.36+) in a Service Project, connected to a Shared VPC network in a Host Project. It incorporates GKE Hub Fleet registration, Multi-Cluster Services (MCS), Multi-Cluster Gateway API routing, and workload management.

## Architecture Diagram

![GKE Shared VPC Architecture][def]

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
- [fleet.tf](fleet.tf) - Registers GKE clusters to GKE Hub Fleet and enables MCS, MCI, and Config Sync (GitOps) features.
- [workloads.tf](workloads.tf) - References GitOps managed store workloads and legacy routing.
- [custom_lb_option1a.tf](custom_lb_option1a.tf) - Optional Terraform configuration for deploying an internal application load balancer targeting GKE Network Endpoint Groups (NEGs).
- [outputs.tf](outputs.tf) - Exports cluster endpoints, names, and Fleet membership details.

### GitOps & Kustomize Directory Layout (`gitops/`)
All `store-*` manifests are managed using **GKE Config Sync** and structured via **Kustomize**:
- `gitops/base/common/` - Shared resources (namespace, service definitions).
- `gitops/base/deployment/` - Standard deployment overlay.
  - `store-deployment.yaml` - Store microservice deployment.
- `gitops/base/rollout/` - Progressive delivery overlay.
  - `store-rollout.yaml` - Argo Rollout canary specification.
- `gitops/base/argo-rollouts/` - Controller configurations and manifests for Argo Rollouts.
- `gitops/clusters/primary/`
  - `kustomization.yaml` - Primary cluster Kustomize overlay (references `../../base/deployment` or `../../base/rollout`).
  - `store-service-export-central1.yaml` - Multi-Cluster ServiceExports for `us-central1`.
  - `store-gateway-preferred.yaml` - Cross-region Internal Gateway API specification.
  - `store-route-preferred.yaml` - HTTPRoute directing traffic to store backends.
  - `store-backend-policy.yaml` - GCPBackendPolicy defining region backend preference (`us-central1` PREFERRED, `us-west1` DEFAULT).
- `gitops/clusters/secondary/`
  - `kustomization.yaml` - Secondary cluster Kustomize overlay (references `../../base/deployment` or `../../base/rollout`).
  - `store-service-export-west1.yaml` - Multi-Cluster ServiceExports for `us-west1`.

### Utility Manifests
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



[def]: assets/gke_shared_vpc_topology.png