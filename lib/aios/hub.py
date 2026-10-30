"""Hubs and the hub list (spec 06, Hubs; V0.4, memos 21, 22, 25, 26).

A hub is a name and a base URL; a package <paket> lies there as the repo <base>/<paket>, its
versions are the tags v<SemVer>. The hub list (hubs: of the vault root, then of home; for
tests AIOS_HUBS) is searched for package names without hub. This module also is the source of
the resolver: versions from git ls-remote, manifests from the cache ~/.aios/packages/.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from . import config, package, paths, semver, ui
from .resolver import FROM
from .ui import Abort, Plan, say

DEFAULT = "aibex-aios"
GITHUB = "https://github.com/"
TAG = re.compile(r"refs/tags/v([^\s^]+)$")
TOPIC = "aios-package"


@dataclass
class Hub:
    name: str
    url: str
    origin: str                                     # vault, home, AIOS_HUBS, default, named


def github(name):
    """Base URL of a hub that is not in the hub list: the GitHub owner <name> (spec 06);
    AIOS_GITHUB redirects it for tests (spec 04)."""
    return os.environ.get("AIOS_GITHUB", GITHUB).rstrip("/") + "/" + name


def entries(raw):
    """(name, url) of a hubs: value: a list of names or name: url, or a mapping."""
    out = []
    items = raw.items() if isinstance(raw, dict) else [
        next(iter(x.items())) if isinstance(x, dict) else (x, None) for x in raw]
    for name, url in items:
        name = str(name).strip()
        if name:
            out.append((name, str(url).strip() if url else github(name)))
    return out


def hub_list(cfg=None):
    """The hub list in search order: AIOS_HUBS, else hubs: of the vault root before home (the
    vault root wins for the same name), else [aibex-aios] (spec 06, Hub-Liste)."""
    env = os.environ.get("AIOS_HUBS")
    if env is not None and env.strip():
        hubs = []
        for item in env.split():
            name, _, url = item.partition("=")
            hubs.append(Hub(name, url or github(name), "AIOS_HUBS"))
        return hubs
    cfg = cfg or config.load(paths.cwd())
    hubs, seen = [], set()
    for level in ("vault", "home"):
        for file, lvl, raw in cfg.hub_entries:
            if lvl != level:
                continue
            for name, url in entries(raw):
                if name not in seen:
                    seen.add(name)
                    hubs.append(Hub(name, url, level))
    return hubs or [Hub(DEFAULT, github(DEFAULT), "default")]


def covered(cfg=None):
    """Hub names of home that are covered by a hub of the same name of the vault root."""
    cfg = cfg or config.load(paths.cwd())
    vault = {n for f, lvl, raw in cfg.hub_entries if lvl == "vault" for n, _ in entries(raw)}
    return sorted(n for f, lvl, raw in cfg.hub_entries if lvl == "home" for n, _ in entries(raw)
                  if n in vault)


def git(*args, cwd=None):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)


# ---------------------------------------------------------------------------
# source of the resolver: versions and manifests
# ---------------------------------------------------------------------------

class GitSource:
    """Versions from the tags of <base>/<name>, manifests from the cache (spec 06, Holen)."""

    def __init__(self, hubs):
        self.urls = {h.name: h.url for h in hubs}
        self.tags = {}

    def repo(self, name, hub):
        if hub.startswith(FROM):
            return hub[len(FROM):]
        base = self.urls.get(hub) or github(hub)
        return base.rstrip("/") + "/" + name

    def versions(self, name, hub):
        repo = self.repo(name, hub)
        if repo not in self.tags:
            r = git("ls-remote", "--tags", repo)
            self.tags[repo] = [] if r.returncode else [
                m.group(1) for line in r.stdout.splitlines() for m in [TAG.search(line)] if m]
        return self.tags[repo]

    def folder(self, name, hub, version):
        """Cache of a version; with --from per source (V0.6, memo 03, K1; memo 50)."""
        if hub.startswith(FROM):
            key = Path("_from") / hashlib.sha256(hub[len(FROM):].encode()).hexdigest()[:12]
        else:
            key = Path(hub)
        return paths.user_dir() / "packages" / key / name / version

    def tag_commit(self, name, hub, version):
        """Commit of the tag v<version> in the source (peeled), or None."""
        r = git("ls-remote", self.repo(name, hub), f"refs/tags/v{version}", f"refs/tags/v{version}^{{}}")
        found = dict(reversed(line.split("\t")) for line in r.stdout.splitlines() if "\t" in line)
        return found.get(f"refs/tags/v{version}^{{}}") or found.get(f"refs/tags/v{version}")

    def fetch(self, name, hub, version):
        """The version in the cache (git clone --depth 1 --branch v<version>); its folder. With
        --from the cache is fetched anew when the tag in the source points elsewhere (K1)."""
        d = self.folder(name, hub, version)
        if (d / ".git").is_dir():
            if not hub.startswith(FROM):
                return d
            head = git("rev-parse", "HEAD", cwd=d).stdout.strip()
            if head and head == self.tag_commit(name, hub, version):
                return d
            shutil.rmtree(d, ignore_errors=True)
        d.parent.mkdir(parents=True, exist_ok=True)
        tmp = d.parent / (version + ".tmp")
        shutil.rmtree(tmp, ignore_errors=True)
        r = git("clone", "-q", "--depth", "1", "--branch", f"v{version}", self.repo(name, hub), str(tmp))
        if r.returncode:
            shutil.rmtree(tmp, ignore_errors=True)
            raise Abort(f"cannot fetch {name} {version} from {self.repo(name, hub)}: {r.stderr.strip()}")
        tmp.rename(d)
        return d

    def commit(self, name, hub, version):
        return git("rev-parse", "HEAD", cwd=self.fetch(name, hub, version)).stdout.strip()

    def manifest(self, name, hub, version):
        d = self.fetch(name, hub, version)
        try:
            m = package.load(d)
        except package.ManifestError as e:
            raise Abort(str(e))
        if m.name != name:
            raise Abort(f"{self.repo(name, hub)} v{version}: manifest.yaml names {m.name}, not {name}")
        if str(m.version) != version:
            raise Abort(f"{self.repo(name, hub)}: tag v{version} has version {m.version} in manifest.yaml")
        return m


# ---------------------------------------------------------------------------
# index and search (aios --library)
# ---------------------------------------------------------------------------

def index(h):
    """Packages of a hub as [(name, type, description)], or None if the hub cannot be searched:
    aios-index/index.yaml of the hub, else on GitHub the repos with the topic aios-package."""
    d = paths.user_dir() / "hub" / h.name
    url = h.url.rstrip("/") + "/aios-index"
    if (d / ".git").is_dir():
        git("pull", "-q", "--ff-only", cwd=d)
    elif git("ls-remote", url).returncode == 0:
        d.parent.mkdir(parents=True, exist_ok=True)
        git("clone", "-q", "--depth", "1", url, str(d))
    if (d / "index.yaml").is_file():
        import yaml
        data = yaml.safe_load((d / "index.yaml").read_text(encoding="utf-8")) or {}
        return [(str(p.get("name")), str(p.get("type") or ""), str(p.get("description") or ""))
                for p in data.get("packages") or [] if p.get("name")]
    if h.url.startswith(GITHUB) and shutil.which("gh"):
        owner = h.url[len(GITHUB):].strip("/")
        r = subprocess.run(["gh", "repo", "list", owner, "--topic", TOPIC, "--limit", "500",
                            "--json", "name,description"], capture_output=True, text=True)
        if r.returncode == 0:
            return [(x["name"], "", x.get("description") or "") for x in json.loads(r.stdout or "[]")]
    return None


def library(arg=None):
    """aios --library [<suchwort> | <paket>]: packages of the hub list, or versions of a package."""
    hubs = hub_list()
    if arg and "/" in arg:                          # <hub>/<paket>: only this hub, also outside the list
        name, _, arg = arg.partition("/")
        hubs = [h for h in hubs if h.name == name] or [Hub(name, github(name), "named")]
    if arg:
        src = GitSource(hubs)
        found = [(h, src.versions(arg, h.name)) for h in hubs]
        found = [(h, v) for h, v in found if v]
        if found:
            for h, vs in found:
                ordered = sorted(semver.Version.parse(v) for v in vs if valid(v))
                say(f"{h.name}/{arg}  " + " ".join(str(v) for v in ordered))
            return 0
    rows, unsearchable = [], []
    for h in hubs:
        packages = index(h)
        if packages is None:
            unsearchable.append(h.name)
            continue
        for name, kind, text in packages:
            if not arg or arg.lower() in name.lower() or arg.lower() in text.lower():
                rows.append((f"{h.name}/{name}", kind, text))
    if rows:
        w = max(len(r[0]) for r in rows) + 2
        for name, kind, text in sorted(rows):
            say(f"{name:<{w}}{kind:<14}{text}".rstrip())
    elif arg:
        say(f"no package matches {arg}")
    else:
        say("no packages")
    for name in unsearchable:
        say(f"(hub {name} cannot be searched: no aios-index, no topic {TOPIC}; fetch by name)")
    return 0


def valid(v):
    try:
        semver.Version.parse(v)
        return True
    except semver.VersionError:
        return False


# ---------------------------------------------------------------------------
# aios --hubs: show and change the hub list
# ---------------------------------------------------------------------------

def target(vault):
    """config.yaml for aios --hubs: of the vault root with --vault, else of home."""
    if not vault:
        return paths.user_dir() / "config.yaml"
    cfg = config.load(paths.cwd())
    if cfg.vault is None:
        raise Abort(f"{paths.cwd()} is not in a vault")
    return cfg.vault / ".aios" / "config.yaml"     # also before the binding (distribution, V0.5, memo 64)


def hubs_block(lines):
    """(index of 'hubs:', end of its block) or (None, None)."""
    for i, line in enumerate(lines):
        if line.startswith("hubs:"):
            if config.strip_comment(line)[5:].strip():
                raise Abort("hubs: must be a block of '- name' or '- name: url' lines")
            j = i + 1
            while j < len(lines) and (not lines[j].strip() or lines[j][0].isspace()):
                j += 1
            while j > i + 1 and not lines[j - 1].strip():
                j -= 1
            return i, j
    return None, None


def item_name(line):
    item = config.strip_comment(line).strip()
    if not item.startswith("-"):
        return None
    return item[1:].strip().split(":", 1)[0].strip() or None


def write(file, name, url, remove=False):
    lines = file.read_text(encoding="utf-8").splitlines() if file.is_file() else []
    start, end = hubs_block(lines)
    entry = f"  - {name}" + (f": {url}" if url and url != github(name) else "")
    if start is None:
        lines += ["hubs:", entry]
    else:
        block = [x for x in lines[start + 1:end] if item_name(x) != name]
        if not remove:
            block.append(entry)
        lines = lines[:start] + (["hubs:"] + block if block else []) + lines[end:]
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text("\n".join(lines) + "\n", encoding="utf-8")


def command(args):
    """aios --hubs [add <name> [<url>] | remove <name>] [--vault]."""
    vault = "--vault" in args
    args = [a for a in args if a != "--vault"]
    if not args:
        cfg = config.load(paths.cwd())
        hidden = covered(cfg)
        for h in hub_list(cfg):
            say(f"{h.name:<20}{h.url}  ({h.origin})")
        for name in hidden:
            say(f"(home: {name} covered by the vault root)")
        return 0
    if args[0] not in ("add", "remove") or len(args) not in (2, 3) or (args[0] == "remove" and len(args) != 2):
        raise Abort("usage: aios --hubs [add <name> [<url>] | remove <name>] [--vault]")
    name = args[1]
    if not re.match(r"^[A-Za-z0-9][A-Za-z0-9._-]*$", name):
        raise Abort(f"{name} is not a hub name")
    url = args[2] if len(args) == 3 else github(name)
    file = target(vault)
    raw = config.read(file).get("hubs") if file.is_file() else None
    have = dict(entries(raw)) if raw else {}
    if args[0] == "add" and have.get(name) == url:
        say(f"=> hub {name} is in the hub list of {file}, nothing to do")
        return 0
    if args[0] == "remove" and name not in have:
        say(f"=> hub {name} is not in the hub list of {file}, nothing to do")
        return 0
    plan = Plan()
    first = args[0] == "add" and name != DEFAULT and not os.environ.get("AIOS_HUBS", "").strip() \
        and not config.load(paths.cwd()).hub_entries
    if first:                                       # the first list keeps the default hub (memo 60, D1)
        plan.add(f"{file}: hubs: {DEFAULT} {github(DEFAULT)} (the default, kept in the new list)",
                 lambda: write(file, DEFAULT, github(DEFAULT)))
    if args[0] == "add":
        plan.add(f"{file}: hubs: {name} {url}", lambda: write(file, name, url))
    else:
        plan.add(f"{file}: remove {name} from hubs:", lambda: write(file, name, None, remove=True))
    if ui.MODE != "yes":
        say(f"=> {args[0]} hub {name}")
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> hub list: " + ", ".join(h.name for h in hub_list()))
    return 0
