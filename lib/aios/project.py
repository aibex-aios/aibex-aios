"""Structure and name of a project (spec 05, Struktur eines Projekts, Namensregel).

The checks S1-S4 are shared by aios --init, the consistency check of the
SessionStart hook and aios --integrity, so that they cannot drift apart.
"""

from __future__ import annotations

import os
import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

from . import config

TEMPLATE = Path(__file__).resolve().parents[2] / "templates" / "gitignore"
PREFIX = re.compile(r"^[A-Z][A-Z0-9]*$")
STEP = re.compile(r"^(?:[A-Z]|\d+)$")              # a child adds one capital letter or a number


def git(p, *args):
    return subprocess.run(["git", "-C", str(p), *args], capture_output=True, text=True)


def template_lines():
    return [line for line in TEMPLATE.read_text(encoding="utf-8").splitlines() if line.strip()]


# ---------------------------------------------------------------------------
# structure S1-S4
# ---------------------------------------------------------------------------

@dataclass
class Gap:
    key: str          # masterspace | repo | gitignore | parent
    text: str         # name of the gap as in spec 05


@dataclass
class Parent:
    """The repo above a project (S4)."""
    root: Path
    rel: str                                        # path of the project relative to root, posix
    ignored: bool
    tracked: list = field(default_factory=list)

    @property
    def ok(self):
        return self.ignored and not self.tracked


def own_repo(p):
    """S2: the project is the root of its own repo."""
    return (Path(p) / ".git").exists()


def missing_gitignore_lines(p):
    """S3: lines of the template missing in <p>/.gitignore."""
    gi = Path(p) / ".gitignore"
    have = gi.read_text(encoding="utf-8").splitlines() if gi.is_file() else []
    return [line for line in template_lines() if line not in have]


def parent_repo(p):
    """S4: the nearest repo above p up to and including the vault root, or None."""
    p = Path(os.path.realpath(p))
    root = config.vault_root(p)
    if root is None or p == root:
        return None
    for d in p.parents:
        if (d / ".git").exists():
            rel = p.relative_to(d).as_posix()
            ignored = git(d, "check-ignore", "-q", "--no-index", rel + "/").returncode == 0
            out = git(d, "ls-files", "--", rel).stdout
            return Parent(d, rel, ignored, [f for f in out.splitlines() if f])
        if d == root:
            break
    return None


def check(p):
    """Gaps of the structure of the project p (S1-S4), empty if complete."""
    p = Path(os.path.realpath(p))
    gaps = []
    if not (p / "@").is_dir():
        gaps.append(Gap("masterspace", "local masterspace @/"))
    if not own_repo(p):
        gaps.append(Gap("repo", "own git repo"))
    missing = missing_gitignore_lines(p)
    if missing:
        gaps.append(Gap("gitignore", ".gitignore lines: " + ", ".join(missing)))
    parent = parent_repo(p)
    if parent and not parent.ok:
        gaps.append(Gap("parent", f"exclusion in parent repo {parent.root}"))
    return gaps


# ---------------------------------------------------------------------------
# name rule
# ---------------------------------------------------------------------------

@dataclass
class Name:
    name: str
    problems: list = field(default_factory=list)
    proposal: str = ""

    @property
    def ok(self):
        return not self.problems


def split(name):
    """(prefix, parts) of a name of the form <Prefix>-<Teil>[-<Teil>...], or (None, parts)."""
    parts = name.split("-")
    if len(parts) >= 2 and PREFIX.match(parts[0]):
        return parts[0], parts[1:]
    return None, parts


def parent_prefix(p):
    """Prefix a child of p's parent builds on: '' under the vault root, None if the parent
    has no conforming name (then only the form is checked)."""
    p = Path(os.path.realpath(p))
    up = p.parent
    if up.name.startswith("§"):
        return ""
    prefix, parts = split(up.name)
    if prefix is None or any(not part or not re.match(r"^[A-Z0-9]", part) for part in parts):
        return None
    return prefix


def fits(prefix, base):
    """The prefix adds one capital letter or a number to base ('' under the vault root:
    one capital letter)."""
    if base is None:
        return bool(PREFIX.match(prefix))
    if not prefix.startswith(base):
        return False
    step = prefix[len(base):]
    return bool(re.match(r"^[A-Z]$", step)) if base == "" else bool(STEP.match(step))


def capitalize(part):
    return part[:1].upper() + part[1:]


def propose(name, base):
    """A conforming proposal: whitespace and _ become -, parts start upper case, the prefix
    is base plus the initial of the first part (a valid prefix is kept)."""
    parts = [x for x in re.split(r"[\s_\-]+", name.strip()) if x]
    if not parts:
        return ""
    if len(parts) >= 2 and PREFIX.match(parts[0]) and fits(parts[0], base):
        return "-".join([parts[0]] + [capitalize(x) for x in parts[1:]])
    parts = [capitalize(x) for x in parts]
    initial = next((c for c in parts[0] if c.isalpha()), "X").upper()
    return "-".join([(base or "") + initial] + parts)


def check_name(p):
    """Name rule of spec 05 for the project folder p; the vault root is exempt."""
    p = Path(os.path.realpath(p))
    n = Name(p.name)
    if p.name.startswith("§"):
        return n
    base = parent_prefix(p)
    if re.search(r"\s|/", p.name):
        n.problems.append("the name contains whitespace")
    prefix, parts = split(p.name)
    if prefix is None:
        n.problems.append("the name has no prefix (<Prefix>-<Teil>, prefix of capital letters and digits)")
    else:
        if not fits(prefix, base):
            if base == "":
                n.problems.append(f"the prefix {prefix} must be one capital letter directly under the vault root")
            else:
                n.problems.append(f"the prefix {prefix} does not fit the parent prefix {base} "
                                  f"({base} plus one capital letter or a number)")
        for part in parts:
            if not part:
                n.problems.append("the name has an empty part (--)")
            elif not re.match(r"^[A-Z0-9]", part):
                n.problems.append(f"the part '{part}' does not start with a capital letter or a digit")
    if n.problems:
        n.proposal = propose(p.name, base)
    return n
