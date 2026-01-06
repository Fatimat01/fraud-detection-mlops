# Grafana - Visualization and Dashboards

resource "helm_release" "grafana" {
  count = var.enable_grafana ? 1 : 0

  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  #  version    = "10.0.0"
  namespace = "monitoring"

  create_namespace = true # Create if prometheus is disabled
  wait             = true
  timeout          = 900

  depends_on = [
    helm_release.kube_prometheus_stack
  ]

  values = [
    yamlencode({
      # Replicas
      replicas = var.environment == "prod" ? 2 : 1

      # Admin credentials
      adminUser     = "admin"
      adminPassword = var.grafana_admin_password

      # Persistence
      persistence = {
        enabled          = true
        storageClassName = "gp3"
        size             = "10Gi"
        accessModes      = ["ReadWriteOnce"]
      }

      # Resources
      resources = {
        limits = {
          memory = "512Mi"
        }
        requests = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }

      # Data sources
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
              access    = "proxy"
              isDefault = true
              jsonData = {
                timeInterval = "30s"
              }
            },
            {
              name   = "Loki"
              type   = "loki"
              url    = "http://loki.monitoring.svc.cluster.local:3100"
              access = "proxy"
            },
            {
              name   = "AlertManager"
              type   = "alertmanager"
              url    = "http://kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093"
              access = "proxy"
              jsonData = {
                implementation = "prometheus"
              }
            }
          ]
        }
      }

      # Dashboard providers
      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name            = "default"
              orgId           = 1
              folder          = ""
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            },
            {
              name            = "kubernetes"
              orgId           = 1
              folder          = "Kubernetes"
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/kubernetes"
              }
            },
            {
              name            = "application"
              orgId           = 1
              folder          = "Application"
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/application"
              }
            }
          ]
        }
      }

      # Pre-installed dashboards
      dashboards = {
        default = {
          # Cluster overview
          "cluster-overview" = {
            gnetId     = 7249
            revision   = 1
            datasource = "Prometheus"
          }

          # Node exporter full
          "node-exporter" = {
            gnetId     = 1860
            revision   = 31
            datasource = "Prometheus"
          }
        }

        kubernetes = {
          # Kubernetes cluster monitoring
          "k8s-cluster-monitoring" = {
            gnetId     = 7249
            revision   = 1
            datasource = "Prometheus"
          }

          # Kubernetes pods
          "k8s-pods" = {
            gnetId     = 6417
            revision   = 1
            datasource = "Prometheus"
          }

          # Kubernetes deployments
          "k8s-deployments" = {
            gnetId     = 8588
            revision   = 1
            datasource = "Prometheus"
          }

          # Persistent volumes
          "k8s-persistent-volumes" = {
            gnetId     = 13646
            revision   = 2
            datasource = "Prometheus"
          }
        }

        application = {
          # Will be populated by application team via CI/CD
          # Placeholder for custom dashboards
        }
      }

      # Grafana configuration
      "grafana.ini" = {
        server = {
          root_url = var.environment == "prod" ? "https://grafana.yourdomain.com" : ""
        }

        analytics = {
          reporting_enabled = false
          check_for_updates = false
        }

        security = {
          admin_user = "admin"
          # Disable guest access
          allow_embedding = false
        }

        users = {
          # Allow users to sign up
          allow_sign_up        = false
          auto_assign_org      = true
          auto_assign_org_role = "Viewer"
        }

        auth = {
          disable_login_form   = false
          disable_signout_menu = false
        }

        "auth.anonymous" = {
          enabled = false
        }

        # Alerting
        alerting = {
          enabled = true
        }

        # Unified alerting
        "unified_alerting" = {
          enabled = true
        }
      }

      # Service configuration
      service = {
        type = "ClusterIP"
        port = 80
      }

      # Ingress (optional)
      ingress = {
        enabled = false
        # Uncomment for external access
        # enabled = true
        # ingressClassName = "nginx"
        # hosts = ["grafana.${var.environment}.yourdomain.com"]
        # tls = [
        #   {
        #     secretName = "grafana-tls"
        #     hosts      = ["grafana.${var.environment}.yourdomain.com"]
        #   }
        # ]
      }

      # Plugins
      plugins = [
        "grafana-piechart-panel",
        "grafana-clock-panel",
        "grafana-simple-json-datasource",
      ]

      # ServiceMonitor for Grafana itself
      serviceMonitor = {
        enabled = true
        labels = {
          release = "kube-prometheus-stack"
        }
      }

      # Security context
      securityContext = {
        runAsNonRoot = true
        runAsUser    = 472
        fsGroup      = 472
      }

      # Sidecar for automatic dashboard discovery
      sidecar = {
        dashboards = {
          enabled = true
          label   = "grafana_dashboard"
          # Watch all namespaces for ConfigMaps with dashboards
          searchNamespace = "ALL"
        }

        datasources = {
          enabled = true
          label   = "grafana_datasource"
        }
      }
    })
  ]
}

# Output
output "grafana_namespace" {
  description = "Namespace where Grafana is deployed"
  value       = var.enable_grafana ? helm_release.grafana[0].namespace : null
}

output "grafana_service" {
  description = "Grafana service name"
  value       = var.enable_grafana ? "grafana" : null
}
