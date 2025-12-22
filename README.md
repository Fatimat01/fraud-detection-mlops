# Fraud Detection MLOps - Deployment Guide

This repository contains an end-to-end MLOps example with:
- Model training (XGBoost + MLflow)
- Model serving (FastAPI + Prometheus metrics)
- Docker images for training and serving
- Kubernetes deployment via Helm
- Infrastructure provisioning via Terraform
- CI/CD pipelines in GitHub Actions

## Prerequisites

- Python 3.10+
- Docker + Docker Buildx
- AWS CLI (authenticated)
- Terraform 1.9.0+
- kubectl
- Helm 3.13+

## Local end-to-end deployment (Terraform + ECR + Helm)

This mirrors the CI/CD lifecycle using Makefile targets.

1) Set environment variables
```sh
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REGISTRY=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
export TF_ENV=dev
export HELM_ENV=staging
export K8S_NAMESPACE=staging
```

2) Bootstrap the Terraform backend (first time only)
```sh
make tf-bootstrap
```

3) Provision infrastructure
```sh
make tf-init
make tf-plan
make tf-apply
```

4) Configure kubectl for the new cluster
```sh
make kubeconfig
```

5) Train or refresh local model artifacts
```sh
python -m src.training.train
```

6) Build and push images to ECR
```sh
make push-ecr
```

7) Deploy to the cluster with Helm
```sh
make helm-deploy
```

8) Verify rollout and run smoke tests
```sh
make k8s-verify
make k8s-smoke
```

Notes:
- `TF_ENV` defaults to `dev` because only `infrastructure/terraform/environments/dev` exists.
- Override `IMAGE_TAG` for deterministic releases: `IMAGE_TAG=v1.2.3 make push-ecr`.
- `HELM_ENV` selects `helm/serving/values-$(HELM_ENV).yaml` if present.

## Local Docker-only deployment (no cloud)

Use this for quick local dev without Terraform, ECR, or Helm.

```sh
python -m src.training.train
make build-local
make local-up
make local-status
curl http://localhost:8000/health
```

Dashboards:
- MLflow: http://localhost:5000
- API docs: http://localhost:8000/docs
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)

Stop services:
```sh
make local-down
```

## CI/CD overview

1) CI Pipeline (`.github/workflows/ci.yaml`)
   - Linting, tests, security scans, IaC checks, and Docker build validation.

2) Build, Scan, Sign, Push (`.github/workflows/cd-build-push.yaml`)
   - Builds training/serving images, scans with Trivy, signs with Cosign,
     attests SBOMs, and publishes an `image-manifest.json` artifact.

3) Deploy to Staging (`.github/workflows/cd-staging.yaml`)
   - Consumes `image-manifest.json`, verifies signature/SBOM, deploys with Helm,
     and runs smoke tests.

4) Promote to Production (`.github/workflows/cd-promote-production.yaml`)
   - Validates staging, retags image, deploys to prod, runs smoke tests.

5) Rollback (`.github/workflows/rollback-production.yaml`)
   - Helm rollback on prod.

6) Terraform workflows
   - Plan on PRs (`terraform-plan.yaml`), Apply on manual dispatch
     (`terraform-apply.yaml`), Drift detection on schedule
     (`terraform-drift.yaml`).

## Makefile targets (quick reference)

| Target | Purpose |
| --- | --- |
| `make install` | Install dev dependencies and pre-commit hooks |
| `make lint` | Run ruff, black, and mypy |
| `make test` | Run unit tests |
| `make test-all` | Run full test suite with coverage |
| `make security` | Run Bandit security scan |
| `make build-local` | Build local training + serving images |
| `make local-up` | Start local MLflow/Serving/Prometheus/Grafana |
| `make local-down` | Stop local services |
| `make tf-bootstrap` | Bootstrap Terraform backend (one-time) |
| `make tf-init` | Terraform init for selected env |
| `make tf-plan` | Terraform plan |
| `make tf-apply` | Terraform apply |
| `make tf-destroy` | Terraform destroy |
| `make kubeconfig` | Configure kubectl for EKS cluster |
| `make push-ecr` | Build and push images to ECR |
| `make helm-deploy` | Deploy serving app with Helm |
| `make k8s-verify` | Verify rollout status |
| `make k8s-smoke` | Smoke test health/metrics endpoints |

## Cleanup

Helm uninstall:
```sh
make helm-uninstall
```

Terraform destroy:
```sh
make tf-destroy
```
