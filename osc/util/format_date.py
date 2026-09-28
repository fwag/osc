import os


def format_iso(dt):
    """Formats a datetime object into ISO 8601 format.

    :param dt: The datetime object.
    :return: The datetime as string in ISO 8601 format.
    """
    return dt.isoformat()
