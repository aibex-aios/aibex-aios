"""Fixed locations of AIOS, redirectable for tests (spec 04, Umlenkung fuer Tests)."""

import os
from pathlib import Path


def home() -> Path:
    return Path(os.environ.get("HOME", str(Path.home())))


def prefix() -> Path:
    """Shared installations, default /opt/aios (AIOS_PREFIX)."""
    return Path(os.environ.get("AIOS_PREFIX", "/opt/aios"))


def user_dir() -> Path:
    """Per-user data, ~/.aios."""
    return home() / ".aios"


def claude_dir() -> Path:
    """Claude Code configuration, ~/.claude (AIOS_CLAUDE_DIR)."""
    return Path(os.environ.get("AIOS_CLAUDE_DIR", str(home() / ".claude")))


def bin_dir() -> Path:
    """Directory of the forwarders, ~/bin."""
    return home() / "bin"
