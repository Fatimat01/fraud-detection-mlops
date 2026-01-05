locals {
  target_env   = "dev"
  project_name = "fraud-detection-${local.target_env}"
  cluster_name = local.project_name
}

#data source eks
data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_secretsmanager_secret" "grafana" {
  name = "eks-secrets"
}

data "aws_secretsmanager_secret_version" "grafana" {
  secret_id = data.aws_secretsmanager_secret.grafana.id
}

# Helm Addons Module
module "helm_addons" {
  source = "../modules/helm-addons"
  providers = {
    helm       = helm
    kubernetes = kubernetes
  }
  cluster_name           = data.aws_eks_cluster.this.name
  cluster_endpoint       = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = data.aws_eks_cluster.this.certificate_authority[0].data
  oidc_provider_arn      = data.aws_iam_openid_connect_provider.eks.arn
  environment            = local.target_env
  vpc_id                 = data.aws_eks_cluster.this.vpc_config[0].vpc_id
  # Security
  enable_kyverno      = true
  enable_cert_manager = true

  # Networking
  enable_ingress_nginx                = true
  enable_aws_load_balancer_controller = true

  # Monitoring (NEW)
  enable_prometheus = true
  enable_grafana    = true
  enable_loki       = true

  # Grafana admin password
  grafana_admin_password = jsondecode(data.aws_secretsmanager_secret_version.grafana.secret_string)["grafana_admin_password"]
}

# Kyverno Policies Module (NEW)
module "kyverno_policies" {
  source = "../modules/kyverno-policies"

  environment = local.target_env
  github_org  = var.github_org
  github_repo = var.github_repo

  depends_on = [module.helm_addons]
}
