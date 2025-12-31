# AWS Load Balancer Controller
# Required for ALB/NLB integration with Kubernetes

locals {
  oidc_provider_url = replace(
    var.oidc_provider_arn,
    "arn:aws:iam::${split(":", var.oidc_provider_arn)[4]}:oidc-provider/",
    ""
  )
}

# IAM role for service account
resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name = "${var.cluster_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# IAM policy for AWS Load Balancer Controller
resource "aws_iam_role_policy" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name = "AWSLoadBalancerControllerIAMPolicy"
  role = aws_iam_role.aws_load_balancer_controller[0].id

  policy = file("${path.module}/policies/lb-controller-policy.json")
}

# Helm release
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
#  version    = "1.6.0"
  namespace  = "kube-system"

  wait    = true
  timeout = 300

  depends_on = [
    time_sleep.wait_for_cluster,
    aws_iam_role_policy.aws_load_balancer_controller
  ]

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller[0].arn
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "replicaCount"
    value = var.environment == "prod" ? "2" : "1"
  }
}
