# cert-manager - TLS Certificate Management
resource "helm_release" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  #  version    = "v1.13.0"
  namespace = "cert-manager"

  create_namespace = true
  wait             = true
  timeout          = 300

  depends_on = [time_sleep.wait_for_cluster]

  values = [
    yamlencode({
      installCRDs = true

      replicaCount = var.environment == "prod" ? 2 : 1

      resources = {
        limits = {
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      # Enable Prometheus metrics
      prometheus = {
        enabled = true
      }
    })
  ]
}
