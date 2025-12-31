variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster is deployed"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_kyverno" {
  description = "Enable Kyverno policy engine"
  type        = bool
  default     = true
}

variable "enable_cert_manager" {
  description = "Enable cert-manager for TLS certificates"
  type        = bool
  default     = true
}

variable "enable_ingress_nginx" {
  description = "Enable NGINX Ingress Controller"
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = ""  # Will be generated if not provided
}

variable "enable_prometheus" {
  description = "Enable Prometheus monitoring stack"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Enable Grafana dashboards"
  type        = bool
  default     = true
}

variable "enable_loki" {
  description = "Enable Loki log aggregation"
  type        = bool
  default     = true
}
