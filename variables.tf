variable "host_project_id" {
  type        = string
  description = "The ID of the host project where the Shared VPC network is defined."
}

variable "service_project_id" {
  type        = string
  description = "The ID of the service project where the GKE cluster will be deployed."
}

variable "region" {
  type        = string
  description = "The region where network resources and the GKE cluster should be provisioned."
  default     = "us-central1"
}

variable "vpc_name" {
  type        = string
  description = "The name of the VPC network to create/use in the host project."
  default     = "shared-vpc"
}

variable "subnet_name" {
  type        = string
  description = "The name of the subnet to create/use for GKE nodes."
  default     = "gke-subnet"
}

variable "node_cidr" {
  type        = string
  description = "The IP range (CIDR) for GKE node instances."
  default     = "10.10.0.0/18"
}

variable "pod_cidr" {
  type        = string
  description = "The IP range (CIDR) for GKE pods (secondary subnet range)."
  default     = "240.0.0.0/16"
}


variable "kubernetes_version" {
  type        = string
  description = "The GKE Kubernetes version to target."
  default     = "1.36"
}

variable "region_2" {
  type        = string
  description = "The second region where network resources and the second GKE cluster should be provisioned."
  default     = "us-west1"
}

variable "subnet_name_2" {
  type        = string
  description = "The name of the second subnet to create/use for GKE nodes in us-west1."
  default     = "gke-subnet"
}

variable "node_cidr_2" {
  type        = string
  description = "The IP range (CIDR) for the second GKE cluster node instances in us-west1."
  default     = "10.10.64.0/18"
}

variable "pod_cidr_2" {
  type        = string
  description = "The IP range (CIDR) for GKE pods in the second cluster (secondary subnet range)."
  default     = "240.1.0.0/16"
}

