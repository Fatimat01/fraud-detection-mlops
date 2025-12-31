# infrastructure/terraform/environments/dev/variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "fraud-detection"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}



# variable "grafana_admin_password" {
#   description = "Grafana admin password"
#   type        = string
#   sensitive   = true

#   validation {
#     condition     = length(var.grafana_admin_password) >= 8
#     error_message = "Grafana admin password must be at least 8 characters long."
#   }
# }
variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "Fatimat01"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "fraud-detection-mlops"
}
# variable "cluster_name" {
#   description = "EKS cluster name"
#   type        = string
# }

# variable "cluster_endpoint" {
#   description = "EKS cluster endpoint"
#   type        = string
# }

# variable "cluster_ca_certificate" {
#   description = "EKS cluster CA certificate"
#   type        = string
# }
