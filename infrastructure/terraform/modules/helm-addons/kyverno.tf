# Kyverno - Policy Engine
resource "helm_release" "kyverno" {
  count = var.enable_kyverno ? 1 : 0

  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  version    = "3.1.0"
  namespace  = "kyverno"

  create_namespace = true
  wait             = true
  timeout          = 300

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
    })
  ]

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Output for use in other modules
output "kyverno_namespace" {
  value = var.enable_kyverno ? helm_release.kyverno[0].namespace : null
}
