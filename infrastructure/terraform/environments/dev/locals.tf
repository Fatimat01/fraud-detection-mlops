# Local variables
locals {
  cluster_name = "${var.project_name}-${var.environment}"
  common_tags = {
    Environment = "dev"
    Project     = "fraud-detection-mlops"
    ManagedBy   = "terraform"
  }
}
