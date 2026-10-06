import unittest
from datetime import datetime, timezone

from osc.util.format_date import format_iso


class TestFormatDate(unittest.TestCase):
    def test_format_iso(self):
        dt = datetime(2023, 10, 27, 10, 0, 0, tzinfo=timezone.utc)
        self.assertEqual(format_iso(dt), "2023-10-27T10:00:00+00:00")


if __name__ == "__main__":
    unittest.main()
