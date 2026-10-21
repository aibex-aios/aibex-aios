"""Versions and ranges of packages (spec 06, Versionen und Bereiche).

Versions follow SemVer 2.0: MAJOR.MINOR.PATCH, an optional pre-release (-rc1) and build
metadata (+...), which is ignored; missing parts count as 0 and a leading v is allowed.
Ranges follow the version specifiers of pip: ==, !=, >=, <=, >, <, ~=, combined with a comma;
* or an empty range means any version. Standard library only.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

VERSION = re.compile(r"^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$")
OPERATORS = ("~=", "==", "!=", ">=", "<=", ">", "<")


class VersionError(ValueError):
    """A version or range that does not follow spec 06."""


@dataclass(frozen=True)
class Version:
    major: int
    minor: int = 0
    patch: int = 0
    pre: tuple = ()                                 # pre-release identifiers, () for a release
    parts: int = 3                                  # number of parts given (for ~=)

    @classmethod
    def parse(cls, text):
        m = VERSION.match(str(text).strip())
        if not m:
            raise VersionError(f"{text!r} is not a version (MAJOR.MINOR.PATCH)")
        major, minor, patch, pre = m.groups()
        parts = 3 if patch is not None else 2 if minor is not None else 1
        ids = tuple(int(x) if x.isdigit() else x for x in pre.split(".")) if pre else ()
        return cls(int(major), int(minor or 0), int(patch or 0), ids, parts)

    def key(self):
        """Order of SemVer 2.0: a pre-release is lower than its release; numeric identifiers
        are lower than alphanumeric ones and compare as numbers."""
        pre = (1,) if not self.pre else (0,) + tuple((0, x, "") if isinstance(x, int) else (1, 0, x)
                                                     for x in self.pre)
        return (self.major, self.minor, self.patch, pre)

    def __lt__(self, other):
        return self.key() < other.key()

    def __le__(self, other):
        return self.key() <= other.key()

    def __gt__(self, other):
        return self.key() > other.key()

    def __ge__(self, other):
        return self.key() >= other.key()

    def __eq__(self, other):
        return isinstance(other, Version) and self.key() == other.key()

    def __hash__(self):
        return hash(self.key())

    def release(self):
        """The version without pre-release (for requires.aios: 0.4.0-dev counts as 0.4.0, L1)."""
        return Version(self.major, self.minor, self.patch)

    def __str__(self):
        s = f"{self.major}.{self.minor}.{self.patch}"
        return s + ("-" + ".".join(str(x) for x in self.pre) if self.pre else "")


@dataclass(frozen=True)
class Range:
    clauses: tuple                                  # (operator, Version)
    text: str = "*"

    @classmethod
    def parse(cls, text):
        """A range like '>=0.4,<0.5' or '~=6.0'; a bare version means ==, * or '' any version."""
        t = str(text if text is not None else "").strip().strip("'\"")
        if t in ("", "*"):
            return cls((), "*")
        clauses = []
        for part in t.split(","):
            part = part.strip()
            op = next((o for o in OPERATORS if part.startswith(o)), "==")
            value = part[len(op):].strip() if part.startswith(op) else part
            if not value:
                raise VersionError(f"{text!r}: {op} without a version")
            v = Version.parse(value)
            if op == "~=" and v.parts < 2:
                raise VersionError(f"{text!r}: ~= needs at least two parts (~=X.Y)")
            clauses.append((op, v))
        return cls(tuple(clauses), t)

    def names_pre(self):
        return any(v.pre for _, v in self.clauses)

    def contains(self, version):
        """True if version fulfils all clauses. A pre-release fulfils a range only if the
        range itself names a pre-release (spec 06)."""
        v = version if isinstance(version, Version) else Version.parse(version)
        if v.pre and not self.names_pre():
            return False
        return all(check(op, v, w) for op, w in self.clauses)

    def __str__(self):
        return self.text


def check(op, v, w):
    if op == "==":
        return v == w
    if op == "!=":
        return v != w
    if op == ">=":
        return v >= w
    if op == "<=":
        return v <= w
    if op == ">":
        return v > w
    if op == "<":
        return v < w
    # ~=X.Y means >=X.Y,<(X+1).0; ~=X.Y.Z means >=X.Y.Z,<X.(Y+1).0
    upper = Version(w.major + 1) if w.parts == 2 else Version(w.major, w.minor + 1)
    return w <= v < upper


def default_range(version):
    """Range for a package fetched without one (spec 06, L5): ~=X.Y from 1.0 on, ~=0.Y.Z below."""
    v = version if isinstance(version, Version) else Version.parse(version)
    if v.major >= 1:
        return Range.parse(f"~={v.major}.{v.minor}")
    return Range.parse(f"~={v.major}.{v.minor}.{v.patch}")


def kernel_fits(requires, kernel):
    """requires.aios against the AIOS version without its pre-release (L1)."""
    r = requires if isinstance(requires, Range) else Range.parse(requires)
    k = kernel if isinstance(kernel, Version) else Version.parse(kernel)
    return r.contains(k.release())


def highest(versions, ranges):
    """The highest version that fulfils all ranges, or None."""
    fitting = [v for v in versions if all(r.contains(v) for r in ranges)]
    return max(fitting) if fitting else None
