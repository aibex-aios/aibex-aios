"""aios --context --permit: PreToolUse hook for Bash, Skill and Read (spec 02, Freigabe; V0.6, memos 20-23,
47, 65, 101).

Standard library only. In an A/W a single command of the forwarder is allowed without a question
(E1-E3), unless a deny or ask rule of the user matches it (E4); so is the Skill tool for a registered
wrapper of the kernel (S1-S3) and the Read tool for a part file under ~/.aios/cache (R1-R3). Otherwise,
and on every error, the hook prints nothing and the host asks as usual.
"""

from __future__ import annotations

import fnmatch
import json
import os
import re
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


def kernel_skills():
    """Names of the kernel skills of this kernel and the alias gui (S2)."""
    d = Path(__file__).resolve().parents[2] / "skills" / "aios"
    return {p.name for p in d.iterdir() if (p / "SKILL.md").is_file()} | {"gui"}


def registered_kernel(cwd, name):
    """S2: name is registered as a wrapper of the kernel in .aios/registry of cwd or a folder above."""
    entry = re.compile(r"^  " + re.escape(name) + r':\n    source: "kernel"$', re.M)
    d = Path(cwd)
    for p in (d, *d.parents):
        f = p / ".aios" / "registry"
        if f.is_file() and entry.search(f.read_text(encoding="utf-8")):
            return True
    return False


def hits_skill(rule, name):
    """S3: Skill, Skill(<name>), Skill(<prefix>:*), Skill(<glob *>); another form counts as a hit."""
    rule = rule.strip()
    if rule == "Skill":
        return True
    if not rule.startswith("Skill(") or not rule.endswith(")"):
        return False
    pat = rule[len("Skill("):-1].strip()
    if pat.endswith(":*"):
        return name.startswith(pat[:-2])
    if any(x in pat for x in "[]?"):
        return True
    return fnmatch.fnmatchcase(name, pat)


def in_cache(file_path):
    """R2: an absolute path that lies below ~/.aios/cache after resolving .. and symlinks."""
    if not isinstance(file_path, str) or not os.path.isabs(file_path):
        return False
    cache = Path(os.path.realpath(paths.cache_dir()))
    p = Path(os.path.realpath(file_path))
    return p != cache and cache in p.parents


def hits_read(rule, file_path):
    """R3: Read, Read(~/<glob>), Read(//<glob>); a pattern with [ ] ? counts as a hit; other forms
    are relative to a project or a settings file and cannot cover ~/.aios/cache."""
    rule = rule.strip()
    if rule == "Read":
        return True
    if not rule.startswith("Read(") or not rule.endswith(")"):
        return False
    pat = rule[len("Read("):-1].strip()
    if pat in ("**", "*") or any(x in pat for x in "[]?"):
        return True
    if pat.startswith("~/"):
        pat = str(paths.home()) + pat[1:]
    elif pat.startswith("//"):
        pat = pat[1:]
    else:
        return False
    p = os.path.realpath(file_path)
    return any(fnmatch.fnmatchcase(f, pat) for f in (file_path, p))


def read_decision(cwd, file_path):
    """Read tool: a part file of the master context or an assistant (R1-R3; V0.6, memos 100, 101, B18)."""
    if not in_cache(file_path):                                                  # R2
        return None
    if any(hits_read(r, file_path) for r in rules(cwd)):                         # R3
        return None
    return allow("AIBOS: part file of the master context")


def allow(reason):
    return json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                              "permissionDecision": "allow",
                                              "permissionDecisionReason": reason}})


def skill_decision(cwd, name):
    """Skill tool: a registered wrapper of the kernel in an A/W (S1-S3; V0.6, memo 65, B10)."""
    if not isinstance(name, str) or name not in kernel_skills():                 # S2
        return None
    if not registered_kernel(cwd, name):
        return None
    if any(hits_skill(r, name) for r in rules(cwd)):                           # S3
        return None
    return allow("AIBOS: kernel skill in an AIBOS workspace")


def decision(raw):
    """The JSON line that allows the command, the skill or the read, or None (E1-E4, S1-S3, R1-R3)."""
    d = json.loads(raw or "{}")
    if not isinstance(d, dict):
        return None
    tool = d.get("tool_name")
    if tool not in (None, "Bash", "Skill", "Read"):
        return None
    cwd = d.get("cwd") or paths.cwd()
    if tool == "Read":
        if not os.path.isdir(cwd) or config.load(cwd).kind != "aios":       # R1
            return None
        return read_decision(cwd, (d.get("tool_input") or {}).get("file_path"))
    if tool == "Skill":
        if not os.path.isdir(cwd) or config.load(cwd).kind != "aios":       # S1
            return None
        return skill_decision(cwd, (d.get("tool_input") or {}).get("skill"))
    command = (d.get("tool_input") or {}).get("command") or ""
    if not os.path.isdir(cwd) or config.load(cwd).kind != "aios":           # E1
        return None
    if not is_forwarder_call(command) or not single(command):              # E2, E3
        return None
    if any(hits(r, command) for r in rules(cwd)):                          # E4
        return None
    return allow("AIBOS: command of AIOS in an AIBOS workspace")


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
