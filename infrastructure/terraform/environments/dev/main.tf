# infrastructure/terraform/environments/dev/main.tf

module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  az_count     = var.az_count
}

module "ecr" {
  source = "../../modules/ecr"

  project_name     = var.project_name
  environment      = var.environment
  repository_names = ["training", "serving"]
}

module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment
  bucket_names = ["data", "models", "mlflow-artifacts"]
}

module "eks" {
  source = "../../modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  cluster_version     = var.eks_cluster_version
  node_instance_types = var.eks_node_instance_types
  capacity_type       = var.eks_capacity_type
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size

  depends_on = [module.vpc]
}



module "rds" {
  source = "../../modules/rds"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.eks.node_group_security_group_id]

  # Dev settings (cost-optimized)
  instance_class               = var.rds_instance_class
  allocated_storage            = var.rds_allocated_storage
  multi_az                     = false
  deletion_protection          = false
  performance_insights_enabled = false

  depends_on = [module.vpc, module.eks]
}
