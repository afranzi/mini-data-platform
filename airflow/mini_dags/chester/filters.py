from mini_dags.chester.utils import dates

chester_filters = {
    "iso_format": dates.iso_format,
    "date_iso": dates.date_iso,
    "parse_date": dates.parse_date,
    "plus_time": dates.plus_time,
    "minus_time": dates.minus_time,
    "relative_time": dates.relative_time,
    "date_replace": dates.date_replace,
    "format_date": dates.format_date,
    "quarter": dates.quarter,
    "year": dates.year,
    "month": dates.month,
    "day": dates.day,
    "hour": dates.hour,
}
