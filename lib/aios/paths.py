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


def user_versions() -> Path:
    """Fallback for installations when /opt/aios cannot be set up, ~/.aios/versions."""
    return user_dir() / "versions"


def sudo_cmd() -> str:
    """Program used as sudo (AIOS_SUDO), tests never call the real sudo."""
    return os.environ.get("AIOS_SUDO", "sudo")


def stup_url() -> str:
    """Source of stup (AIOS_STUP_URL), may be a file:// URL in tests."""
    return os.environ.get(
        "AIOS_STUP_URL", "https://raw.githubusercontent.com/bluccino/tool-stup/master/bin/stup")


def pip_cmd() -> str:
    """Command that installs python/requirements.txt into the venv (AIOS_PIP), empty = default."""
    return os.environ.get("AIOS_PIP", "")


def cwd() -> str:
    """Logical working directory ($PWD) like the forwarders and the shell, physical as fallback."""
    pwd = os.environ.get("PWD")
    try:
        if pwd and os.path.samefile(pwd, os.getcwd()):
            return os.path.abspath(pwd)
    except OSError:
        pass
    return os.getcwd()


def cache_dir() -> Path:
    """Part files of the master context, ~/.aios/cache."""
    return user_dir() / "cache"
