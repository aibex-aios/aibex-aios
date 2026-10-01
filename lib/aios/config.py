"""Configuration chain .aios/config.yaml (spec 04, Formate and Konfigurationskette).

config.yaml uses a small subset of YAML, read without PyYAML:
top-level `key: value`, `key: [a, b]`, one nested level (`skills:` with `name: version`,
or `- item` lists), comments and quotes. The forwarders read `aios:` the same way.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

from . import paths

KEY = re.compile(r"^([A-Za-z_][\w-]*):(?:\s+(.*?))?\s*$")
SUBKEY = re.compile(r"^([A-Za-z0-9_][\w./-]*):(?:\s+(.*?))?\s*$")   # skills: name or assistant/name
VERSION = re.compile(r"^v?(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)$")
LEVELS = {                                          # key -> levels where it is allowed
    "aios": ("vault", "project"),
    "skills": ("vault", "project"),
    "assistants": ("vault", "project"),
    "hosts": ("vault", "project", "home"),
    "inline_limit": ("home",),
}
INLINE_LIMIT = 9000


class ConfigError(Exception):
    """config.yaml outside the supported subset."""


# ---------------------------------------------------------------------------
# reading one file
# ---------------------------------------------------------------------------

def strip_comment(line):
    quote = None
    for i, c in enumerate(line):
        if quote:
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "#" and (i == 0 or line[i - 1] in " \t"):
            return line[:i].rstrip()
    return line.rstrip()


def scalar(text):
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        return text[1:-1]
    return text


def value(text):
    text = text.strip()
    if text.startswith("[") and text.endswith("]"):
        inner = text[1:-1].strip()
        return [scalar(x) for x in inner.split(",")] if inner else []
    return scalar(text)


BLOCK = (">", "|", ">-", "|-", ">+", "|+")


def parse(text, name="config.yaml"):
    """dict of the subset; raises ConfigError with the line number.

    Also reads block scalars (key: > or key: |) as used in frontmatters of ASSISTANT.md.
    """
    result, current, block = {}, None, None
    for no, raw in enumerate(text.splitlines(), 1):
        if block is not None:
            if not raw.strip() or raw[0].isspace():
                block.append(raw.strip())
                continue
            result[current] = (" " if result[current] == ">" else "\n").join(x for x in block if x)
            block, current = None, None
        line = strip_comment(raw.rstrip("\r"))
        if not line.strip():
            continue
        if not line[0].isspace():
            m = KEY.match(line)
            if not m:
                raise ConfigError(f"{name}:{no}: expected 'key: value'")
            key, val = m.group(1), m.group(2)
            if key in result:
                raise ConfigError(f"{name}:{no}: key {key} appears twice")
            if val in BLOCK:
                result[key], current, block = val[0], key, []
            elif val:
                result[key], current = value(val), None
            else:
                result[key], current = None, key
            continue
        if current is None:
            raise ConfigError(f"{name}:{no}: indented line without a key above")
        item = line.strip()
        if item.startswith("- ") or item == "-":
            if result[current] is None:
                result[current] = []
            if not isinstance(result[current], list):
                raise ConfigError(f"{name}:{no}: list item inside a mapping")
            result[current].append(scalar(item[1:]))
            continue
        m = SUBKEY.match(item)
        if not m or not m.group(2):
            raise ConfigError(f"{name}:{no}: expected 'name: value' below {current}")
        if result[current] is None:
            result[current] = {}
        if not isinstance(result[current], dict):
            raise ConfigError(f"{name}:{no}: mapping entry inside a list")
        result[current][m.group(1)] = scalar(m.group(2))
    if block is not None:
        result[current] = (" " if result[current] == ">" else "\n").join(x for x in block if x)
    return result


def read(file):
    return parse(file.read_text(encoding="utf-8"), str(file))


# ---------------------------------------------------------------------------
# the chain
# ---------------------------------------------------------------------------

def vault_root(path):
    """Nearest directory named §… at or above the physical path (spec 02), or None."""
    p = Path(os.path.realpath(path))
    for d in [p, *p.parents]:
        if d.name.startswith("§"):
            return d
    return None


def chain_dirs(path):
    """Directories from path up to the vault root, nearest first; empty outside a vault."""
    p = Path(os.path.realpath(path))
    root = vault_root(p)
    if root is None:
        return []
    dirs = []
    for d in [p, *p.parents]:
        dirs.append(d)
        if d == root:
            break
    return dirs


class Config:
    """Effective configuration of a directory: per key the nearest entry wins."""

    def __init__(self, path):
        self.path = Path(os.path.realpath(path))
        self.vault = vault_root(self.path)
        self.values = {}                            # key -> value
        self.source = {}                            # key -> file (skills: name -> file)
        self.skills = {}                            # name -> version
        self.skill_source = {}
        self.assistants = {}                        # name -> version (manifest assistants:)
        self.assistant_source = {}
        self.files = []                             # chain files, nearest first
        self.warnings = []

    @property
    def aios(self):
        """Version that activates the directory (without v), None = legacy mode."""
        return self.values.get("aios")

    @property
    def hosts(self):
        return self.values.get("hosts", ["claude-code"])

    @property
    def inline_limit(self):
        return int(self.values.get("inline_limit", INLINE_LIMIT))

    def take(self, file, level, data):
        for key, val in data.items():
            if key not in LEVELS:
                self.warnings.append(f"{file}: unknown key {key} ignored")
                continue
            if level not in LEVELS[key]:
                self.warnings.append(f"{file}: {key} is not allowed here, ignored")
                continue
            if key in ("skills", "assistants"):
                if not isinstance(val, dict):
                    self.warnings.append(f"{file}: {key} must map names to versions, ignored")
                    continue
                entries, sources = (self.skills, self.skill_source) if key == "skills" else \
                    (self.assistants, self.assistant_source)
                for name, version in val.items():
                    if name not in entries:
                        entries[name], sources[name] = version, file
                continue
            if key == "aios":
                m = VERSION.match(str(val or ""))
                if not m:
                    self.warnings.append(f"{file}: aios: {val} is not a version, ignored")
                    continue
                val = m.group(1)
            if key == "hosts" and not isinstance(val, list):
                val = [val]
            if key == "inline_limit" and not str(val).isdigit():
                self.warnings.append(f"{file}: inline_limit must be a number, ignored")
                continue
            if key not in self.values:
                self.values[key], self.source[key] = val, file


def load(path="."):
    """Read the chain of path: .aios/config.yaml up to the vault root, then ~/.aios/config.yaml."""
    cfg = Config(path)
    home = paths.home()
    for d in chain_dirs(cfg.path):
        if d == home:                               # ~/.aios/config.yaml is the home level
            continue
        f = d / ".aios" / "config.yaml"
        if f.is_file():
            level = "vault" if d == cfg.vault else "project"
            cfg.files.append(f)
            try:
                cfg.take(f, level, read(f))
            except (ConfigError, UnicodeDecodeError) as e:
                cfg.warnings.append(f"{e}; file ignored")
    f = paths.user_dir() / "config.yaml"
    if f.is_file():
        cfg.files.append(f)
        try:
            cfg.take(f, "home", read(f))
        except (ConfigError, UnicodeDecodeError) as e:
            cfg.warnings.append(f"{e}; file ignored")
    return cfg


def describe(cfg):
    """Lines for aios --config: effective values and their origin."""
    def where(f):
        return str(f) if f else "default"
    lines = [f"path      {cfg.path}",
             f"vault     {cfg.vault or '- (outside a vault)'}"]
    if os.environ.get("AIOS_HOME"):
        lines.append(f"AIOS_HOME {os.environ['AIOS_HOME']} (chooses the version)")
    lines.append(f"aios      {cfg.aios} ({where(cfg.source.get('aios'))})" if cfg.aios
                 else "aios      - (not activated: legacy mode)")
    for name in sorted(cfg.skills):
        lines.append(f"skill     {name} {cfg.skills[name]} ({cfg.skill_source[name]})")
    for name in sorted(cfg.assistants):
        lines.append(f"assistant {name} {cfg.assistants[name]} ({cfg.assistant_source[name]})")
    lines.append(f"hosts     {', '.join(cfg.hosts)} ({where(cfg.source.get('hosts'))})")
    lines.append(f"inline    {cfg.inline_limit} ({where(cfg.source.get('inline_limit'))})")
    lines += [f"warning   {w}" for w in cfg.warnings]
    return lines


# ---------------------------------------------------------------------------
# writing the key aios (line based: comments and other keys stay)
# ---------------------------------------------------------------------------

def set_aios(file, version):
    lines = file.read_text(encoding="utf-8").splitlines() if file.is_file() else []
    out, done = [], False
    for line in lines:
        if line.startswith("aios:"):
            if not done:
                out.append(f"aios: {version}")
                done = True
            continue
        out.append(line)
    if not done:
        out.insert(0, f"aios: {version}")
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text("\n".join(out) + "\n", encoding="utf-8")


def drop_aios(file):
    """Remove the key aios; an empty file (and an empty .aios/) is removed. Returns what is left."""
    lines = [line for line in file.read_text(encoding="utf-8").splitlines() if not line.startswith("aios:")]
    if any(strip_comment(line).strip() for line in lines):
        file.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return "kept"
    file.unlink()
    try:
        file.parent.rmdir()
        return "dir"
    except OSError:
        return "file"


# ---------------------------------------------------------------------------
# writing skills: entries (line based, spec 03 Manifest)
# ---------------------------------------------------------------------------

def _skills_block(lines, section="skills"):
    """(index of '<section>:', end index of its block) or (None, None)."""
    for i, line in enumerate(lines):
        if line.startswith(f"{section}:"):
            if strip_comment(line)[len(section) + 1:].strip():
                raise ConfigError(f"{section}: must be a block of 'name: version' lines")
            j = i + 1
            while j < len(lines) and (not lines[j].strip() or lines[j][0].isspace()):
                j += 1
            while j > i + 1 and not lines[j - 1].strip():
                j -= 1
            return i, j
    return None, None


def set_skill(file, key, version, section="skills"):
    """<section>: <key>: <version> in file (skills: or assistants:); other lines stay."""
    lines = file.read_text(encoding="utf-8").splitlines() if file.is_file() else []
    start, end = _skills_block(lines, section)
    entry = f"  {key}: {version}"
    if start is None:
        lines += [f"{section}:", entry]
    else:
        for i in range(start + 1, end):
            m = SUBKEY.match(lines[i].strip())
            if m and m.group(1) == key:
                lines[i] = entry
                break
        else:
            lines.insert(end, entry)
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text("\n".join(lines) + "\n", encoding="utf-8")


def drop_skill(file, key, section="skills"):
    """Remove <section>: <key>; an empty block and an empty file are removed."""
    lines = file.read_text(encoding="utf-8").splitlines()
    start, end = _skills_block(lines, section)
    if start is None:
        return
    keep = [i for i in range(start + 1, end)
            if not (SUBKEY.match(lines[i].strip()) and SUBKEY.match(lines[i].strip()).group(1) == key)]
    block = [lines[i] for i in keep]
    rest = lines[:start] + (([f"{section}:"] + block) if any(strip_comment(x).strip() for x in block) else []) + lines[end:]
    if any(strip_comment(x).strip() for x in rest):
        file.write_text("\n".join(rest) + "\n", encoding="utf-8")
    else:
        file.unlink()
