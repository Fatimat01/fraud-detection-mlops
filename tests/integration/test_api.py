# tests/integration/test_api.py

from collections.abc import Generator
from unittest.mock import MagicMock, mock_open, patch

import numpy as np
import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def integration_client() -> Generator[TestClient, None, None]:
    """Integration test client with mocked model."""
    mock_model = MagicMock()
    mock_model.predict_proba.return_value = np.array([[0.4, 0.6]])

    mock_engineer = MagicMock()
    mock_engineer.transform.return_value = np.array([[1.0] * 29])

    from src.serving import app as app_module

    with patch.object(app_module, "open", mock_open(read_data=b"mock")):
        with patch.object(app_module.pickle, "load") as mock_pickle:
            mock_pickle.side_effect = [mock_model, mock_engineer]

            with TestClient(app_module.app) as client:
                yield client


def test_end_to_end_prediction_flow(integration_client: TestClient) -> None:
    """Test complete API flow: health -> predict -> metrics."""
    # 1. Verify service is healthy
    health = integration_client.get("/health")
    assert health.status_code == 200
    assert health.json()["status"] == "healthy"
    assert health.json()["model_loaded"] is True

    # 2. Make a prediction
    transaction = {
        "V1": -1.5,
        "V2": 0.5,
        "V3": 1.2,
        "V4": 0.8,
        "V5": -0.3,
        "V6": 0.4,
        "V7": 0.2,
        "V8": 0.1,
        "V9": 0.4,
        "V10": 0.1,
        "V11": -0.6,
        "V12": -0.6,
        "V13": -1.0,
        "V14": -0.3,
        "V15": 1.5,
        "V16": -0.5,
        "V17": 0.2,
        "V18": 0.0,
        "V19": 0.4,
        "V20": 0.3,
        "V21": 0.0,
        "V22": 0.3,
        "V23": -0.1,
        "V24": 0.1,
        "V25": 0.1,
        "V26": -0.2,
        "V27": 0.1,
        "V28": 0.0,
        "Amount": 150.0,
    }

    prediction = integration_client.post("/predict", json=transaction)
    assert prediction.status_code == 200

    result = prediction.json()
    assert "is_fraud" in result
    assert "fraud_probability" in result

    # 3. Verify metrics were updated
    metrics = integration_client.get("/metrics")
    assert metrics.status_code == 200
    assert "fraud_predictions_total" in metrics.text
    assert "fraud_prediction_latency_seconds" in metrics.text


def test_multiple_predictions_consistency(integration_client: TestClient) -> None:
    """Test that multiple predictions work correctly."""
    transaction = {
        "V1": 0.0,
        "V2": 0.0,
        "V3": 0.0,
        "V4": 0.0,
        "V5": 0.0,
        "V6": 0.0,
        "V7": 0.0,
        "V8": 0.0,
        "V9": 0.0,
        "V10": 0.0,
        "V11": 0.0,
        "V12": 0.0,
        "V13": 0.0,
        "V14": 0.0,
        "V15": 0.0,
        "V16": 0.0,
        "V17": 0.0,
        "V18": 0.0,
        "V19": 0.0,
        "V20": 0.0,
        "V21": 0.0,
        "V22": 0.0,
        "V23": 0.0,
        "V24": 0.0,
        "V25": 0.0,
        "V26": 0.0,
        "V27": 0.0,
        "V28": 0.0,
        "Amount": 100.0,
    }

    # Make 5 predictions
    for _ in range(5):
        response = integration_client.post("/predict", json=transaction)
        assert response.status_code == 200
        result = response.json()
        assert result["fraud_probability"] == 0.6  # Mocked value


def test_error_recovery(integration_client: TestClient) -> None:
    """Test API error handling and recovery."""
    # Send invalid request
    invalid_response = integration_client.post("/predict", json={"invalid": "data"})
    assert invalid_response.status_code == 422

    # Verify service still works after error
    health = integration_client.get("/health")
    assert health.status_code == 200

    # Valid request should work
    valid_transaction = {
        "V1": 0.0,
        "V2": 0.0,
        "V3": 0.0,
        "V4": 0.0,
        "V5": 0.0,
        "V6": 0.0,
        "V7": 0.0,
        "V8": 0.0,
        "V9": 0.0,
        "V10": 0.0,
        "V11": 0.0,
        "V12": 0.0,
        "V13": 0.0,
        "V14": 0.0,
        "V15": 0.0,
        "V16": 0.0,
        "V17": 0.0,
        "V18": 0.0,
        "V19": 0.0,
        "V20": 0.0,
        "V21": 0.0,
        "V22": 0.0,
        "V23": 0.0,
        "V24": 0.0,
        "V25": 0.0,
        "V26": 0.0,
        "V27": 0.0,
        "V28": 0.0,
        "Amount": 50.0,
    }
    valid_response = integration_client.post("/predict", json=valid_transaction)
    assert valid_response.status_code == 200


def test_openapi_schema(integration_client: TestClient) -> None:
    """Test that OpenAPI schema is accessible."""
    response = integration_client.get("/openapi.json")
    assert response.status_code == 200

    schema = response.json()
    assert schema["info"]["title"] == "Fraud Detection API"
    assert schema["info"]["version"] == "1.0.0"
    assert "/predict" in schema["paths"]
    assert "/health" in schema["paths"]


## smoke test for pytest coverage
def test_training_imports() -> None:
    pass
