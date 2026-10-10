"""Pure summary logic: no server, no database."""

from datetime import date, datetime
from types import SimpleNamespace

from app.summary import build_summary, trip_day

DAY = date(2026, 10, 1)


def trip(amount: int, payment: str, commission: int) -> SimpleNamespace:
    return SimpleNamespace(amount=amount, payment=payment, commission=commission)


def test_regular_day():
    trips = [trip(2400, "card", 360), trip(1500, "cash", 225), trip(3000, "card", 450)]

    summary = build_summary(DAY, trips)

    assert summary == {
        "date": DAY,
        "trips_count": 3,
        "revenue": 6900,
        "commission": 1035,
        "net": 5865,
        "cash": {"amount": 1500, "count": 1},
        "card": {"amount": 5400, "count": 2},
    }


def test_empty_day_gives_zeros():
    summary = build_summary(DAY, [])

    assert summary == {
        "date": DAY,
        "trips_count": 0,
        "revenue": 0,
        "commission": 0,
        "net": 0,
        "cash": {"amount": 0, "count": 0},
        "card": {"amount": 0, "count": 0},
    }


def test_only_cash():
    summary = build_summary(DAY, [trip(1000, "cash", 150), trip(800, "cash", 120)])

    assert summary["revenue"] == 1800
    assert summary["net"] == 1530
    assert summary["cash"] == {"amount": 1800, "count": 2}
    assert summary["card"] == {"amount": 0, "count": 0}


def test_only_card():
    summary = build_summary(DAY, [trip(5000, "card", 750)])

    assert summary["trips_count"] == 1
    assert summary["net"] == 4250
    assert summary["cash"] == {"amount": 0, "count": 0}
    assert summary["card"] == {"amount": 5000, "count": 1}


def test_trip_over_midnight_belongs_to_start_day():
    start = datetime.fromisoformat("2026-10-02T23:40:00+05:00")

    assert trip_day(start) == date(2026, 10, 2)


def test_utc_time_is_converted_to_almaty_day():
    assert trip_day(datetime.fromisoformat("2026-10-01T19:30:00Z")) == date(2026, 10, 2)


def test_utc_time_just_before_almaty_midnight():
    assert trip_day(datetime.fromisoformat("2026-10-01T18:59:59Z")) == date(2026, 10, 1)


def test_other_offset_is_converted_to_almaty_day():
    # 23:30 in UTC+06:00 is 22:30 in Almaty, same day
    assert trip_day(datetime.fromisoformat("2026-10-01T23:30:00+06:00")) == date(2026, 10, 1)
