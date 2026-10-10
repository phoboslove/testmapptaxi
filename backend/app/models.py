"""Pydantic schemas for the API."""

from datetime import date, datetime
from typing import Annotated, Literal

from pydantic import (
    AwareDatetime,
    BaseModel,
    ConfigDict,
    Field,
    StringConstraints,
    ValidationInfo,
    field_validator,
)
from pydantic_core import PydanticCustomError

from .summary import to_almaty, trip_day

TripId = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=64)]
Money = Annotated[int, Field(strict=True)]
Payment = Literal["cash", "card"]

TRIP_EXAMPLE = {
    "id": "t100",
    "start": "2026-10-01T08:10:00+05:00",
    "end": "2026-10-01T08:32:00+05:00",
    "amount": 2400,
    "payment": "card",
    "commission": 360,
}


class TripIn(BaseModel):
    """A trip as sent by the client. Times must carry a UTC offset."""

    model_config = ConfigDict(extra="forbid", json_schema_extra={"examples": [TRIP_EXAMPLE]})

    id: TripId
    start: AwareDatetime
    end: AwareDatetime
    amount: Annotated[Money, Field(gt=0)]
    payment: Payment
    commission: Annotated[Money, Field(ge=0)]

    @field_validator("start", "end")
    @classmethod
    def normalize_time(cls, value: datetime) -> datetime:
        return to_almaty(value)

    # Cross-field checks are attached to the later field, so a 422 points
    # at "end" / "commission" and the client can show it under that input.
    @field_validator("end")
    @classmethod
    def end_after_start(cls, end: datetime, info: ValidationInfo) -> datetime:
        start = info.data.get("start")
        if start is not None and end <= start:
            raise PydanticCustomError("end_not_after_start", "end must be later than start")
        return end

    @field_validator("commission")
    @classmethod
    def commission_within_amount(cls, commission: int, info: ValidationInfo) -> int:
        amount = info.data.get("amount")
        if amount is not None and commission > amount:
            raise PydanticCustomError("commission_over_amount", "commission must not exceed amount")
        return commission

    @property
    def day(self) -> date:
        return trip_day(self.start)


class TripOut(BaseModel):
    """A stored trip. Times are always in +05:00."""

    model_config = ConfigDict(
        json_schema_extra={"examples": [{**TRIP_EXAMPLE, "day": "2026-10-01"}]}
    )

    id: str
    start: datetime
    end: datetime
    amount: int
    payment: Payment
    commission: int
    day: date


class PaymentTotals(BaseModel):
    amount: int
    count: int


class Summary(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "date": "2026-10-01",
                    "trips_count": 2,
                    "revenue": 3900,
                    "commission": 585,
                    "net": 3315,
                    "cash": {"amount": 1500, "count": 1},
                    "card": {"amount": 2400, "count": 1},
                }
            ]
        }
    )

    date: date
    trips_count: int
    revenue: int
    commission: int
    net: int
    cash: PaymentTotals
    card: PaymentTotals
