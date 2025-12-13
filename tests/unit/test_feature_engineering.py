import pandas as pd
import pytest

from src.features.feature_engineering import FeatureEngineer


@pytest.fixture
def sample_data() -> pd.DataFrame:
    """Create sample data for testing."""
    return pd.DataFrame(
        {
            "V1": [1.0, 2.0, 3.0],
            "Amount": [100.0, 200.0, 300.0],
            "Time": [0, 1, 2],
        }
    )


def test_feature_engineer_fit_transform(sample_data: pd.DataFrame) -> None:
    """Test fit_transform works correctly."""
    fe = FeatureEngineer(scale_features=["Amount"])
    result = fe.fit_transform(sample_data)

    assert "Time" not in result.columns
    assert "Amount" in result.columns
    assert fe._is_fitted


def test_feature_engineer_transform_without_fit(sample_data: pd.DataFrame) -> None:
    """Test that transform raises error if not fitted."""
    fe = FeatureEngineer()

    with pytest.raises(ValueError, match="must be fitted"):
        fe.transform(sample_data)


def test_feature_engineer_scaling(sample_data: pd.DataFrame) -> None:
    """Test that Amount is scaled."""
    fe = FeatureEngineer(scale_features=["Amount"])
    result = fe.fit_transform(sample_data)

    assert abs(result["Amount"].mean()) < 0.1
