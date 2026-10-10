"""Pure business logic: which day a trip belongs to and the daily summary.

No database or HTTP here, so it can be tested on plain lists of objects.
"""

from collections.abc import Iterable
from datetime import date, datetime, timedelta, timezone
from typing import Literal, Protocol

# Almaty is UTC+05:00 since 2024. A fixed offset is used instead of
# ZoneInfo("Asia/Almaty"): it needs no tz database (absent on Windows)
# and does not depend on how fresh that database is.
ALMATY_TZ = timezone(timedelta(hours=5))


class TripLike(Protocol):
    amount: int
    commission: int
    payment: Literal["cash", "card"]


def to_almaty(moment: datetime) -> datetime:
    """Convert an aware datetime to Almaty time, dropping sub-second precision."""
    return moment.astimezone(ALMATY_TZ).replace(microsecond=0)


def trip_day(start: datetime) -> date:
    """A trip belongs to the Almaty calendar day on which it started."""
    return to_almaty(start).date()


def build_summary(day: date, trips: Iterable[TripLike]) -> dict:
    """Totals for one day. The caller passes the trips of that day."""
    totals = {"cash": {"amount": 0, "count": 0}, "card": {"amount": 0, "count": 0}}
    revenue = commission = count = 0
    for trip in trips:
        revenue += trip.amount
        commission += trip.commission
        count += 1
        totals[trip.payment]["amount"] += trip.amount
        totals[trip.payment]["count"] += 1
    return {
        "date": day,
        "trips_count": count,
        "revenue": revenue,
        "commission": commission,
        "net": revenue - commission,
        "cash": totals["cash"],
        "card": totals["card"],
    }
