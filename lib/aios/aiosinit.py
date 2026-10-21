"""aios --init [<path>]: make a folder a project or complete a project (spec 05, Initialisieren).

Only what is missing of the structure S1-S4 is done; the steps are shared with
aios --activate at the vault root (spec 04).
"""

from __future__ import annotations

import os
import re
from pathlib import Path

from . import config, context, paths, project, registry, ui
from .ui import Abort, Plan, say, warn

NEW = "AIOS: Projekt initialisiert"
COMPLETED = "AIOS: Projekt ergänzt"
ASSISTANT = re.compile(r"^[a-z0-9][a-z0-9-]*$")


class NameViolation(Exception):
    """A name that violates the name rule, without --name or --accept-name (exit 2)."""


def git(p, *args):
    return project.git(p, *args)


def existing(p):
    while not p.exists():
        p = p.parent
    return p


class Steps:
    """The missing parts of the structure of p as plan steps, and the commit of what AIOS wrote."""

    def __init__(self, p, plan, root=False):
        self.p, self.plan, self.root = p, plan, root
        self.written = []                           # files to commit in the project
        self.taken = []                             # files taken over from the repo above (A14)
        self.new_repo = False
        self.changes = False

    def act(self, text, action):
        self.plan.add(text, action)
        self.changes = True

    def structure(self):
        p = self.p
        if not (p / "@").is_dir():
            def masterspace():
                (p / "@").mkdir(parents=True, exist_ok=True)
                (p / "@" / ".gitkeep").touch()
                self.written.append("@/.gitkeep")
            self.act("create @/ (with .gitkeep)", masterspace)
        if not project.own_repo(p):
            self.new_repo = True

            def git_init():
                p.mkdir(parents=True, exist_ok=True)
                r = git(p, "init", "-q")
                if r.returncode:
                    raise Abort(f"git init failed: {r.stderr.strip()}")
                git(p, "symbolic-ref", "HEAD", "refs/heads/main")
            self.act("git init (branch main)", git_init)
        missing = project.missing_gitignore_lines(p) if p.exists() else project.template_lines()
        if missing:
            def gitignore():
                gi = p / ".gitignore"
                have = gi.read_text(encoding="utf-8").splitlines() if gi.is_file() else []
                gi.write_text("\n".join(have + missing) + "\n", encoding="utf-8")
                self.written.append(".gitignore")
            self.act(".gitignore: " + ", ".join(missing), gitignore)
        if not self.root:
            self.parent()

    def parent(self):
        """S4: exclude the project in the repo above and commit only that there."""
        pr = project.parent_repo(self.p)
        if pr is None or pr.ok:
            return
        what = []
        if not pr.ignored:
            what.append(f"/{pr.rel}/ in {pr.root / '.gitignore'}")
        if pr.tracked:
            what.append(f"git rm -r --cached {pr.rel} ({len(pr.tracked)} files, they stay on disk "
                        f"and are committed in the project)")
            self.taken = [f[len(pr.rel) + 1:] for f in pr.tracked if f.startswith(pr.rel + "/")]
        message = f"AIOS: {pr.rel} als eigenes Projekt ausgeschlossen"

        def exclude():
            staged = git(pr.root, "diff", "--cached", "--name-only").stdout.strip()
            if not pr.ignored:
                gi = pr.root / ".gitignore"
                have = gi.read_text(encoding="utf-8") if gi.is_file() else ""
                gi.write_text(have + ("" if not have or have.endswith("\n") else "\n") + f"/{pr.rel}/\n",
                              encoding="utf-8")
            if pr.tracked:
                git(pr.root, "rm", "-r", "-q", "--cached", "--", pr.rel)
            if staged:
                warn(f"the repo {pr.root} has staged changes; commit the exclusion there by hand")
                return
            git(pr.root, "add", "--", ".gitignore")
            if git(pr.root, "diff", "--cached", "--quiet").returncode == 0:
                return                                      # nothing changed there (A16)
            r = git(pr.root, "commit", "-q", "-m", message)
            if r.returncode:
                warn(f"commit in {pr.root} failed ({r.stderr.strip() or r.stdout.strip()}); commit by hand")
        self.act(f"repo above {pr.root}: " + "; ".join(what) + f"; commit \"{message}\"", exclude)

    def assistant(self, value):
        file = self.p / ".aios" / "config.yaml"
        current = None
        if file.is_file():
            try:
                current = config.read(file).get("assistant")
            except config.ConfigError as e:
                raise Abort(f"{e}; fix the file first")
        if current == value:
            return

        def write():
            config.set_key(file, "assistant", value)
            self.written.append(".aios/config.yaml")
        self.act(f"assistant: {value} in {file}", write)

    def register(self):
        p = self.p

        def run():
            s = registry.Sync(context.Context(p))
            for problem in s.problems:
                warn(problem)
            if s:
                s.apply()
                if ui.MODE != "yes":
                    say(f"   registered: {s.summary()}")
        self.plan.add("register the project skills", run)

    def commit(self, extra=()):
        def run():
            files = sorted(set(self.written) | set(self.taken) | set(extra))
            files = [f for f in files if (self.p / f).exists()]
            if files:                                       # ignored files cannot be added
                ignored = set(git(self.p, "check-ignore", "--", *files).stdout.splitlines())
                files = [f for f in files if f not in ignored]
            if not files:
                return
            git(self.p, "add", "--", *files)
            if git(self.p, "diff", "--cached", "--quiet", "--", *files).returncode == 0:
                return                                      # rewritten with the same content (A16)
            r = git(self.p, "commit", "-q", "-m", NEW if self.new_repo else COMPLETED, "--", *files)
            if r.returncode:
                warn(f"commit failed ({r.stderr.strip() or r.stdout.strip()}); commit by hand")
        self.plan.add(f"commit \"{NEW if self.new_repo else COMPLETED}\" with the files AIOS wrote"
                      + (" and the files taken over from the repo above" if self.taken else ""), run)


def move(src, dst):
    """Rename src to dst, via an intermediate name if only the case differs (macOS, A13)."""
    if dst.exists() and os.path.samefile(src, dst):
        tmp = src.parent / (src.name + ".aios-rename")
        src.rename(tmp)
        tmp.rename(dst)
    else:
        src.rename(dst)


def run(plan, title, done):
    """Plan, one confirmation, execute; with --yes only the result (spec 05)."""
    if ui.MODE == "yes":
        plan.run()
    else:
        say(title)
        ui.confirm(plan, "go on?", "cancelled")
    for line in done:
        say(line)


def init(path=None, assistant=None, name=None, accept_name=False):
    p = Path(os.path.abspath(path or paths.cwd()))
    rename = None
    if name:
        if "/" in name or not name.strip():
            raise Abort(f"{name} is not a folder name")
        if p.exists() and p.name != name:
            rename = (p, p.parent / name)
        p = p.parent / name
    if p.exists() and not p.is_dir():
        raise Abort(f"{p} is not a directory")
    if rename and p.exists() and not os.path.samefile(rename[0], p):
        raise Abort(f"{p} exists already")
    cfg = config.load(existing(rename[0] if rename else p))
    if cfg.vault is None:
        raise Abort(f"{p} is not in a vault")
    if not cfg.aios:
        raise Abort(f"the vault {cfg.vault} is not activated; run: aios --activate v<version> {cfg.vault}")
    if assistant is not None and assistant not in ("none", "inherit") and not ASSISTANT.match(assistant):
        raise Abort(f"{assistant} is not an assistant name (or none, inherit)")
    root = p.exists() and Path(os.path.realpath(p)) == cfg.vault

    plan = Plan()
    violation = None
    if not root:
        n = project.check_name(p)
        if not n.ok and not accept_name:
            violation = n
            for problem in n.problems:
                plan.add(f"name {n.name}: {problem}")
            plan.add(f"proposal: {n.proposal} (--name {n.proposal}; keep the name with --accept-name)")
    if rename:
        plan.add(f"rename {rename[0]} -> {rename[1].name}", lambda: move(*rename))
    elif not p.exists():
        plan.add(f"create the folder {p}", lambda: p.mkdir(parents=True))

    steps = Steps(p, plan, root=root)
    steps.structure()
    if assistant is not None and assistant != "inherit":
        steps.assistant(assistant)
    if not steps.changes and not rename and p.exists():
        say(f"=> {p} is a complete project, nothing to do")
        return 0
    steps.register()
    steps.commit()

    if violation is not None and ui.MODE != "plan":
        say(f"=> the name {violation.name} violates the name rule: " + "; ".join(violation.problems))
        say(f"   proposal: {violation.proposal}")
        say("   run again with --name <name> (proposal) or --accept-name (keep the name)")
        raise NameViolation()
    verb = "initialize the project" if steps.new_repo else "complete the project"
    done = [f"=> {p} is a project"]
    if ui.MODE != "yes":
        done.append("   the master context and the skills apply completely from the next chat")
    run(plan, f"=> {verb} {p}", done)
    return 0
