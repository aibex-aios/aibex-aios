"""aios --skill <name> (version-neutral AIOS skills, spec 04) and aios-context --list (spec 02)."""

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


SESSION = "${CLAUDE_SESSION_ID}"                   # placeholder in a body that needs the session id


def needs_session(text):
    """A skill whose body uses the session id gets a wrapper with --session (spec 04)."""
    return SESSION in strip_frontmatter(text)


def body(name, session_id=None):
    """Print the body of skills/aios/<name>/SKILL.md of the running version (the valid one);
    with --session the placeholder ${CLAUDE_SESSION_ID} is replaced by the id."""
    f = source(name)
    if not f.is_file():
        raise Abort(f"AIOS {version()} has no AIOS skill {name}")
    text = strip_frontmatter(f.read_text(encoding="utf-8"))
    if session_id is not None:
        from . import session
        try:
            session.file(session_id)
        except session.BadId as e:
            raise Abort(str(e))
        text = text.replace(SESSION, session_id)
    print(text, end="")
    return 0


# ---------------------------------------------------------------------------
# aios-context --list
# ---------------------------------------------------------------------------

def number(n):
    return f"{n:,}".replace(",", ".")


def plural(n, one, many):
    return f"{n} {one if n == 1 else many}"


def assignment_text(ctx):
    """Line Assistent of the listing: assignment of the project with its origin (spec 02)."""
    from . import assistant
    name, src = ctx.cfg.assignment
    shown = name
    if name != "none":
        found, _ = assistant.assistants(ctx)
        shown = f"{name} {registry.version_of(found[name][1])}" if name in found else f"{name} (nicht gefunden)"
    if src is None:
        return f"{shown} (keine Zuordnung)"
    where = src.parent.parent
    return f"{shown} (" + ("" if where == ctx.cwd else "inherit, ") + f"zugeordnet in {where.name})"


def listing(ctx):
    """Lines of the listing for /aios-context (spec 02, Aufstellung)."""
    if ctx.mode == "none":
        return ["Kein Vault — kein Master-Kontext."]
    if ctx.mode == "legacy":
        return ["Legacy-Modus (ai-brain, kein aios: in der Kette) — siehe /masterspace."]
    base = ctx.vault.parent

    def rel(p):
        return str(Path(p).relative_to(base))

    name = ctx.cwd.name if ctx.initialized else \
        f"{ctx.cwd.name} (nicht initialisiert, Kette bis {ctx.project.name})"
    chars = len(ctx.render())
    out = [f"Master-Kontext id {ctx.id}, AIOS {version()} — {name}", "",
           f"{'Kette':27}{' → '.join(ms.parent.name for ms in ctx.masterspaces)}",
           f"{'Assistent':27}{assignment_text(ctx)}", "",
           f"{'Master-Kontext (geladen)':27}{plural(len(ctx.loaded), 'Datei', 'Dateien')}, {number(chars)} Zeichen"]
    out += [f"  {rel(p)}" for p in ctx.loaded]
    out.append(f"{'verfügbares Wissen':27}{plural(len(ctx.available), 'Datei', 'Dateien')}"
               + (" (nicht geladen, Inhaltsverzeichnis im Master-Kontext)" if ctx.available else ""))
    out += [f"  {rel(p)}" for p in ctx.available]

    chain, problems = registry.blueprints(ctx)
    sync = registry.Sync(ctx) if ctx.initialized else None
    pending = {n for n, *_ in (sync.new + sync.changed)} if sync else set()
    skills, assistants, prompts = [], [], []
    for name_, (d, ver) in sorted(chain.items()):
        state = "nicht registriert" if name_ in pending or sync is None else "registriert"
        skills.append(f"{name_} {ver}".rstrip() + f" ({d.parents[2].name}) — {state}")
    for ms in ctx.masterspaces:
        for a in sorted((ms / "@!Assistant").glob("*/ASSISTANT.md")):
            assistants.append(f"{a.parent.name} {registry.version_of(frontmatter(a))}".rstrip() + f" ({ms.parent.name})")
            for s in sorted((a.parent / "@!Skill").glob("*/SKILL.md")):
                skills.append(f"{s.parent.name} {registry.version_of(frontmatter(s))}".rstrip()
                              + f" (Assistent {a.parent.name}, privat)")
        prompts += [f"{p.stem} ({ms.parent.name})" for p in sorted((ms / "@!Prompt").glob("*.md"))]
    out.append(f"{'Verborgen':27}Blueprints: {plural(len(skills), 'Skill', 'Skills')}, "
               f"{plural(len(assistants), 'Assistent', 'Assistenten')}, {plural(len(prompts), 'Prompt', 'Prompts')}")
    for label, items in (("Skills", skills), ("Assistenten", assistants), ("Prompts", prompts)):
        for i, item in enumerate(items):
            out.append(f"  {label if i == 0 else '':13}{item}")
    if sync and (sync or sync.removed):
        out.append("Hinweis: Blueprints und registrierte Skills stimmen nicht überein — /aios-register")
    out += [f"Übersprungen: {p}" for p in problems]
    return out
