"""AIbex AIOS - operating system for the context of AI assistants.

Python part of AIOS (logic behind `aios` and `aios-context`), see spec/.
"""

from pathlib import Path


def version() -> str:
    """Version of this AIOS source tree or installation (file VERSION)."""
    here = Path(__file__).resolve().parent
    for candidate in (here.parent.parent / "VERSION", here.parent / "VERSION"):
        if candidate.is_file():
            return candidate.read_text(encoding="utf-8").strip()
    return "unknown"
