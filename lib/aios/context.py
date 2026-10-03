"""aios-context - master context (spec 02): vault, chain, classes, output, id, part files.

Standard library only. Without activation (legacy mode) the calls go to ai-brain.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

from . import config, paths, version

LOAD, AVAILABLE, HIDDEN = 0, 1, 2                   # K2: order Laden < Verfuegbar < Verborgen
CLASS_NAMES = {LOAD: "load", AVAILABLE: "available", HIDDEN: "hidden"}
PART_LIMIT = 40000                                  # characters per part file (spec 02)
CACHE_DAYS = 7
HEADING = re.compile(r"^#{1,6}\s+(.+?)\s*#*\s*$")

LATER = {}


# ---------------------------------------------------------------------------
# classes and the master context
# ---------------------------------------------------------------------------

def own_class(name):
    """Class from the prefix of a name, None without prefix; @@ and @! before @."""
    if name.startswith("@!"):
        return HIDDEN
    if name.startswith("@@"):
        return AVAILABLE
    if name.startswith("@"):
        return LOAD
    return None


def chain(cwd):
    """Masterspaces D/@ from the vault root down to cwd (spec 02, Kette)."""
    return [d / "@" for d in reversed(config.chain_dirs(cwd)) if (d / "@").is_dir()]


def title(file):
    """First heading of a markdown file, the file name without heading."""
    try:
        with open(file, encoding="utf-8", errors="replace") as f:
            in_front = False
            for no, line in enumerate(f):
                line = line.rstrip("\n")
                if no == 0 and line.strip() == "---":
                    in_front = True
                    continue
                if in_front:
                    in_front = line.strip() != "---"
                    continue
                m = HEADING.match(line)
                if m:
                    return m.group(1)
    except OSError:
        pass
    return Path(file).stem


def classify(masterspace):
    """{LOAD: [...], AVAILABLE: [...], HIDDEN: [...]} of the .md files below masterspace.

    K1 inherit, K2 strictest class on the path, K3 files directly in @/ load,
    K4 only .md; entries starting with '.' are skipped.
    """
    found = {LOAD: [], AVAILABLE: [], HIDDEN: []}

    def walk(d, cls):
        try:
            entries = sorted(os.scandir(d), key=lambda e: e.name)
        except OSError:
            return
        for e in entries:
            if e.name.startswith("."):
                continue
            if e.is_dir(follow_symlinks=False):
                own = own_class(e.name)
                walk(e.path, cls if own is None else max(cls, own))
            elif e.is_file() and e.name.endswith(".md"):
                found[cls].append(Path(e.path))

    walk(masterspace, LOAD)
    return found


class Context:
    """Master context of one working directory in an activated vault."""

    def __init__(self, cwd):
        self.cwd = Path(os.path.realpath(cwd))      # physical: one id however cwd was reached
        self.cfg = config.load(self.cwd)
        self.vault = self.cfg.vault
        self.masterspaces = chain(self.cwd) if self.vault else []
        self.loaded, self.available, self.hidden = [], [], []
        for ms in self.masterspaces:
            found = classify(ms)
            self.loaded += found[LOAD]
            self.available += found[AVAILABLE]
            self.hidden += found[HIDDEN]
        self.texts = [p.read_text(encoding="utf-8", errors="replace") for p in self.loaded]
        self.titles = [title(p) for p in self.available]

    @property
    def mode(self):
        if self.vault is None:
            return "none"
        return "aios" if self.cfg.aios else "legacy"

    @property
    def project(self):
        """cwd if it has @/, else the nearest directory above with @/ (spec 02)."""
        return self.masterspaces[-1].parent if self.masterspaces else None

    @property
    def initialized(self):
        return (self.cwd / "@").is_dir()

    @property
    def id(self):
        """K5: cwd, paths and contents of the loaded files, paths of the available files."""
        h = hashlib.sha256()
        h.update(f"cwd {self.cwd}\n".encode())
        for p, text in zip(self.loaded, self.texts):
            h.update(f"load {p}\n".encode())
            h.update(text.encode())
            h.update(b"\n")
        for p in self.available:
            h.update(f"available {p}\n".encode())
        return h.hexdigest()[:8]

    def render(self):
        ident = self.id
        out = [f'<aios-context id="{ident}" files="{len(self.loaded)}" cwd="{self.cwd}" '
               f'version="{version()}">\n']
        for p, text in zip(self.loaded, self.texts):
            out.append(f'<aios-file class="load" src="{p}">\n')
            out.append(text if text.endswith("\n") or not text else text + "\n")
            out.append("</aios-file>\n")
        if self.available:
            out.append("<aios-available>\n")
            out += [f"- {p} — {t}\n" for p, t in zip(self.available, self.titles)]
            out.append("</aios-available>\n")
        out.append(f'</aios-context id="{ident}">\n')
        return "".join(out)


# ---------------------------------------------------------------------------
# part files
# ---------------------------------------------------------------------------

def split(text, limit=PART_LIMIT):
    """Parts of at most limit characters, cut at line ends (a longer line is a part of its own)."""
    parts, cur, n = [], [], 0
    for line in text.splitlines(keepends=True):
        if cur and n + len(line) > limit:
            parts.append("".join(cur))
            cur, n = [], 0
        cur.append(line)
        n += len(line)
    if cur:
        parts.append("".join(cur))
    return parts


def clean_cache(keep):
    cache = paths.cache_dir()
    if not cache.is_dir():
        return
    limit = time.time() - CACHE_DAYS * 86400
    for d in cache.iterdir():
        if d.is_dir() and d.name != keep and d.stat().st_mtime < limit:
            shutil.rmtree(d, ignore_errors=True)


def load(ctx):
    """Write the part files once per id; return their paths."""
    ident = ctx.id
    d = paths.cache_dir() / ident
    if not (d / ".complete").is_file():
        shutil.rmtree(d, ignore_errors=True)
        d.mkdir(parents=True)
        for i, part in enumerate(split(ctx.render()), 1):
            (d / f"part-{i}.md").write_text(part, encoding="utf-8")
        (d / ".complete").touch()
    os.utime(d)                                     # in use: not cleaned for another 7 days
    clean_cache(ident)
    return sorted(d.glob("part-*.md"), key=lambda p: int(p.stem.split("-")[1]))


def load_message(ctx, parts):
    ident = ctx.id
    lines = [f"AIOS-CONTEXT-LOAD id={ident} files={len(ctx.loaded)} parts={len(parts)} cwd={ctx.cwd}",
             "Read each of the following part files completely (Read tool), in order:"]
    lines += [f"   {p}" for p in parts]
    lines.append(f'The master context is loaded once </aios-context id="{ident}"> '
                 f"(end of the last part) has been read.")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# hooks (spec 02, Hooks)
# ---------------------------------------------------------------------------

def hook_input():
    """(cwd from the hook JSON on stdin or None, raw stdin)."""
    if sys.stdin is None or sys.stdin.isatty():
        return None, ""
    raw = sys.stdin.read()
    try:
        d = json.loads(raw or "{}").get("cwd")
    except (ValueError, AttributeError):
        d = None
    return (d if d and os.path.isdir(d) else None), raw


def hook_source(raw):
    """source of the SessionStart JSON (startup, resume, clear, compact); startup without JSON."""
    try:
        return json.loads(raw or "{}").get("source") or "startup"
    except (ValueError, AttributeError):
        return "startup"


def uninitialized_message(ctx):
    choices = (f"(title, assistant, initialize or continue in the project {ctx.project})"
               if ctx.project else "(title, assistant, initialize)")
    return (f"PROJECT-UNINITIALIZED: {ctx.cwd} has no local masterspace (@/). Before your first\n"
            f"answer, run `aios --init \"{ctx.cwd}\" --plan` and show the dialog \"Projekt\n"
            f"initialisieren\" {choices}.\n"
            f"Give no other answer until the user decides.")


def incomplete_message(ctx, gaps):
    return (f"PROJECT-INCOMPLETE: {ctx.cwd} is an AIOS project but lacks: "
            + ", ".join(g.text for g in gaps) + ".\n"
            f"Before your first answer, offer the user to complete it with\n"
            f"`aios --init \"{ctx.cwd}\"` (show the plan from --plan, run with --yes after yes).\n"
            f"If the user declines, continue normally and do not offer it again.")


def mandatory_message(ctx, size, limit):
    ident = ctx.id
    return (f"AIOS-CONTEXT-MANDATORY: the master context of this project is too large\n"
            f" for direct injection ({size} > {limit} characters). Before your first\n"
            f" answer, tell the user \"Lade Master-Kontext\", read every part file listed\n"
            f" below completely with the Read tool, then tell the user\n"
            f" \"Master-Kontext geladen (id {ident})\".")


def check_message(ctx):
    ident = ctx.id
    return (f"AIOS-CONTEXT-CHECK: expected id={ident} (files={len(ctx.loaded)}, cwd={ctx.cwd}).\n"
            f" Before answering, verify that BOTH exact markers <aios-context id=\"{ident}\"\n"
            f" and </aios-context id=\"{ident}\"> are present in your context (memory or a\n"
            f" summary of earlier loading does not count). If not: tell the user\n"
            f" \"Lade Master-Kontext\", run `aios-context --load \"{ctx.cwd}\"` via Bash, read every\n"
            f" listed part file completely with the Read tool, then tell the user\n"
            f" \"Master-Kontext geladen (id {ident})\". If both markers are present, do nothing.")


def session(ctx, source="startup"):
    """SessionStart: warnings, PROJECT-UNINITIALIZED or (at startup) PROJECT-INCOMPLETE,
    master context inline or part files."""
    from . import project, registry
    out = [f"AIOS-WARNING: {w}" for w in ctx.cfg.warnings]
    if ctx.initialized:                             # registration for the next chat (spec 03)
        s = registry.Sync(ctx)
        out += [f"AIOS-WARNING: {p}" for p in s.problems]
        if s:
            s.apply()
            out.append(f"AIOS-SKILLS: {s.summary()} — wirksam ab dem nächsten Chat")
    if not ctx.initialized:
        out.append(uninitialized_message(ctx))
    elif source == "startup":                       # consistency check, first start only (spec 02)
        gaps = project.check(ctx.cwd)
        if gaps:
            out.append(incomplete_message(ctx, gaps))
    text = ctx.render()
    limit = ctx.cfg.inline_limit
    if len(text) <= limit:
        out.append("AIOS-CONTEXT (loaded automatically by SessionStart hook):")
        out.append(text.rstrip("\n"))
    else:
        out.append(mandatory_message(ctx, len(text), limit))
        out.append(load_message(ctx, load(ctx)))
    return "\n".join(out)


# ---------------------------------------------------------------------------
# legacy mode and command line
# ---------------------------------------------------------------------------

def legacy(cmd, cwd, stdin=""):
    """Without activation aios-context behaves like ai-brain (spec 02, Legacy-Modus)."""
    brain = shutil.which("ai-brain")
    if cmd == "--id":
        out = subprocess.run([brain, "--id"], capture_output=True, text=True, cwd=cwd).stdout.strip() \
            if brain else ""
        print(f"{out} mode=legacy" if out.startswith("id=") else f"id=- files=0 cwd={cwd} mode=legacy")
        return 0
    if not brain:
        return 0
    r = subprocess.run([brain, cmd], input=stdin, text=True, capture_output=True, cwd=cwd)
    sys.stdout.write(r.stdout)
    return 0


USAGE = ("usage: aios-context --session | --advise | --context [<path>] | --load [<path>] | --id [<path>]"
         " | --list [<path>] | --sync [--yes|--plan] | --assistant <name> | --assistants"
         " | --assignment [<path>] [--session <id>]")


def main(argv):
    if argv and argv[0] in LATER:
        print(f"aios-context {argv[0]}: not implemented yet (step {LATER[argv[0]]})", file=sys.stderr)
        return 2
    cmd = argv[0] if argv else ""
    if cmd == "--sync" and argv[1:] in ([], ["--yes"], ["--plan"]):
        from . import registry, ui
        if argv[1:] == ["--plan"]:
            ui.MODE = "plan"
        return registry.register(paths.cwd(), yes=argv[1:] == ["--yes"])
    if cmd in ("--assistant", "--assistants") and len(argv) == (2 if cmd == "--assistant" else 1):
        return assistant_cmd(argv)
    if cmd == "--assignment":
        return assignment_cmd(argv[1:])
    if cmd in ("--session", "--advise") and len(argv) == 1:
        try:
            return hook(cmd)
        except Exception as e:                      # noqa: BLE001 - a hook never breaks the session
            print(f"AIOS-WARNING: aios-context {cmd} failed: {e}")
            return 0
    if cmd not in ("--context", "--load", "--id", "--list") or len(argv) > 2:
        print(USAGE, file=sys.stderr)
        return 1
    cwd = os.path.abspath(argv[1]) if len(argv) == 2 else paths.cwd()
    if not os.path.isdir(cwd):
        print(f"aios-context: {cwd} is not a directory", file=sys.stderr)
        return 1
    ctx = Context(cwd)
    if cmd == "--list":
        from .skills import listing
        print("\n".join(listing(ctx)))
        return 0
    if ctx.mode == "none":
        if cmd == "--id":
            print(f"id=- files=0 cwd={ctx.cwd} mode=none")
        else:
            print("aios-context: not in a vault, no master context", file=sys.stderr)
        return 0
    if ctx.mode == "legacy":
        return legacy(cmd, cwd)
    for w in ctx.cfg.warnings:
        print(f"aios-context: warning: {w}", file=sys.stderr)
    if cmd == "--id":
        print(f"id={ctx.id} files={len(ctx.loaded)} cwd={ctx.cwd} mode=aios-{version()}")
    elif cmd == "--context":
        sys.stdout.write(ctx.render())
    else:
        print(load_message(ctx, load(ctx)))
    return 0


def assistant_cmd(argv):
    """--assistant <name>: context of an assistant; --assistants: assistants of the chain (spec 03)."""
    from . import assistant
    from .ui import Abort
    ctx = Context(paths.cwd())
    if ctx.mode != "aios":
        print("aios-context: assistants need a vault activated with AIOS (aios --activate)", file=sys.stderr)
        return 1
    try:
        if argv[0] == "--assistants":
            print("\n".join(assistant.available_lines(*assistant.assistants(ctx))))
        else:
            sys.stdout.write(assistant.render(ctx, argv[1]))
    except Abort as e:
        print(f"*** aios-context {argv[0]}: {e}", file=sys.stderr)
        return 1
    return 0


def assignment_cmd(args):
    """--assignment [<path>] [--session <id>]: assistant=<name|none> from=<config.yaml|session|->
    (spec 02); with --session the assistant of the session from its marker, if there is one."""
    from . import session
    sid, rest = None, list(args)
    if "--session" in rest:
        i = rest.index("--session")
        if i + 1 >= len(rest):
            print(USAGE, file=sys.stderr)
            return 1
        sid = rest[i + 1]
        del rest[i:i + 2]
    if len(rest) > 1 or any(r.startswith("--") for r in rest):
        print(USAGE, file=sys.stderr)
        return 1
    cwd = os.path.abspath(rest[0]) if rest else paths.cwd()
    if not os.path.isdir(cwd):
        print(f"aios-context: {cwd} is not a directory", file=sys.stderr)
        return 1
    if sid is not None:
        try:
            marker = session.read(sid)
        except session.BadId as e:
            print(f"*** aios-context --assignment: {e}", file=sys.stderr)
            return 1
        if marker:
            print(f"assistant={marker['assistant']} from=session")
            return 0
    cfg = config.load(cwd)
    name, source = cfg.assignment if cfg.vault and cfg.aios else ("none", None)
    print(f"assistant={name} from={source or '-'}")
    return 0


def hook(cmd):
    given, raw = hook_input()
    cwd = given or paths.cwd()
    ctx = Context(cwd)
    if ctx.mode == "none":
        return 0
    if ctx.mode == "legacy":
        return legacy(cmd, cwd, raw)
    print(session(ctx, hook_source(raw)) if cmd == "--session" else check_message(ctx))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
