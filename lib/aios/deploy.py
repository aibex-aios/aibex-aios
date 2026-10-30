"""aios --deploy: deploy the elements of fetched packages (spec 06, Ausrollen; V0.4, memos 23, 24).

Deploying decides which elements of a fetched package act in the project: all of them, or a
selection only: [...] in packages: of the project. Nothing is copied (P7); afterwards the
project skills of the session are registered anew. The marker .aios-deploy of a package
folder and the helpers on it live here as well; aios --fetch writes the marker.
"""

from __future__ import annotations

import os
from pathlib import Path

from . import config, elements, paths, registry, ui
from .ui import Abort, Plan, say

MARKER = ".aios-deploy"


# ---------------------------------------------------------------------------
# marker of a package folder
# ---------------------------------------------------------------------------

def files_of(d):
    """{relative path: bytes} of a blueprint without the marker. Subfolders with their own marker
    (skills deployed into an assistant with --assistant) belong to their own deployment (spec 03)."""
    out = {}
    for root, dirs, files in os.walk(d):
        dirs[:] = [x for x in dirs if not (Path(root) / x / MARKER).is_file()]
        for f in files:
            p = Path(root) / f
            rel = p.relative_to(d).as_posix()
            if rel != MARKER:
                out[rel] = p.read_bytes()
    return out


def digest_of(d):
    import hashlib
    h = hashlib.sha256()
    for rel, data in sorted(files_of(d).items()):
        h.update(f"{rel}\n".encode())
        h.update(data)
        h.update(b"\n")
    return "sha256:" + h.hexdigest()


def read_marker(d):
    f = d / MARKER
    if not f.is_file():
        return None
    out = {}
    for line in f.read_text(encoding="utf-8").splitlines():
        if ":" in line and not line.startswith("#"):
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip().strip('"')
    return out




# ---------------------------------------------------------------------------
# target and registration
# ---------------------------------------------------------------------------

def target_project(to):
    p = Path(os.path.abspath(to or paths.cwd()))
    root = config.vault_root(p)
    if root is None:
        raise Abort(f"{p} is not in a vault")
    if not (p / "@").is_dir():
        raise Abort(f"{p} is not a project (no @/); give --to <project> or initialize it with /aios-init")
    if not config.load(p).aios:
        raise Abort(f"{p} is not activated (legacy mode); run: aios --activate v<version> {root}")
    return p


def register_session(plan, later=False, target=None):
    """Step 5 of the deploy: register the skills of the target, default the project of the session
    (spec 03; V0.6, memo 03, K2). later=True: the target becomes a bound project only in this plan
    (vault root bound by a distribution)."""
    cwd = str(target) if target else paths.cwd()

    def run():
        ctx, s = registry.sync_for(cwd)
        if s:
            s.apply()
            say(f"   registered in {cwd}: {s.summary()}")
    ctx, s = registry.sync_for(cwd)
    if s is not None or later:
        plan.add(f"register the skills of {cwd}", run)




# ---------------------------------------------------------------------------
# commands
# ---------------------------------------------------------------------------

def show(to=None):
    """aios --deploy without a package: the packages of the project and their elements."""
    project = target_project(to)
    pkgs = elements.packages(project / "@")
    if not pkgs:
        say(f"=> no fetched packages in {project}")
        return 0
    say(f"=> packages of {project}")
    for p in pkgs:
        on, off = p.split()
        sel = "all elements deployed" if p.only is None else "only " + ", ".join(sorted(p.only))
        say(f"   {p.name} {p.version} ({p.hub}) — {sel}")
        for state, items in (("deployed", on), ("not deployed", off)):
            for kind, name in items:
                say(f"      {state:<14}" + ("knowledge" if kind == "knowledge" else f"{kind[:-1]} {name}"))
    return 0


def select(name, only, to=None):
    """aios --deploy <package> --only <element>... | --all: write only: in packages: (P7)."""
    from . import fetch
    project = target_project(to)
    wanted = fetch.wanted(project)
    if name not in wanted:
        raise Abort(f"{name} is not in packages: of {project / '.aios' / 'config.yaml'}; "
                    "only packages fetched for this project can be deployed in part (H4)")
    pkg = next((p for p in elements.packages(project / "@") if p.name == name), None)
    if pkg is None:
        raise Abort(f"{name} is in packages:, but not fetched; run: aios --fetch")
    have = [n for names in pkg.elements().values() for n in names]
    unknown = [e for e in only or [] if e not in have]
    if unknown:
        raise Abort(f"{name} has no element {', '.join(unknown)}; elements: {', '.join(have)}")
    entry = wanted[name]
    new = dict(entry) if isinstance(entry, dict) else {"range": entry}
    new.pop("only", None)
    if only is not None:
        new["only"] = sorted(set(only), key=have.index)
    if new == (entry if isinstance(entry, dict) else {"range": entry}):
        say(f"=> {name}: " + ("only " + ", ".join(new["only"]) if "only" in new else "all elements")
            + " already deployed, nothing to do")
        return 0
    file = project / ".aios" / "config.yaml"
    text = fetch.entry_text(new if len(new) > 1 else new["range"])
    plan = Plan()
    plan.add(f"{file}: packages: {name}: {text}", lambda: config.set_skill(file, name, text, "packages"))
    register_session(plan)
    if ui.MODE != "yes":
        say(f"=> deploy " + ("only " + ", ".join(new["only"]) if "only" in new else "all elements")
            + f" of {name} in {project}")
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> {name}: " + ("only " + ", ".join(new["only"]) if "only" in new else "all elements") + " deployed")
    say("   skills are available from the next chat (or after /reload-skills)")
    return 0


def command(args):
    """Parse aios --deploy [<package> --only <element>... | --all] [--to <project>]."""
    to, rest, only, everything, i = None, [], None, False, 0
    while i < len(args):
        a = args[i]
        if a == "--to" and i + 1 < len(args):
            to = args[i + 1]
            i += 2
            continue
        if a == "--only":
            only = []
        elif a == "--all":
            everything = True
        elif a.startswith("--"):
            raise Abort(f"unexpected argument {a}")
        elif only is not None:
            only.append(a)
        else:
            rest.append(a)
        i += 1
    if rest and "==" in rest[0]:
        raise Abort(f"aios --deploy deploys elements of fetched packages; to fetch {rest[0]} use: "
                    f"aios --fetch {rest[0]}")
    if not rest:
        if only is not None or everything:
            raise Abort("usage: aios --deploy <package> --only <element>... | --all [--to <project>]")
        return show(to)
    if len(rest) != 1 or (only is None) == (not everything) or only == []:
        raise Abort("usage: aios --deploy <package> --only <element>... | --all [--to <project>]")
    return select(rest[0], None if everything else only, to)
