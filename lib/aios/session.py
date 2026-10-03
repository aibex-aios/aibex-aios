"""Marker of a session ~/.aios/sessions/<session-id>.yaml (spec 04, Merker der Session).

It holds the assistant a session started with (a name or none, never inherit), so that
resume and compaction keep it (spec 02, Assistent der Session). Local, per session.
"""

from __future__ import annotations

import re
import time
from pathlib import Path

from . import config, paths

ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")
HEADER = "# written by AIOS (session), do not edit"
KEEP_DAYS = 30
STAMP = "%Y-%m-%dT%H:%M:%S"


class BadId(ValueError):
    """A session id with characters that cannot be part of a file name."""


def file(session_id) -> Path:
    if not ID.match(session_id or ""):
        raise BadId(f"{session_id!r} is not a session id")
    return paths.user_dir() / "sessions" / f"{session_id}.yaml"


def read(session_id):
    """{cwd, assistant, used} of the marker, or None if it is missing or unreadable."""
    f = file(session_id)
    try:
        data = config.read(f)
    except (OSError, config.ConfigError, UnicodeDecodeError):
        return None
    a = str(data.get("assistant") or "")
    if a == "inherit" or not config.ASSISTANT_NAME.match(a):
        return None
    return data


def write(session_id, cwd, assistant):
    """Write the marker anew (the assistant is a name or none)."""
    if assistant == "inherit":
        raise ValueError("the marker never holds inherit")
    f = file(session_id)
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(f'{HEADER}\ncwd: "{cwd}"\nassistant: {assistant}\nused: {time.strftime(STAMP)}\n',
                 encoding="utf-8")


def touch(session_id):
    """Update used of an existing marker."""
    data = read(session_id)
    if data:
        write(session_id, data.get("cwd", ""), data["assistant"])


def clean(days=KEEP_DAYS):
    """Remove markers whose used lies more than <days> days back (at startup, spec 02)."""
    d = paths.user_dir() / "sessions"
    if not d.is_dir():
        return
    limit = time.time() - days * 86400
    for f in d.glob("*.yaml"):
        try:
            used = time.mktime(time.strptime(str(config.read(f).get("used", "")), STAMP))
        except (OSError, ValueError, config.ConfigError, UnicodeDecodeError, OverflowError):
            used = f.stat().st_mtime
        if used < limit:
            f.unlink(missing_ok=True)
