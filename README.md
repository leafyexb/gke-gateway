# GKE Standard Cluster with Shared VPC Terraform Configuration

This repository contains the Terraform configuration to deploy a standard GKE cluster (version 1.36+) in a Service Project, connected to a Shared VPC network in a Host Project.

## Architecture Diagram

![GKE Shared VPC Architecture](assets/gke_shared_vpc_topology.png)

## File Structure

- [providers.tf](providers.tf) - Defines the required terraform and Google providers.
- [variables.tf](variables.tf) - Configures input variables, including CIDR blocks, projects, and regions.
- [vpc.tf](vpc.tf) - Provisions the host project's Shared VPC network, subnet, and enables Shared VPC.
- [iam.tf](iam.tf) - Configures the host project IAM role bindings required for the service project GKE resources.
- [gke.tf](gke.tf) - Provisions the GKE cluster and node pools in the service project.
- [outputs.tf](outputs.tf) - Lists deployment outputs like cluster endpoint and name.

## Configuration Details

The setup conforms to the following specifications:
- **Kubernetes Version**: 1.36+ (configured via `kubernetes_version` variable, defaulting to `1.36`).
- **Node IP range (Primary subnet)**: `10.10.0.0/18`
- **Pod IP range (Secondary subnet range)**: `240.0.0.0/16`
- **Services IP range**: GKE-managed default range (allocated automatically by GKE, not configured in the host subnet)
- **Shared VPC architecture**: VPC resides in the Host Project, GKE resources reside in the Service Project.

## Prerequisites

Before running Terraform:
1. Ensure you have two Google Cloud projects:
   - **Host Project** (e.g. `my-vpc-host-project`)
   - **Service Project** (e.g. `my-gke-service-project`)
2. Have active GCP credentials with appropriate permissions in both projects (e.g. Project Owner or Network Admin in the Host project, and Kubernetes Engine Admin in the Service project).
3. Install the Terraform CLI (v1.3.0+).

## How to Deploy

1. Clone or open this workspace.
2. Initialize the working directory:
   ```bash
   terraform init
   ```
3. The `terraform.tfvars` file has been pre-created in the workspace with your project IDs:
   ```hcl
   host_project_id    = "gke-host-project-499816"
   service_project_id = "gke-service-project-499816"
   ```
4. Verify the resources to be created:
   ```bash
   terraform plan
   ```
5. Apply the changes:
   ```bash
   terraform apply
   ```
