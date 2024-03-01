import math
from datetime import datetime, timedelta
from typing import Any

from dateutil.relativedelta import relativedelta


def get_sys_time() -> float:
    return math.floor(datetime.now().timestamp() * 1000)


def parse_date(date: str) -> datetime:
    return datetime.strptime(date, "%Y-%m-%d")


def plus_time(date: datetime, **kwargs: Any) -> datetime:
    return date + timedelta(**kwargs)


def minus_time(date: datetime, **kwargs: Any) -> datetime:
    return date - timedelta(**kwargs)


def relative_time(date: datetime, **kwargs: Any) -> datetime:
    delta = relativedelta(**kwargs)
    return date + delta


def date_replace(date: datetime, **kwargs: Any) -> datetime:
    return date.replace(**kwargs)


def format_date(date: datetime, format: str) -> str:
    return date.strftime(format)


def iso_format(date: datetime) -> str:
    return date.strftime("%Y-%m-%dT%H:%M:%S")


def date_iso(date: datetime) -> str:
    return date.strftime("%Y-%m-%d")


def year(date: datetime) -> str:
    return date.strftime("%Y")


def month(date: datetime) -> str:
    return date.strftime("%m")


def day(date: datetime) -> str:
    return date.strftime("%d")


def hour(date: datetime) -> str:
    return date.strftime("%H")


def quarter(date: datetime) -> str:
    return str(math.ceil(date.month / 3.0))


def today() -> datetime:
    return datetime.today()
