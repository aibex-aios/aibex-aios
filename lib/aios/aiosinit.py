"""aios --init [<path>]: make a folder a project (spec 03, Initialisieren)."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

from . import config, context, paths, registry
from .ui import Abort, Plan, confirm, say, warn

COMMIT_MESSAGE = "AIOS: Projekt initialisiert"


def git(p, *args):
    return subprocess.run(["git", "-C", str(p), *args], capture_output=True, text=True)


def init(path=None):
    p = Path(os.path.abspath(path or paths.cwd()))
    if not p.is_dir():
        raise Abort(f"{p} is not a directory")
    cfg = config.load(p)
    if cfg.vault is None:
        raise Abort(f"{p} is not in a vault")
    if not cfg.aios:
        raise Abort(f"the vault {cfg.vault} is not activated; run: aios --activate v<version> {cfg.vault}")
    if p == cfg.vault:
        raise Abort("the vault root is the root project; aios --activate creates its @/")
    if (p / "@").is_dir():
        raise Abort(f"{p} is already a project (@/ exists)")

    plan = Plan()
    template = Path(__file__).resolve().parents[2] / "templates" / "gitignore"
    wanted = [line for line in template.read_text(encoding="utf-8").splitlines() if line.strip()]
    gi = p / ".gitignore"
    have = gi.read_text(encoding="utf-8").splitlines() if gi.is_file() else []
    missing = [line for line in wanted if line not in have]

    def create():
        for d in ("@", "@Memo"):
            (p / d).mkdir(exist_ok=True)
            (p / d / ".gitkeep").touch()
        if missing:
            text = "\n".join(have + missing) + "\n"
            gi.write_text(text, encoding="utf-8")
    plan.add("create @/ and @Memo/ (with .gitkeep)"
             + (f", .gitignore: {', '.join(missing)}" if missing else ""), create)

    top = git(p, "rev-parse", "--show-toplevel")
    is_root = top.returncode == 0 and Path(top.stdout.strip()).resolve() == p.resolve()
    if is_root:
        plan.add(f"{p} is already a git repository, no git init")
    else:
        if top.returncode == 0:
            plan.add(f"note: {p} lies inside the git repository {top.stdout.strip()}; "
                     f"git init creates a nested repository")

        def git_init():
            r = git(p, "init", "-q")
            if r.returncode:
                raise Abort(f"git init failed: {r.stderr.strip()}")
            git(p, "symbolic-ref", "HEAD", "refs/heads/main")
        plan.add("git init (branch main)", git_init)

    def register():
        s = registry.Sync(context.Context(p))
        for problem in s.problems:
            warn(problem)
        if s:
            s.apply()
            say(f"   registered: {s.summary()}")
    plan.add("register the project skills", register)

    def commit():
        files = [f for f in (".gitignore", "@/.gitkeep", "@Memo/.gitkeep") if (p / f).exists()]
        git(p, "add", "--", *files)
        r = git(p, "commit", "-q", "-m", COMMIT_MESSAGE, "--", *files)
        if r.returncode:
            warn(f"first commit failed ({r.stderr.strip() or r.stdout.strip()}); commit by hand")
    plan.add(f"first commit \"{COMMIT_MESSAGE}\": .gitignore, @/.gitkeep, @Memo/.gitkeep", commit)

    say(f"=> initialize the project {p}")
    confirm(plan, "initialize?", "initialization cancelled")
    say(f"=> {p} is a project")
    say("   the master context of the new project applies completely from the next chat")
    return 0
