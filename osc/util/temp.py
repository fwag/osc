"""
Helpers for temporary files and directories
"""

import tempfile


def create_scratch_file(suffix: str = ".tmp") -> str:
    """Creates a scratch file and returns its path.

    An empty file is created. The caller is responsible for deleting the file.

    Keyword arguments:
    suffix -- the suffix of the scratch file (default: ".tmp")

    Returns:
        The path to the scratch file.
    """
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as f:
        return f.name
