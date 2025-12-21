# infrastructure/terraform/environments/dev/main.tf

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
    bucket         = "fraud-detection-terraform-state-306617143793"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile = true
    encrypt        = true
  }
}

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


# Helm Addons Module
module "helm_addons" {
  source = "../../modules/helm-addons"
  providers = {
    helm       = helm
    kubernetes = kubernetes
  }
  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority_data
  oidc_provider_arn      = module.eks.oidc_provider_arn
  environment            = var.environment

  # Security
  enable_kyverno                      = true
  enable_cert_manager                 = true

  # Networking
  enable_ingress_nginx                = true
  enable_aws_load_balancer_controller = true

  # Monitoring (NEW)
  enable_prometheus = true
  enable_grafana    = true
  enable_loki       = true

  # Grafana admin password
  grafana_admin_password = var.grafana_admin_password

  depends_on = [module.eks]
}

# Kyverno Policies Module (NEW)
module "kyverno_policies" {
  source = "../../modules/kyverno-policies"

  environment = var.environment
  github_org  = var.github_org
  github_repo = var.github_repo

  depends_on = [module.helm_addons]
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
