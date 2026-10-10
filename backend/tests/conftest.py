from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import REPO_ROOT
from app.main import create_app

SEED_PATH = REPO_ROOT / "data" / "trips.json"


@pytest.fixture
def db_path(tmp_path: Path) -> Path:
    return tmp_path / "test.db"


@pytest.fixture
def client(db_path: Path):
    """App on a fresh temporary database, seeded from data/trips.json."""
    with TestClient(create_app(db_path, SEED_PATH)) as test_client:
        yield test_client
