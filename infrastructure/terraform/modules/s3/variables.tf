# infrastructure/terraform/modules/s3/variables.tf

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "bucket_names" {
  description = "List of S3 bucket names"
  type        = list(string)
  default     = ["data", "models", "mlflow-artifacts"]
}
