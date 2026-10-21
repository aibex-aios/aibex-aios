"""Changeover of a vault or project from v0.3 (spec 06, Umstellung von v0.3; V0.4, memo 47).

v0.3 kept exact versions under skills: and assistants: of .aios/config.yaml and deployed
blueprints with the marker .aios-deploy into @!Skill/ and @!Assistant/. In v0.4 these become
packages: skills: <name> is the package skill-<name>, assistants: <name> the package
assistent-<name>. The same version is kept when the hub has it (as its default range),
otherwise the highest version is taken and the change is named in the plan.
"""

from __future__ import annotations

import shutil
from pathlib import Path

from . import config, deploy, hub, integrity, resolver, semver, ui
from .install import make_writable
from .ui import Abort, say, warn

PREFIX = {"skills": "skill-", "assistants": "assistent-"}


def entries(project):
    """[(section, old name, version)] of skills: and assistants: of the project's own config.yaml;
    entries <assistant>/<skill> are passed over with a warning (spec 06)."""
    f = project / ".aios" / "config.yaml"
    if not f.is_file():
        return []
    try:
        data = config.read(f)
    except config.ConfigError:
        return []
    out = []
    for section in ("skills", "assistants"):
        for name, ver in (data.get(section) or {}).items() if isinstance(data.get(section), dict) else []:
            if "/" in name:
                warn(f"{f}: {section}: {name} (a skill inside an assistant) has no package, passed over")
                continue
            out.append((section, name, str(ver)))
    return out


def legacy(project):
    """packages: read from skills: and assistants: of v0.3 while they are not changed over:
    {package: default range of the old version} (spec 06, Umstellung von v0.3)."""
    out = {}
    for section, name, ver in entries(project):
        try:
            out[PREFIX[section] + name] = str(semver.default_range(ver))
        except semver.VersionError:
            warn(f"{section}: {name}: {ver} is not a version, passed over")
    return out


def blueprint(project, section, name):
    """The deployed blueprint of v0.3 (with marker) of an entry, or None."""
    d = project / "@" / ("@!Skill" if section == "skills" else "@!Assistant") / name
    return d if (d / deploy.MARKER).is_file() else None


class Change:
    """Changeover of one project: new packages: entries, blueprints to remove."""

    def __init__(self, project, source, hubs, kernel):
        self.project = project
        self.packages, self.remove, self.notes, self.skipped = {}, [], [], []
        r = resolver.Resolver(source, hubs, kernel)
        for section, name, ver in entries(project):
            pkg = PREFIX[section] + name
            try:
                key = r.locate(pkg)
            except resolver.ResolveError as e:
                self.skipped.append(f"{section}: {name} {ver}: {e}; the entry stays")
                continue
            versions = [v for v in r.versions(pkg, key) if not v.pre]
            old = semver.Version.parse(ver)
            new = old if old in versions else max(versions)
            if new != old:
                self.notes.append(f"{pkg}: {ver} is not in the hub {key}, takes {new}")
            self.packages[pkg] = (section, name, str(semver.default_range(new)))
            d = blueprint(project, section, name)
            if d:
                self.remove.append(d)

    def __bool__(self):
        return bool(self.packages)

    def lines(self):
        out = [f"{self.project}: {s}: {n} -> packages: {p}: \"{rng}\"" for p, (s, n, rng) in self.packages.items()]
        out += [f"{self.project}: remove the deployed blueprint {d} (replaced by the package)" for d in self.remove]
        out += [f"{self.project}: note: {n}" for n in self.notes]
        return out

    def apply(self):
        f = self.project / ".aios" / "config.yaml"
        for pkg, (section, name, rng) in self.packages.items():
            config.set_skill(f, pkg, f'"{rng}"', "packages")
            config.drop_skill(f, name, section)
        for d in self.remove:
            make_writable(d)
            shutil.rmtree(d)
        from . import fetch
        mode, ui.MODE = ui.MODE, "yes"              # confirmed with the plan of the activation
        try:
            fetch.sync(str(self.project))
        finally:
            ui.MODE = mode


def plan(path, plan_, kernel):
    """Add the changeover of all projects at and below path to the plan of aios --activate."""
    cfg = config.load(path)
    hubs = hub.hub_list(cfg)
    source = hub.GitSource(hubs)
    changes = []
    for p, _ in integrity.projects(Path(path)):
        if not entries(p):
            continue
        c = Change(p, source, [h.name for h in hubs], kernel)
        for s in c.skipped:
            warn(s)
        if c:
            changes.append(c)
    for c in changes:
        plan_.add("changeover from v0.3:\n         " + "\n         ".join(c.lines()), c.apply)
    return changes
