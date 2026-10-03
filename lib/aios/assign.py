"""aios --assistant <name|none|inherit> [--to <project>] [--session <id>]: assign the assistant
to a project (spec 03, Zuordnung and Wechsel) and, with --session, set the marker of the session.

Writes only the line assistant: in <project>/.aios/config.yaml; comments and other lines stay.
"""

from __future__ import annotations

import os
from pathlib import Path

from . import assistant, config, context, paths, session, ui
from .ui import Abort, Plan, say

USAGE = "usage: aios --assistant <name|none|inherit> [--to <project>] [--session <id>]"


def effective(p):
    """Assistant that applies in p (a name or none), from the chain."""
    return config.load(p).assignment[0]


def after(target, value, vault):
    """Assistant that applies in target once assistant: <value> is written there."""
    if value != "inherit":
        return value
    return "none" if target == vault else effective(target.parent)


def label(ctx, name):
    if name == "none":
        return "kein Assistent"
    found, _ = assistant.assistants(ctx)
    return str(found[name][1].get("title", name)) if name in found else f"{name} (not found)"


def target_of(cwd, ctx, to):
    """The project of the session, or with --to a project of its chain (or the vault root)."""
    if to is None:
        if ctx.project is None:
            raise Abort(f"{cwd} is not in a project; initialize it with /aios-init")
        return ctx.project
    t = Path(os.path.realpath(to))
    if t not in config.chain_dirs(cwd):
        raise Abort(f"{t} is not a project of the chain of {cwd}")
    if not (t / "@").is_dir() and t != ctx.vault:
        raise Abort(f"{t} is not a project (no @/)")
    return t


def command(args):
    value, opts, i = None, {}, 0
    while i < len(args):
        a = args[i]
        if a in ("--to", "--session") and i + 1 < len(args):
            opts[a[2:]] = args[i + 1]
            i += 2
            continue
        if a.startswith("--") or value is not None:
            raise Abort(USAGE)
        value = a
        i += 1
    if value is None:
        raise Abort(USAGE)
    return assign(value, to=opts.get("to"), session_id=opts.get("session"))


def assign(value, to=None, session_id=None):
    cwd = Path(os.path.realpath(paths.cwd()))
    if session_id is not None:
        try:
            session.file(session_id)                # a bad id stops before anything is written
        except session.BadId as e:
            raise Abort(str(e))
    ctx = context.Context(cwd)
    if ctx.mode != "aios":
        raise Abort("assistants need a vault activated with AIOS (aios --activate)")
    target = target_of(cwd, ctx, to)
    tctx = ctx if target == ctx.project else context.Context(target)
    if value not in config.RESERVED:
        value, _ = assistant.resolve(tctx, value)   # name or title; error with the list
    file = target / ".aios" / "config.yaml"
    current = None
    if file.is_file():
        try:
            current = config.read(file).get("assistant")
        except config.ConfigError as e:
            raise Abort(f"{e}; fix the file first, nothing changed")

    old, new = effective(target), after(target, value, ctx.vault)
    session_before = effective(cwd)
    name = target.name
    plan = Plan()
    if current != value:
        plan.add(f"Projekt {name}: {label(tctx, old)} → {label(tctx, new)}  (assistant: {value} in {file})",
                 lambda: config.set_key(file, "assistant", value))
        plan.add(f"gilt für alle neuen Chats in {name} und in den Unterprojekten mit inherit")
    if plan and ui.MODE == "yes":
        plan.run()
    elif plan:
        say(f"=> assign the assistant of {target}")
        ui.confirm(plan, "go on?", "cancelled")
    elif ui.MODE == "plan":
        say(f"=> {name}: assistant: {value} already, nothing to do")
        raise ui.PlanOnly()

    lines = [f"=> {name}: assistant {value}" + (f", applies: {label(tctx, new)}" if value == "inherit" else "")
             if plan else f"=> {name}: assistant: {value} already, nothing to do"]
    if session_id is not None:
        now = effective(cwd)
        if to is None or now != session_before:
            session.write(session_id, cwd, now)
            lines.append(f"   session {session_id}: {now}")
    for line in lines:
        say(line)
    return 0
