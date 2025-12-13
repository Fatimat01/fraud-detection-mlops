import pickle
from pathlib import Path

import mlflow
import xgboost as xgb
import yaml
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)

from src.data.preprocessing import load_data, split_data
from src.features.feature_engineering import FeatureEngineer


def load_config(config_path: str = "configs/model_config.yaml") -> dict:
    """Load configuration from YAML file."""
    with open(config_path) as f:
        return yaml.safe_load(f)


def train_model(config: dict) -> tuple[xgb.XGBClassifier, FeatureEngineer, dict]:
    """Train the fraud detection model."""
    df = load_data(config["data"]["source"])

    x_train, x_test, y_train, y_test = split_data(
        df=df,
        target_col=config["features"]["target"],
        test_size=config["data"]["test_size"],
        random_state=config["data"]["random_state"],
    )

    feature_engineer = FeatureEngineer(scale_features=["Amount"])
    x_train_processed = feature_engineer.fit_transform(x_train)
    x_test_processed = feature_engineer.transform(x_test)

    model = xgb.XGBClassifier(**config["model"]["params"])
    model.fit(x_train_processed, y_train)

    y_pred = model.predict(x_test_processed)
    y_pred_proba = model.predict_proba(x_test_processed)[:, 1]

    metrics = {
        "accuracy": accuracy_score(y_test, y_pred),
        "precision": precision_score(y_test, y_pred),
        "recall": recall_score(y_test, y_pred),
        "f1": f1_score(y_test, y_pred),
        "roc_auc": roc_auc_score(y_test, y_pred_proba),
    }

    return model, feature_engineer, metrics


def save_artifacts(
    model: xgb.XGBClassifier,
    feature_engineer: FeatureEngineer,
    output_dir: str = "models",
) -> None:
    """Save model and feature engineer locally."""
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)

    with open(output_path / "model.pkl", "wb") as f:
        pickle.dump(model, f)

    with open(output_path / "feature_engineer.pkl", "wb") as f:
        pickle.dump(feature_engineer, f)


def train_with_mlflow(config_path: str = "configs/model_config.yaml") -> None:
    """Train model with MLflow tracking."""
    config = load_config(config_path)

    mlflow.set_experiment(config["training"]["experiment_name"])

    with mlflow.start_run():
        mlflow.log_params(config["model"]["params"])

        model, feature_engineer, metrics = train_model(config)

        mlflow.log_metrics(metrics)

        save_artifacts(model, feature_engineer)
        mlflow.log_artifacts("models")

        # Use sklearn flavor instead of xgboost
        mlflow.sklearn.log_model(
            model,
            name="model",
            registered_model_name="fraud-detection-model",
        )

        print(f"Metrics: {metrics}")


if __name__ == "__main__":
    train_with_mlflow()
