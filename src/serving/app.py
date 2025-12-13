import pickle
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from pathlib import Path

import pandas as pd
import xgboost as xgb
from fastapi import FastAPI, HTTPException
from prometheus_client import Counter, Histogram, make_asgi_app
from pydantic import BaseModel

from src.features.feature_engineering import FeatureEngineer


class ModelState:
    model: xgb.XGBClassifier | None = None
    feature_engineer: FeatureEngineer | None = None


state = ModelState()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Load model on startup, cleanup on shutdown."""
    model_path = Path("models")

    with open(model_path / "model.pkl", "rb") as f:
        state.model = pickle.load(f)

    with open(model_path / "feature_engineer.pkl", "rb") as f:
        state.feature_engineer = pickle.load(f)

    yield

    state.model = None
    state.feature_engineer = None


app = FastAPI(title="Fraud Detection API", version="1.0.0", lifespan=lifespan)

PREDICTION_COUNT = Counter(
    "fraud_predictions_total",
    "Total predictions",
    ["result"],
)
PREDICTION_LATENCY = Histogram(
    "fraud_prediction_latency_seconds",
    "Prediction latency",
)

metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)


class Transaction(BaseModel):
    """Input transaction schema."""

    V1: float
    V2: float
    V3: float
    V4: float
    V5: float
    V6: float
    V7: float
    V8: float
    V9: float
    V10: float
    V11: float
    V12: float
    V13: float
    V14: float
    V15: float
    V16: float
    V17: float
    V18: float
    V19: float
    V20: float
    V21: float
    V22: float
    V23: float
    V24: float
    V25: float
    V26: float
    V27: float
    V28: float
    Amount: float


class Prediction(BaseModel):
    """Output prediction schema."""

    is_fraud: bool
    fraud_probability: float


@app.get("/health")
async def health() -> dict:
    """Health check endpoint."""
    return {"status": "healthy", "model_loaded": state.model is not None}


@app.post("/predict", response_model=Prediction)
async def predict(transaction: Transaction) -> Prediction:
    """Make fraud prediction."""
    if state.model is None or state.feature_engineer is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    with PREDICTION_LATENCY.time():
        df = pd.DataFrame([transaction.model_dump()])
        df_processed = state.feature_engineer.transform(df)

        probability = state.model.predict_proba(df_processed)[0, 1]
        is_fraud = probability > 0.5

        PREDICTION_COUNT.labels(result="fraud" if is_fraud else "not_fraud").inc()

    return Prediction(is_fraud=is_fraud, fraud_probability=float(probability))
