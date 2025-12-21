make lint

# Run tests
make test

## train model and test locally
- 1. Train model locally first (creates models/ directory)
python -m src.training.train

- 2. Build images
make build-local

- 3. Start services (MLflow, Serving, Prometheus, Grafana)
docker-compose up -d mlflow serving prometheus grafana

- 4. Check services
docker-compose ps

- 5. Test API
curl http://localhost:8000/health

- 6. View UIs
- MLflow: http://localhost:5000
- API docs: http://localhost:8000/docs
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)

## Test prediction
```
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "V1": -1.36, "V2": -0.07, "V3": 2.54, "V4": 1.38, "V5": -0.34,
    "V6": 0.46, "V7": 0.24, "V8": 0.10, "V9": 0.14, "V10": -0.21,
    "V11": -0.03, "V12": -0.19, "V13": -0.28, "V14": -0.05, "V15": -0.63,
    "V16": -0.21, "V17": -0.06, "V18": -0.07, "V19": -0.05, "V20": -0.08,
    "V21": -0.07, "V22": 0.01, "V23": -0.02, "V24": -0.05, "V25": 0.17,
    "V26": 0.02, "V27": 0.02, "V28": 0.01, "Amount": 149.62
  }'
```

---

## Current Structure
```
fraud-detection-mlops/
├── .dockerignore
├── .github/workflows/
├── .gitignore
├── .pre-commit-config.yaml
├── Makefile
├── pyproject.toml
├── docker-compose.yaml
├── configs/
│   ├── model_config.yaml
│   └── prometheus.yaml
├── data/
│   └── creditcard.csv
├── docker/
│   ├── Dockerfile.training
│   └── Dockerfile.serving
├── models/
│   ├── model.json
│   └── feature_engineer.pkl
├── src/
│   └── ...
└── tests/
    └── ...
```
aws secretsmanager delete-secret --secret-id fraud-detection-dev-db-credentials --force-delete-without-recovery
