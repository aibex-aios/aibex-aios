"""aios --workspace: the projects of a workspace as git checkouts (spec 06, Workspaces; V0.4, memos
10, 12, 18, 57; V0.6, memos 163-177).

A workspace is a vault root with .aios/workspace.yaml listing repos with revision and path. They
are cloned nested below the root, parents before children, and excluded in the repo above, with a
commit of only that line (I9). attach binds a workspace to this machine, sync reconciles the tree
with the remotes: it moves a branch only by fast-forward and never drops changes (P4); a tag or a
commit is checked out as the local branch ws/<revision>, never as a detached HEAD.
"""

from __future__ import annotations

import datetime
import os
import re
from dataclasses import dataclass, field
from pathlib import Path

from . import config, paths, project, ui
from .ui import Abort, Plan, say, warn

FILE = Path(".aios") / "workspace.yaml"
LOCAL = Path(".aios") / "workspace.local.yaml"
LOCAL_HEAD = "# written by AIOS (workspace), do not edit\n"
CLOUD = ("Library/CloudStorage", "Library/Mobile Documents", "Dropbox")   # spec 06, Schlüssel sync:
USAGE = ("usage: aios --workspace attach <repo> [<vault-folder>] | sync [<path>] [--group <g>]"
         " | status [<path>] | freeze [<path>]")


@dataclass
class Item:
    name: str
    url: str
    revision: str
    path: str
    groups: list = field(default_factory=list)

    @property
    def depth(self):
        return len(Path(self.path).parts)


def git(p, *args):
    return project.git(p, *args)


# ---------------------------------------------------------------------------
# workspace.yaml, workspace.local.yaml
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
    """[Item] of root/.aios/workspace.yaml, checked (spec 06), parents before children (F155);
    import is reported and passed over."""
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
            warn(f"{where} ({name}): import has no effect, passed over")
        groups = p.get("groups") or []
        items.append(Item(name, url, rev, path, list(groups) if isinstance(groups, list) else [groups]))
    return sorted(items, key=lambda i: i.depth)        # stable: same depth keeps the file order


def selected(items, groups):
    """Without groups all items; with groups the items of these groups and those without a group."""
    if not groups:
        return items
    return [i for i in items if not i.groups or set(i.groups) & set(groups)]


def detached(root):
    """Paths (relative, posix) detached on this machine (.aios/workspace.local.yaml, F164)."""
    f = Path(root) / LOCAL
    if not f.is_file():
        return []
    import yaml
    try:
        data = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as e:
        warn(f"{f}: {e}; read as empty")
        return []
    return [str(e.get("path")) for e in data.get("detached") or [] if isinstance(e, dict) and e.get("path")]


def is_detached(path, gone):
    p = Path(path)
    return any(p == Path(d) or Path(d) in p.parents for d in gone)


def under(item, rel):
    """True if the item lies at or below rel (relative to the root, '.' = everything)."""
    if rel in ("", "."):
        return True
    p, r = Path(item.path), Path(rel)
    return p == r or r in p.parents


# ---------------------------------------------------------------------------
# key sync:, cloud folders
# ---------------------------------------------------------------------------

def cloud_folder(path):
    """The cloud service whose folder holds path, or None (spec 06; V0.6, memo 174: F188)."""
    p = Path(os.path.realpath(path))
    home = Path(os.path.realpath(paths.home()))
    for c in CLOUD:
        base = home / c
        if p == base or base in p.parents:
            return c.split("/")[-1]
    return None


def sync_mode(root, cfg=None):
    """(mode, reason) for the vault root: auto, manual or off (F183, F188)."""
    cloud = cloud_folder(root)
    if cloud:
        return "off", f"the vault lies in a cloud folder ({cloud})"
    cfg = cfg or config.load(root)
    value = cfg.values.get("sync")
    if value:
        return value, f"sync: {value} in {cfg.source.get('sync')}"
    if (Path(root) / FILE).is_file():
        return "auto", "default with workspace.yaml"
    return "off", "no workspace.yaml"


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
    r = git(d, "fetch", "-q", "--tags", "origin")
    if r.returncode:
        return "kept", f"fetch failed: {(r.stderr or r.stdout).strip()}"
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


def root_item(root):
    """The vault root as an item: its origin and the checked out branch (spec 06, sync, step 2)."""
    branch = git(root, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    return Item(Path(root).name, origin_of(root), branch, ".")


# ---------------------------------------------------------------------------
# sync (steps 1-3; steps 4-5 follow in step 3 of the implementation)
# ---------------------------------------------------------------------------

def report(path, state, why=""):
    say(f"   {path}: {state}" + (f" ({why})" if why and state != "ok" else ""))


def runnable(d):
    """Step 3: reconcile packages and workhorses with lock.yaml, then register (F158)."""
    from . import fetch, registry
    if not (d / "@").is_dir():
        return
    keep = ui.MODE
    ui.MODE = "yes"
    try:
        if (d / ".aios" / "lock.yaml").is_file():
            try:
                fetch.sync(str(d))
            except (Abort, ui.Cancelled, ui.PlanOnly) as e:
                warn(f"{d}: packages not reconciled ({e}); run aios --fetch there")
        try:
            registry.register(str(d), yes=True)
        except (Abort, ui.Cancelled, ui.PlanOnly) as e:
            warn(f"{d}: skills not registered ({e})")
    finally:
        ui.MODE = keep


def plan_sync(plan, root, rel=".", groups=()):
    """Add the steps of sync for the projects of root at or below rel to plan (spec 06, sync)."""
    items = [i for i in selected(load(root), groups) if under(i, rel)]
    gone = detached(root)
    cloned = []
    for item in items:                                  # step 1: clone what is missing
        d = root / item.path
        if is_detached(item.path, gone):
            continue
        if not d.exists():
            def act(item=item, d=d):
                clone(item, d)
                cloned.append(d)
                report(item.path, "cloned", item.revision)
            plan.add(f"clone {item.url} ({item.revision}) -> {item.path}", act)
    targets = ([root_item(root)] if rel in ("", ".") and origin_of(root) else []) + \
        [i for i in items if (root / i.path).exists() and not is_detached(i.path, gone)]
    for item in targets:                                # step 2: fetch, fast-forward only
        d = root if item.path == "." else root / item.path
        plan.add(f"update {item.path} ({item.revision}, fast-forward only)",
                 lambda item=item, d=d: report(item.path, *update(item, d)))
    if any(not (root / i.path).exists() for i in items if not is_detached(i.path, gone)):
        plan.add("make the newly cloned projects runnable (aios --fetch, registration)",
                 lambda: [runnable(d) for d in cloned])
    for d in gone:
        if under(Item("", "", "", d), rel):
            plan.add(f"{d}: detached on this machine, passed over")
    return items


def refuse_off(root):
    mode, why = sync_mode(root)
    if mode == "off":
        raise Abort(f"the workspace sync is off for {root} ({why}); plain git stays allowed")
    return mode


def do_sync(path=None, groups=()):
    """aios --workspace sync [<path>] [--group <g>…] (spec 06, sync)."""
    start = Path(os.path.realpath(path or paths.cwd()))
    root = root_of(start)
    activated(root)
    refuse_off(root)
    rel = start.relative_to(root).as_posix() if start != root else "."
    plan = Plan()
    items = plan_sync(plan, root, rel, groups)
    if not items and rel != ".":
        raise Abort(f"no project of {root / FILE} at or below {start}")
    if ui.MODE != "yes":
        say(f"=> sync the workspace {root}" + ("" if rel == "." else f" at {rel}"))
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> workspace {root.name} synchronized")
    return 0


# ---------------------------------------------------------------------------
# attach <repo> [<vault-folder>]
# ---------------------------------------------------------------------------

REPO_URL = re.compile(r"(://|^[^/\s]+@[^/\s]+:|\.git/?$)")


def is_repo(arg):
    """URL of a repo or path (F171)."""
    return bool(REPO_URL.search(arg))


def repo_name(url):
    return Path(url.rstrip("/")).name.removesuffix(".git")


def kernel_ok(version):
    """(True, None) if the bound version runs here, else (False, install step or None)."""
    from . import install
    from . import version as running
    if version in (running(), None):
        return True, None
    if f"v{version}" in install.installations():
        return True, None
    try:
        repo = install.find_repo()
    except Abort:
        return False, None
    return False, repo


def attach(repo, folder=None):
    """aios --workspace attach <repo> [<vault-folder>]: clone the vault root, then sync (F161)."""
    target = Path(folder) if folder else Path(paths.cwd()) / ("§" + repo_name(repo))
    target = Path(os.path.abspath(target))
    if not target.name.startswith("§"):
        raise Abort(f"{target}: the folder of a vault root starts with § (spec 02)")
    if target.exists():
        raise Abort(f"{target} exists already; inside it use: aios --workspace sync")
    cloud = cloud_folder(target.parent)
    if cloud:
        raise Abort(f"{target} would lie in a cloud folder ({cloud}); the workspace sync is off there (spec 06)")
    plan = Plan()

    def run():
        target.parent.mkdir(parents=True, exist_ok=True)
        r = git(target.parent, "clone", "-q", repo, target.name)
        if r.returncode:
            raise Abort(f"cannot clone {repo}: {r.stderr.strip()}")
        report(".", "cloned", repo)
        if not (target / FILE).is_file():
            raise Abort(f"{repo} has no {FILE}; the vault root is cloned, nothing else")
        cfg = config.load(target)
        mode, why = sync_mode(target, cfg)
        if mode == "off":
            raise Abort(f"the vault root is cloned, the sync is off ({why})")
        ok, src = kernel_ok(cfg.aios)
        if not ok:
            if src is None:
                raise Abort(f"the vault binds AIOS {cfg.aios}, which is not installed and no clone of "
                            f"aibex-aios is known; install it, then run: aios --workspace sync in {target}")
            from . import install
            keep = ui.MODE
            ui.MODE = "yes"
            try:
                install.install(f"v{cfg.aios}")
            finally:
                ui.MODE = keep
        inner = Plan()
        plan_sync(inner, target)
        keep = ui.MODE
        ui.MODE = "yes"
        try:
            inner.run()
        finally:
            ui.MODE = keep

    plan.add(f"clone {repo} -> {target} (vault root)", run)
    plan.add("install the bound kernel version if it is missing (aios --install)")
    plan.add("then sync: clone the projects of workspace.yaml, parents before children; reconcile "
             "packages and workhorses; register the skills")
    if ui.MODE != "yes":
        say(f"=> attach the workspace {repo} to this machine")
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> workspace {target} attached")
    return 0


# ---------------------------------------------------------------------------
# freeze, status
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


def state(item, d, gone=()):
    """(branch, revision, remote, changes) of a project for status and integrity."""
    if is_detached(item.path, gone):
        return "—", "detached", "—", "—"
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
    gone = detached(root)
    rows = [("Project", "Path", "Branch", "Revision", "Remote", "Changes")]
    for item in load(root):
        rows.append((item.name, item.path, *state(item, root / item.path, gone)))
    mode, why = sync_mode(root)
    print(f"Workspace {root.name} — {datetime.date.today().isoformat()} — sync: {mode}")
    print()
    widths = [max(len(r[i]) for r in rows) + 2 for i in range(5)]
    for r in rows:
        print("".join(f"{c:<{w}}" for c, w in zip(r[:5], widths)) + r[5])
    return 0


def command(args):
    if not args:
        raise Abort(USAGE)
    sub, rest, groups, i = args[0], [], [], 1
    while i < len(args):
        if args[i] == "--group" and i + 1 < len(args):
            groups.append(args[i + 1])
            i += 2
            continue
        rest.append(args[i])
        i += 1
    if sub == "attach" and 1 <= len(rest) <= 2 and not groups:
        if is_repo(rest[0]):
            return attach(rest[0], rest[1] if len(rest) == 2 else None)
        raise Abort("attach <path> (get a detached subtree back) comes with detach; "
                    "attach a workspace with the URL of its vault root")
    if sub == "sync" and len(rest) <= 1:
        return do_sync(rest[0] if rest else None, groups)
    if sub == "freeze" and len(rest) <= 1 and not groups:
        return freeze(rest[0] if rest else None)
    if sub == "status" and len(rest) <= 1 and not groups:
        return status(rest[0] if rest else None)
    if sub in ("init", "update"):
        raise Abort(f"--workspace {sub} is gone since v0.6.4: use "
                    + ("attach <repo> [<vault-folder>]" if sub == "init" else "sync [<path>]"))
    raise Abort(USAGE)


# ---------------------------------------------------------------------------
# aios --integrity (spec 05, F2)
# ---------------------------------------------------------------------------

def integrity(start, results):
    """Rows and notes for the projects of the workspaces at or above start and of the workspaces
    below it (each checked project with .aios/workspace.yaml, memo 73, B7) that lie below start."""
    roots = [find_root(start)] + [r.path for r in results if (r.path / FILE).is_file()]
    for root in dict.fromkeys(r for r in roots if r is not None):
        integrity_of(root, start, results)
    results.sort(key=lambda r: r.path.parts)          # report order of projects(): the tree


def integrity_of(root, start, results):
    from .integrity import Result
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
