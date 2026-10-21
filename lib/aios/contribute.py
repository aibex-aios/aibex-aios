"""aios --contribute: files back to the repo of a package as a pull request (spec 06, Rückfluss;
V0.4, memos 11, 19, 55).

A contribution goes into a new branch contrib/<user>/<date>-<short name> of the package repo
(a fork without write access), the files into contrib/<user>/<file name>, and becomes a pull
request against the default branch with gh. AIOS never pushes to the default branch (P5).
"""

from __future__ import annotations

import datetime
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from . import config, hub, paths, ui
from .ui import Abort, Plan, say

GITHUB = re.compile(r"^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$")


def run(*cmd, cwd=None):
    return subprocess.run(list(cmd), cwd=cwd, capture_output=True, text=True)


def locked(name):
    """(project, entry) of the nearest lock.yaml of the chain that holds the package."""
    import yaml
    for d in config.chain_dirs(paths.cwd()):
        f = d / ".aios" / "lock.yaml"
        if f.is_file():
            data = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
            e = (data.get("packages") or {}).get(name)
            if e:
                return d, e
    raise Abort(f"{name} is not fetched in a project of the chain (no entry in lock.yaml)")


def slug(repo):
    """owner/name of a repo for gh: from a GitHub URL, else the last two parts of the path."""
    m = GITHUB.match(repo)
    if m:
        return f"{m.group(1)}/{m.group(2)}"
    parts = repo.rstrip("/").split("/")
    return "/".join(parts[-2:])


def gh(*args):
    if not shutil.which("gh"):
        raise Abort("aios --contribute needs gh (GitHub CLI); nothing was created")
    return run("gh", *args)


def short(name):
    return re.sub(r"[^a-z0-9]+", "-", Path(name).stem.lower()).strip("-") or "beitrag"


def contribute(files, to, message=None):
    if not files:
        raise Abort("usage: aios --contribute <file>... --to <package> [--message <text>]")
    srcs = [Path(os.path.abspath(f)) for f in files]
    missing = [str(p) for p in srcs if not p.is_file()]
    if missing:
        raise Abort("no such file: " + ", ".join(missing))
    project, e = locked(to)
    repo = e.get("from") or e.get("repo")
    if not repo:
        raise Abort(f"lock.yaml of {project} has no repo for {to}")
    if gh("auth", "status").returncode != 0:
        raise Abort("gh is not logged in (gh auth login); nothing was created")
    user = gh("api", "user", "--jq", ".login").stdout.strip()
    if not user:
        raise Abort("cannot read the GitHub user from gh; nothing was created")
    s = slug(repo)
    perm = gh("api", f"repos/{s}", "--jq", ".permissions.push").stdout.strip()
    fork = perm != "true"
    day = datetime.date.today().isoformat()
    branch = f"contrib/{user}/{day}-{short(srcs[0].name)}"
    title = message or f"Beitrag: {', '.join(p.name for p in srcs)} von {user}"
    body = (f"Beitrag zum Paket `{to}` mit `aios --contribute`.\n\n"
            f"- geholte Version: {e.get('version')} (Commit {str(e.get('commit') or '')[:12]})\n"
            f"- Dateien: " + ", ".join(f"`contrib/{user}/{p.name}`" for p in srcs) + "\n\n"
            "Der Maintainer prüft den Beitrag und übernimmt ihn in den Inhalt des Pakets "
            "(beim Taschenrechner nach `knowledge/@!Funktionstasten/`).\n")
    plan = Plan()
    lines = [f"repo {repo}" + (f" (fork for {user}, no write access)" if fork else ""),
             f"branch {branch}"] + [f"{p} -> contrib/{user}/{p.name}" for p in srcs] + \
            [f"pull request \"{title}\" against the default branch"]
    result = {}
    plan.add("contribute:\n         " + "\n         ".join(lines),
             lambda: result.setdefault("url", send(repo, s, fork, user, branch, srcs, title, body)))
    if ui.MODE != "yes":
        say(f"=> contribute to {to}")
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> pull request: {result.get('url', '')}".rstrip())
    return 0


def send(repo, s, fork, user, branch, srcs, title, body):
    tmp = Path(tempfile.mkdtemp(prefix="aios-contribute."))
    try:
        work = tmp / "repo"
        r = run("git", "clone", "-q", repo, str(work))
        if r.returncode:
            raise Abort(f"cannot clone {repo}: {r.stderr.strip()}")
        base = run("git", "rev-parse", "--abbrev-ref", "origin/HEAD", cwd=work).stdout.strip()
        base = base.split("/", 1)[1] if "/" in base else "main"
        push = "origin"
        if fork:
            r = gh("repo", "fork", s, "--clone=false")
            if r.returncode:
                raise Abort(f"cannot fork {s}: {r.stderr.strip()}")
            run("git", "remote", "add", "fork", hub.github(user) + "/" + s.split("/")[1], cwd=work)
            push = "fork"
        name, n = branch, 1
        while run("git", "ls-remote", "--exit-code", "--heads", push, name, cwd=work).returncode == 0:
            n += 1
            name = f"{branch}-{n}"
        run("git", "checkout", "-q", "-b", name, cwd=work)
        target = work / "contrib" / user
        target.mkdir(parents=True, exist_ok=True)
        for p in srcs:
            shutil.copyfile(p, target / p.name)
        run("git", "add", "--", f"contrib/{user}", cwd=work)
        r = run("git", "commit", "-q", "-m", title, cwd=work)
        if r.returncode:
            raise Abort(f"commit failed: {(r.stderr or r.stdout).strip()}")
        r = run("git", "push", "-q", push, name, cwd=work)
        if r.returncode:
            raise Abort(f"push failed: {r.stderr.strip()}")
        head = f"{user}:{name}" if fork else name
        r = gh("pr", "create", "--repo", s, "--base", base, "--head", head, "--title", title, "--body", body)
        if r.returncode:
            raise Abort(f"gh pr create failed: {r.stderr.strip()}; the branch {name} is pushed")
        return r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def command(args):
    files, to, message, i = [], None, None, 0
    while i < len(args):
        a = args[i]
        if a in ("--to", "--message") and i + 1 < len(args):
            if a == "--to":
                to = args[i + 1]
            else:
                message = args[i + 1]
            i += 2
            continue
        if a.startswith("--"):
            raise Abort(f"unexpected argument {a}")
        files.append(a)
        i += 1
    if not to:
        raise Abort("usage: aios --contribute <file>... --to <package> [--message <text>]")
    return contribute(files, to, message)
