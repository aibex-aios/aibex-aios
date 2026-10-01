"""aios-context --assistant <name>, --assistants (spec 03, Assistenten). Stateless: nothing is written."""

from __future__ import annotations

import unicodedata
from pathlib import Path

from . import config
from .context import AVAILABLE, LOAD, classify, title
from .skills import strip_frontmatter
from .ui import Abort


def normalize(text):
    """Compare names without case and umlauts: Obstgärtner == obstgaertner."""
    t = text.strip().lower()
    for a, b in (("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")):
        t = t.replace(a, b)
    t = unicodedata.normalize("NFKD", t)
    return "".join(c for c in t if not unicodedata.combining(c))


def meta_of(file):
    text = file.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise Abort(f"{file} has no frontmatter")
    end = text.find("\n---", 3)
    try:
        return config.parse(text[4:end], str(file))
    except config.ConfigError as e:
        raise Abort(str(e))


def assistants(ctx):
    """{name: (dir, meta)} of the chain; the nearest masterspace wins (spec 03)."""
    found = {}
    for ms in ctx.masterspaces:
        for f in sorted((ms / "@!Assistant").glob("*/ASSISTANT.md")):
            meta = meta_of(f)
            if meta.get("name") != f.parent.name:
                raise Abort(f"{f}: name {meta.get('name')!r} differs from the folder {f.parent.name!r}")
            found[f.parent.name] = (f.parent, meta)
    return found


def available_lines(found):
    if not found:
        return ["no assistants in the chain (@!Assistant/<name>/ASSISTANT.md)"]
    return [f"{n:20} {m.get('title', n)} — {m.get('description', '')}  ({d.parents[2].name})"
            for n, (d, m) in sorted(found.items())]


def resolve(ctx, query):
    found = assistants(ctx)
    q = normalize(query)
    hits = [n for n, (d, m) in found.items() if q in (normalize(n), normalize(str(m.get("title", ""))))]
    if len(hits) != 1:
        what = "no assistant" if not hits else "more than one assistant"
        raise Abort(f"{what} named {query!r}; available:\n" + "\n".join(available_lines(found)))
    return hits[0], found[hits[0]]


def lookup(assistant_dir, ctx, kind, name):
    """Prompt or skill: first in the assistant folder, then in the chain from the project upwards."""
    rel = Path("@!Prompt") / f"{name}.md" if kind == "prompt" else Path("@!Skill") / name / "SKILL.md"
    for base in [assistant_dir] + [ms for ms in reversed(ctx.masterspaces)]:
        if (base / rel).is_file():
            return base / rel
    raise Abort(f"{kind} {name} of the assistant {assistant_dir.name} not found "
                f"(looked in {assistant_dir} and the masterspaces of the chain)")


def as_list(value):
    if value in (None, ""):
        return []
    return value if isinstance(value, list) else [value]


def render(ctx, query):
    name, (d, meta) = resolve(ctx, query)
    prompt = lookup(d, ctx, "prompt", meta["prompt"]) if meta.get("prompt") else None
    skills = [lookup(d, ctx, "skill", s) for s in as_list(meta.get("skills"))]
    found = classify(d)
    knowledge = [p for p in found[LOAD] if p != d / "ASSISTANT.md"]
    available = found[AVAILABLE]
    model = meta.get("model")
    model = ", ".join(f"{k}: {v}" for k, v in model.items()) if isinstance(model, dict) else (model or "")
    t = meta.get("title", name)
    out = [f'<aios-assistant name="{name}" title="{t}" src="{d}">\n',
           "<aios-assistant-meta>\n",
           f"description: {meta.get('description', '')}\n",
           f"model: {model or '-'}\n",
           f"tools: {', '.join(as_list(meta.get('tools'))) or '-'}\n",
           f"skills: {', '.join(as_list(meta.get('skills'))) or '-'}\n",
           "</aios-assistant-meta>\n"]

    def file(cls, p, text):
        out.append(f'<aios-file class="{cls}" src="{p}">\n')
        out.append(text if text.endswith("\n") or not text else text + "\n")
        out.append("</aios-file>\n")
    if prompt:
        file("prompt", prompt, prompt.read_text(encoding="utf-8"))
    file("assistant", d / "ASSISTANT.md", strip_frontmatter((d / "ASSISTANT.md").read_text(encoding="utf-8")))
    for p in knowledge:
        file("load", p, p.read_text(encoding="utf-8", errors="replace"))
    if available:
        out.append("<aios-available>\n")
        out += [f"- {p} — {title(p)}\n" for p in available]
        out.append("</aios-available>\n")
    for s in skills:
        file("skill", s, s.read_text(encoding="utf-8"))
    out.append(f'</aios-assistant name="{name}">\n')
    return "".join(out)
