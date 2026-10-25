"""aios --fetch: fetch packages into a project (spec 06, Holen; V0.4, memos 23, 24, 37).

A package is fetched whole from its hub: the resolver picks the versions, the versions are
cloned into the cache ~/.aios/packages/ and mirrored without .git to <project>/@/@!Package/
<name>/ with the marker .aios-deploy. packages: of the project's .aios/config.yaml holds the
wanted packages, .aios/lock.yaml the resolved state. AIOS commits nothing of it (I9).
"""

from __future__ import annotations

import os
import re
import shutil
import tempfile
from pathlib import Path

from . import backup, config, deploy, hub, package, paths, resolver, semver, ui
from .deploy import MARKER, digest_of, read_marker
from .install import frontmatter, make_writable
from .ui import Abort, Plan, say, warn

SPEC = re.compile(r"^(?:([A-Za-z0-9][A-Za-z0-9._-]*)/)?([a-z0-9][a-z0-9-]{0,63})(.*)$")
LOCK_HEAD = "# written by AIOS (fetch, workspace), do not edit\n"


# ---------------------------------------------------------------------------
# packages: and lock.yaml of a project
# ---------------------------------------------------------------------------

def config_file(project):
    return project / ".aios" / "config.yaml"


def lock_file(project):
    return project / ".aios" / "lock.yaml"


def wanted(project):
    """packages: of the project's own config.yaml as {name: entry} (not inherited, spec 04)."""
    f = config_file(project)
    try:
        data = config.read(f).get("packages") if f.is_file() else None
    except config.ConfigError as e:
        raise Abort(f"{e}; fix the file first")
    if data is None:
        return {}
    if not isinstance(data, dict):
        raise Abort(f"{f}: packages must map names to ranges")
    return data


def request(entry):
    """Request from a packages: entry: a range or {range, hub, from, only}."""
    try:
        if isinstance(entry, dict):
            return resolver.Request(semver.Range.parse(entry.get("range", "*")), entry.get("hub") or None,
                                    entry.get("from") or None)
        return resolver.Request(semver.Range.parse(entry))
    except semver.VersionError as e:
        raise Abort(str(e))


def entry_text(entry):
    """The value written to packages:, a quoted range or a one-line mapping."""
    if not isinstance(entry, dict):
        return f'"{entry}"'
    parts = []
    for key in ("range", "hub", "from", "only"):
        v = entry.get(key)
        if v in (None, "", []):
            continue
        if key == "only":
            parts.append(f"only: [{', '.join(v)}]")
        elif key == "range":
            parts.append(f'range: "{v}"')
        else:
            parts.append(f"{key}: {v}")
    return "{" + ", ".join(parts) + "}" if len(parts) > 1 or "range" not in entry else f'"{entry["range"]}"'


def direction(old, new):
    """upgrade or downgrade from the version of a marker to the chosen one."""
    try:
        return "downgrade" if semver.Version.parse(str(new)) < semver.Version.parse(str(old)) else "upgrade"
    except semver.VersionError:
        return "upgrade"


def read_lock(project):
    f = lock_file(project)
    if not f.is_file():
        return {}
    import yaml
    try:
        data = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as e:
        raise Abort(f"{f}: {e}")
    return data


def locked(lock):
    """{name: (version, hub key)} of lock.yaml for the resolver."""
    out = {}
    for name, e in (lock.get("packages") or {}).items():
        key = resolver.FROM + e["from"] if e.get("from") else e.get("hub")
        if e.get("version") and key:
            out[name] = (str(e["version"]), key)
    return out


def write_lock(project, lock):
    """lock.yaml in the subset of spec 04, readable by the forwarders without PyYAML (S3)."""
    from . import yamlsub
    f = lock_file(project)
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(yamlsub.dump(lock, LOCK_HEAD.lstrip("# ").rstrip("\n")), encoding="utf-8")


# ---------------------------------------------------------------------------
# mirror into @!Package/
# ---------------------------------------------------------------------------

def package_dir(project, name):
    return project / "@" / "@!Package" / name


def mirror(src, dst, fields):
    """Replace dst by a copy of src without .git (only this folder) and write the marker."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix=f".{dst.name}.", dir=dst.parent))
    try:
        shutil.copytree(src, tmp / dst.name, ignore=shutil.ignore_patterns(".git", MARKER),
                        copy_function=shutil.copyfile)
        make_writable(tmp / dst.name)
        fields = dict(fields, digest=digest_of(tmp / dst.name))
        (tmp / dst.name / MARKER).write_text(
            "# written by aios --fetch, do not edit\n"
            + "".join(f"{k}: {v}\n" for k, v in fields.items()), encoding="utf-8")
        if dst.exists():
            make_writable(dst)
            shutil.rmtree(dst)
        os.rename(tmp / dst.name, dst)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def state(dst):
    """(marker, directly changed) of an existing package folder; (None, False) if missing."""
    if not dst.is_dir():
        return None, False
    mark = read_marker(dst)
    return mark, bool(mark) and digest_of(dst) != mark.get("digest")


# ---------------------------------------------------------------------------
# checks of the picked packages
# ---------------------------------------------------------------------------

def check(picks, source):
    """Abort for packages that cannot be fetched in v0.4 (yet); warnings for hooks."""
    seen = {}
    for p in picks.values():
        m = p.manifest
        for w in m.warnings:
            warn(w)
        if m.contents.get("hooks"):
            warn(f"{p.name} {p.version}: hooks {', '.join(m.contents['hooks'])} have no effect in v0.5, "
                 "the package is fetched without them")
        problems = package.check_tree(source.fetch(p.name, p.hub, str(p.version)), m)
        if problems:
            raise Abort(f"{p.name} {p.version} cannot be fetched: " + "; ".join(problems))
        for e in m.elements():
            if e != "knowledge" and e in seen:
                raise Abort(f"the packages {seen[e]} and {p.name} both bring an element {e}")
            seen[e] = p.name


# ---------------------------------------------------------------------------
# the command
# ---------------------------------------------------------------------------

class Fetch:
    def __init__(self, to=None):
        self.project = deploy.target_project(to)
        self.cfg = config.load(self.project)
        self.hubs = hub.hub_list(self.cfg)
        self.source = hub.GitSource(self.hubs)
        self.packages = wanted(self.project)
        from . import migrate
        self.legacy = {n: r for n, r in migrate.legacy(self.project).items() if n not in self.packages}
        self.lock = read_lock(self.project)
        self.kernel = self.cfg.aios

    def resolve(self, packages, upgrade=()):
        """Picks for packages: and the not yet changed over skills:/assistants: of v0.3."""
        while True:
            requests = {n: request(e) for n, e in {**self.legacy, **packages}.items()}
            r = resolver.Resolver(self.source, [h.name for h in self.hubs], self.kernel,
                                  locked(self.lock), upgrade)
            try:
                return r.resolve(requests)
            except resolver.NotFound as e:            # an entry of v0.3 without package: pass over
                if e.name not in self.legacy or e.name in packages:
                    raise
                warn(f"{e}; the entry of v0.3 is passed over")
                del self.legacy[e.name]

    def from_lock(self, packages):
        """Picks from lock.yaml without the network: all versions in the cache and every range of
        packages: still fulfilled; None otherwise (spec 06, ohne Netz)."""
        entries = self.lock.get("packages") or {}
        if not entries or set(packages) - set(entries):
            return None
        picks = {}
        for name, e in entries.items():
            key = resolver.FROM + e["from"] if e.get("from") else e.get("hub")
            d = self.source.folder(name, key, str(e.get("version")))
            if not (d / ".git").is_dir():
                return None
            try:
                m = package.load(d)
            except package.ManifestError:
                return None
            if name in packages and not request(packages[name]).range.contains(m.version):
                return None
            picks[name] = resolver.Pick(name, m.version, key, m, e.get("requested"),
                                        list(e.get("required_by") or []))
        needed = {d for p in picks.values() for d in p.manifest.depends} | set(packages)
        return picks if needed == set(picks) else None

    def plan(self, picks, packages, title, done):
        """Show the plan for the new state and execute it after one confirmation."""
        check(picks, self.source)
        plan = Plan()
        moved = []                                  # package folders the plan replaces or removes
        old = self.lock.get("packages") or {}
        lines = []
        for name, p in picks.items():
            dst = package_dir(self.project, name)
            mark, changed = state(dst)
            was = old.get(name, {}).get("version")
            where = p.repo or p.hub
            if mark is None and dst.is_dir():
                raise Abort(f"{dst} exists and has no {MARKER}; move it away first")
            if mark and mark.get("version") == str(p.version) and not changed:
                lines.append(f"unchanged  {name} {p.version} ({where})")
                continue
            why = ("new" if mark is None and was is None else "missing" if mark is None else
                   f"{direction(mark.get('version'), p.version)} {mark.get('version')} -> {p.version}"
                   if mark.get("version") != str(p.version)
                   else "changed directly, restored")
            src = self.source.fetch(name, p.hub, str(p.version))
            fields = {"name": name, "version": p.version, "hub": "-" if p.repo else p.hub,
                      "repo": p.repo or self.source.repo(name, p.hub),
                      "commit": self.source.commit(name, p.hub, str(p.version))}
            plan.add(f"{why:<10} {name} {p.version} ({where}) -> {dst}",
                     lambda src=src, dst=dst, fields=fields: mirror(src, dst, fields))
            moved.append(dst)
        base = package_dir(self.project, "")
        for d in sorted(base.iterdir()) if base.is_dir() else []:
            if d.name not in picks and (d / MARKER).is_file():
                plan.add(f"remove     {d.name} -> {d}", lambda d=d: d.exists() and (make_writable(d), shutil.rmtree(d)))
                moved.append(d)
        if packages != self.packages:
            file = config_file(self.project)
            for name in sorted(set(self.packages) - set(packages)):
                plan.add(f"{file}: packages: remove {name}", lambda n=name: config.drop_skill(file, n, "packages"))
            for name in sorted(packages):
                if packages[name] != self.packages.get(name):
                    text = entry_text(packages[name])
                    plan.add(f"{file}: packages: {name}: {text}",
                             lambda n=name, t=text: config.set_skill(file, n, t, "packages"))
        lock = {"schema": 1, "packages": {}}
        for name, p in picks.items():
            e = {"version": str(p.version)}
            if p.repo:
                e["from"] = p.repo
            else:
                e["hub"] = p.hub
                e["repo"] = self.source.repo(name, p.hub)
            e["tag"] = f"v{p.version}"
            e["commit"] = self.source.commit(name, p.hub, str(p.version))
            if name in packages:
                e["requested"] = str(request(packages[name]).range)
            if p.required_by:
                e["required_by"] = p.required_by
            lock["packages"][name] = e
        if self.lock.get("workspace"):
            lock["workspace"] = self.lock["workspace"]
        if lock != self.lock:
            plan.add(f"{lock_file(self.project)}: {len(picks)} packages",
                     lambda: write_lock(self.project, lock))
        if not plan:
            say(f"=> the packages of {self.project} match lock.yaml, nothing to do")
            for line in lines:
                say(f"   {line}")
            return 0
        deploy.register_session(plan)
        session = Path(paths.cwd())
        bk = backup.Backup(self.project)
        copied = [config_file(self.project), lock_file(self.project),
                  session / ".aios" / "registry", session / ".claude" / "skills"]
        plan.steps.insert(0, (f"back up what the plan changes -> {backup.folder(self.project)}",
                              lambda: bk.start(copied, moved)))
        plan.add("remove the backup", bk.finish)
        if ui.MODE != "yes":
            say(title)
            for line in lines:
                say(f"   {line}")
        try:
            ui.confirm(plan, "go on?", "cancelled")
        except (ui.PlanOnly, SystemExit):
            raise
        except BaseException as e:                  # noqa: BLE001 - all or nothing (spec 01, I11)
            if not bk.started:
                raise
            backup.restore(self.project)
            raise Abort(f"the plan failed ({type(e).__name__}: {e}); "
                        f"the state before the plan is restored")
        for line in done(picks):
            say(line)
        return 0


def hints(project):
    """A5 and the surface of apps: how to use what was fetched."""
    def run(picks):
        out = [f"=> packages of {project}: " + ", ".join(f"{p.name} {p.version}" for p in picks.values())]
        for p in picks.values():
            d = package_dir(project, p.name)
            for a in p.manifest.contents.get("assistants") or []:
                title = frontmatter(d / "assistants" / a / "ASSISTANT.md").get("title", a)
                out.append(f"   assign the assistant to a project of the chain with /aios-assistant {title}")
            if p.manifest.contents.get("gui"):
                out.append(f"   open the app {p.name} with /{p.manifest.contents['gui']} or the tile Apps of /aios-gui")
        out.append("   new skills are available from the next chat (or after /reload-skills)")
        return out
    return run


def parse_spec(spec):
    m = SPEC.match(spec)
    if not m:
        raise Abort(f"{spec}: expected [<hub>/]<package>[<range>], e.g. taschenrechner~=0.1.0")
    hub_name, name, rng = m.group(1), m.group(2), m.group(3).strip()
    if rng and not rng[0] in "=!<>~*":
        raise Abort(f"{spec}: expected [<hub>/]<package>[<range>], e.g. taschenrechner~=0.1.0")
    try:
        r = semver.Range.parse(rng) if rng else None
    except semver.VersionError as e:
        raise Abort(str(e))
    return hub_name, name, r


def add(spec, hub_name=None, repo=None, to=None):
    """aios --fetch [<hub>/]<package>[<range>] [--hub <hub>] [--from <repo>] [--to <project>]."""
    named, name, rng = parse_spec(spec)
    if named and hub_name and named != hub_name:
        raise Abort(f"{spec}: the hub {named} and --hub {hub_name} differ")
    hub_name = named or hub_name
    if hub_name and repo:
        raise Abort("--from and a hub exclude each other")
    f = Fetch(to)
    packages = dict(f.packages)
    entry = packages.get(name)
    if rng is None and entry is not None and not hub_name and not repo:
        rng_text = None                                 # keep the entry of packages:
    else:
        if rng is None:
            key = resolver.FROM + repo if repo else hub_name
            r = resolver.Resolver(f.source, [h.name for h in f.hubs], f.kernel)
            key = r.locate(name, key)
            releases = [v for v in r.versions(name, key) if not v.pre]
            if not releases:
                raise Abort(f"{name} has no released version")
            rng = semver.default_range(max(releases))
        rng_text = str(rng)
        new = {"range": rng_text}
        if hub_name:
            new["hub"] = hub_name
        if repo:
            new["from"] = str(Path(repo).resolve()) if Path(repo).exists() else repo
        if isinstance(entry, dict) and entry.get("only"):
            new["only"] = entry["only"]
        packages[name] = new if len(new) > 1 else rng_text
    picks = f.resolve(packages, upgrade={name} if rng_text else ())
    return f.plan(picks, packages, f"=> fetch {name} into {f.project}", hints(f.project))


def sync(to=None):
    """aios --fetch without a package: the project follows lock.yaml (spec 06, Abgleich)."""
    f = Fetch(to)
    picks = f.from_lock({**f.legacy, **f.packages})
    if picks is None:
        picks = f.resolve(f.packages)
    return f.plan(picks, f.packages, f"=> reconcile the packages of {f.project} with lock.yaml",
                  lambda picks: [f"=> the packages of {f.project} match lock.yaml"])


def upgrade(name=None, to=None):
    f = Fetch(to)
    if name and name not in f.packages:
        raise Abort(f"{name} is not in packages: of {config_file(f.project)}")
    picks = f.resolve(f.packages, upgrade={name} if name else True)
    return f.plan(picks, f.packages, f"=> upgrade {name or 'the packages'} of {f.project}", hints(f.project))


def remove(name, to=None):
    f = Fetch(to)
    if name not in f.packages:
        raise Abort(f"{name} is not in packages: of {config_file(f.project)}")
    packages = {n: e for n, e in f.packages.items() if n != name}
    picks = f.resolve(packages)
    if name in picks:
        raise Abort(f"{name} is still required by " + ", ".join(picks[name].required_by))
    return f.plan(picks, packages, f"=> remove {name} from {f.project}",
                  lambda picks: [f"=> {name} removed; @Data/ stays untouched"])


def offer_restore(to=None):
    """A backup left by a broken plan: the next aios --fetch only offers to restore it (spec 06)."""
    project = deploy.target_project(to)
    if not backup.exists(project):
        return None
    plan = Plan()
    plan.add(f"restore from the backup of {backup.created(project)} in {backup.folder(project)}",
             lambda: backup.restore(project))
    say(f"=> a plan in {project} did not finish; restore the state before it")
    ui.confirm(plan, "restore?", "cancelled; the backup stays")
    say(f"=> {project} restored; run aios --fetch again")
    return 0


def command(args):
    """Parse aios --fetch [spec] [--hub h] [--from repo] [--to p] | --upgrade [name] | --remove name."""
    opts, rest, i = {}, [], 0
    while i < len(args):
        a = args[i]
        if a in ("--hub", "--from", "--to", "--remove") and i + 1 < len(args):
            opts[a[2:]] = args[i + 1]
            i += 2
            continue
        if a == "--upgrade":
            opts["upgrade"] = True
        elif a.startswith("--") or len(rest) == 1:
            raise Abort(f"unexpected argument {a}")
        else:
            rest.append(a)
        i += 1
    to = opts.get("to")
    if offer_restore(to) is not None:
        return 0
    if "remove" in opts:
        if rest or opts.get("upgrade") or "hub" in opts or "from" in opts:
            raise Abort("usage: aios --fetch --remove <package> [--to <project>]")
        return remove(opts["remove"], to)
    if opts.get("upgrade"):
        if "hub" in opts or "from" in opts:
            raise Abort("usage: aios --fetch --upgrade [<package>] [--to <project>]")
        return upgrade(rest[0] if rest else None, to)
    if rest:
        return add(rest[0], opts.get("hub"), opts.get("from"), to)
    if "hub" in opts or "from" in opts:
        raise Abort("--hub and --from need a package")
    return sync(to)
