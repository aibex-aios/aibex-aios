"""Package manifest manifest.yaml (spec 06, Pakete).

A package is a versioned unit described by manifest.yaml at the root of its repo. This module
reads and checks the manifest, tells modules from plain packages and lists the elements a
package can deploy. The manifest is read with PyYAML.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

from . import semver
from .install import frontmatter

NAME = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
TYPES = ("kernel", "app", "assistant", "skill", "knowledge", "tutorial", "distribution")
MODULE_TYPES = ("kernel", "app", "assistant", "skill")
RESERVED = ("aios", "gui", "none", "inherit")      # besides the prefix aios-
CONTENT_LISTS = ("skills", "assistants", "commands", "hooks")
WORKER_SCRIPTS = ("install", "remove", "start", "stop")


class ManifestError(Exception):
    """manifest.yaml that does not follow spec 06."""


@dataclass
class Manifest:
    name: str
    version: semver.Version
    type: str
    description: str
    requires: semver.Range
    depends: dict = field(default_factory=dict)     # name -> Range
    contents: dict = field(default_factory=dict)
    workers: dict = field(default_factory=dict)
    license: str = ""
    userdata: object = None
    warnings: list = field(default_factory=list)

    @property
    def is_module(self):
        """A module adds something AIOS can do (spec 06): a module type, or contents with a
        skill, assistant, command or hook."""
        return self.type in MODULE_TYPES or any(self.contents.get(k) for k in CONTENT_LISTS)

    def elements(self):
        """Names of the elements that can be deployed: skills, assistants and commands by
        their names, the knowledge as 'knowledge' (spec 06, N2). Hooks have no effect in v0.4."""
        names = []
        for kind in ("skills", "assistants", "commands"):
            names += list(self.contents.get(kind) or [])
        if self.contents.get("knowledge"):
            names.append("knowledge")
        return names


def name_problem(name):
    """None if name is a valid package name (spec 06), else the reason."""
    if not isinstance(name, str) or not NAME.match(name):
        return f"{name!r} is not a package name (lower case letters, digits, -, at most 64)"
    if name in RESERVED or name.startswith("aios-"):
        return f"{name} is a reserved name"
    return None


def as_list(value, where):
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list) and all(isinstance(x, str) for x in value):
        return value
    raise ManifestError(f"{where}: expected a list of names")


def parse(data, where="manifest.yaml", kernel=False):
    """Manifest from the parsed YAML data; kernel=True allows the name aios (spec 06, Q1)."""
    if not isinstance(data, dict):
        raise ManifestError(f"{where}: not a mapping")
    for key in ("name", "version", "type", "description", "requires"):
        if data.get(key) in (None, ""):
            raise ManifestError(f"{where}: {key} is missing")
    name = data["name"]
    problem = None if kernel and name == "aios" else name_problem(name)
    if problem:
        raise ManifestError(f"{where}: {problem}")
    try:
        version = semver.Version.parse(data["version"])
        if version.parts != 3:
            raise semver.VersionError(f"{data['version']!r} is not MAJOR.MINOR.PATCH")
    except semver.VersionError as e:
        raise ManifestError(f"{where}: version {e}")
    warnings = []
    kind = data["type"]
    if kind not in TYPES:
        warnings.append(f"{where}: unknown type {kind!r}, treated as knowledge")
        kind = "knowledge"
    requires = data["requires"]
    if not isinstance(requires, dict) or "aios" not in requires:
        raise ManifestError(f"{where}: requires needs aios: \"<range>\"")
    try:
        req = semver.Range.parse(requires["aios"])
        depends = {}
        for dep, rng in (data.get("depends") or {}).items():
            if dep == "aios":
                raise ManifestError(f"{where}: depends must not name aios, use requires")
            problem = name_problem(dep)
            if problem:
                raise ManifestError(f"{where}: depends: {problem}")
            depends[dep] = semver.Range.parse(rng)
    except semver.VersionError as e:
        raise ManifestError(f"{where}: {e}")
    contents = dict(data.get("contents") or {})
    for key in CONTENT_LISTS:
        contents[key] = as_list(contents.get(key), f"{where}: contents.{key}")
    gui = contents.get("gui")
    if gui and gui not in contents["skills"]:
        raise ManifestError(f"{where}: contents.gui {gui} is not in contents.skills")
    names = [n for k in ("skills", "assistants", "commands") for n in contents[k]]
    dup = sorted({n for n in names if names.count(n) > 1})
    if dup:
        raise ManifestError(f"{where}: element names are not unique: {', '.join(dup)}")
    if "knowledge" in names:
        raise ManifestError(f"{where}: knowledge is reserved as the name of the knowledge element")
    workers = data.get("workers") or {}
    for w, spec in workers.items():
        if not isinstance(spec, dict) or not spec.get("install") or not spec.get("remove"):
            raise ManifestError(f"{where}: worker {w} needs install and remove")
    return Manifest(name, version, kind, str(data["description"]), req, depends, contents, workers,
                    str(data.get("license") or ""), data.get("userdata"), warnings)


def load(folder, kernel=False):
    """Manifest of the package in folder (manifest.yaml at its root)."""
    import yaml                                     # PyYAML, only where manifests are read
    file = Path(folder) / "manifest.yaml"
    if not file.is_file():
        raise ManifestError(f"{folder} has no manifest.yaml")
    try:
        data = yaml.safe_load(file.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        raise ManifestError(f"{file}: {e}")
    return parse(data, str(file), kernel)


def check_tree(folder, m):
    """Problems of the package tree against its manifest (spec 06, Prüfung beim Holen);
    empty if the package may be fetched."""
    folder = Path(folder)
    problems = []
    for name in m.contents["skills"]:
        f = folder / "skills" / name / "SKILL.md"
        if not f.is_file():
            problems.append(f"skill {name}: skills/{name}/SKILL.md is missing")
            continue
        ver = str(frontmatter(f).get("version") or "").strip("'\" ")
        if not re.match(r"^\d+\.\d+\.\d+$", ver):
            problems.append(f"skill {name}: no valid version")
    for name in m.contents["assistants"]:
        if not (folder / "assistants" / name / "ASSISTANT.md").is_file():
            problems.append(f"assistant {name}: assistants/{name}/ASSISTANT.md is missing")
    for name in m.contents["commands"]:
        if not (folder / "commands" / name).is_file():
            problems.append(f"command {name}: commands/{name} is missing")
    if m.contents.get("knowledge") and not (folder / "knowledge").is_dir():
        problems.append("knowledge: the folder knowledge/ is missing")
    for w, spec in m.workers.items():
        for script in WORKER_SCRIPTS:
            if spec.get(script) and not (folder / spec[script]).is_file():
                problems.append(f"worker {w}: {spec[script]} is missing")
    return problems
