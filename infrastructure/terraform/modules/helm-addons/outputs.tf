output "kyverno_installed" {
  description = "Whether Kyverno is installed"
  value       = var.enable_kyverno
}

output "cert_manager_installed" {
  description = "Whether cert-manager is installed"
  value       = var.enable_cert_manager
}

output "ingress_nginx_installed" {
  description = "Whether NGINX Ingress is installed"
  value       = var.enable_ingress_nginx
}

output "aws_load_balancer_controller_installed" {
  description = "Whether AWS Load Balancer Controller is installed"
  value       = var.enable_aws_load_balancer_controller
}

output "prometheus_namespace" {
  description = "Namespace where Prometheus is deployed"
  value       = helm_release.kube_prometheus_stack.namespace
}

output "prometheus_service" {
  description = "Prometheus service name"
  value       = "kube-prometheus-stack-prometheus"
}

output "alertmanager_service" {
  description = "AlertManager service name"
  value       = "kube-prometheus-stack-alertmanager"
}


# Monitoring outputs
output "prometheus_installed" {
  description = "Whether Prometheus is installed"
  value       = var.enable_prometheus
}

output "prometheus_endpoint" {
  description = "Prometheus service endpoint"
  value       = var.enable_prometheus ? "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090" : null
}

output "grafana_installed" {
  description = "Whether Grafana is installed"
  value       = var.enable_grafana
}

output "grafana_endpoint" {
  description = "Grafana service endpoint"
  value       = var.enable_grafana ? "http://grafana.monitoring.svc.cluster.local:80" : null
}

output "loki_installed" {
  description = "Whether Loki is installed"
  value       = var.enable_loki
}

output "loki_endpoint" {
  description = "Loki service endpoint"
  value       = var.enable_loki ? "http://loki.monitoring.svc.cluster.local:3100" : null
}

output "alertmanager_endpoint" {
  description = "AlertManager service endpoint"
  value       = var.enable_prometheus ? "http://kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093" : null
}
