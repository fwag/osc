from datetime import datetime


def format_iso(dt: datetime) -> str:
    """Formats a datetime object into an ISO 8601 string.
    """
    return dt.isoformat()
