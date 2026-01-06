# infrastructure/terraform/modules/helm-addons/mlflow.tf

# MLflow Tracking Server

# IAM Role for MLflow (S3 access via IRSA)
resource "aws_iam_role" "mlflow" {
  count = var.enable_mlflow ? 1 : 0

  name = "${var.cluster_name}-mlflow-role"

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
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:mlflow:mlflow"
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-mlflow-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# IAM Policy for MLflow S3 access
resource "aws_iam_role_policy" "mlflow_s3" {
  count = var.enable_mlflow ? 1 : 0

  name = "mlflow-s3-access"
  role = aws_iam_role.mlflow[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.mlflow_artifact_bucket}",
          "arn:aws:s3:::${var.mlflow_artifact_bucket}/*"
        ]
      }
    ]
  })
}

# Create MLflow namespace
resource "kubernetes_namespace" "mlflow" {
  count = var.enable_mlflow ? 1 : 0

  metadata {
    name = "mlflow"

    labels = {
      name        = "mlflow"
      environment = var.environment
    }
  }

  depends_on = [time_sleep.wait_for_cluster]
}

# MLflow backend secret (RDS connection string)
resource "kubernetes_secret" "mlflow_backend" {
  count = var.enable_mlflow ? 1 : 0

  metadata {
    name      = "mlflow-backend-secret"
    namespace = kubernetes_namespace.mlflow[0].metadata[0].name
  }

  data = {
    connection-string = "postgresql://${var.mlflow_db_username}:${var.mlflow_db_password}@${var.mlflow_db_host}:5432/${var.mlflow_db_name}"
  }

  depends_on = [kubernetes_namespace.mlflow]
}

# MLflow Helm release
resource "helm_release" "mlflow" {
  count = var.enable_mlflow ? 1 : 0

  name       = "mlflow"
  chart      = "${path.module}/../../../../helm/mlflow"
  namespace  = kubernetes_namespace.mlflow[0].metadata[0].name

  wait    = true
  timeout = 600

  depends_on = [
    kubernetes_namespace.mlflow,
    kubernetes_secret.mlflow_backend,
    time_sleep.wait_for_cluster
  ]

  values = [
    yamlencode({
      replicaCount = var.environment == "prod" ? 2 : 1

      backend = {
        secretName = "mlflow-backend-secret"
        secretKey  = "connection-string"
      }

      artifacts = {
        s3 = {
          enabled = true
          bucket  = var.mlflow_artifact_bucket
          region  = var.aws_region
        }
      }

      serviceAccount = {
        create = true
        name   = "mlflow"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.mlflow[0].arn
        }
      }

      resources = {
        requests = {
          memory = var.environment == "prod" ? "512Mi" : "256Mi"
          cpu    = var.environment == "prod" ? "250m" : "100m"
        }
        limits = {
          memory = var.environment == "prod" ? "1Gi" : "512Mi"
          cpu    = var.environment == "prod" ? "1000m" : "500m"
        }
      }

      env = {
        ENVIRONMENT = var.environment
      }
    })
  ]
}
