"""Resolver of the packages of a project (spec 06, Resolver; V0.4, memos 15 F5, 17, 21, 26).

From the wanted packages of one project (packages: of its own config.yaml) the resolver picks,
per package, the highest version that fulfils all ranges, takes the depends of the picked
versions as new ranges and repeats until nothing changes. There is no backtracking: if no
version fulfils all ranges, it stops with a list of the conflicts.

Where a package comes from is a hub. A package without hub is looked up in the hub list; a
dependency first in the hub of the package that requires it, then in the hub list. Versions
and manifests come from a source with two methods (the hub access of step 3, or a source in
memory for the tests):

    versions(name, hub) -> list of version strings, empty if the hub has no such package
    manifest(name, hub, version) -> package.Manifest
"""

from __future__ import annotations

from dataclasses import dataclass, field

from . import semver

FROM = "from:"                                      # hub key of a package from a repo (--from)


class ResolveError(Exception):
    """The packages cannot be resolved; the message lists the reasons."""


class NotFound(ResolveError):
    def __init__(self, name, hubs):
        self.name, self.hubs = name, list(hubs)
        super().__init__(f"package {name} not found in the hubs " + ", ".join(self.hubs))


class Ambiguous(ResolveError):
    """A name in several hubs of the hub list (exit 3; the skill asks which one)."""

    def __init__(self, name, hubs):
        self.name, self.hubs = name, list(hubs)
        super().__init__(f"package {name} is in several hubs: " + ", ".join(self.hubs)
                         + f"; choose one with --hub <hub> or <hub>/{name}")


class Conflict(ResolveError):
    def __init__(self, conflicts):
        self.conflicts = conflicts                  # list of (name, [(range, origin)], reason)
        lines = []
        for name, ranges, reason in conflicts:
            lines.append(f"- {name}: {reason}; " + "; ".join(f"{r} ({o})" for r, o in ranges))
        super().__init__("no versions fulfil all ranges:\n" + "\n".join(lines))


@dataclass
class Request:
    """A wanted package from packages: (spec 06, Konfiguration und Lock)."""
    range: semver.Range = field(default_factory=lambda: semver.Range.parse("*"))
    hub: str | None = None
    repo: str | None = None                          # --from <repo>


@dataclass
class Pick:
    name: str
    version: semver.Version
    hub: str
    manifest: object
    requested: str | None = None                     # range from packages:
    required_by: list = field(default_factory=list)

    @property
    def repo(self):
        return self.hub[len(FROM):] if self.hub.startswith(FROM) else None


class Resolver:
    def __init__(self, source, hubs, kernel, locked=None, upgrade=()):
        """hubs: names of the hub list in search order; kernel: AIOS version of the target
        project; locked: name -> (version, hub) from lock.yaml; upgrade: names to choose anew,
        or True for all."""
        self.source, self.hubs = source, list(hubs)
        self.kernel = semver.Version.parse(kernel) if isinstance(kernel, str) else kernel
        self.locked = {n: (semver.Version.parse(v) if isinstance(v, str) else v, h)
                       for n, (v, h) in (locked or {}).items()}
        self.upgrade = upgrade
        self.cache = {}

    # -- lookup --------------------------------------------------------------

    def versions(self, name, hub):
        key = (name, hub)
        if key not in self.cache:
            out = []
            for v in self.source.versions(name, hub) or []:
                try:
                    out.append(semver.Version.parse(v))
                except semver.VersionError:
                    continue                         # tags of another form are passed over
            self.cache[key] = out
        return self.cache[key]

    def locate(self, name, hub=None, prefer=None):
        """Hub of a package: the named hub; else the preferred hub (the hub of the package that
        requires it) if it has the package; else the one hub of the hub list that has it."""
        if hub:
            if not self.versions(name, hub):
                raise NotFound(name, [hub[len(FROM):] if hub.startswith(FROM) else hub])
            return hub
        if name in self.locked and not self.upgrading(name):
            return self.locked[name][1]
        if prefer and not prefer.startswith(FROM) and self.versions(name, prefer):
            return prefer
        found = [h for h in self.hubs if self.versions(name, h)]
        if not found:
            raise NotFound(name, ([prefer] if prefer and not prefer.startswith(FROM) else []) + self.hubs)
        if len(found) > 1:
            raise Ambiguous(name, found)
        return found[0]

    def upgrading(self, name):
        return self.upgrade is True or name in self.upgrade

    # -- choice --------------------------------------------------------------

    def choose(self, name, hub, ranges):
        """(version, manifest) or (None, reason): the locked version while it fulfils all ranges
        (no silent update), else the highest version that fulfils them and requires.aios."""
        rs = [r for r, _ in ranges]
        if name in self.locked and not self.upgrading(name):
            v, lhub = self.locked[name]
            if lhub == hub and v in self.versions(name, hub) and all(r.contains(v) for r in rs):
                m = self.source.manifest(name, hub, str(v))
                if semver.kernel_fits(m.requires, self.kernel):
                    return v, m
        fitting = sorted((v for v in self.versions(name, hub) if all(r.contains(v) for r in rs)),
                         reverse=True)
        if not fitting:
            return None, "no version fulfils the ranges"
        for v in fitting:
            m = self.source.manifest(name, hub, str(v))
            if semver.kernel_fits(m.requires, self.kernel):
                return v, m
        return None, f"no fitting version runs with AIOS {self.kernel.release()} (requires.aios)"

    def resolve(self, requests):
        """name -> Pick for the requests (name -> Request) and all their dependencies."""
        hubs = {}
        for name, req in requests.items():
            hubs[name] = self.locate(name, FROM + req.repo if req.repo else req.hub)
        chosen = {}
        for _ in range(100):
            ranges = {n: [(r.range, "packages:")] for n, r in requests.items()}
            required_by = {}
            for n in sorted(chosen):
                v, m = chosen[n]
                for dep, rng in m.depends.items():
                    if dep not in hubs:
                        hubs[dep] = self.locate(dep, prefer=hubs[n])
                    ranges.setdefault(dep, []).append((rng, f"{n} {v}"))
                    required_by.setdefault(dep, []).append(n)
            conflicts, new = [], {}
            for n in sorted(ranges):
                v, m = self.choose(n, hubs[n], ranges[n])
                if v is None:
                    conflicts.append((n, ranges[n], m))
                else:
                    new[n] = (v, m)
            if conflicts:
                raise Conflict(conflicts)
            if {n: v for n, (v, _) in new.items()} == {n: v for n, (v, _) in chosen.items()}:
                return {n: Pick(n, v, hubs[n], m,
                                str(requests[n].range) if n in requests else None,
                                sorted(set(required_by.get(n, []))))
                        for n, (v, m) in sorted(new.items())}
            chosen = new
        raise ResolveError("the ranges do not settle (cycle of changing choices)")


class MemorySource:
    """A source in memory for the tests: {(hub, name): {version: Manifest}}."""

    def __init__(self, packages):
        self.packages = packages

    def versions(self, name, hub):
        return list(self.packages.get((hub, name), {}))

    def manifest(self, name, hub, version):
        return self.packages[(hub, name)][version]
