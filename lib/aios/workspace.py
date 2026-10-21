"""aios --workspace: projects of a workspace as git checkouts (spec 06, Workspaces; V0.4, memos 10,
12, 18, 57).

A workspace is a project with .aios/workspace.yaml listing repos with revision and path. They are
cloned nested below the root project and excluded in the repo above, with a commit of only that
line (I9). update moves a branch only by fast-forward and never drops changes (P4); a tag or a
commit is checked out as the local branch ws/<revision>, never as a detached HEAD.
"""

from __future__ import annotations

import datetime
import os
from dataclasses import dataclass, field
from pathlib import Path

from . import config, paths, project, ui
from .ui import Abort, Plan, say, warn

FILE = Path(".aios") / "workspace.yaml"


@dataclass
class Item:
    name: str
    url: str
    revision: str
    path: str
    groups: list = field(default_factory=list)


def git(p, *args):
    return project.git(p, *args)


# ---------------------------------------------------------------------------
# workspace.yaml
# ---------------------------------------------------------------------------

def find_root(start):
    """The nearest directory at or above start with .aios/workspace.yaml, or None."""
    p = Path(os.path.realpath(start))
    for d in [p, *p.parents]:
        if (d / FILE).is_file():
            return d
        if d.name.startswith("§"):
            break
    return None


def load(root):
    """[Item] of root/.aios/workspace.yaml, checked (spec 06); import is reported and passed over."""
    import yaml
    f = Path(root) / FILE
    try:
        data = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as e:
        raise Abort(f"{f}: {e}")
    if not isinstance(data, dict):
        raise Abort(f"{f}: expected a mapping with projects")
    remotes = data.get("remotes") or {}
    items, seen = [], set()
    for i, p in enumerate(data.get("projects") or [], 1):
        where = f"{f}: project {i}"
        if not isinstance(p, dict):
            raise Abort(f"{where} is not a mapping")
        name = p.get("name")
        if not name or name in seen:
            raise Abort(f"{where}: name missing or not unique")
        seen.add(name)
        if ("remote" in p) == ("repo" in p):
            raise Abort(f"{where} ({name}): exactly one of remote and repo")
        if "remote" in p:
            if p["remote"] not in remotes:
                raise Abort(f"{where} ({name}): unknown remote {p['remote']}")
            url = str(remotes[p["remote"]]).rstrip("/") + "/" + name
        else:
            url = str(p["repo"])
        rev, path = str(p.get("revision") or ""), str(p.get("path") or "")
        if not rev:
            raise Abort(f"{where} ({name}): revision missing")
        if not path or os.path.isabs(path) or ".." in Path(path).parts:
            raise Abort(f"{where} ({name}): path must be relative, below the root, without ..")
        if "import" in p:
            warn(f"{where} ({name}): import has no effect in v0.4, passed over")
        groups = p.get("groups") or []
        items.append(Item(name, url, rev, path, list(groups) if isinstance(groups, list) else [groups]))
    return items


def selected(items, groups):
    """Without groups all items; with groups the items of these groups and those without a group."""
    if not groups:
        return items
    return [i for i in items if not i.groups or set(i.groups) & set(groups)]


# ---------------------------------------------------------------------------
# one project: clone, exclusion, update
# ---------------------------------------------------------------------------

def kind(d, rev):
    """branch or commit (tag or SHA) of a revision in the clone d."""
    if git(d, "rev-parse", "--verify", "-q", f"refs/remotes/origin/{rev}").returncode == 0:
        return "branch"
    return "commit"


def exclude(d):
    """Exclude d in the repo above and commit only that line (spec 05 S4, I9)."""
    pr = project.parent_repo(d)
    if pr is None or pr.ignored:
        return
    gi = pr.root / ".gitignore"
    have = gi.read_text(encoding="utf-8") if gi.is_file() else ""
    gi.write_text(have + ("" if not have or have.endswith("\n") else "\n") + f"/{pr.rel}/\n", encoding="utf-8")
    git(pr.root, "add", "--", ".gitignore")
    r = git(pr.root, "commit", "-q", "-m", f"AIOS: {pr.rel} als Projekt des Workspace ausgeschlossen",
            "--", ".gitignore")
    if r.returncode:
        warn(f"commit in {pr.root} failed ({(r.stderr or r.stdout).strip()}); commit the exclusion by hand")


def clone(item, d):
    d.parent.mkdir(parents=True, exist_ok=True)
    r = git(d.parent, "clone", "-q", item.url, d.name)
    if r.returncode:
        raise Abort(f"cannot clone {item.url}: {r.stderr.strip()}")
    if kind(d, item.revision) == "branch":
        cur = git(d, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
        if cur != item.revision:
            git(d, "checkout", "-q", "-b", item.revision, f"origin/{item.revision}")
    else:
        sha = git(d, "rev-parse", "--verify", "-q", f"{item.revision}^{{commit}}").stdout.strip()
        if not sha:
            raise Abort(f"{item.name}: revision {item.revision} not found in {item.url}")
        git(d, "checkout", "-q", "-b", f"ws/{item.revision}", sha)
    exclude(d)


def origin_of(d):
    return git(d, "remote", "get-url", "origin").stdout.strip()


def same_repo(a, b):
    norm = lambda u: u.rstrip("/").removesuffix(".git").removeprefix("file://")
    return norm(a) == norm(b)


def conflict(item, d):
    """Why d cannot be updated as item, or None."""
    if not (d / ".git").exists():
        return "the folder exists and is not a git repo"
    if not same_repo(origin_of(d), item.url):
        return f"origin is {origin_of(d)}, not {item.url}"
    return None


def update(item, d):
    """Fast-forward d to the revision of item; (state, reason) with state ok, moved or kept."""
    why = conflict(item, d)
    if why:
        return "kept", why
    if git(d, "status", "--porcelain").stdout.strip():
        return "kept", "uncommitted changes"
    git(d, "fetch", "-q", "--tags", "origin")
    if kind(d, item.revision) == "branch":
        cur = git(d, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
        if cur != item.revision:
            return "kept", f"branch {cur} is checked out, not {item.revision}"
        target = f"origin/{item.revision}"
    else:
        target = git(d, "rev-parse", "--verify", "-q", f"{item.revision}^{{commit}}").stdout.strip()
        if not target:
            return "kept", f"revision {item.revision} not found"
    head = git(d, "rev-parse", "HEAD").stdout.strip()
    tsha = git(d, "rev-parse", target).stdout.strip()
    if head == tsha or git(d, "merge-base", "--is-ancestor", tsha, "HEAD").returncode == 0:
        return "ok", "contains the revision"
    if git(d, "merge-base", "--is-ancestor", "HEAD", tsha).returncode != 0:
        return "kept", "own commits, no fast-forward possible"
    r = git(d, "merge", "-q", "--ff-only", tsha)
    if r.returncode:
        return "kept", f"fast-forward failed: {r.stderr.strip()}"
    return "moved", f"fast-forward to {item.revision}"


# ---------------------------------------------------------------------------
# commands
# ---------------------------------------------------------------------------

def root_of(path):
    root = find_root(path or paths.cwd())
    if root is None:
        raise Abort(f"no .aios/workspace.yaml at or above {path or paths.cwd()}")
    return root


def activated(path):
    cfg = config.load(path)
    if cfg.vault is None:
        raise Abort(f"{path} is not in a vault")
    if not cfg.aios:
        raise Abort(f"the vault {cfg.vault} is not activated; run: aios --activate v<version> {cfg.vault}")


def do_update(root, groups):
    """Plan and run update for the projects of root."""
    items = selected(load(root), groups)
    plan = Plan()
    for item in items:
        d = root / item.path
        if not d.exists():
            plan.add(f"clone {item.url} ({item.revision}) -> {item.path}",
                     lambda item=item, d=d: (clone(item, d), report(item, "cloned", item.revision)))
        else:
            plan.add(f"update {item.path} ({item.revision}, fast-forward only)",
                     lambda item=item, d=d: report(item, *update(item, d)))
    if not items:
        say(f"=> no projects in {root / FILE}" + (f" for the groups {', '.join(groups)}" if groups else ""))
        return 0
    if ui.MODE != "yes":
        say(f"=> update the workspace {root}")
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> workspace {root.name}: {len(items)} projects")
    return 0


def report(item, state, why):
    say(f"   {item.path}: {state}" + (f" ({why})" if state != "ok" else ""))


def init(repo, folder=None, groups=()):
    here = Path(paths.cwd())
    activated(here)
    name = folder or Path(repo.rstrip("/")).name.removesuffix(".git")
    root = here / name
    if root.exists():
        raise Abort(f"{root} exists already")
    plan = Plan()
    item = Item(name, repo, "", name)

    def run():
        root.parent.mkdir(parents=True, exist_ok=True)
        r = git(root.parent, "clone", "-q", repo, root.name)
        if r.returncode:
            raise Abort(f"cannot clone {repo}: {r.stderr.strip()}")
        exclude(root)
        if not (root / FILE).is_file():
            raise Abort(f"{repo} has no {FILE}; the root project is cloned, nothing else")
        for i in selected(load(root), groups):
            d = root / i.path
            if d.exists():
                report(i, *update(i, d))
            else:
                clone(i, d)
                report(i, "cloned", i.revision)
    plan.add(f"clone {repo} -> {root}, then the projects of its {FILE}"
             + (f" (groups {', '.join(groups)})" if groups else ""), run)
    if ui.MODE != "yes":
        say(f"=> init the workspace {root}")
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> workspace {root} ready")
    return 0


def freeze(path=None):
    from . import fetch
    root = root_of(path)
    activated(root)
    frozen = {}
    for item in load(root):
        d = root / item.path
        if (d / ".git").exists():
            frozen[item.name] = git(d, "rev-parse", "HEAD").stdout.strip()
    lock = fetch.read_lock(root)
    new = dict(lock) if lock else {"schema": 1}
    new.setdefault("schema", 1)
    new["workspace"] = frozen
    if new == lock:
        say(f"=> {root / '.aios' / 'lock.yaml'} holds this state, nothing to do")
        return 0
    plan = Plan()
    plan.add(f"{root / '.aios' / 'lock.yaml'}: workspace with {len(frozen)} commits",
             lambda: fetch.write_lock(root, new))
    if ui.MODE != "yes":
        say(f"=> freeze the workspace {root}")
    ui.confirm(plan, "go on?", "cancelled")
    say("=> frozen: " + ", ".join(f"{n} {s[:8]}" for n, s in frozen.items()))
    return 0


def state(item, d):
    """(branch, revision, remote, changes) of a project for status and integrity."""
    if not d.exists():
        return "—", "missing", "—", "—"
    why = conflict(item, d)
    if why:
        return "—", "conflict", "—", why
    branch = git(d, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    ref = f"origin/{item.revision}" if kind(d, item.revision) == "branch" else f"{item.revision}^{{commit}}"
    sha = git(d, "rev-parse", "--verify", "-q", ref).stdout.strip()
    rev = "ok" if sha and git(d, "merge-base", "--is-ancestor", sha, "HEAD").returncode == 0 else "behind"
    r = git(d, "rev-list", "--left-right", "--count", "@{upstream}...HEAD")
    if r.returncode == 0:
        behind, ahead = (int(x) for x in r.stdout.split())
        remote = "ok" if not (ahead or behind) else ", ".join(
            x for x in (f"{ahead} ahead" if ahead else "", f"{behind} behind" if behind else "") if x)
    else:
        remote = "—"
    n = len([x for x in git(d, "status", "--porcelain").stdout.splitlines() if x])
    return branch, rev, remote, "ok" if not n else f"{n} changed"


def status(path=None):
    root = root_of(path)
    rows = [("Project", "Path", "Branch", "Revision", "Remote", "Changes")]
    for item in load(root):
        rows.append((item.name, item.path, *state(item, root / item.path)))
    print(f"Workspace {root.name} — {datetime.date.today().isoformat()}")
    print()
    widths = [max(len(r[i]) for r in rows) + 2 for i in range(5)]
    for r in rows:
        print("".join(f"{c:<{w}}" for c, w in zip(r[:5], widths)) + r[5])
    return 0


def command(args):
    if not args:
        raise Abort("usage: aios --workspace init <repo> [<folder>] | update | freeze | status [<path>] [--group <g>]")
    sub, rest, groups, i = args[0], [], [], 1
    while i < len(args):
        if args[i] == "--group" and i + 1 < len(args):
            groups.append(args[i + 1])
            i += 2
            continue
        rest.append(args[i])
        i += 1
    if sub == "init" and 1 <= len(rest) <= 2:
        return init(rest[0], rest[1] if len(rest) == 2 else None, groups)
    if sub == "update" and len(rest) <= 1:
        root = root_of(rest[0] if rest else None)
        activated(root)
        return do_update(root, groups)
    if sub == "freeze" and len(rest) <= 1 and not groups:
        return freeze(rest[0] if rest else None)
    if sub == "status" and len(rest) <= 1 and not groups:
        return status(rest[0] if rest else None)
    raise Abort("usage: aios --workspace init <repo> [<folder>] | update | freeze | status [<path>] [--group <g>]")


# ---------------------------------------------------------------------------
# aios --integrity (spec 05, F2)
# ---------------------------------------------------------------------------

def integrity(start, results):
    """Rows and notes for the projects of a workspace at or above start that lie below start."""
    from .integrity import Result
    root = find_root(start)
    if root is None:
        return
    try:
        items = load(root)
    except Abort as e:
        warn(str(e))
        return
    known = {r.path: r for r in results}
    for item in items:
        d = (root / item.path).resolve() if (root / item.path).exists() else root / item.path
        if start != d and start not in d.parents:
            continue
        depth = sum(1 for r in results if r.path != d and r.path in d.parents)   # projects above it
        if not d.exists():
            results.append(Result(d, depth, init_note="missing: clone"))
            continue
        why = conflict(item, d)
        r = known.get(d)
        if r is None:                               # a foreign repo without @/ (spec 06, L2)
            r = Result(d, depth, repo=True, init_note="foreign repo")
            from .integrity import commit_state, push_hints
            r.changed, r.new = commit_state(d)
            r.hints += push_hints(d)
            results.append(r)
        if why:
            r.hints.append(f"workspace: {why}")
            continue
        _, rev, _, _ = state(item, d)
        if rev != "ok":
            r.hints.append(f"workspace: revision {item.revision} is not in the checked out branch")
    results.sort(key=lambda r: r.path.parts)          # report order of projects(): the tree
