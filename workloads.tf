# Create 'store' namespace in Primary Cluster
resource "kubernetes_namespace_v1" "store_primary" {
  provider = kubernetes.primary
  metadata {
    name = "store"
  }
  depends_on = [google_container_node_pool.primary_nodes]
}

# Create 'store' namespace in Secondary Cluster
resource "kubernetes_namespace_v1" "store_secondary" {
  provider = kubernetes.secondary
  metadata {
    name = "store"
  }
  depends_on = [google_container_node_pool.secondary_nodes]
}

# Deploy store application to Primary Cluster
resource "kubernetes_manifest" "store_deployment_primary" {
  provider = kubernetes.primary

  manifest = yamldecode(file("${path.module}/store-deployment.yaml"))

  depends_on = [
    google_container_node_pool.primary_nodes,
    kubernetes_namespace_v1.store_primary
  ]
}

# Deploy store application to Secondary Cluster
resource "kubernetes_manifest" "store_deployment_secondary" {
  provider = kubernetes.secondary

  manifest = yamldecode(file("${path.module}/store-deployment.yaml"))

  depends_on = [
    google_container_node_pool.secondary_nodes,
    kubernetes_namespace_v1.store_secondary
  ]
}

# Deploy Service and ServiceExport on Primary Cluster (us-central1) via kubectl local-exec with isolated KUBECONFIG
resource "null_resource" "store_service_export_central1" {
  triggers = {
    manifest_sha = filemd5("${path.module}/store-service-export-central1.yaml")
  }

  depends_on = [
    google_container_node_pool.primary_nodes,
    kubernetes_namespace_v1.store_primary,
    google_gke_hub_feature.mcs_feature
  ]

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=$(mktemp)
      gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.service_project_id}
      kubectl apply --server-side --force-conflicts -f ${path.module}/store-service-export-central1.yaml
      rm -f $KUBECONFIG
    EOT
  }
}

# Deploy Service and ServiceExport on Secondary Cluster (us-west1) via kubectl local-exec with isolated KUBECONFIG
resource "null_resource" "store_service_export_west1" {
  triggers = {
    manifest_sha = filemd5("${path.module}/store-service-export-west1.yaml")
  }

  depends_on = [
    google_container_node_pool.secondary_nodes,
    kubernetes_namespace_v1.store_secondary,
    google_gke_hub_feature.mcs_feature
  ]

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=$(mktemp)
      gcloud container clusters get-credentials ${google_container_cluster.secondary.name} --region ${google_container_cluster.secondary.location} --project ${var.service_project_id}
      kubectl apply --server-side --force-conflicts -f ${path.module}/store-service-export-west1.yaml
      rm -f $KUBECONFIG
    EOT
  }
}

# Deploy Multi-Cluster Gateway on Config Cluster via kubectl local-exec with isolated KUBECONFIG
resource "null_resource" "internal_cross_region_gateway" {
  triggers = {
    manifest_sha = filemd5("${path.module}/internal-cross-region-gateway.yaml")
  }

  depends_on = [
    google_container_node_pool.primary_nodes,
    kubernetes_namespace_v1.store_primary,
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

# Deploy HTTPRoute on Config Cluster via kubectl local-exec with isolated KUBECONFIG
resource "null_resource" "internal_store_route" {
  triggers = {
    manifest_sha = filemd5("${path.module}/internal-store-route.yaml")
  }

  depends_on = [
    kubernetes_namespace_v1.store_primary,
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

# --- NEW SOLUTION 2 ARCHITECTURE (Single ServiceImport + GCPBackendPolicy Backend Preference) ---

# Deploy Preferred GKE Gateway on Config Cluster
resource "null_resource" "store_gateway_preferred" {
  triggers = {
    manifest_sha = filemd5("${path.module}/store-gateway-preferred.yaml")
  }

  depends_on = [
    google_container_node_pool.primary_nodes,
    kubernetes_namespace_v1.store_primary,
    google_gke_hub_feature.mci_feature
  ]

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=$(mktemp)
      gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.service_project_id}
      kubectl apply --server-side --force-conflicts -f ${path.module}/store-gateway-preferred.yaml
      rm -f $KUBECONFIG
    EOT
  }
}

# Deploy Preferred HTTPRoute referencing single 'store' ServiceImport
resource "null_resource" "store_route_preferred" {
  triggers = {
    manifest_sha = filemd5("${path.module}/store-route-preferred.yaml")
  }

  depends_on = [
    kubernetes_namespace_v1.store_primary,
    null_resource.store_gateway_preferred
  ]

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=$(mktemp)
      gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.service_project_id}
      kubectl apply --server-side --force-conflicts -f ${path.module}/store-route-preferred.yaml
      rm -f $KUBECONFIG
    EOT
  }
}

# Deploy GCPBackendPolicy setting backendPreference PREFERRED for primary region and DEFAULT for standby region
resource "null_resource" "store_backend_policy" {
  triggers = {
    manifest_sha = filemd5("${path.module}/store-backend-policy.yaml")
  }

  depends_on = [
    kubernetes_namespace_v1.store_primary,
    null_resource.store_route_preferred
  ]

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=$(mktemp)
      gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.service_project_id}
      kubectl apply --server-side --force-conflicts -f ${path.module}/store-backend-policy.yaml
      rm -f $KUBECONFIG
    EOT
  }
}
