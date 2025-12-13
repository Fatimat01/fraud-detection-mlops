.PHONY: install lint format test test-all security build run-local stop-local clean

# Platform targets
PLATFORMS := linux/amd64,linux/arm64

install:
	pip install -e ".[dev]"
	pre-commit install

# Check code quality
lint:
	ruff check src tests
	black --check src tests
	mypy src

# Clean up code automatically
format:
	ruff check --fix src tests
	black src tests

test:
	pytest tests/unit -v

test-all:
	pytest tests -v --cov=src --cov-report=html

security:
	bandit -r src -c pyproject.toml

# Setup buildx builder (run once)
buildx-setup:
	docker buildx create --name multiplatform --use || docker buildx use multiplatform
	docker buildx inspect --bootstrap

# Local builds (current platform only, loads to docker)
build-training-local:
	docker buildx build --load -f docker/Dockerfile.training -t fraud-detection:training .

build-serving-local:
	docker buildx build --load -f docker/Dockerfile.serving -t fraud-detection:serving .

build-local: build-training-local build-serving-local

# Multi-platform builds (push to registry)
build-training:
	docker buildx build --platform $(PLATFORMS) -f docker/Dockerfile.training -t fraud-detection:training --push .

build-serving:
	docker buildx build --platform $(PLATFORMS) -f docker/Dockerfile.serving -t fraud-detection:serving --push .

build: build-training build-serving

run-local:
	docker-compose up -d

stop-local:
	docker-compose down

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type d -name .pytest_cache -exec rm -rf {} +
	find . -type d -name .mypy_cache -exec rm -rf {} +
	find . -type d -name .ruff_cache -exec rm -rf {} +
	rm -rf htmlcov .coverage
