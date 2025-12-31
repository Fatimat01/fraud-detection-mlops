# Kyverno - Policy Engine
resource "helm_release" "kyverno" {
  count = var.enable_kyverno ? 1 : 0

  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  #  version    = "3.6.1"
  namespace = "kyverno"

  create_namespace = true
  wait             = true
  timeout          = 900

  depends_on = [time_sleep.wait_for_cluster]

  values = [
    yamlencode({
      replicaCount = var.environment == "prod" ? 3 : 1

      resources = {
        limits = {
          memory = "512Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      # Enable policy reports
      backgroundController = {
        enabled = true
      }

      # Enable metrics for monitoring
      metricsService = {
        enabled = true
      }

      # Configure admission controller
      admissionController = {
        replicas = var.environment == "prod" ? 3 : 1
      }

      cleanupController = {
        enabled = false
      }

      cleanupJobs = {
        enabled = false
      }
    })
  ]

  set {
    name  = "installCRDs"
    value = "true"
  }
}
