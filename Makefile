.PHONY: install lint format test test-all security build buildx-setup \
	run-local stop-local clean \
	local-build local-up local-down local-status local-logs local-train local-restart-serving \
	tf-bootstrap tf-init tf-plan tf-apply tf-destroy tf-output kubeconfig \
	ecr-login build-training-ecr build-serving-ecr build-ecr push-training-ecr push-serving-ecr push-ecr \
	helm-deploy helm-status helm-uninstall k8s-verify k8s-smoke

COMPOSE_CMD ?= docker compose
COMPOSE_FILE ?= docker-compose.yaml
AWS_REGION ?= us-east-1
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
ECR_REGISTRY ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
ECR_REPOSITORY_TRAINING ?= fraud-detection-dev-training
ECR_REPOSITORY_SERVING ?= fraud-detection-dev-serving
IMAGE_TAG ?= git-$(shell git rev-parse --short HEAD)
CORE_TF_ENV ?= dev
TF_DIR ?= infrastructure/terraform
CORE_TF_DIR ?= infrastructure/terraform/environments/$(CORE_TF_ENV)
HELM_ADDON_DIR ?= infrastructure/terraform/helm-addons
TF_BOOTSTRAP_DIR ?= infrastructure/terraform/bootstrap
EKS_CLUSTER_NAME ?=
HELM_RELEASE ?= fraud-detection-serving
HELM_ENV ?= staging
K8S_NAMESPACE ?= $(HELM_ENV)
HELM_VALUES ?= ./helm/serving/values-$(HELM_ENV).yaml
HELM_VALUES_FILE := $(wildcard $(HELM_VALUES))
HELM_VALUES_ARG := $(if $(HELM_VALUES_FILE),--values $(HELM_VALUES_FILE),)

# Platform targets
PLATFORMS := linux/amd64,linux/arm64

# Install dependencies
install:
	pip install -e ".[dev]"
	pre-commit install

##########################################################
############## LINTING AND SECURITY CHECKS #################
# Check code quality
lint:
	ruff check src tests
	black --check src tests
	mypy src

# Clean up code automatically
format:
	ruff check --fix src tests
	black src tests

unit-test:
	pytest tests/unit -v

# Run tests with coverage
test-all:
	pytest tests -v --cov=src --cov-report=term-missing

# Run security scan with defaults in pyproject.toml
security:
	bandit -r src -c pyproject.toml

######################################################
############## LOCAL DEVELOPMENT AND TESTING ################
# Train model locally
train-model:
	python -m src.training.train

# Setup buildx builder (run once)
buildx-setup:
	docker buildx create --name multiplatform --use || docker buildx use multiplatform
	docker buildx inspect --bootstrap

# Local builds (current platform only, loads to docker)
build-training-local:
	docker buildx build --load -f docker/Dockerfile.training -t fraud-detection:training .

build-serving-local:
	docker buildx build --load -f docker/Dockerfile.serving -t fraud-detection:serving .

# build both images locally
build-local: build-training-local build-serving-local

# Multi-platform builds (push to registry)
build-push-training:
	docker buildx build --platform $(PLATFORMS) -f docker/Dockerfile.training -t fraud-detection:training --push .

build-push-serving:
	docker buildx build --platform $(PLATFORMS) -f docker/Dockerfile.serving -t fraud-detection:serving --push .

build: build-training build-serving

run-local:
	$(MAKE) local-up

stop-local:
	$(MAKE) local-down

local-build:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) build

local-up:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) up -d --build mlflow serving prometheus grafana

local-down:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) down

local-status:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) ps

local-logs:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) logs -f --tail=200

local-train:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile training up -d mlflow
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) --profile training run --rm training

local-restart-serving:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) restart serving


##########################################################
############## CLOUD INFRASTRUCTURE AND DEPLOYMENT ##########
# Bootstrap Terraform backend
tf-bootstrap:
	terraform -chdir=$(TF_BOOTSTRAP_DIR) init
	terraform -chdir=$(TF_BOOTSTRAP_DIR) apply

##### Deploy Terraform infrastructure
tf-format:
	terraform -chdir=$(TF_DIR) fmt -recursive

tf-init:
	terraform -chdir=$(CORE_TF_DIR) init

tf-plan:
	terraform -chdir=$(CORE_TF_DIR) plan

tf-apply:
	terraform -chdir=$(CORE_TF_DIR) plan -out=tfplan
	terraform -chdir=$(CORE_TF_DIR) apply tfplan
	rm -f $(CORE_TF_DIR)/tfplan

deploy-core-infra: tf-init tf-plan tf-apply

tf-destroy:
	terraform -chdir=$(CORE_TF_DIR) destroy

tf-output:
	terraform -chdir=$(CORE_TF_DIR) output

### Update kubeconfig with EKS cluster details
kubeconfig:
	@if [ -n "$(EKS_CLUSTER_NAME)" ]; then \
		aws eks update-kubeconfig --region $(AWS_REGION) --name $(EKS_CLUSTER_NAME); \
	else \
		CLUSTER_NAME=$$(terraform -chdir=$(CORE_TF_DIR) output -raw eks_cluster_name); \
		aws eks update-kubeconfig --region $(AWS_REGION) --name $$CLUSTER_NAME; \
	fi

## apply k8s manifests
k8s-apply:
	kubectl apply -f infrastructure/k8s-manifests/

#### Deploy Helm Addons
helm-addons-init:
	terraform -chdir=$(HELM_ADDON_DIR) init -reconfigure

helm-addons-plan:
	terraform -chdir=$(HELM_ADDON_DIR) plan

helm-addons-apply:
	terraform -chdir=$(HELM_ADDON_DIR) plan -out=tfplan
	terraform -chdir=$(HELM_ADDON_DIR) apply tfplan
	rm -f $(HELM_ADDON_DIR)/tfplan

deploy-helm-addons: helm-addons-init helm-addons-apply


## destroy helm addons
helm-addons-destroy:
	terraform -chdir=$(HELM_ADDON_DIR) destroy

ecr-login:
	aws ecr get-login-password --region $(AWS_REGION) \
		| docker login --username AWS --password-stdin $(ECR_REGISTRY)

build-training-ecr:
	docker build -f docker/Dockerfile.training \
		-t $(ECR_REGISTRY)/$(ECR_REPOSITORY_TRAINING):$(IMAGE_TAG) .

build-serving-ecr:
	docker build -f docker/Dockerfile.serving \
		-t $(ECR_REGISTRY)/$(ECR_REPOSITORY_SERVING):$(IMAGE_TAG) .

build-ecr: build-training-ecr build-serving-ecr

push-training-ecr: ecr-login build-training-ecr
	docker push $(ECR_REGISTRY)/$(ECR_REPOSITORY_TRAINING):$(IMAGE_TAG)

push-serving-ecr: ecr-login build-serving-ecr
	docker push $(ECR_REGISTRY)/$(ECR_REPOSITORY_SERVING):$(IMAGE_TAG)

push-ecr: push-training-ecr push-serving-ecr

helm-deploy:
	helm upgrade --install $(HELM_RELEASE) ./helm/serving \
		--namespace $(K8S_NAMESPACE) \
		--create-namespace \
		--set image.repository=$(ECR_REGISTRY)/$(ECR_REPOSITORY_SERVING) \
		--set image.tag=$(IMAGE_TAG) \
		$(HELM_VALUES_ARG) \
		--atomic \
		--timeout 10m \
		--wait

helm-status:
	helm status $(HELM_RELEASE) -n $(K8S_NAMESPACE)

helm-uninstall:
	helm uninstall $(HELM_RELEASE) -n $(K8S_NAMESPACE)

k8s-verify:
	kubectl rollout status deployment/$(HELM_RELEASE) -n $(K8S_NAMESPACE) --timeout=300s

k8s-smoke:
	SERVICE_URL=$$(kubectl get svc $(HELM_RELEASE) -n $(K8S_NAMESPACE) \
		-o jsonpath='{.status.loadBalancer.ingress[0].hostname}'); \
	if [ -z "$$SERVICE_URL" ]; then \
		echo "Service URL not found; check service type or ingress." >&2; \
		exit 1; \
	fi; \
	curl -f http://$$SERVICE_URL:8000/health; \
	curl -f http://$$SERVICE_URL:8000/metrics || true

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type d -name .pytest_cache -exec rm -rf {} +
	find . -type d -name .mypy_cache -exec rm -rf {} +
	find . -type d -name .ruff_cache -exec rm -rf {} +
	rm -rf htmlcov .coverage
