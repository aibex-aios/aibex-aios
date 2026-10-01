"""aios-context - master context (spec 02): vault, chain, classes, output, id, part files.

Standard library only. Without activation (legacy mode) the calls go to ai-brain.
"""

from __future__ import annotations

import hashlib
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

LATER = {"--session": 6, "--advise": 6, "--sync": 7, "--list": 8, "--agent": 10}


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
        self.cwd = Path(os.path.abspath(cwd))
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
# legacy mode and command line
# ---------------------------------------------------------------------------

def legacy(argv, cwd):
    """Without activation aios-context behaves like ai-brain (spec 02, Legacy-Modus)."""
    brain = shutil.which("ai-brain")
    if argv == ["--id"]:
        out = subprocess.run([brain, "--id"], capture_output=True, text=True, cwd=cwd).stdout.strip() \
            if brain else ""
        print(f"{out} mode=legacy" if out.startswith("id=") else f"id=- files=0 cwd={cwd} mode=legacy")
        return 0
    if not brain:
        return 0
    sys.stdout.flush()
    os.execv(brain, [brain, *argv])


def main(argv):
    cwd = paths.cwd()
    if argv and argv[0] in LATER:
        print(f"aios-context {argv[0]}: not implemented yet (step {LATER[argv[0]]})", file=sys.stderr)
        return 2
    if argv not in (["--context"], ["--load"], ["--id"]):
        print("usage: aios-context --context | --load | --id (aios-context -? for all options)", file=sys.stderr)
        return 1
    ctx = Context(cwd)
    if ctx.mode == "none":
        if argv == ["--id"]:
            print(f"id=- files=0 cwd={ctx.cwd} mode=none")
        else:
            print("aios-context: not in a vault, no master context", file=sys.stderr)
        return 0
    if ctx.mode == "legacy":
        return legacy(argv, cwd)
    for w in ctx.cfg.warnings:
        print(f"aios-context: warning: {w}", file=sys.stderr)
    if argv == ["--id"]:
        print(f"id={ctx.id} files={len(ctx.loaded)} cwd={ctx.cwd} mode=aios-{version()}")
    elif argv == ["--context"]:
        sys.stdout.write(ctx.render())
    else:
        print(load_message(ctx, load(ctx)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
