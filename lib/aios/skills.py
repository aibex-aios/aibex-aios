"""aios --skill <name> (version-neutral AIOS skills, spec 04) and aios --context --list (spec 02)."""

from __future__ import annotations

from pathlib import Path

from . import registry, version
from .install import frontmatter
from .ui import Abort


def source(name):
    return Path(__file__).resolve().parents[2] / "skills" / "aios" / name / "SKILL.md"


def strip_frontmatter(text):
    if text.startswith("---\n"):
        end = text.find("\n---", 3)
        if end > 0:
            nl = text.find("\n", end + 4)
            text = "" if nl < 0 else text[nl + 1:]
    return text.lstrip("\n")


SESSION = "<session-id>"                           # placeholder in a body that needs the session id


def needs_session(text):
    """A skill whose body uses the session id gets a wrapper with --session (spec 04)."""
    return SESSION in strip_frontmatter(text)


def memo_registered():
    """The project of cwd has a skill memo in its .aios/registry (precedence of memo, spec 03)."""
    from . import context, paths
    ctx = context.Context(paths.cwd())
    return ctx.project is not None and "memo" in registry.read_registry(ctx.project)


def in_aibos_workspace():
    """Location check of aios --skill (spec 03, Ortsprüfung; V0.6, memo 23): cwd in an A/W."""
    from . import config, paths
    return config.load(paths.cwd()).kind == "aios"


def with_forwarder(text):
    """Every call in backticks that starts with aios gets the absolute path of the forwarder, so that
    the model never calls an aios from the PATH (V0.6, F42)."""
    from . import paths
    return text.replace("`aios ", f"`{paths.forwarder()} ")


def body(name, session_id=None):
    """Print the body of skills/aios/<name>/SKILL.md of the running version (the valid one);
    with --session the placeholder <session-id> is replaced by the id (wrappers give the id as a
    line of text instead, spec 04). Outside an A/W only the line of the location check."""
    import sys
    from . import paths
    if not in_aibos_workspace():
        print(f"Kein AIBOS-Workspace: {paths.cwd()}", file=sys.stderr)
        return 1
    f = source(name)
    if not f.is_file():
        raise Abort(f"AIOS {version()} has no AIOS skill {name}")
    if name == "aios-memo" and memo_registered():
        print("Use `/memo` — the skill `memo` is registered in this project.")
        return 0
    text = strip_frontmatter(f.read_text(encoding="utf-8"))
    if session_id is not None:
        from . import session
        try:
            session.file(session_id)
        except session.BadId as e:
            raise Abort(str(e))
        text = text.replace(SESSION, session_id)
    print(with_forwarder(text), end="")
    return 0


# ---------------------------------------------------------------------------
# aios --context --list
# ---------------------------------------------------------------------------

def number(n):
    return f"{n:,}"


def plural(n, one, many):
    return f"{n} {one if n == 1 else many}"


def assignment_text(ctx):
    """Line Assistent of the listing: assignment of the project with its origin (spec 02)."""
    from . import assistant
    name, src = ctx.cfg.assignment
    shown = name
    if name != "none":
        found, _ = assistant.assistants(ctx)
        shown = f"{name} {registry.version_of(found[name][1])}" if name in found else f"{name} (not found)"
    if src is None:
        return f"{shown} (no assignment)"
    where = src.parent.parent
    return f"{shown} (" + ("" if where == ctx.cwd else "inherit, ") + f"assigned in {where.name})"


def listing(ctx):
    """Lines of the listing for /aios-context (spec 02, Aufstellung)."""
    if ctx.mode == "none":
        return ["No vault — no master context."]
    if ctx.mode == "legacy":
        return ["Legacy mode (ai-brain, no aios: in the chain) — see /masterspace."]
    base = ctx.vault.parent

    def rel(p):
        return str(Path(p).relative_to(base))

    name = ctx.cwd.name if ctx.initialized else \
        f"{ctx.cwd.name} (not initialized, chain up to {ctx.project.name})"
    chars = len(ctx.render())
    out = [f"Master context id {ctx.id}, AIOS {version()} — {name}", "",
           f"{'Chain':27}{' → '.join(ms.parent.name for ms in ctx.masterspaces)}",
           f"{'Assistant':27}{assignment_text(ctx)}", "",
           f"{'Master context (loaded)':27}{plural(len(ctx.loaded), 'file', 'files')}, {number(chars)} characters"]
    out += [f"  {rel(p)}" for p in ctx.loaded]
    out.append(f"{'Available knowledge':27}{plural(len(ctx.available), 'file', 'files')}"
               + (" (not loaded, table of contents in the master context)" if ctx.available else ""))
    out += [f"  {rel(p)}" for p in ctx.available]

    from . import elements
    chain, problems = registry.blueprints(ctx)
    sync = registry.Sync(ctx) if ctx.initialized else None
    pending = {n for n, *_ in (sync.new + sync.changed)} if sync else set()
    skills, assistants, prompts = [], [], []
    for name_, (d, ver) in sorted(chain.items()):
        state = "not registered" if name_ in pending or sync is None else "registered"
        where = d.parents[2].name if d.parent.name == "@!Skill" else \
            f"{d.parents[4].name}, package {d.parents[1].name}"
        skills.append(f"{name_} {ver}".rstrip() + f" ({where}) — {state}")
    for ms in ctx.masterspaces:
        for a in sorted((ms / "@!Assistant").glob("*/ASSISTANT.md")):
            assistants.append(f"{a.parent.name} {registry.version_of(frontmatter(a))}".rstrip() + f" ({ms.parent.name})")
            for s in sorted((a.parent / "@!Skill").glob("*/SKILL.md")):
                skills.append(f"{s.parent.name} {registry.version_of(frontmatter(s))}".rstrip()
                              + f" (assistant {a.parent.name}, private)")
        for pkg in elements.packages(ms):           # assistants of packages count too (O2)
            for d in pkg.dirs("assistants"):
                assistants.append(f"{d.name} {registry.version_of(frontmatter(d / 'ASSISTANT.md'))}".rstrip()
                                  + f" ({ms.parent.name}, package {pkg.name})")
        prompts += [f"{p.stem} ({ms.parent.name})" for p in sorted((ms / "@!Prompt").glob("*.md"))]
    out.append(f"{'Hidden':27}Blueprints: {plural(len(skills), 'skill', 'skills')}, "
               f"{plural(len(assistants), 'assistant', 'assistants')}, {plural(len(prompts), 'prompt', 'prompts')}")
    for label, items in (("Skills", skills), ("Assistants", assistants), ("Prompts", prompts)):
        for i, item in enumerate(items):
            out.append(f"  {label if i == 0 else '':13}{item}")
    out += package_lines(ctx)
    if sync and (sync or sync.removed):
        out.append("Note: blueprints and registered skills differ — /aios-register")
    out += [f"Skipped: {p}" for p in problems]
    return out


def package_lines(ctx):
    """Section Packages of the listing: fetched packages of the chain with their deployed,
    covered and not deployed elements (spec 02, spec 06 Vorrang and H3)."""
    from . import elements
    pkgs = [p for ms in ctx.masterspaces for p in elements.packages(ms)]
    if not pkgs:
        return []
    covered = {}
    for kind, local in (("skills", "@!Skill"), ("assistants", "@!Assistant")):
        for name, old, new in elements.covered(ctx.masterspaces, kind, local):
            covered.setdefault(old, []).append(f"{kind[:-1]} {name}: covered by {new}")
    out = [f"{'Packages':27}{plural(len(pkgs), 'package', 'packages')}"]
    for p in pkgs:
        on, off = p.split()
        kinds = {}
        for kind, name in on:
            kinds.setdefault(kind, []).append(name)
        what = "; ".join(("knowledge" if k == "knowledge" else f"{k} " + ", ".join(n))
                         for k, n in kinds.items()) or ("no elements deployed" if off else "no elements")  # O3
        out.append(f"  {p.name} {p.version} ({p.hub}, {p.masterspace.parent.name}) — {what}")
        out += [f"      {c}" for c in covered.get(f"package {p.name} ({p.masterspace.parent.name})", [])]
        if off:
            out.append("      fetched, not deployed: " + ", ".join(f"{k[:-1] if k != 'knowledge' else k} {n}"
                                                             if k != "knowledge" else "knowledge" for k, n in off))
    return out
