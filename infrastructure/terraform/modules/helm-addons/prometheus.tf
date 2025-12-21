# Prometheus Stack (Operator + Prometheus + AlertManager)
# Using kube-prometheus-stack (formerly prometheus-operator)

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.5.0"
  namespace  = "monitoring"

  create_namespace = true
  wait             = true
  timeout          = 600

  depends_on = [time_sleep.wait_for_cluster]

  values = [
    yamlencode({
      # Prometheus Operator
      prometheusOperator = {
        enabled = true

        resources = {
          limits = {
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
        }

        # Create CRDs
        createCustomResource = true

        # Monitor the operator itself
        serviceMonitor = {
          enabled = true
        }
      }

      # Prometheus Server
      prometheus = {
        enabled = true

        prometheusSpec = {
          replicas = var.environment == "prod" ? 2 : 1

          # Retention
          retention = var.environment == "prod" ? "30d" : "15d"
          retentionSize = "10GB"

          # Storage
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.environment == "prod" ? "50Gi" : "20Gi"
                  }
                }
              }
            }
          }

          # Resources
          resources = {
            limits = {
              memory = var.environment == "prod" ? "4Gi" : "2Gi"
            }
            requests = {
              cpu    = var.environment == "prod" ? "1000m" : "500m"
              memory = var.environment == "prod" ? "2Gi" : "1Gi"
            }
          }

          # Service monitors - what to scrape
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false

          # Enable all service monitors in all namespaces
          serviceMonitorSelector = {}
          podMonitorSelector     = {}

          # Additional scrape configs
          additionalScrapeConfigs = []

          # Security context
          securityContext = {
            runAsNonRoot = true
            runAsUser    = 65534
            fsGroup      = 65534
          }

          # Enable admin API (for remote management)
          enableAdminAPI = true

          # External labels (for federation)
          externalLabels = {
            cluster     = var.cluster_name
            environment = var.environment
          }
        }

        # Service configuration
        service = {
          type = "ClusterIP"
          port = 9090
        }

        # Ingress (optional)
        ingress = {
          enabled = false
          # Enable this if you want external access
          # ingressClassName = "nginx"
          # hosts = ["prometheus.${var.environment}.yourdomain.com"]
        }
      }

      # AlertManager
      alertmanager = {
        enabled = true

        alertmanagerSpec = {
          replicas = var.environment == "prod" ? 3 : 1

          # Storage
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }

          # Resources
          resources = {
            limits = {
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          # Security context
          securityContext = {
            runAsNonRoot = true
            runAsUser    = 65534
            fsGroup      = 65534
          }
        }

        # Configuration for alert routing
        config = {
          global = {
            resolve_timeout = "5m"
          }

          route = {
            group_by        = ["alertname", "cluster", "service"]
            group_wait      = "10s"
            group_interval  = "10s"
            repeat_interval = "12h"
            receiver        = "default"

            routes = [
              {
                match = {
                  alertname = "Watchdog"
                }
                receiver = "null"
              },
              {
                match = {
                  severity = "critical"
                }
                receiver        = "critical"
                continue        = true
                repeat_interval = "1h"
              }
            ]
          }

          receivers = [
            {
              name = "null"
            },
            {
              name = "default"
              # Add Slack/PagerDuty/Email config here
            },
            {
              name = "critical"
              # Add PagerDuty/OpsGenie config here
            }
          ]
        }
      }

      # Grafana - Disabled (we'll deploy separately with more control)
      grafana = {
        enabled = false
      }

      # Node Exporter - Collects node metrics
      nodeExporter = {
        enabled = true

        serviceMonitor = {
          enabled = true
        }
      }

      # Kube State Metrics - Collects k8s object metrics
      kubeStateMetrics = {
        enabled = true

        serviceMonitor = {
          enabled = true
        }
      }

      # Default rules and alerts
      defaultRules = {
        create = true
        rules = {
          alertmanager              = true
          etcd                      = true
          configReloaders           = true
          general                   = true
          k8s                       = true
          kubeApiserverAvailability = true
          kubeApiserverSlos         = true
          kubelet                   = true
          kubeProxy                 = true
          kubePrometheusGeneral     = true
          kubePrometheusNodeRecording = true
          kubernetesApps            = true
          kubernetesResources       = true
          kubernetesStorage         = true
          kubernetesSystem          = true
          kubeScheduler             = true
          kubeStateMetrics          = true
          network                   = true
          node                      = true
          nodeExporterAlerting      = true
          nodeExporterRecording     = true
          prometheus                = true
          prometheusOperator        = true
        }
      }

      # ServiceMonitor for kube-controller-manager
      kubeControllerManager = {
        enabled = true
        service = {
          enabled = true
          port    = 10257
          targetPort = 10257
        }
        serviceMonitor = {
          enabled = true
          https   = true
          insecureSkipVerify = true
        }
      }

      # ServiceMonitor for kube-scheduler
      kubeScheduler = {
        enabled = true
        service = {
          enabled = true
          port    = 10259
          targetPort = 10259
        }
        serviceMonitor = {
          enabled = true
          https   = true
          insecureSkipVerify = true
        }
      }

      # ServiceMonitor for CoreDNS
      coreDns = {
        enabled = true
        service = {
          enabled = true
          port    = 9153
          targetPort = 9153
        }
        serviceMonitor = {
          enabled = true
        }
      }

      # ServiceMonitor for kubelet
      kubelet = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }
    })
  ]

  # Override specific values for environment
  dynamic "set" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      name  = "prometheus.prometheusSpec.replicas"
      value = "2"
    }
  }
}
