"""aios --install distribution-<name>: install a distribution (spec 06, Distributionen; spec 04).

One plan, one confirmation: first the machine (the kernel of kernel: from the clone of aibex-aios
like aios --install v<version>, the workhorses), then the vault (binding with changeover, fetching
into the vault root with backup, registering). A failing machine part leaves the vault untouched;
what is installed stays. Without a version the same command upgrades to the highest one.

From a clone without PyYAML (fresh machine) the kernel comes first with its own plan (standard
library only), then the installed bin/aios takes over with the same arguments and shows the plan
of the distribution (V0.5, memos 71, 73: B7).
"""

from __future__ import annotations

import os
import re
import shutil
import sys
from pathlib import Path

from . import activate, backup, config, fetch, hub, install, package, paths, resolver, semver, ui
from .ui import Abort, Plan, say

PREFIX = "distribution-"
KERNEL = re.compile(r"""^kernel:\s*["']?==\s*(\d+\.\d+\.\d+)["']?\s*(?:#.*)?$""", re.M)


def is_spec(arg):
    """Does the argument of aios --install name a distribution (not a version)?"""
    try:
        _, name, _ = fetch.parse_spec(arg)
    except Abort:
        return False
    return name.startswith(PREFIX)


def vault_root(vault):
    p = Path(os.path.abspath(vault or paths.cwd()))
    root = config.vault_root(p)
    if root is None:
        raise Abort(f"{p} is not in a vault")
    if vault and p != root:
        raise Abort(f"{p} is not the root of its vault {root}; a distribution goes into the vault root")
    return root


def choose(f, name, rng, hub_name, repo):
    """(version, manifest, hub key) of the distribution: the highest released version in rng."""
    r = resolver.Resolver(f.source, [h.name for h in f.hubs], f.kernel or "0.0.0")
    key = r.locate(name, resolver.FROM + repo if repo else hub_name)
    versions = [v for v in r.versions(name, key) if (rng.contains(v) if rng else not v.pre)]
    if not versions:
        raise Abort(f"{name} has no version" + (f" in {rng}" if rng else ""))
    version = max(versions)
    m = package.load(f.source.fetch(name, key, str(version)))
    if m.type != "distribution":
        raise Abort(f"{name} {version} is a package of type {m.type}, not a distribution")
    return version, m, key


def kernel_of(manifest):
    """X.Y.Z of kernel: "==X.Y.Z", or None (a distribution without kernel)."""
    if not manifest.kernel:
        return None
    return str(getattr(manifest.kernel, "text", manifest.kernel)).lstrip("=").strip()


def other_with_kernel(f, name):
    """Another distribution with kernel: in packages: of the vault root (one per vault, spec 06)."""
    for other in f.packages:
        if other == name or not other.startswith(PREFIX):
            continue
        d = fetch.package_dir(f.project, other)
        try:
            if (d / "manifest.yaml").is_file() and package.load(d).kernel:
                return other
        except package.ManifestError:
            continue
    return None


def kernel_steps(version, stages):
    """Steps of the machine part for the kernel: nothing if installed, else like aios --install."""
    tag = f"v{version}"
    known = install.installations()
    if tag in known and known[tag][0].is_dir():
        return [(f"AIOS {tag} is already installed in {known[tag][0]}", None)]
    repo = install.find_repo()
    tag = install.choose_version(repo, tag)
    p = Plan()
    missing = install.basic_kit()
    if missing:
        raise Abort("the basic kit is missing (" + "; ".join(install.kit_lines(missing))
                    + "); install it, then run aios --install again")
    root, entries = install.plan_root(p)           # ~/.aios/versions (spec 04; V0.6, F26)
    stage = install.extract(repo, tag)
    stages.append(stage)
    p.add(f"install AIOS {tag} from {repo} -> {root / tag} (read-only)",
          lambda: install.build(stage, tag, root, entries))
    install.plan_user(p, stage, repo if install.clone_of_this() else None)
    return p.steps


def install_distribution(spec, vault=None, hub_name=None, repo=None):
    named, name, rng = fetch.parse_spec(spec)
    if named and hub_name and named != hub_name:
        raise Abort(f"{spec}: the hub {named} and --hub {hub_name} differ")
    hub_name = named or hub_name
    if hub_name and repo:
        raise Abort("--from and a hub exclude each other")
    root = vault_root(vault)
    f = fetch.Fetch(project=root)
    version, m, key = choose(f, name, rng, hub_name, repo)
    kernel = kernel_of(m)
    if kernel is None and not f.kernel:
        raise Abort(f"{name} {version} has no kernel: and {root} is not bound to a version of AIOS; "
                    f"run aios --activate v<version> {root} first")
    if kernel:
        other = other_with_kernel(f, name)
        if other:
            raise Abort(f"{other} in {root} also brings a kernel; one distribution with kernel: per "
                        f"vault (remove it with aios --fetch --remove {other} --to {root})")
        f.kernel = kernel
    entry = {"range": f"=={version}"}
    if hub_name:
        entry["hub"] = hub_name
    if repo:
        entry["from"] = str(Path(repo).resolve()) if Path(repo).exists() else repo
    old = f.packages.get(name)
    if isinstance(old, dict) and old.get("only"):
        entry["only"] = old["only"]
    packages = dict(f.packages)
    packages[name] = entry if len(entry) > 1 else entry["range"]
    stages = []
    try:
        machine = Plan()
        if kernel:
            machine.steps += kernel_steps(kernel, stages)
        try:
            picks = f.resolve(packages, upgrade={name} | set(m.depends))
        except resolver.Conflict as e:
            own = sorted(set(f.packages) & set(m.depends))
            raise Abort(f"{e}\n   a package of a distribution is overridden only with only: (spec 06, "
                        f"Übersteuern)" + (f"; remove {', '.join(own)} from packages: of {root}" if own else ""))
        first = Plan()
        if kernel:
            activate.plan_activation(f"v{kernel}", root, first, installed=False)
        was = (f.lock.get("packages") or {}).get(name, {}).get("version")
        what = (f"upgrade {name} {was} -> {version}" if was and str(was) != str(version)
                else f"install {name} {version}")
        return f.plan(picks, packages, f"=> {what} into {root}" + (f" (kernel {kernel})" if kernel else ""),
                      fetch.hints(root), machine=machine, first=first.steps)
    finally:
        for s in stages:
            shutil.rmtree(s, ignore_errors=True)


# ---------------------------------------------------------------------------
# fresh machine: clone without PyYAML (B7)
# ---------------------------------------------------------------------------

def has_yaml():
    try:
        import yaml  # noqa: F401
    except ImportError:
        return False
    return True


def bootstrap_kernel(spec, root, hub_name, repo):
    """(version, origin) of the kernel to install first, standard library only: kernel: of the
    chosen version of the distribution (read line by line), else the binding of the vault root,
    else the highest release tag of the clone."""
    named, name, rng = fetch.parse_spec(spec)
    hub_name = named or hub_name
    cfg = config.load(root)
    source = hub.GitSource(hub.hub_list(cfg))
    r = resolver.Resolver(source, [h.name for h in hub.hub_list(cfg)], "0.0.0")
    try:
        key = r.locate(name, resolver.FROM + repo if repo else hub_name)
    except resolver.ResolveError as e:
        raise Abort(str(e))
    versions = [v for v in r.versions(name, key) if (rng.contains(v) if rng else not v.pre)]
    if not versions:
        raise Abort(f"{name} has no version" + (f" in {rng}" if rng else ""))
    version = max(versions)
    d = source.fetch(name, key, str(version))
    m = KERNEL.search((d / "manifest.yaml").read_text(encoding="utf-8"))
    if m:
        return m.group(1), f"kernel: of {name} {version}"
    if cfg.aios:
        return str(cfg.aios), f"binding of {root}"
    tag = install.choose_version(install.find_repo(), None)
    return tag[1:], f"highest release tag of {install.find_repo()}"


def bootstrap(args, rest, opts):
    """Kernel first (own plan), then exec the installed bin/aios with the same arguments."""
    if not install.clone_of_this():
        raise Abort(f"PyYAML is missing in {sys.executable}; reinstall AIOS with aios --install")
    root = vault_root(rest[1] if len(rest) > 1 else None)
    kernel, origin = bootstrap_kernel(rest[0], root, opts.get("hub"), opts.get("from"))
    tag = f"v{kernel}"
    stages = []
    try:
        steps = kernel_steps(kernel, stages)
        if steps[0][1] is not None:                 # not installed yet: plan of the kernel
            p = Plan()
            p.steps += steps
            p.add(f"then: aios --install {' '.join(args)} with AIOS {tag} (plan of the distribution)")
            say(f"=> AIbex AIOS {tag} first ({origin}; PyYAML is missing in {sys.executable})")
            ui.confirm(p, "install?", "installation cancelled")
    finally:
        for s in stages:
            shutil.rmtree(s, ignore_errors=True)
    aios = install.installations()[tag][0] / "bin" / "aios"
    flag = {"yes": ["--yes"], "plan": ["--plan"]}.get(ui.MODE, [])
    sys.stdout.flush()
    os.execv(str(aios), [str(aios), "--install", *args, *flag])


def command(args):
    """aios --install distribution-<name>[<range>] [<vault>] [--hub <hub>] [--from <repo>]."""
    opts, rest, i = {}, [], 0
    while i < len(args):
        a = args[i]
        if a in ("--hub", "--from") and i + 1 < len(args):
            opts[a[2:]] = args[i + 1]
            i += 2
            continue
        if a.startswith("--") or len(rest) == 2:
            raise Abort("usage: aios --install distribution-<name>[<range>] [<vault>] [--from <repo>]")
        rest.append(a)
        i += 1
    if not has_yaml():
        return bootstrap(args, rest, opts)
    if backup.exists(vault_root(rest[1] if len(rest) > 1 else None)):
        return fetch.offer_restore(vault_root(rest[1] if len(rest) > 1 else None))
    return install_distribution(rest[0], rest[1] if len(rest) > 1 else None, opts.get("hub"), opts.get("from"))
