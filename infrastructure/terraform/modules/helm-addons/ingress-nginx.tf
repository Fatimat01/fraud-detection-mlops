# NGINX Ingress Controller
resource "helm_release" "ingress_nginx" {
  count = var.enable_ingress_nginx ? 1 : 0

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
#  version    = "4.14.0"
  namespace  = "ingress-nginx"

  create_namespace = true
  wait             = true
  timeout          = 900

  depends_on = [
    helm_release.aws_load_balancer_controller
  ]

  values = [
    yamlencode({
      controller = {
        replicaCount = var.environment == "prod" ? 3 : 1

        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"              = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"  = "tcp"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          }
        }

        resources = {
          limits = {
            memory = "512Mi"
          }
          requests = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }

        # Enable metrics
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
    })
  ]
}
