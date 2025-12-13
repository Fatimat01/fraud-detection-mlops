import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)


def evaluate_model(
    y_true: pd.Series,
    y_pred: pd.Series,
    y_pred_proba: pd.Series | None = None,
) -> dict:
    """Calculate evaluation metrics."""
    metrics = {
        "accuracy": accuracy_score(y_true, y_pred),
        "precision": precision_score(y_true, y_pred),
        "recall": recall_score(y_true, y_pred),
        "f1": f1_score(y_true, y_pred),
    }

    if y_pred_proba is not None:
        metrics["roc_auc"] = roc_auc_score(y_true, y_pred_proba)

    return metrics


def get_classification_report(y_true: pd.Series, y_pred: pd.Series) -> str:
    """Generate classification report."""
    return classification_report(y_true, y_pred, target_names=["Not Fraud", "Fraud"])


def get_confusion_matrix(y_true: pd.Series, y_pred: pd.Series) -> pd.DataFrame:
    """Generate confusion matrix as DataFrame."""
    cm = confusion_matrix(y_true, y_pred)
    return pd.DataFrame(
        cm,
        index=["Actual Not Fraud", "Actual Fraud"],
        columns=["Predicted Not Fraud", "Predicted Fraud"],
    )
