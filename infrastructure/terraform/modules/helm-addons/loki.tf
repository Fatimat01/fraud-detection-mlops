# Loki - Log Aggregation System

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  #  version    = "5.41.0"
  namespace = "monitoring"

  create_namespace = false # Already created
  wait             = true
  timeout          = 900

  depends_on = [helm_release.kube_prometheus_stack, time_sleep.wait_for_cluster]

  values = [
    yamlencode({
      # Deployment mode (single binary for simplicity)
      deploymentMode = "SingleBinary"

      loki = {
        # Authentication
        auth_enabled = false

        # Common configuration
        commonConfig = {
          replication_factor = 1
        }

        # Storage configuration
        storage = {
          type = "filesystem"
          filesystem = {
            chunks_directory = "/var/loki/chunks"
            rules_directory  = "/var/loki/rules"
          }
        }

        # Schema configuration
        schemaConfig = {
          configs = [
            {
              from         = "2024-01-01"
              store        = "tsdb"
              object_store = "filesystem"
              schema       = "v12"
              index = {
                prefix = "index_"
                period = "24h"
              }
            }
          ]
        }

        # Limits
        limits_config = {
          retention_period           = var.environment == "prod" ? "720h" : "360h" # 30d or 15d
          ingestion_rate_mb          = 10
          ingestion_burst_size_mb    = 20
          max_query_series           = 500
          max_query_parallelism      = 32
          reject_old_samples         = true
          reject_old_samples_max_age = "168h"
        }

        # Query configuration
        query_scheduler = {
          max_outstanding_requests_per_tenant = 256
        }

        # Ruler (for alerts)
        rulerConfig = {
          alertmanager_url = "http://kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093"
        }
      }

      # SingleBinary deployment
      singleBinary = {
        replicas = var.environment == "prod" ? 2 : 1

        resources = {
          limits = {
            memory = var.environment == "prod" ? "2Gi" : "1Gi"
          }
          requests = {
            cpu    = var.environment == "prod" ? "500m" : "250m"
            memory = var.environment == "prod" ? "1Gi" : "512Mi"
          }
        }

        # Persistence
        persistence = {
          enabled          = true
          storageClassName = "gp3"
          size             = var.environment == "prod" ? "10Gi" : "5Gi"
        }
      }

      # SimpleScalable deployment (disabled when using SingleBinary)
      simpleScalable = {
        read    = { replicas = 0 }
        write   = { replicas = 0 }
        backend = { replicas = 0 }
      }

      # Monitoring
      monitoring = {
        serviceMonitor = {
          enabled = true
          labels = {
            release = "kube-prometheus-stack"
          }
        }

        selfMonitoring = {
          enabled = false
        }

        lokiCanary = {
          enabled = false
        }
      }

      # Test pod
      test = {
        enabled = false
      }
    })
  ]
}

# Promtail - Log collector (DaemonSet on each node)
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.15.3"
  namespace  = "monitoring"

  create_namespace = false
  wait             = true
  timeout          = 600

  depends_on = [helm_release.loki]

  values = [
    yamlencode({
      config = {
        # Loki endpoint
        clients = [
          {
            url = "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
          }
        ]

        # Scrape configs
        snippets = {
          scrapeConfigs = yamlencode([
            {
              job_name = "kubernetes-pods"

              kubernetes_sd_configs = [
                {
                  role = "pod"
                }
              ]

              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_pod_node_name"]
                  target_label  = "node_name"
                },
                {
                  source_labels = ["__meta_kubernetes_namespace"]
                  target_label  = "namespace"
                },
                {
                  source_labels = ["__meta_kubernetes_pod_name"]
                  target_label  = "pod"
                },
                {
                  source_labels = ["__meta_kubernetes_pod_container_name"]
                  target_label  = "container"
                },
                {
                  source_labels = ["__meta_kubernetes_pod_label_app"]
                  target_label  = "app"
                }
              ]
            }
          ])
        }
      }

      # Resources
      resources = {
        limits = {
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      # ServiceMonitor
      serviceMonitor = {
        enabled = true
        labels = {
          release = "kube-prometheus-stack"
        }
      }
    })
  ]
}
