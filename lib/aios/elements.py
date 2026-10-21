"""Fetched packages of a masterspace and their deployed elements (spec 06, Ausrollen, Wirkung).

A package in <project>/@/@!Package/<name>/ (with the marker .aios-deploy) acts with the elements
that are deployed: all of them, unless packages: of the project names a selection only: [...]
(H2, H3); dependencies are always deployed whole (H4). The elements are found from the
folders of the package (skills/<n>/SKILL.md, assistants/<n>/ASSISTANT.md, commands/<n>,
knowledge/), so the hooks need no YAML parser. Standard library only.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from . import config

MARKER = ".aios-deploy"
KINDS = ("skills", "assistants", "commands", "knowledge")


def marker(d):
    """Fields of the marker of a package folder, None without marker."""
    f = Path(d) / MARKER
    if not f.is_file():
        return None
    out = {}
    for line in f.read_text(encoding="utf-8").splitlines():
        if ":" in line and not line.startswith("#"):
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip().strip('"')
    return out


@dataclass
class Package:
    name: str
    dir: Path
    masterspace: Path
    meta: dict
    only: set | None                                # None: all elements deployed

    @property
    def version(self):
        return self.meta.get("version", "")

    @property
    def hub(self):
        return self.meta.get("hub") or "-"

    def elements(self):
        """{kind: [names]} from the folders of the package."""
        out = {k: [] for k in KINDS}
        for kind, file in (("skills", "SKILL.md"), ("assistants", "ASSISTANT.md")):
            base = self.dir / kind
            if base.is_dir():
                out[kind] = sorted(p.name for p in base.iterdir() if (p / file).is_file())
        base = self.dir / "commands"
        if base.is_dir():
            out["commands"] = sorted(p.name for p in base.iterdir() if p.is_file())
        if (self.dir / "knowledge").is_dir():
            out["knowledge"] = ["knowledge"]
        return out

    def deployed(self, element):
        return self.only is None or element in self.only

    def split(self):
        """(deployed, not deployed) as lists of (kind, name)."""
        on, off = [], []
        for kind, names in self.elements().items():
            for n in names:
                (on if self.deployed(n) else off).append((kind, n))
        return on, off

    def dirs(self, kind):
        """Folders of the deployed elements of a kind (skills or assistants)."""
        return [self.dir / kind / n for n in self.elements()[kind] if self.deployed(n)]


def selection(project):
    """{package: set of elements} from only: in packages: of the project's own config.yaml."""
    f = Path(project) / ".aios" / "config.yaml"
    try:
        data = config.read(f).get("packages") if f.is_file() else None
    except (config.ConfigError, UnicodeDecodeError):
        return {}
    out = {}
    for name, entry in (data or {}).items() if isinstance(data, dict) else []:
        if isinstance(entry, dict) and entry.get("only"):
            only = entry["only"]
            out[name] = set(only if isinstance(only, list) else [only])
    return out


def packages(masterspace):
    """Fetched packages of a masterspace <project>/@, sorted by name."""
    base = Path(masterspace) / "@!Package"
    if not base.is_dir():
        return []
    only = selection(Path(masterspace).parent)
    out = []
    for d in sorted(p for p in base.iterdir() if p.is_dir() and not p.name.startswith(".")):
        meta = marker(d)
        if meta is not None:
            out.append(Package(d.name, d, Path(masterspace), meta, only.get(d.name)))
    return out


def candidates(masterspaces, kind, local):
    """(name, folder, origin) of a kind along the chain, in the order in which they apply:
    per masterspace from the vault root down first the packages, then the local blueprints
    (local@!Skill or @!Assistant); a later entry of the same name covers an earlier one (S6)."""
    file = "SKILL.md" if kind == "skills" else "ASSISTANT.md"
    out = []
    for ms in masterspaces:
        for p in packages(ms):
            for d in p.dirs(kind):
                out.append((d.name, d, f"package {p.name} ({ms.parent.name})"))
        base = ms / local
        if base.is_dir():
            for d in sorted(x for x in base.iterdir() if x.is_dir() and not x.name.startswith(".")):
                if kind == "assistants" and not (d / file).is_file():
                    continue
                out.append((d.name, d, f"local blueprint ({ms.parent.name})"))
    return out


def covered(masterspaces, kind, local):
    """[(name, covered origin, covering origin)] along the chain (spec 06, Vorrang)."""
    seen, out = {}, []
    for name, d, origin in candidates(masterspaces, kind, local):
        if name in seen:
            out.append((name, seen[name], origin))
        seen[name] = origin
    return out
