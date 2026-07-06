# ==============================================================================
# Workloads & Routing Managed via GitOps (GKE Config Sync)
# ==============================================================================
# All store-* application manifests (Deployment, Service, ServiceExport, Gateway,
# HTTPRoute, GCPBackendPolicy) have been migrated into GitOps configuration under:
#   - gitops/base/               (Shared Namespace, Deployment, Service definitions)
#   - gitops/clusters/primary/   (Primary Config Cluster manifests & Kustomization)
#   - gitops/clusters/secondary/ (Secondary Cluster manifests & Kustomization)
#
# Continuous deployment and synchronization are configured via GKE Hub Fleet
# Config Sync (google_gke_hub_feature_membership in fleet.tf).
# ==============================================================================

# Deploy legacy Multi-Cluster Gateway on Config Cluster via kubectl local-exec if required
resource "null_resource" "internal_cross_region_gateway" {
  triggers = {
    manifest_sha = filemd5("${path.module}/internal-cross-region-gateway.yaml")
  }

  depends_on = [
    google_container_node_pool.primary_nodes,
    google_gke_hub_feature.mci_feature
  ]

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=$(mktemp)
      gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.service_project_id}
      kubectl apply --server-side --force-conflicts -f ${path.module}/internal-cross-region-gateway.yaml
      rm -f $KUBECONFIG
    EOT
  }
}

# Deploy legacy HTTPRoute on Config Cluster via kubectl local-exec if required
resource "null_resource" "internal_store_route" {
  triggers = {
    manifest_sha = filemd5("${path.module}/internal-store-route.yaml")
  }

  depends_on = [
    null_resource.internal_cross_region_gateway
  ]

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=$(mktemp)
      gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.service_project_id}
      kubectl apply --server-side --force-conflicts -f ${path.module}/internal-store-route.yaml
      rm -f $KUBECONFIG
    EOT
  }
}
