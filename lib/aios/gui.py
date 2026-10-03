"""aios --gui [--session <id>] [--html] [--aios]: surfaces of assistants and of AIOS
(spec 03, Oberflächen). Read only.

A surface is a description gui.yaml in the folder of a surface skill (read with PyYAML),
with optional HTML parts next to it. Without --html the body of the surface skill is printed,
extended by the instruction how to show it; with --html an HTML fragment.
"""

from __future__ import annotations

import html
import json
from pathlib import Path

from . import assistant, context, paths, session, skills
from .ui import Abort

KEYS = {"title", "intro", "tiles"}
TILE_KEYS = {"title", "text", "prompt", "skill", "html", "icon"}
ACTIONS = ("prompt", "skill", "html")
MAX_TILES = 12
AIOS_GUI = Path(__file__).resolve().parents[2] / "skills" / "aios" / "aios-gui"
HINT = "AIOS-Oberfläche: `/aios-gui`"


# ---------------------------------------------------------------------------
# description gui.yaml
# ---------------------------------------------------------------------------

def read(folder):
    """The checked description of the surface in folder (gui.yaml)."""
    f = folder / "gui.yaml"
    if not f.is_file():
        raise Abort(f"{f} is missing")
    try:
        import yaml
    except ImportError:
        raise Abort("aios --gui needs PyYAML (python/requirements.txt of the installation)")
    try:
        d = yaml.safe_load(f.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        raise Abort(f"{f}: {e}")
    problems = check(d, folder)
    if problems:
        raise Abort(f"{f}: " + "; ".join(problems))
    return d


def check(d, folder):
    if not isinstance(d, dict):
        return ["expected a mapping with title and tiles"]
    p = [f"unknown key {k}" for k in d if k not in KEYS]
    if not isinstance(d.get("title"), str) or not d["title"].strip():
        p.append("title is missing")
    if "intro" in d and not isinstance(d["intro"], str):
        p.append("intro must be one sentence")
    tiles = d.get("tiles")
    if not isinstance(tiles, list) or not 1 <= len(tiles) <= MAX_TILES:
        p.append(f"tiles must be a list of 1 to {MAX_TILES} tiles")
        return p
    for i, t in enumerate(tiles, 1):
        if not isinstance(t, dict):
            p.append(f"tile {i} is not a mapping")
            continue
        p += [f"tile {i}: unknown key {k}" for k in t if k not in TILE_KEYS]
        if not isinstance(t.get("title"), str) or not t["title"].strip():
            p.append(f"tile {i}: title is missing")
        acts = [a for a in ACTIONS if a in t]
        if len(acts) != 1:
            p.append(f"tile {i}: exactly one of prompt, skill, html")
        elif not isinstance(t[acts[0]], str) or not t[acts[0]].strip():
            p.append(f"tile {i}: {acts[0]} must be a text")
        elif acts[0] == "html" and ("/" in t["html"] or not (folder / t["html"]).is_file()):
            p.append(f"tile {i}: HTML part {t['html']} not found in {folder}")
    return p


def action(t):
    """(kind, value) of a tile; skill becomes the prompt /<skill>."""
    if "html" in t:
        return "html", t["html"]
    if "skill" in t:
        return "prompt", "/" + t["skill"]
    return "prompt", t["prompt"]


# ---------------------------------------------------------------------------
# output: body with instruction, or HTML fragment
# ---------------------------------------------------------------------------

def instruction(d, call):
    """How Claude shows the surface (spec 03, Darstellung), with the tiles as data."""
    lines = ["", "## Oberfläche zeigen", "",
             "Zeige diese Oberfläche jetzt, ohne weitere Erklärung:", "",
             f"- **Desktop-App mit HTML-Oberflächen** (Werkzeug für HTML-Oberflächen im Chat verfügbar): "
             f"führe `{call} --html` aus und zeige die Ausgabe unverändert mit diesem Werkzeug.",
             "- **Sonst (CLI, Headless):** Menü mit dem Auswahlwerkzeug (`AskUserQuestion`), Frage = Titel, "
             "höchstens 4 Einträge je Ebene, bei mehr Kacheln als letzter Eintrag „Weitere …“ mit der nächsten Ebene. "
             "Kacheln mit HTML-Teil fehlen im Menü; nenne sie als Hinweis („nur in der Desktop-App“). "
             "Nach der Wahl: einen Prompt so behandeln, als hätte der User ihn getippt; `/<skill>` als Aufruf des Skills.",
             "", f"Titel: {d['title']}"]
    if d.get("intro"):
        lines.append(f"Intro: {d['intro']}")
    lines.append("Kacheln:")
    for t in d["tiles"]:
        kind, value = action(t)
        what = f"HTML-Teil {value}" if kind == "html" else f"sendet: {value}"
        lines.append(f"- {t['title']}" + (f" — {t['text']}" if t.get("text") else "") + f" ({what})")
    return "\n".join(lines) + "\n"


def fragment(d, folder):
    """HTML fragment: heading, intro, tiles as buttons (sendPrompt), HTML parts embedded."""
    e = html.escape
    out = ['<div class="aios-gui">',
           "<style>.aios-gui{font-family:system-ui,sans-serif;max-width:720px}"
           ".aios-gui .tiles{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px}"
           ".aios-gui button.tile{text-align:left;padding:12px;border-radius:10px;border:1px solid #8884;"
           "background:transparent;color:inherit;cursor:pointer}.aios-gui button.tile:hover{background:#8882}"
           ".aios-gui .tile b{display:block;margin-bottom:4px}.aios-gui .part{margin-top:16px}</style>",
           f"<h2>{e(d['title'])}</h2>"]
    if d.get("intro"):
        out.append(f"<p>{e(d['intro'])}</p>")
    out.append('<div class="tiles">')
    parts = []
    for t in d["tiles"]:
        kind, value = action(t)
        text = f"<span>{e(t['text'])}</span>" if t.get("text") else ""
        icon = f' data-icon="{e(t["icon"])}"' if t.get("icon") else ""
        if kind == "html":
            parts.append((t, value))
            anchor = "aios-part-" + str(len(parts))
            out.append(f'<button class="tile"{icon} onclick="document.getElementById(\'{anchor}\')'
                       f'.scrollIntoView({{behavior:\'smooth\'}})"><b>{e(t["title"])}</b>{text}</button>')
        else:
            out.append(f'<button class="tile"{icon} onclick=\'sendPrompt({e(json.dumps(value, ensure_ascii=False))})\'>'
                       f"<b>{e(t['title'])}</b>{text}</button>")
    out.append("</div>")
    for i, (t, name) in enumerate(parts, 1):
        out.append(f'<section class="part" id="aios-part-{i}"><h3>{e(t["title"])}</h3>')
        out.append((folder / name).read_text(encoding="utf-8").rstrip("\n"))
        out.append("</section>")
    out.append("</div>")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------------------
# aios --gui
# ---------------------------------------------------------------------------

def session_assistant(ctx, session_id):
    """Name of the assistant of the session (marker), else of the assignment of the project."""
    if session_id is not None:
        try:
            m = session.read(session_id)
        except session.BadId as e:
            raise Abort(str(e))
        if m:
            return m["assistant"]
    return ctx.cfg.assignment[0]


def command(args):
    opts = {"html": False, "aios": False, "session": None}
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--session" and i + 1 < len(args):
            opts["session"] = args[i + 1]
            i += 2
            continue
        if a in ("--html", "--aios"):
            opts[a[2:]] = True
        else:
            raise Abort("usage: aios --gui [--session <id>] [--html] | aios --gui --aios [--html]")
        i += 1
    return show(**opts)


def show(html=False, aios=False, session=None):
    body_file = None
    if aios:                                        # the AIOS skill aios-gui calls this: no body
        folder, call = AIOS_GUI, "aios --gui --aios"
    else:
        ctx = context.Context(paths.cwd())
        if ctx.mode != "aios":
            print(f"Kein Assistent aktiv.\n{HINT}")
            return 0
        name = session_assistant(ctx, session)
        if name == "none":
            print(f"Kein Assistent aktiv.\n{HINT}")
            return 0
        try:
            name, (d, meta) = assistant.resolve(ctx, name)
        except Abort:
            print(f"Der Assistent {name} wurde nicht gefunden.\n{HINT}")
            return 0
        title = meta.get("title", name)
        gui_name = meta.get("gui")
        if not gui_name:
            print(f"Der Assistent {title} hat keine Oberfläche.\n{HINT}")
            return 0
        if gui_name not in assistant.as_list(meta.get("skills")):
            raise Abort(f"gui {gui_name} of the assistant {name} is not in its skills")
        body_file = assistant.lookup(d, ctx, "skill", gui_name)
        folder = body_file.parent
        call = "aios --gui" + (f" --session {session}" if session else "")
    d = read(folder)
    if html:
        print(fragment(d, folder), end="")
    else:
        body = skills.strip_frontmatter(body_file.read_text(encoding="utf-8")).rstrip("\n") + "\n" \
            if body_file else f"# {d['title']}\n"
        print(body + instruction(d, call), end="")
    return 0

