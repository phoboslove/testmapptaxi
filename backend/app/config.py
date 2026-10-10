"""Settings from environment variables with sensible defaults."""

import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

DB_PATH = Path(os.getenv("TRIPS_DB_PATH", REPO_ROOT / "backend" / "trips.db"))
SEED_PATH = Path(os.getenv("TRIPS_SEED_PATH", REPO_ROOT / "data" / "trips.json"))
