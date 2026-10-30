"""aios --context --permit: PreToolUse hook for Bash (spec 02, Freigabe; V0.6, memos 20-23, 47).

Standard library only. In an A/W a single command of the forwarder is allowed without a question
(E1-E3), unless a deny or ask rule of the user matches it (E4). Otherwise, and on every error,
the hook prints nothing and the host asks as usual.
"""

from __future__ import annotations

import fnmatch
import json
import os
import sys
from pathlib import Path

from . import config, paths

FORBIDDEN = (";", "&", "|", "`", "$(", ">", "<", "\n", "\r")      # E3: a single command only
MANAGED = (Path("/Library/Application Support/ClaudeCode/managed-settings.json"),   # macOS
           Path("/etc/claude-code/managed-settings.json"))                          # Linux


class Unreadable(Exception):
    """A settings file that cannot be read: never allow (spec 02, E4)."""


def forwarders():
    """Absolute paths of the forwarders of the kernel (E2)."""
    return [str(paths.forwarder()), str(paths.prefix() / "bin" / "aios")]


def is_forwarder_call(command):
    """E2: the command starts with the absolute path of a forwarder, bare or in quotes (V0.6, B5),
    then a blank or the end."""
    c = command.strip()
    return any(c == p or c.startswith(p + " ")
               for f in forwarders() for p in (f, f'"{f}"', f"'{f}'"))


def single(command):
    """E3: no chaining, pipe, substitution or redirection."""
    return not any(x in command for x in FORBIDDEN)


def managed_files():
    env = os.environ.get("AIOS_MANAGED_SETTINGS")
    return [Path(env)] if env else list(MANAGED)


def settings_files(cwd):
    """User, project (shared and local) and managed settings (E4)."""
    d = Path(cwd)
    return [paths.claude_dir() / "settings.json", d / ".claude" / "settings.json",
            d / ".claude" / "settings.local.json", *managed_files()]


def rules(cwd):
    """deny and ask rules of all settings files; an unreadable file raises Unreadable."""
    found = []
    for f in settings_files(cwd):
        if not f.is_file():
            continue
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, ValueError) as e:
            raise Unreadable(f"{f}: {e}")
        perm = data.get("permissions") if isinstance(data, dict) else None
        if not isinstance(perm, dict):
            continue
        for key in ("deny", "ask"):
            entries = perm.get(key) or []
            if not isinstance(entries, list):
                raise Unreadable(f"{f}: permissions.{key} is not a list")
            found += [str(e) for e in entries]
    return found


def hits(rule, command):
    """True if a rule may match the command: Bash, Bash(<exact>), Bash(<prefix>:*), Bash(<glob *>);
    a pattern of unknown form counts as a hit (cautious, V0.6, memo 47)."""
    rule = rule.strip()
    if rule == "Bash":
        return True
    if not rule.startswith("Bash(") or not rule.endswith(")"):
        return False                                # rule for another tool
    pat = rule[len("Bash("):-1].strip()
    c = command.strip()
    if pat.endswith(":*"):
        return c.startswith(pat[:-2])
    if any(x in pat for x in "[]?"):
        return True                                 # unknown form: do not allow
    return fnmatch.fnmatchcase(c, pat)


def decision(raw):
    """The JSON line that allows the command, or None (E1-E4)."""
    d = json.loads(raw or "{}")
    if not isinstance(d, dict):
        return None
    if d.get("tool_name") not in (None, "Bash"):
        return None
    cwd = d.get("cwd") or paths.cwd()
    command = (d.get("tool_input") or {}).get("command") or ""
    if not os.path.isdir(cwd) or config.load(cwd).kind != "aios":           # E1
        return None
    if not is_forwarder_call(command) or not single(command):              # E2, E3
        return None
    if any(hits(r, command) for r in rules(cwd)):                          # E4
        return None
    return json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                              "permissionDecision": "allow",
                                              "permissionDecisionReason": "AIBOS: command of AIOS in an AIBOS workspace"}})


def main():
    """Read the hook JSON from stdin; never fails, errors go to the log only (spec 02)."""
    raw = "" if sys.stdin is None or sys.stdin.isatty() else sys.stdin.read()
    try:
        out = decision(raw)
    except Exception as e:                          # noqa: BLE001 - an error never allows
        try:
            cwd = (json.loads(raw or "{}") or {}).get("cwd") or paths.cwd()
        except Exception:                           # noqa: BLE001
            cwd = paths.cwd()
        paths.log("--permit", cwd, f"aios --context --permit failed: {e}")
        return 0
    if out:
        print(out)
    return 0
