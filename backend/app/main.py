"""FastAPI application: days, trips, daily summary."""

from contextlib import asynccontextmanager
from datetime import date
from pathlib import Path

from fastapi import FastAPI, HTTPException, Query, Response, status
from fastapi.middleware.cors import CORSMiddleware

from . import config, db
from .models import Summary, TripIn, TripOut
from .seed import load_seed
from .summary import build_summary

DayQuery = Query(alias="date", description="Day in Almaty time, YYYY-MM-DD", examples=["2026-10-01"])


def create_app(db_path: Path | None = None, seed_path: Path | None = None) -> FastAPI:
    db_path = Path(db_path or config.DB_PATH)
    seed_path = Path(seed_path or config.SEED_PATH)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        db.init_db(db_path)
        load_seed(db_path, seed_path)
        yield

    app = FastAPI(title="Driver shift diary", version="1.0.0", lifespan=lifespan)
    # Open for local development; restrict origins in production.
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

    @app.get("/health")
    def health() -> dict:
        return {"status": "ok"}

    @app.get("/api/days", response_model=list[date])
    def get_days() -> list[str]:
        """Days (Almaty time) that have at least one trip, sorted ascending."""
        return db.list_days(db_path)

    @app.get("/api/trips", response_model=list[TripOut])
    def get_trips(day: date = DayQuery) -> list[TripOut]:
        """Trips that started on the given day, sorted by start."""
        return db.list_trips(db_path, day)

    @app.get("/api/summary", response_model=Summary)
    def get_summary(day: date = DayQuery) -> dict:
        """Totals for the day. A day without trips gives zeros."""
        return build_summary(day, db.list_trips(db_path, day))

    @app.post(
        "/api/trips",
        response_model=TripOut,
        status_code=status.HTTP_201_CREATED,
        responses={
            200: {"description": "Same trip was already stored; nothing created", "model": TripOut},
            409: {"description": "Trip id already exists with different data"},
        },
    )
    def post_trip(trip: TripIn, response: Response) -> TripOut:
        """Add a trip. Re-sending the same trip is safe and returns 200."""
        try:
            stored, created = db.create_trip(db_path, trip)
        except db.TripConflictError as error:
            raise HTTPException(status.HTTP_409_CONFLICT, str(error)) from error
        if not created:
            response.status_code = status.HTTP_200_OK
        return stored

    return app


app = create_app()
