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

PREFIX = {"skills": "skill-", "assistants": "assistant-"}  # assistent- up to v0.4 (V0.5, memo 05)


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


def changed(d):
    """True if the content of a deployed blueprint no longer matches the digest of its marker."""
    return (deploy.read_marker(d) or {}).get("digest") != deploy.digest_of(d)


def blueprint(project, section, name):
    """The deployed blueprint of v0.3 (with marker) of an entry, or None."""
    d = project / "@" / ("@!Skill" if section == "skills" else "@!Assistant") / name
    return d if (d / deploy.MARKER).is_file() else None


class Change:
    """Changeover of one project: new packages: entries, blueprints to remove."""

    def __init__(self, project, source, hubs, kernel):
        self.project = project
        self.packages, self.remove, self.keep, self.notes, self.skipped = {}, [], [], [], []
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
            if d:                                   # a changed blueprint stays as a local one (P4, memo 73, B6)
                (self.keep if changed(d) else self.remove).append(d)

    def __bool__(self):
        return bool(self.packages)

    def lines(self):
        out = [f"{self.project}: {s}: {n} -> packages: {p}: \"{rng}\"" for p, (s, n, rng) in self.packages.items()]
        out += [f"{self.project}: remove the deployed blueprint {d} (replaced by the package)" for d in self.remove]
        out += [f"{self.project}: {d} changed directly, stays as local blueprint (covers the package)"
                for d in self.keep]
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
        for d in self.keep:
            make_writable(d)
            (d / deploy.MARKER).unlink()
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


# ---------------------------------------------------------------------------
# changeover from v0.4 (spec 06, Umstellung von v0.4; V0.5, memos 30, 35, 41 N9)
# ---------------------------------------------------------------------------

RENAMES = {"assistent-gaertner": "assistant-gaertner", "assistent-astronom": "assistant-astronom"}


def locked_versions(project):
    from . import fetch
    try:
        lock = fetch.read_lock(project)
    except Abort:
        return {}
    return {n: str(e.get("version")) for n, e in (lock.get("packages") or {}).items()}


def fits(d, kernel):
    """Does the fetched package folder d run with kernel (requires.aios)? True if it is missing."""
    from . import package
    if not (d / "manifest.yaml").is_file():
        return True
    try:
        m = package.load(d)
    except package.ManifestError:
        return True
    return semver.kernel_fits(m.requires, semver.Version.parse(kernel))


class Change04:
    """Changeover of one project to v0.5: renamed packages, versions that fit v0.5, @Data/."""

    def __init__(self, project, source, hubs, kernel):
        from . import fetch
        self.project = project
        self.entries, self.lines_, self.conflicts, self.data = {}, [], [], []
        r = resolver.Resolver(source, hubs, kernel)
        locked = locked_versions(project)
        for name, entry in fetch.wanted(project).items():
            new = RENAMES.get(name, name)
            if new == name and fits(fetch.package_dir(project, name), kernel):
                continue                            # runs with the new kernel: unchanged
            req = fetch.request(entry)
            pick = None
            for rng in (req.range, semver.Range.parse("*")):
                try:
                    pick = r.resolve({new: resolver.Request(rng, req.hub, req.repo)})[new]
                    break
                except resolver.ResolveError:
                    continue
            if pick is None:
                self.conflicts.append(f"{project}: {name} has no version that runs with AIOS {kernel} "
                                      f"(requires.aios); remove it with aios --fetch --remove {name} "
                                      f"--to {project} or wait for a new version of the package")
                continue
            was = locked.get(name)
            rng = str(semver.default_range(pick.version))     # Fragepaket zu Schritt 11
            text = fetch.entry_text(dict(entry, range=rng)) if isinstance(entry, dict) else f'"{rng}"'
            self.entries[name] = (new, text)
            why = "renamed" if new != name else "requires.aios"
            self.lines_.append(f"{project}: packages: {name} {was or '?'} -> {new} {pick.version}: {text} ({why})")
            if new != name:
                src, dst = project / "@Data" / name, project / "@Data" / new
                if src.is_dir():
                    if dst.exists():
                        self.conflicts.append(f"{project}: {dst} exists; move {src} by hand first")
                    else:
                        self.data.append((src, dst))
                        self.lines_.append(f"{project}: rename {src} -> {dst}")

    def __bool__(self):
        return bool(self.entries)

    def apply(self):
        from . import fetch
        f = self.project / ".aios" / "config.yaml"
        for name, (new, text) in self.entries.items():
            if new != name:
                config.drop_skill(f, name, "packages")
            config.set_skill(f, new, text, "packages")
        for src, dst in self.data:
            src.rename(dst)
        mode, ui.MODE = ui.MODE, "yes"              # confirmed with the plan of the activation
        try:
            fetch.sync(str(self.project))
        finally:
            ui.MODE = mode


def plan04(path, plan_, kernel):
    """Add the changeover from v0.4 of all projects at and below path to the plan of
    aios --activate v0.5.<n>; packages without a fitting version abort before anything happens."""
    from . import fetch
    cfg = config.load(path)
    hubs = hub.hub_list(cfg)
    source = hub.GitSource(hubs)
    changes, conflicts = [], []
    for p, _ in integrity.projects(Path(path)):
        if not fetch.wanted(p):
            continue
        c = Change04(p, source, [h.name for h in hubs], kernel)
        conflicts += c.conflicts
        if c:
            changes.append(c)
    if conflicts:
        raise Abort("the changeover to AIOS " + kernel + " is not possible:\n   "
                    + "\n   ".join(conflicts) + "\n   nothing is changed")
    for c in changes:
        plan_.add("changeover from v0.4:\n         " + "\n         ".join(c.lines_), c.apply)
    return changes
