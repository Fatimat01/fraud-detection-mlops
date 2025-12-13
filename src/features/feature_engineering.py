import pandas as pd
from sklearn.preprocessing import StandardScaler


class FeatureEngineer:
    """Simple feature engineering pipeline."""

    def __init__(self, scale_features: list[str] | None = None):
        self.scale_features = scale_features or ["Amount"]
        self.scaler = StandardScaler()
        self._is_fitted = False

    def fit(self, df: pd.DataFrame) -> "FeatureEngineer":
        """Fit the feature engineer on training data."""
        if self.scale_features:
            self.scaler.fit(df[self.scale_features])
        self._is_fitted = True
        return self

    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """Transform features."""
        if not self._is_fitted:
            raise ValueError("FeatureEngineer must be fitted before transform")

        df = df.copy()

        if self.scale_features:
            df[self.scale_features] = self.scaler.transform(df[self.scale_features])

        if "Time" in df.columns:
            df = df.drop(columns=["Time"])

        return df

    def fit_transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """Fit and transform in one step."""
        return self.fit(df).transform(df)
