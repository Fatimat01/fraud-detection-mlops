from pathlib import Path

import pandas as pd
from sklearn.model_selection import train_test_split


def load_data(path: str | Path) -> pd.DataFrame:
    """Load raw data from CSV."""
    return pd.read_csv(path)


def split_data(
    df: pd.DataFrame,
    target_col: str,
    test_size: float = 0.2,
    random_state: int = 42,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.Series, pd.Series]:
    """Split data into train and test sets."""
    X = df.drop(columns=[target_col])
    y = df[target_col]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=test_size, random_state=random_state, stratify=y
    )

    return X_train, X_test, y_train, y_test


def get_feature_columns(df: pd.DataFrame, exclude: list[str]) -> list[str]:
    """Get feature columns excluding specified columns."""
    return [col for col in df.columns if col not in exclude]
