from datetime import datetime


def format_iso(dt: datetime) -> str:
    """Returns the given datetime object as iso-8601 formated string"""
    return dt.isoformat()
