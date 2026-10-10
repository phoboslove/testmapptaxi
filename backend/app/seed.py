"""Load data/trips.json into the database at startup."""

import json
import logging
from pathlib import Path

from pydantic import ValidationError

from . import db
from .models import TripIn

log = logging.getLogger(__name__)


def load_seed(db_path: Path, seed_path: Path) -> int:
    """Insert seed trips that are not in the database yet. Returns how many were added.

    Every record goes through the same validation as POST /api/trips.
    Invalid records and ids already stored with other data are logged and skipped.
    """
    if not seed_path.exists():
        log.warning("Seed file %s not found, skipping", seed_path)
        return 0
    records = json.loads(seed_path.read_text(encoding="utf-8"))
    if not isinstance(records, list):
        log.warning("Seed file %s must contain a JSON array, skipping", seed_path)
        return 0

    added = 0
    with db.connect(db_path) as conn:
        for index, record in enumerate(records):
            try:
                trip = TripIn.model_validate(record)
            except ValidationError as error:
                log.warning("Seed record #%d is invalid, skipped: %s", index, error.errors())
                continue
            inserted, differs = db.insert_if_absent(conn, trip)
            added += inserted
            if differs:
                log.warning("Seed trip '%s' differs from the stored one, kept stored", trip.id)
    return added
