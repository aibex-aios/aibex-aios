"""aios --worker, aios --run: workers and commands of packages (spec 06, Arbeitspferde; V0.4, memo 41).

A worker is a program with a life cycle that a package brings (install, remove, start, stop).
Every script runs only after its own confirmation: the plan shows its path and content (P3).
Whether a worker is installed is kept per computer in ~/.aios/workers.yaml. A command of a
package runs with aios --run when the user calls it, without a question (P3).
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

from . import deploy, elements, package, paths, ui
from .ui import Abort, Plan, say, warn

ACTIONS = ("install", "remove", "start", "stop")


# ---------------------------------------------------------------------------
# state ~/.aios/workers.yaml
# ---------------------------------------------------------------------------

def state_file():
    return paths.user_dir() / "workers.yaml"


def read_state():
    import yaml
    f = state_file()
    if not f.is_file():
        return {}
    try:
        return yaml.safe_load(f.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as e:
        raise Abort(f"{f}: {e}")


def write_state(data):
    import yaml
    f = state_file()
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text("# written by AIOS (aios --worker), do not edit\n"
                 + yaml.safe_dump(data, sort_keys=True, allow_unicode=True), encoding="utf-8")


def key(project, pkg, name):
    return f"{project}|{pkg}/{name}"


def installed(project, pkg):
    """Names of the installed workers of a package in a project."""
    prefix = f"{project}|{pkg}/"
    return sorted(k[len(prefix):] for k, v in read_state().items()
                  if k.startswith(prefix) and (v or {}).get("installed"))


def set_state(project, pkg, name, version, on):
    data = read_state()
    if on:
        data[key(project, pkg, name)] = {"installed": True, "version": str(version)}
    else:
        data.pop(key(project, pkg, name), None)
    write_state(data)


# ---------------------------------------------------------------------------
# workers
# ---------------------------------------------------------------------------

def workers_of(project, pkg):
    d = project / "@" / "@!Package" / pkg
    if not (d / deploy.MARKER).is_file():
        raise Abort(f"no fetched package {pkg} in {project}")
    try:
        m = package.load(d)
    except package.ManifestError as e:
        raise Abort(str(e))
    return d, m


def run_script(d, project, pkg, script):
    env = dict(os.environ, AIOS_PACKAGE=str(d), AIOS_PROJECT=str(project),
               AIOS_DATA=str(project / "@Data" / pkg))
    r = subprocess.run(["bash", str(d / script)], cwd=d, env=env, capture_output=True, text=True)
    for line in (r.stdout + r.stderr).splitlines():
        say(f"   | {line}")
    return r.returncode


def show(to=None):
    """aios --worker without arguments: the workers of the project and their state."""
    project = deploy.target_project(to)
    rows = []
    for p in elements.packages(project / "@"):
        if not (p.dir / "manifest.yaml").is_file():
            continue
        try:
            m = package.load(p.dir)
        except package.ManifestError:
            continue
        on = installed(project, p.name)
        for name, spec in m.workers.items():
            rows.append(f"   {p.name}/{name}  " + ("installed" if name in on else "not installed")
                        + (f" — {spec['description']}" if spec.get("description") else ""))
    if not rows:
        say(f"=> no workers in the packages of {project}")
        return 0
    say(f"=> workers of {project}")
    for r in rows:
        say(r)
    return 0


def act(spec, action, to=None):
    """aios --worker <package>/<name> install|remove|start|stop: plan with the script, then run."""
    pkg, _, name = spec.partition("/")
    if not pkg or not name or action not in ACTIONS:
        raise Abort("usage: aios --worker <package>/<name> install|remove|start|stop [--to <project>]")
    project = deploy.target_project(to)
    d, m = workers_of(project, pkg)
    if name not in m.workers:
        raise Abort(f"{pkg} has no worker {name}; workers: {', '.join(m.workers) or '-'}")
    w = m.workers[name]
    script = w.get(action)
    if not script:
        raise Abort(f"the worker {pkg}/{name} has no {action} script")
    on = name in installed(project, pkg)
    if action == "install" and on:
        say(f"=> {pkg}/{name} is installed, nothing to do")
        return 0
    if action in ("start", "stop") and not on:
        raise Abort(f"{pkg}/{name} is not installed; first: aios --worker {pkg}/{name} install")
    text = (d / script).read_text(encoding="utf-8")
    result = {}
    plan = Plan()
    plan.add(f"run {d / script} (bash, in {d})" + "".join(f"\n         | {line}" for line in text.splitlines()),
             lambda: result.setdefault("rc", run_script(d, project, pkg, script)))
    if ui.MODE != "yes":
        say(f"=> {action} the worker {pkg}/{name} of {project}")
    ui.confirm(plan, "run the script?", "cancelled")
    rc = result.get("rc", 0)
    if action == "install":
        if rc:
            warn(f"install of {pkg}/{name} failed (exit {rc}); running remove")
            if w.get("remove"):
                rc2 = run_script(d, project, pkg, w["remove"])
                warn(f"remove of {pkg}/{name} " + ("done" if rc2 == 0 else f"failed (exit {rc2})"))
            raise Abort(f"{pkg}/{name} is not installed")
        set_state(project, pkg, name, m.version, True)
    elif action == "remove":
        set_state(project, pkg, name, m.version, False)
        if rc:
            warn(f"remove of {pkg}/{name} ended with exit {rc}; it counts as removed")
    elif rc:
        raise Abort(f"{action} of {pkg}/{name} failed (exit {rc})")
    say(f"=> {pkg}/{name}: {action} done")
    return 0


def command(args):
    to, rest, i = None, [], 0
    while i < len(args):
        if args[i] == "--to" and i + 1 < len(args):
            to = args[i + 1]
            i += 2
            continue
        rest.append(args[i])
        i += 1
    if not rest:
        return show(to)
    if len(rest) != 2:
        raise Abort("usage: aios --worker [<package>/<name> install|remove|start|stop] [--to <project>]")
    return act(rest[0], rest[1], to)


# ---------------------------------------------------------------------------
# aios --run
# ---------------------------------------------------------------------------

def run_command(args):
    """aios --run <command> [arguments]: a deployed command of a package of the chain, nearest
    masterspace first; the user calls it, so there is no question (P3)."""
    if not args:
        raise Abort("usage: aios --run <command> [arguments]")
    name, rest = args[0], args[1:]
    from . import context
    ctx = context.Context(paths.cwd())
    if ctx.mode != "aios":
        raise Abort(f"{paths.cwd()} is not in an activated vault")
    for ms in reversed(ctx.masterspaces):
        for p in elements.packages(ms):
            f = p.dir / "commands" / name
            if f.is_file() and p.deployed(name):
                env = dict(os.environ, AIOS_PACKAGE=str(p.dir), AIOS_PROJECT=str(ms.parent),
                           AIOS_DATA=str(ms.parent / "@Data" / p.name))
                return subprocess.run(["bash", str(f), *rest], env=env).returncode
    raise Abort(f"no deployed command {name} in the packages of the chain")
