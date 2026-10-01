"""aios --activate, --deactivate, --config (spec 04)."""

from __future__ import annotations

import os
from pathlib import Path

from . import config, install, paths
from .ui import Abort, Plan, confirm, say


def target(path):
    p = Path(os.path.abspath(path or paths.cwd()))
    if not p.is_dir():
        raise Abort(f"{p} is not a directory")
    return p


def effective(p):
    cfg = config.load(p)
    if cfg.aios:
        return f"{p} runs with AIOS {cfg.aios} ({cfg.source['aios']})"
    return f"{p} runs in legacy mode (ai-brain)"


def activate(version, path=None):
    tag = install.normalize(version)
    m = config.VERSION.match(tag)
    if not m:
        raise Abort(f"{version} is not a version (v<MAJOR.MINOR.PATCH>)")
    p = target(path)
    root = config.vault_root(p)
    if root is None:
        raise Abort(f"{p} is not in a vault (no directory named §… above it)")
    known = install.installations()
    if tag not in known or not known[tag][0].is_dir():
        raise Abort(f"AIOS {tag} is not installed; run: aios --install {tag}")
    plan = Plan()
    if p == root:
        if not (p / "@").is_dir():
            plan.add(f"create the root masterspace {p / '@'}", lambda: (p / "@").mkdir())
    elif not (p / "@").is_dir():
        raise Abort(f"{p} is not a project (no @/); initialize it with /aios-init "
                    f"or activate the vault {root}")
    file = p / ".aios" / "config.yaml"
    if file.is_file():
        try:
            data = config.read(file)
        except config.ConfigError as e:
            raise Abort(f"{e}; fix the file first")
        if config.VERSION.match(str(data.get("aios") or "")) and \
                config.VERSION.match(str(data["aios"])).group(1) == m.group(1):
            say(f"=> {effective(p)}, nothing to do")
            return 0
        what = f"aios: {m.group(1)} in {file}" + (f" (was {data['aios']})" if data.get("aios") else "")
    else:
        what = f"create {file} with aios: {m.group(1)}"
    plan.add(what, lambda: config.set_aios(file, m.group(1)))
    say(f"=> activate AIOS {tag} for {p}")
    if not confirm(plan, "activate?", "activation cancelled"):
        return 1
    say(f"=> {effective(p)}")
    say("   the master context and the skill registration apply from the next chat")
    return 0


def deactivate(path=None):
    p = target(path)
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
