# infrastructure/terraform/modules/ecr/variables.tf

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "repository_names" {
  description = "List of ECR repository names"
  type        = list(string)
  default     = ["training", "serving"]
}
