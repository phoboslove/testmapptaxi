"""SQLite storage: one table, plain sqlite3."""

import sqlite3
from collections.abc import Iterator, Mapping
from contextlib import contextmanager
from datetime import date
from pathlib import Path

from .models import TripIn, TripOut

SCHEMA = """
CREATE TABLE IF NOT EXISTS trips (
    id         TEXT PRIMARY KEY,
    start      TEXT NOT NULL,
    end_at     TEXT NOT NULL,
    amount     INTEGER NOT NULL,
    payment    TEXT NOT NULL CHECK (payment IN ('cash', 'card')),
    commission INTEGER NOT NULL,
    day        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_trips_day ON trips(day);
"""

COLUMNS = "id, start, end_at, amount, payment, commission, day"


class TripConflictError(Exception):
    """The id already exists with different data."""


@contextmanager
def connect(db_path: Path) -> Iterator[sqlite3.Connection]:
    """Open a connection, commit on success, roll back on error, always close."""
    conn = sqlite3.connect(db_path, timeout=10)
    conn.row_factory = sqlite3.Row
    try:
        with conn:
            yield conn
    finally:
        conn.close()


def init_db(db_path: Path) -> None:
    with connect(db_path) as conn:
        conn.executescript(SCHEMA)


def to_row(trip: TripIn) -> dict:
    """Normalized column values; also used to compare trips for duplicates."""
    return {
        "id": trip.id,
        "start": trip.start.isoformat(timespec="seconds"),
        "end_at": trip.end.isoformat(timespec="seconds"),
        "amount": trip.amount,
        "payment": trip.payment,
        "commission": trip.commission,
        "day": trip.day.isoformat(),
    }


def from_row(row: Mapping) -> TripOut:
    return TripOut(
        id=row["id"],
        start=row["start"],
        end=row["end_at"],
        amount=row["amount"],
        payment=row["payment"],
        commission=row["commission"],
        day=row["day"],
    )


def _insert(conn: sqlite3.Connection, row: dict, or_ignore: bool = False) -> bool:
    verb = "INSERT OR IGNORE" if or_ignore else "INSERT"
    cursor = conn.execute(
        f"{verb} INTO trips ({COLUMNS}) "
        "VALUES (:id, :start, :end_at, :amount, :payment, :commission, :day)",
        row,
    )
    return cursor.rowcount == 1


def _get_row(conn: sqlite3.Connection, trip_id: str) -> sqlite3.Row | None:
    return conn.execute(f"SELECT {COLUMNS} FROM trips WHERE id = ?", (trip_id,)).fetchone()


def create_trip(db_path: Path, trip: TripIn) -> tuple[TripOut, bool]:
    """Insert a trip idempotently.

    Returns (trip, created). The PRIMARY KEY is the guard against duplicates:
    try to INSERT first, and only on a key collision read the stored row and
    compare. Same data -> (stored trip, False); different data -> conflict.
    """
    row = to_row(trip)
    try:
        with connect(db_path) as conn:
            _insert(conn, row)
        return from_row(row), True
    except sqlite3.IntegrityError:
        pass
    with connect(db_path) as conn:
        existing = _get_row(conn, trip.id)
    if existing is None or dict(existing) != row:
        raise TripConflictError(f"Trip with id '{trip.id}' already exists with different data")
    return from_row(existing), False


def insert_if_absent(conn: sqlite3.Connection, trip: TripIn) -> tuple[bool, bool]:
    """INSERT OR IGNORE for seeding. Returns (inserted, differs_from_stored)."""
    row = to_row(trip)
    if _insert(conn, row, or_ignore=True):
        return True, False
    return False, dict(_get_row(conn, trip.id)) != row


def list_trips(db_path: Path, day: date) -> list[TripOut]:
    with connect(db_path) as conn:
        rows = conn.execute(
            f"SELECT {COLUMNS} FROM trips WHERE day = ? ORDER BY start, id", (day.isoformat(),)
        ).fetchall()
    return [from_row(row) for row in rows]


def list_days(db_path: Path) -> list[str]:
    with connect(db_path) as conn:
        rows = conn.execute("SELECT DISTINCT day FROM trips ORDER BY day").fetchall()
    return [row["day"] for row in rows]


def count_trips(db_path: Path) -> int:
    with connect(db_path) as conn:
        return conn.execute("SELECT COUNT(*) FROM trips").fetchone()[0]
