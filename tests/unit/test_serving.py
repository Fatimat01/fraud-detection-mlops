# tests/unit/test_serving.py

from collections.abc import Generator
from unittest.mock import MagicMock, mock_open, patch

import numpy as np
import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def mock_model() -> MagicMock:
    """Mock XGBoost model."""
    model = MagicMock()
    model.predict_proba.return_value = np.array([[0.3, 0.7]])  # 70% fraud probability
    return model


@pytest.fixture
def mock_feature_engineer() -> MagicMock:
    """Mock feature engineer."""
    engineer = MagicMock()
    engineer.transform.return_value = np.array([[1.0] * 28 + [100.0]])  # Mock processed features
    return engineer


@pytest.fixture
def client(
    mock_model: MagicMock, mock_feature_engineer: MagicMock
) -> Generator[TestClient, None, None]:
    """Test client with mocked model loading."""
    with patch("builtins.open", mock_open(read_data=b"mock_pickle_data")):
        with patch("pickle.load") as mock_pickle:
            # First call returns model, second returns feature_engineer
            mock_pickle.side_effect = [mock_model, mock_feature_engineer]

            from src.serving.app import app

            with TestClient(app) as test_client:
                yield test_client


def test_health_endpoint(client: TestClient) -> None:
    """Test health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["model_loaded"] is True


def test_metrics_endpoint(client: TestClient) -> None:
    """Test Prometheus metrics endpoint."""
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "python_info" in response.text
    assert "fraud_predictions_total" in response.text


def test_predict_endpoint_valid_input(client: TestClient) -> None:
    """Test prediction endpoint with valid transaction."""
    payload = {
        "V1": -1.3598071336738,
        "V2": -0.0727811733098497,
        "V3": 2.53634673796914,
        "V4": 1.37815522427443,
        "V5": -0.338320769942518,
        "V6": 0.462387777762292,
        "V7": 0.239598554061257,
        "V8": 0.0986979012610507,
        "V9": 0.363786969611213,
        "V10": 0.0907941719789316,
        "V11": -0.551599533260813,
        "V12": -0.617800855762348,
        "V13": -0.991389847235408,
        "V14": -0.311169353699879,
        "V15": 1.46817697209427,
        "V16": -0.470400525259478,
        "V17": 0.207971241929242,
        "V18": 0.0257905801985591,
        "V19": 0.403992960255733,
        "V20": 0.251412098239705,
        "V21": -0.018306777944153,
        "V22": 0.277837575558899,
        "V23": -0.110473910188767,
        "V24": 0.0669280749146731,
        "V25": 0.128539358273528,
        "V26": -0.189114843888824,
        "V27": 0.133558376740387,
        "V28": -0.0210530534538215,
        "Amount": 149.62,
    }

    response = client.post("/predict", json=payload)
    assert response.status_code == 200

    data = response.json()
    assert "is_fraud" in data
    assert "fraud_probability" in data
    assert isinstance(data["is_fraud"], bool)
    assert 0.0 <= data["fraud_probability"] <= 1.0

    # Based on mock returning 0.7 probability
    assert data["is_fraud"] is True
    assert data["fraud_probability"] == 0.7


def test_predict_endpoint_missing_fields(client: TestClient) -> None:
    """Test prediction endpoint with missing required fields."""
    payload = {
        "V1": 1.0,
        "Amount": 100.0,
        # Missing V2-V28
    }

    response = client.post("/predict", json=payload)
    assert response.status_code == 422  # Validation error


def test_predict_endpoint_invalid_types(client: TestClient) -> None:
    """Test prediction endpoint with invalid data types."""
    payload = {
        "V1": "invalid_string",  # Should be float
        "V2": 1.0,
        # ... rest of fields
    }

    response = client.post("/predict", json=payload)
    assert response.status_code == 422


def test_predict_endpoint_extra_fields_allowed(client: TestClient) -> None:
    """Test that extra fields are ignored."""
    payload = {
        "V1": -1.3598071336738,
        "V2": -0.0727811733098497,
        "V3": 2.53634673796914,
        "V4": 1.37815522427443,
        "V5": -0.338320769942518,
        "V6": 0.462387777762292,
        "V7": 0.239598554061257,
        "V8": 0.0986979012610507,
        "V9": 0.363786969611213,
        "V10": 0.0907941719789316,
        "V11": -0.551599533260813,
        "V12": -0.617800855762348,
        "V13": -0.991389847235408,
        "V14": -0.311169353699879,
        "V15": 1.46817697209427,
        "V16": -0.470400525259478,
        "V17": 0.207971241929242,
        "V18": 0.0257905801985591,
        "V19": 0.403992960255733,
        "V20": 0.251412098239705,
        "V21": -0.018306777944153,
        "V22": 0.277837575558899,
        "V23": -0.110473910188767,
        "V24": 0.0669280749146731,
        "V25": 0.128539358273528,
        "V26": -0.189114843888824,
        "V27": 0.133558376740387,
        "V28": -0.0210530534538215,
        "Amount": 149.62,
        "extra_field": "should_be_ignored",  # Extra field
    }

    response = client.post("/predict", json=payload)
    assert response.status_code == 200


def test_prediction_below_threshold(mock_feature_engineer: MagicMock) -> None:
    """Test prediction when probability is below 0.5 threshold."""
    # Create mock that returns low probability
    low_prob_model = MagicMock()
    low_prob_model.predict_proba.return_value = np.array([[0.7, 0.3]])  # 30% fraud

    with patch("builtins.open", mock_open(read_data=b"mock_pickle_data")):
        with patch("pickle.load") as mock_pickle:
            mock_pickle.side_effect = [low_prob_model, mock_feature_engineer]

            from src.serving.app import app

            with TestClient(app) as client:
                payload = {
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
                    "Amount": 10.0,
                }

                response = client.post("/predict", json=payload)
                assert response.status_code == 200

                data = response.json()
                assert data["is_fraud"] is False
                assert data["fraud_probability"] == 0.3
