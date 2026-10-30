"""aios --activate, --deactivate, --config (spec 04)."""

from __future__ import annotations

import os
from pathlib import Path

from . import aiosinit, config, install, migrate, paths, semver
from .ui import Abort, Plan, confirm, extra, say


def target(path):
    p = Path(os.path.abspath(path or paths.cwd()))
    if not p.is_dir():
        raise Abort(f"{p} is not a directory")
    return p


def effective(p):
    cfg = config.load(p)
    if cfg.aios:
        return f"{p} runs with AIOS {cfg.aios} ({cfg.source['aios']})"
    if cfg.legacy:
        return f"{p} runs in legacy mode (legacy: ai-brain)"
    return f"{p} has no binding (no effect); for ai-brain write legacy: ai-brain into its .aios/config.yaml"


def plan_activation(tag, p, plan, installed=True):
    """Add binding p to tag (with the changeover from v0.3) to plan; False if nothing to do.
    installed=False: the version is installed by an earlier step of the same plan (Distribution)."""
    m = config.VERSION.match(tag)
    root = config.vault_root(p)
    if root is None:
        raise Abort(f"{p} is not in a vault (no directory named §… above it)")
    known = install.installations()
    if installed and (tag not in known or not known[tag][0].is_dir()):
        raise Abort(f"AIOS {tag} is not installed; run: aios --install {tag}")
    later = Plan()
    target = semver.Version.parse(m.group(1)).release()
    changes = migrate.plan(p, later, m.group(1)) if target >= semver.Version(0, 4) else []   # from v0.3
    if target >= semver.Version(0, 5):              # from v0.4 (spec 06, Umstellung von v0.4)
        changes += migrate.plan04(p, later, m.group(1))
    steps = None
    if p != root:                                   # a binding only at the vault root (V0.6, F5)
        raise Abort(f"{p} is not a vault root; AIOS binds only a vault root: aios --activate {tag} {root}")
    steps = aiosinit.Steps(p, plan, root=True)      # the vault root becomes the root project (spec 04)
    steps.structure()
    file = p / ".aios" / "config.yaml"
    if file.is_file():
        try:
            data = config.read(file)
        except config.ConfigError as e:
            raise Abort(f"{e}; fix the file first")
        if config.VERSION.match(str(data.get("aios") or "")) and \
                config.VERSION.match(str(data["aios"])).group(1) == m.group(1):
            if not (steps and steps.changes) and not changes:
                return False
            what = None
        else:
            what = f"aios: {m.group(1)} in {file}" + (f" (was {data['aios']})" if data.get("aios") else "")
    else:
        what = f"create {file} with aios: {m.group(1)}"
    if what:
        plan.add(what, lambda: config.set_aios(file, m.group(1)))
    if file.is_file() and "legacy" in config.read(file):
        plan.add(f"remove legacy: from {file} (aios: applies)", lambda: config.drop_key(file, "legacy"))
    from .fetch import open_files                  # V0.6, memo 02: only named
    for line in open_files(p):
        plan.add(line.replace("aios --fetch commits nothing", "aios --activate does not commit them"))
    if steps and steps.changes:
        steps.commit(extra=[".aios/config.yaml"])
    plan.steps += later.steps                       # changeover from v0.3 after the activation (spec 06)
    return True


def vault_projects(root):
    """The vault root and all projects below it (as /aios-integrity finds them)."""
    from . import integrity
    return [p for p, _ in integrity.projects(root)]


def plan_registration(root, plan):
    """Wrappers of the kernel skills at the vault root and in all projects (spec 03; V0.6, F18);
    False if all are up to date."""
    from . import context, registry
    if config.load(root).kind != "aios":
        projects = vault_projects(root)
        plan.add(f"register the wrappers of the kernel skills in {len(projects)} projects of {root}",
                 lambda: register_vault(root))
        return True
    if any(registry.Sync(context.Context(p), with_root=False) for p in vault_projects(root)):
        plan.add(f"register the wrappers of the kernel skills in the projects of {root}",
                 lambda: register_vault(root))
        return True
    return False


def register_vault(root):
    from . import context, registry
    for p in vault_projects(root):
        ctx = context.Context(p)
        if ctx.mode == "aios" and ctx.initialized:
            s = registry.Sync(ctx, with_root=False)
            if s:
                s.apply()


def old_wrappers_due(tag, root):
    """The wrappers of earlier versions that the binding of root makes superfluous (F19)."""
    old = install.old_wrappers()
    if not old or not config.is_aibos(tag[1:]):
        return []
    if any(v != root and config.load(v).kind == "alt" for v in install.known_vaults()):
        return []
    return old


def offer_old_wrappers(tag, root):
    """After binding the last known vault below 0.6: remove the wrappers of earlier versions in
    ~/.claude/skills/ with its own question (spec 04, Umstieg auf v0.6; V0.6, F19, memo 49)."""
    old = install.old_wrappers()
    if not old or not config.is_aibos(tag[1:]):
        return
    if any(v != root and config.load(v).kind == "alt" for v in install.known_vaults()):
        say("   the wrappers of earlier versions in ~/.claude/skills/ stay: a known vault is still "
            "bound below 0.6")
        return
    if extra([f"remove {len(old)} wrappers of earlier versions in {old[0].parent} "
              f"({', '.join(d.name for d in old)})"], "remove them?",
             f"the wrappers of earlier versions stay in {old[0].parent}; to remove them run "
             f"aios --activate {tag} {root} in a terminal"):
        import shutil
        for d in old:
            shutil.rmtree(d)
        say(f"   removed {len(old)} wrappers of earlier versions")


def activate(version, path=None):
    tag = install.normalize(version)
    if not config.VERSION.match(tag):
        raise Abort(f"{version} is not a version (v<MAJOR.MINOR.PATCH>)")
    p = target(path)
    plan = Plan()
    bound = plan_activation(tag, p, plan)
    registers = config.is_aibos(tag[1:]) and plan_registration(p, plan)
    if not bound and not registers:
        say(f"=> {effective(p)}, nothing to do")
        offer_old_wrappers(tag, p)
        return 0
    due = old_wrappers_due(tag, p)
    if due:
        plan.add(f"then with its own question: remove {len(due)} wrappers of earlier versions in {due[0].parent}")
    say(f"=> activate AIOS {tag} for {p}")
    if not confirm(plan, "activate?", "activation cancelled"):
        return 1
    say(f"=> {effective(p)}")
    offer_old_wrappers(tag, p)
    say("   the master context and the skill registration apply from the next chat")
    return 0


def deactivate(path=None):
    p = target(path)
    root = config.vault_root(p)
    if root is not None and p != root:
        raise Abort(f"{p} is not a vault root; a binding exists only at the vault root {root}")
    file = p / ".aios" / "config.yaml"
    data = {}
    if file.is_file():
        try:
            data = config.read(file)
        except config.ConfigError as e:
            raise Abort(f"{e}; fix the file first")
    if "aios" not in data:
        say(f"=> no aios: in {file}, nothing to do; {effective(p)}")
        return 0
    plan = Plan()
    left = [k for k in data if k != "aios"]
    plan.add(f"remove aios: {data['aios']} from {file}"
             + (f" ({', '.join(left)} stay)" if left else " (the file is then empty and removed)"),
             lambda: config.drop_aios(file))
    say(f"=> deactivate AIOS for {p}")
    if not confirm(plan, "deactivate?", "deactivation cancelled"):
        return 1
    say(f"=> {effective(p)}")
    say("   applies from the next chat")
    return 0


def show(path=None):
    p = target(path)
    cfg = config.load(p)
    for line in config.describe(cfg):
        say(line)
    return 0
