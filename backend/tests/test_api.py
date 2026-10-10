"""HTTP API: reading days, validation, duplicate protection, seeding."""

import json
import logging
import threading

import pytest
from fastapi.testclient import TestClient

from app import db
from app.main import create_app
from app.seed import load_seed
from tests.conftest import SEED_PATH

NEW_TRIP = {
    "id": "new-1",
    "start": "2026-10-05T08:10:00+05:00",
    "end": "2026-10-05T08:32:00+05:00",
    "amount": 2400,
    "payment": "card",
    "commission": 360,
}


def trips_on(client: TestClient, day: str) -> list[dict]:
    response = client.get("/api/trips", params={"date": day})
    assert response.status_code == 200
    return response.json()


# --- reading ---------------------------------------------------------------


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_days_from_seed(client):
    assert client.get("/api/days").json() == ["2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04"]


def test_summary_matches_manual_count(client):
    # 2026-10-01 in data/trips.json: t1..t8
    # card: 900 + 5300 + 4500 = 10700 (3 trips)
    # cash: 1600 + 4200 + 1000 + 2200 + 5900 = 14900 (5 trips)
    # commission: 135 + 240 + 630 + 150 + 330 + 795 + 675 + 885 = 3840
    response = client.get("/api/summary", params={"date": "2026-10-01"})

    assert response.status_code == 200
    assert response.json() == {
        "date": "2026-10-01",
        "trips_count": 8,
        "revenue": 25600,
        "commission": 3840,
        "net": 21760,
        "cash": {"amount": 14900, "count": 5},
        "card": {"amount": 10700, "count": 3},
    }


def test_trips_of_day_sorted_by_start(client):
    trips = trips_on(client, "2026-10-01")

    assert [t["id"] for t in trips] == ["t1", "t2", "t3", "t4", "t5", "t6", "t7", "t8"]
    assert trips[0] == {
        "id": "t1",
        "start": "2026-10-01T08:25:00+05:00",
        "end": "2026-10-01T08:38:00+05:00",
        "amount": 900,
        "payment": "card",
        "commission": 135,
        "day": "2026-10-01",
    }


def test_sorting_does_not_depend_on_insert_order(client):
    late = {**NEW_TRIP, "id": "late", "start": "2026-10-05T10:00:00+05:00", "end": "2026-10-05T10:20:00+05:00"}
    early = {**NEW_TRIP, "id": "early", "start": "2026-10-05T03:00:00Z", "end": "2026-10-05T03:20:00Z"}
    client.post("/api/trips", json=late)
    client.post("/api/trips", json=early)

    assert [t["id"] for t in trips_on(client, "2026-10-05")] == ["early", "late"]


def test_trip_over_midnight_is_in_start_day_only(client):
    assert "t18" in [t["id"] for t in trips_on(client, "2026-10-02")]
    assert "t18" not in [t["id"] for t in trips_on(client, "2026-10-03")]


def test_seed_trip_in_utc_is_normalized_to_almaty_day(client):
    # t26 is written as 2026-10-03T19:30:00Z, which is 00:30 on 04.10 in Almaty
    trip = next(t for t in trips_on(client, "2026-10-04") if t["id"] == "t26")

    assert trip["start"] == "2026-10-04T00:30:00+05:00"
    assert "t26" not in [t["id"] for t in trips_on(client, "2026-10-03")]


def test_empty_day_summary_is_zeros(client):
    summary = client.get("/api/summary", params={"date": "2026-11-01"}).json()

    assert summary["trips_count"] == 0
    assert summary["net"] == 0
    assert trips_on(client, "2026-11-01") == []


@pytest.mark.parametrize("bad_date", ["2026-13-01", "01.10.2026", "yesterday"])
def test_invalid_date_is_422(client, bad_date):
    assert client.get("/api/trips", params={"date": bad_date}).status_code == 422
    assert client.get("/api/summary", params={"date": bad_date}).status_code == 422


def test_missing_date_is_422(client):
    assert client.get("/api/trips").status_code == 422


# --- validation --------------------------------------------------------------


@pytest.mark.parametrize(
    "changes",
    [
        pytest.param({"amount": 0}, id="amount-zero"),
        pytest.param({"amount": -100, "commission": 0}, id="amount-negative"),
        pytest.param({"amount": 2400.5}, id="amount-float"),
        pytest.param({"amount": "2400"}, id="amount-string"),
        pytest.param({"end": NEW_TRIP["start"]}, id="end-equals-start"),
        pytest.param({"end": "2026-10-05T08:00:00+05:00"}, id="end-before-start"),
        pytest.param({"commission": 2401}, id="commission-over-amount"),
        pytest.param({"commission": -1}, id="commission-negative"),
        pytest.param({"payment": "crypto"}, id="bad-payment"),
        pytest.param({"id": ""}, id="empty-id"),
        pytest.param({"id": "   "}, id="blank-id"),
        pytest.param({"id": "x" * 65}, id="too-long-id"),
        pytest.param({"start": "2026-10-05T08:10:00"}, id="start-without-offset"),
        pytest.param({"end": "2026-10-05T08:32:00"}, id="end-without-offset"),
        pytest.param({"note": "hi"}, id="extra-field"),
    ],
)
def test_invalid_trip_is_422(client, changes):
    response = client.post("/api/trips", json={**NEW_TRIP, **changes})

    assert response.status_code == 422
    assert response.json()["detail"][0]["msg"]
    assert trips_on(client, "2026-10-05") == []


def test_missing_field_is_422(client):
    body = {k: v for k, v in NEW_TRIP.items() if k != "payment"}

    assert client.post("/api/trips", json=body).status_code == 422


def test_end_before_start_message_is_readable(client):
    response = client.post("/api/trips", json={**NEW_TRIP, "end": "2026-10-05T08:00:00+05:00"})

    assert "end must be later than start" in response.json()["detail"][0]["msg"]


# --- duplicates ---------------------------------------------------------------


def test_first_post_creates_trip(client):
    response = client.post("/api/trips", json=NEW_TRIP)

    assert response.status_code == 201
    assert response.json() == {**NEW_TRIP, "day": "2026-10-05"}
    assert client.get("/api/days").json()[-1] == "2026-10-05"


def test_same_trip_again_is_200_without_duplicate(client):
    first = client.post("/api/trips", json=NEW_TRIP)
    second = client.post("/api/trips", json=NEW_TRIP)

    assert first.status_code == 201
    assert second.status_code == 200
    assert second.json() == first.json()
    assert len(trips_on(client, "2026-10-05")) == 1


def test_id_with_spaces_is_the_same_trip(client):
    client.post("/api/trips", json=NEW_TRIP)

    assert client.post("/api/trips", json={**NEW_TRIP, "id": "  new-1 "}).status_code == 200


def test_same_id_other_amount_is_409(client):
    client.post("/api/trips", json=NEW_TRIP)

    response = client.post("/api/trips", json={**NEW_TRIP, "amount": 3000})

    assert response.status_code == 409
    assert "already exists" in response.json()["detail"]
    assert trips_on(client, "2026-10-05")[0]["amount"] == 2400


def test_seed_id_with_other_data_is_409(client):
    response = client.post("/api/trips", json={**NEW_TRIP, "id": "t1"})

    assert response.status_code == 409


def test_same_moment_in_other_offset_is_not_conflict(client):
    client.post("/api/trips", json=NEW_TRIP)
    same_in_utc = {**NEW_TRIP, "start": "2026-10-05T03:10:00Z", "end": "2026-10-05T03:32:00Z"}

    response = client.post("/api/trips", json=same_in_utc)

    assert response.status_code == 200
    assert response.json()["start"] == "2026-10-05T08:10:00+05:00"
    assert len(trips_on(client, "2026-10-05")) == 1


def test_sub_second_precision_is_dropped(client):
    client.post("/api/trips", json=NEW_TRIP)
    with_millis = {**NEW_TRIP, "start": "2026-10-05T08:10:00.250+05:00"}

    response = client.post("/api/trips", json=with_millis)

    assert response.status_code == 200
    assert response.json()["start"] == "2026-10-05T08:10:00+05:00"


def test_concurrent_posts_create_one_trip(db_path):
    """Two threads send the same trip at once: one 201, one 200, one row."""
    app = create_app(db_path, SEED_PATH)
    with TestClient(app) as client:
        before = db.count_trips(db_path)
        barrier = threading.Barrier(2)
        statuses = []

        def send():
            barrier.wait()
            statuses.append(client.post("/api/trips", json=NEW_TRIP).status_code)

        threads = [threading.Thread(target=send) for _ in range(2)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()

        assert sorted(statuses) == [200, 201]
        assert db.count_trips(db_path) == before + 1


# --- seed ---------------------------------------------------------------------


def test_seed_twice_does_not_add_records(client, db_path):
    count = db.count_trips(db_path)

    assert count == 35
    assert load_seed(db_path, SEED_PATH) == 0
    assert load_seed(db_path, SEED_PATH) == 0
    assert db.count_trips(db_path) == count


def test_seed_skips_invalid_records_and_warns_on_changed(db_path, tmp_path, caplog):
    seed = tmp_path / "seed.json"
    seed.write_text(json.dumps([NEW_TRIP, {**NEW_TRIP, "id": "bad", "amount": 0}]), encoding="utf-8")
    db.init_db(db_path)

    assert load_seed(db_path, seed) == 1

    seed.write_text(json.dumps([{**NEW_TRIP, "amount": 9999, "commission": 0}]), encoding="utf-8")
    with caplog.at_level(logging.WARNING):
        assert load_seed(db_path, seed) == 0

    assert "differs from the stored one" in caplog.text
    assert db.count_trips(db_path) == 1


def test_missing_seed_file_does_not_crash(db_path, tmp_path):
    with TestClient(create_app(db_path, tmp_path / "nope.json")) as client:
        assert client.get("/api/days").json() == []
