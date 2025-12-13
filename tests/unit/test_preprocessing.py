import pandas as pd
import pytest

from src.data.preprocessing import get_feature_columns, split_data


@pytest.fixture
def sample_data() -> pd.DataFrame:
    """Create sample data for testing."""
    return pd.DataFrame(
        {
            "V1": [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0],
            "V2": [1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1, 9.1, 10.1],
            "Amount": [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000],
            "Time": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
            "Class": [0, 0, 0, 0, 0, 0, 0, 1, 1, 1],  # At least 2 per class
        }
    )


def test_split_data_shapes(sample_data: pd.DataFrame) -> None:
    """Test that split produces correct shapes."""
    x_train, x_test, y_train, y_test = split_data(
        sample_data, target_col="Class", test_size=0.3, random_state=42
    )

    assert len(x_train) == 7
    assert len(x_test) == 3
    assert len(y_train) == 7
    assert len(y_test) == 3


def test_split_data_no_target_leakage(sample_data: pd.DataFrame) -> None:
    """Test that target is not in features."""
    x_train, x_test, _, _ = split_data(sample_data, target_col="Class")

    assert "Class" not in x_train.columns
    assert "Class" not in x_test.columns


def test_get_feature_columns(sample_data: pd.DataFrame) -> None:
    """Test feature column selection."""
    features = get_feature_columns(sample_data, exclude=["Time", "Class"])

    assert "Time" not in features
    assert "Class" not in features
    assert "V1" in features
    assert "Amount" in features
