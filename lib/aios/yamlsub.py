"""Writer for the fixed subset of YAML in lock.yaml and workers.yaml (spec 04, Formate; V0.5,
memo 37, K-a; S3).

Bash forwarders read these files without a YAML parser, so AIOS writes them in one fixed form:
two spaces per level, one key per line, lists only on one line as [a, b], no block texts, a
head line. Strings are quoted when they could be misread (ranges, paths with special
characters, empty strings, words YAML treats as other types). AIOS itself reads the files with
PyYAML; the output is valid YAML.
"""

from __future__ import annotations

import re

PLAIN = re.compile(r"^[A-Za-z0-9_/][A-Za-z0-9._/@+-]*$")
SPECIAL = {"true", "false", "yes", "no", "on", "off", "null", "~", "y", "n"}


def scalar(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    s = str(value)
    number = re.fullmatch(r"[0-9]+(\.[0-9]*)?([eE][+-]?[0-9]+)?|0x[0-9a-fA-F]+|0o[0-7]+", s)
    if PLAIN.match(s) and s.lower() not in SPECIAL and not number:
        return s                                    # e.g. 0.1.0, aibex-aios, v0.1.0, a sha with letters
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def lines(data, level=0):
    out = []
    pad = "  " * level
    for key, value in data.items():
        k = scalar(key)
        if isinstance(value, dict):
            out.append(f"{pad}{k}:")
            out += lines(value, level + 1)
        elif isinstance(value, (list, tuple)):
            out.append(f"{pad}{k}: [" + ", ".join(scalar(v) for v in value) + "]")
        elif value is None:
            out.append(f"{pad}{k}:")
        else:
            out.append(f"{pad}{k}: {scalar(value)}")
    return out


def dump(data, head):
    """Text of data (nested mappings, scalars, flat lists) in the subset, with a head line."""
    return f"# {head}\n" + "\n".join(lines(data)) + "\n"
