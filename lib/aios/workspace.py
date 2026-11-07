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
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

from . import config, paths, project, ui
from .ui import Abort, Plan, say, warn

FILE = Path(".aios") / "workspace.yaml"
LOCAL = Path(".aios") / "workspace.local.yaml"
LOCAL_HEAD = "# written by AIOS (workspace), do not edit\n"
CLOUD = ("Library/CloudStorage", "Library/Mobile Documents", "Dropbox")   # spec 06, Schlüssel sync:
USAGE = ("usage: aios --workspace attach <repo> [<vault-folder>] | attach <path> | sync [<path>] [--group <g>]"
         " [--accept-deletion <path>] | history <path> [--deleted] | restore <path> [--at <time>]"
         " | detach [<path>] | status [<path>] | freeze [<path>]")


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


def host():
    """Short name of this machine for commit messages and conflict copies (F235)."""
    import socket
    r = subprocess.run(["scutil", "--get", "LocalHostName"], capture_output=True, text=True) \
        if Path("/usr/sbin/scutil").exists() else None
    name = r.stdout.strip() if r is not None and r.returncode == 0 else ""
    return name or socket.gethostname().split(".")[0]


def git_bytes(d, *args):
    return subprocess.run(["git", "-C", str(d), *args], capture_output=True).stdout


def copy_name(path, day):
    """<Name> (Konflikt <Rechner> <JJJJ-MM-TT>).<Endung> (F227, F235)."""
    p = Path(path)
    stem, suffix = (p.stem, p.suffix) if p.suffix else (p.name, "")
    return (p.parent / f"{stem} (Konflikt {host()} {day}){suffix}").as_posix()


def resolve(d):
    """Resolve the conflicts of a stopped merge: the remote version wins, the local one stays as a
    conflict copy; deleted against changed keeps the changed one (F227, F233). [copies]"""
    day = datetime.date.today().isoformat()
    copies = []
    for path in git(d, "diff", "--name-only", "--diff-filter=U").stdout.splitlines():
        stages = {line.split()[2] for line in git(d, "ls-files", "-u", "--", path).stdout.splitlines()}
        if "2" in stages and "3" in stages:
            copy = copy_name(path, day)
            (d / copy).write_bytes(git_bytes(d, "show", f":2:{path}"))
            git(d, "checkout", "--theirs", "--", path)
            git(d, "add", "--", path, copy)
            copies.append(copy)
        elif "3" in stages:
            git(d, "checkout", "--theirs", "--", path)
            git(d, "add", "--", path)
        else:
            git(d, "checkout", "--ours", "--", path)
            git(d, "add", "--", path)
    return copies


def update(item, d, copies=True):
    """Bring d to the revision of item (spec 06, sync, step 3): fast-forward, else merge; with
    copies a conflict becomes a conflict copy (F226, F227), without (hook, F230) the merge is
    given up. (state, reason) with state ok, moved or kept."""
    why = conflict(item, d)
    if why:
        return "kept", why
    if git(d, "status", "--porcelain", "--untracked-files=no").stdout.strip():
        return "kept", "local changes that are not saved yet"
    r = git(d, "fetch", "-q", "--tags", "origin")
    if r.returncode:
        return "kept", f"fetch failed: {(r.stderr or r.stdout).strip()}"
    branch = kind(d, item.revision) == "branch"
    if branch:
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
    if git(d, "merge-base", "--is-ancestor", "HEAD", tsha).returncode == 0:
        r = git(d, "merge", "-q", "--ff-only", tsha)
        if r.returncode:
            return "kept", f"fast-forward failed: {r.stderr.strip()}"
        return "moved", f"fast-forward to {item.revision}"
    if not branch:
        return "kept", "own commits on a fixed revision"
    msg = f"AIOS: zusammengeführt auf {host()}"
    r = git(d, "merge", "-q", "--no-edit", "-m", msg, tsha)
    if r.returncode == 0:
        return "moved", f"merged with {target}"
    if not git(d, "diff", "--name-only", "--diff-filter=U").stdout.strip():
        git(d, "merge", "--abort")
        return "kept", f"merge failed: {(r.stderr or r.stdout).strip()}"
    if not copies:
        git(d, "merge", "--abort")
        return "kept", "the same files changed here and on the remote; /aios-sync makes conflict copies"
    made = resolve(d)
    r = git(d, "commit", "-q", "--no-edit", "-m", msg)
    if r.returncode:
        git(d, "merge", "--abort")
        return "kept", f"merge failed: {(r.stderr or r.stdout).strip()}"
    return "moved", f"merged with {target}; conflict copies: " + ", ".join(made) if made else f"merged with {target}"


# step 2: save local changes (spec 06, sync; V0.6, memos 204, 205: F225, F228, F232, F234, F236)

def changes(d):
    """(new, changed, deleted) paths of the working tree, untracked files one by one."""
    new, changed, deleted = [], [], []
    for line in git(d, "status", "--porcelain", "--untracked-files=all").stdout.splitlines():
        code, path = line[:2], line[3:].strip('"')
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        if code == "??":
            new.append(path)
        elif "D" in code:
            deleted.append(path)
        else:
            changed.append(path)
    return new, changed, deleted


def large_deletion(d, deleted):
    """F236: more than 10 tracked files, or all tracked files below @/ or .aios/, are gone."""
    if len(deleted) > 10:
        return True
    gone = set(deleted)
    for top in ("@/", ".aios/"):
        tracked = [f for f in git(d, "ls-files", "--", top).stdout.splitlines()]
        if tracked and all(f in gone for f in tracked):
            return True
    return False


def savable(item, d):
    """Why the local changes of d are not saved, or None (F234)."""
    if conflict(item, d):
        return conflict(item, d)
    if git(d, "rev-parse", "--abbrev-ref", "@{upstream}").returncode:
        return "no upstream"
    if kind(d, item.revision) != "branch":
        return f"fixed revision {item.revision}"
    cur = git(d, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    if cur != item.revision:
        return f"branch {cur} is checked out, not {item.revision}"
    return None


def save(item, d, accept=()):
    """Step 2 of sync: commit all local changes of d (F225); secrets stay out (F232); a large
    deletion is restored unless accepted (F228)."""
    new, changed, deleted = changes(d)
    if not (new or changed or deleted):
        return
    why = savable(item, d)
    if why:
        report(item.path, "not saved", f"{len(new) + len(changed) + len(deleted)} local changes; {why}")
        return
    if deleted and large_deletion(d, deleted):
        keep = False
        if item.path in accept:
            keep = True
        elif ui.MODE == "ask" and sys.stdin.isatty():
            sys.stdout.write(f"   {item.path}: {len(deleted)} files are deleted here (e.g. {', '.join(deleted[:3])}).\n")
            keep = ask_no("take over the deletion (also in the backup)? no: restore them")
        if not keep:
            git(d, "checkout", "--", *deleted)
            report(item.path, "restored", f"{len(deleted)} deleted files (large deletion, F228)")
            deleted = []
    git(d, "add", "-A")
    staged = git(d, "diff", "--cached", "--name-only").stdout.splitlines()
    held = [f for f in staged if SECRET.search(f)]
    if held:
        git(d, "reset", "-q", "--", *held)
        report(item.path, "not saved (secret)", ", ".join(held))
    if not git(d, "diff", "--cached", "--name-only").stdout.strip():
        return
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    r = git(d, "commit", "-q", "-m", f"AIOS: gesichert von {host()} am {stamp}")
    if r.returncode:
        report(item.path, "not saved", (r.stderr or r.stdout).strip())
        return
    report(item.path, "saved", f"{len([f for f in new if f not in held])} new, {len(changed)} changed, "
                               f"{len(deleted)} deleted")


def ask_no(question):
    """A question whose default is no."""
    sys.stdout.write(f"   {question} [y/N] ")
    sys.stdout.flush()
    line = sys.stdin.readline()
    return line.strip().lower() in ("y", "yes", "j", "ja")


def save_text(item, d):
    """Line of the plan for step 2, or None."""
    new, changed, deleted = changes(d)
    if not (new or changed or deleted):
        return None
    why = savable(item, d)
    if why:
        return f"not saved: {item.path} ({len(new) + len(changed) + len(deleted)} local changes; {why})"
    text = f"save {item.path}: {len(new)} new, {len(changed)} changed, {len(deleted)} deleted"
    held = [f for f in new + changed if SECRET.search(f)]
    if held:
        text += f"; not saved (secret): {', '.join(held)}"
    if deleted and large_deletion(d, deleted):
        text += (f"; LARGE DELETION ({len(deleted)} files): restored unless taken over "
                 f"(question, or --accept-deletion {item.path})")
    return text


def sync_steps(plan, root, targets, kept, accept=()):
    """Steps 2 and 3 of sync for the existing repos: save, then fetch and merge."""
    for item in targets:
        d = root if item.path == "." else root / item.path
        text = save_text(item, d)
        if text:
            plan.add(text, lambda item=item, d=d: save(item, d, accept))

    def upd(item, d):
        st, why = update(item, d)
        if st == "kept":
            kept[item.path] = why
        report(item.path, st, why)
    for item in targets:
        d = root if item.path == "." else root / item.path
        plan.add(f"update {item.path} ({item.revision}, merge)", lambda item=item, d=d: upd(item, d))


def root_item(root):
    """The vault root as an item: its origin and the checked out branch (spec 06, sync, step 2)."""
    branch = git(root, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    return Item(Path(root).name, origin_of(root), branch, ".")


# ---------------------------------------------------------------------------
# sync (steps 1-3; steps 4-5 follow in step 3 of the implementation)
# ---------------------------------------------------------------------------

def report(path, state, why=""):
    say(f"   {path}: {state}" + (f" ({why})" if why and state != "ok" else ""))


def aios_clone(d):
    """A clone of an AIOS project: @/, or else the .gitignore of the AIOS template; git keeps no
    empty folder, so an @/ without a tracked file is missing in the clone (B32)."""
    if (d / "@").is_dir():
        return True
    gi = d / ".gitignore"
    if is_package(d) or not gi.is_file():
        return False
    return ".aios/registry" in gi.read_text(encoding="utf-8", errors="replace").split()


def runnable(d):
    """Step 3: reconcile packages and workhorses with lock.yaml, then register (F158)."""
    from . import fetch, registry
    if not aios_clone(d):
        return
    if not (d / "@").is_dir():
        (d / "@").mkdir()
        say(f"   {d.name}: @/ was missing in the clone (no tracked file in it), created")
    keep = ui.MODE
    ui.MODE = "yes"
    try:
        if (d / ".aios" / "lock.yaml").is_file():
            try:
                fetch.sync(str(d))
            except (Abort, ui.Cancelled, ui.PlanOnly) as e:
                warn(f"{d}: packages not reconciled ({e}); run aios --fetch there")
        try:
            registry.register(str(d), yes=True, brief=True)
        except (Abort, ui.Cancelled, ui.PlanOnly) as e:
            warn(f"{d}: skills not registered ({e})")
    finally:
        ui.MODE = keep


# step 4: the manifest follows the repos with a remote (spec 06, sync; Namensschema)

UMLAUT = {"ä": "ae", "ö": "oe", "ü": "ue", "Ä": "Ae", "Ö": "Oe", "Ü": "Ue", "ß": "ss"}
SKIP = (".git", ".claude", ".obsidian", ".aios", "node_modules", "@Data")


def schema_name(root, d):
    """Name of the repo of d at the remote after the schema (F178-F180): <Workspace>-<folder>."""
    clean = lambda n: re.sub(r"[^A-Za-z0-9._-]", "-", "".join(UMLAUT.get(c, c) for c in n))
    ws = clean(Path(root).name.lstrip("§"))
    return ws if Path(d) == Path(root) else f"{ws}-{clean(Path(d).name)}"


def is_package(d):
    """A package repo: manifest.yaml at its root and no @/ (F201)."""
    return (d / "manifest.yaml").is_file() and not (d / "@").is_dir()


def repos(root, gone=()):
    """Paths (relative, posix) of all git repos below root, not the root, not in detached parts."""
    found = []
    for base, dirs, files in os.walk(root):
        b = Path(base)
        rel = b.relative_to(root).as_posix()
        if rel != "." and is_detached(rel, gone):
            dirs[:] = []
            continue
        if b != Path(root) and (b / ".git").exists():
            found.append(rel)
        dirs[:] = sorted(x for x in dirs if x not in SKIP and not x.startswith("."))
    return found


def owner_of(url):
    m = re.match(r"(?:https://github\.com/|git@github\.com:)([^/]+)/", url or "")
    return m.group(1) if m else None


def manifest_steps(plan, root, items, rel, gone):
    """Step 4 of sync: entries for repos with origin that are missing, hints for the rest."""
    import yaml
    data = yaml.safe_load((root / FILE).read_text(encoding="utf-8")) or {}
    remotes = data.get("remotes") or {}
    entries, hints = scan(root, remotes, {i.path for i in load(root)}, {i.name for i in load(root)}, rel, gone)
    if entries:
        plan.add(f"workspace.yaml: add {', '.join(e['path'] for e in entries)}; commit only workspace.yaml",
                 lambda: add_entries(root, entries))
    for h in hints:
        plan.add(f"note: {h}")


def scan(root, remotes, listed, names, rel=".", gone=()):
    """(entries, hints): repos with origin missing in workspace.yaml, notes for the rest (step 4)."""
    names = set(names)
    folders = {}
    entries, hints = [], []
    for r in repos(root, gone):
        if not (rel in ("", ".") or under(Item("", "", "", r), rel)):
            continue
        d = root / r
        folders.setdefault(Path(r).name, []).append(r)
        url = origin_of(d)
        pkg = is_package(d)
        if not url:
            if pkg or not (d / "@").is_dir():
                hints.append(f"{r}: no remote")
            else:
                name = schema_name(root, d)
                owner = owner_of(origin_of(root))
                cmd = (f"; gh repo create {owner}/{name} --private --source {r} --remote origin"
                       if owner else "")
                hints.append(f"{r}: no remote; suggested name {name}{cmd}")
            continue
        name = Path(url.rstrip("/")).name.removesuffix(".git")
        if (d / "@").is_dir() and not pkg and name != schema_name(root, d):
            hints.append(f"{r}: remote {name} differs from the schema ({schema_name(root, d)})")
        if r in listed:
            continue
        if name in names:
            hints.append(f"{r}: the name {name} is in workspace.yaml already, not added")
            continue
        names.add(name)
        base = next((k for k, v in remotes.items()
                     if same_repo(str(v).rstrip("/") + "/" + name, url)), None)
        branch = git(d, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip() or "main"
        entries.append({"name": name, **({"remote": base} if base else {"repo": url}),
                        "revision": branch, "path": r})
    for folder, where in folders.items():
        if len(where) > 1:
            hints.append(f"the folder name {folder} occurs {len(where)} times ({', '.join(where)}); "
                         "the schema gives no unique name")
    return entries, hints


def new_workspace(plan, root):
    """B29: sync at a vault root without workspace.yaml creates it (spec 06, sync, Neuer Workspace)."""
    owner = owner_of(origin_of(root))
    remotes = {owner: f"https://github.com/{owner}"} if owner else {}
    entries, hints = scan(root, remotes, set(), set())
    items = [Item(e["name"], (remotes[e["remote"]] + "/" + e["name"]) if "remote" in e else e["repo"],
                  e["revision"], e["path"]) for e in entries]

    def create():
        import yaml
        f = root / FILE
        f.parent.mkdir(parents=True, exist_ok=True)
        body = yaml.safe_dump({"schema": 1, "remotes": remotes, "projects": entries},
                              sort_keys=False, allow_unicode=True, default_flow_style=False)
        f.write_text(body, encoding="utf-8")
        git(root, "add", "--", str(FILE))
        r = git(root, "commit", "-q", "-m", "AIOS: workspace.yaml angelegt", "--", str(FILE))
        if r.returncode:
            warn(f"commit in {root} failed ({(r.stderr or r.stdout).strip()}); commit workspace.yaml by hand")
        report(".", "workspace.yaml created", f"{len(entries)} projects")
    plan.add(f"create {FILE} (new workspace) with {len(entries)} projects: "
             f"{', '.join(e['path'] for e in entries) or '-'}; commit only workspace.yaml", create)
    targets = ([root_item(root)] if origin_of(root) else []) + items
    kept = {}
    sync_steps(plan, root, targets, kept)
    push_steps(plan, root, targets, kept)
    for h in hints:
        plan.add(f"note: {h}")


def add_entries(root, entries):
    """Append entries to projects: of workspace.yaml (text, comments stay) and commit only it."""
    f = root / FILE
    lines = f.read_text(encoding="utf-8").splitlines()
    block = []
    for e in entries:
        block.append(f"  - name: {e['name']}")
        block += [f"    {k}: {e[k]}" for k in ("remote", "repo", "revision", "path") if k in e]
    at = None
    for n, line in enumerate(lines):
        if line.startswith("projects:"):
            at = n + 1
            while at < len(lines) and (not lines[at].strip() or lines[at][0] in " \t-#"):
                at += 1
            while at > n + 1 and not lines[at - 1].strip():
                at -= 1
            break
    if at is None:
        lines += ["projects:"] + block
    else:
        lines[at:at] = block
    f.write_text("\n".join(lines) + "\n", encoding="utf-8")
    git(root, "add", "--", str(FILE))
    r = git(root, "commit", "-q", "-m", "AIOS: workspace.yaml nachgeführt", "--", str(FILE))
    if r.returncode:
        warn(f"commit in {root} failed ({(r.stderr or r.stdout).strip()}); commit workspace.yaml by hand")
    for e in entries:
        report(e["path"], "added to workspace.yaml", e["name"])


# step 5: push, never tags, never --force, never secrets (F159, F172)

SECRET = re.compile(r"(^|/)@Secret/|(^|/)\.env(\.[^/]*)?$|\.pem$|\.key$|(^|/)id_(rsa|ed25519)[^/]*$")


def outgoing(d):
    """[(sha, author, subject)] of the commits that are not on the upstream, or None (no upstream)."""
    if git(d, "rev-parse", "--abbrev-ref", "@{upstream}").returncode:
        return None
    out = git(d, "log", "--format=%h%x09%an%x09%s", "@{upstream}..HEAD").stdout
    return [tuple(line.split("\t", 2)) for line in out.splitlines() if line]


def secrets(d):
    """[(file, sha)] of secret-like files in the outgoing commits (F172)."""
    out = git(d, "log", "--format=%x00%h", "--name-only", "@{upstream}..HEAD").stdout
    hits, sha = [], ""
    for line in out.splitlines():
        if line.startswith("\x00"):
            sha = line[1:]
        elif line and SECRET.search(line):
            hits.append((line, sha))
    return hits


def push(path, d, kept):
    if path in kept:
        report(path, "not pushed", kept[path])
        return
    ahead = outgoing(d)
    if not ahead:
        return
    hits = secrets(d)
    if hits:
        report(path, "push stopped", "secret-like files: " + ", ".join(f"{f} in {s}" for f, s in hits))
        return
    branch = git(d, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    r = git(d, "push", "-q", "origin", branch)
    if r.returncode:
        report(path, "push failed", (r.stderr or r.stdout).strip())
        return
    report(path, "pushed", f"{len(ahead)} commit{'s' if len(ahead) != 1 else ''} to origin/{branch}")


def push_steps(plan, root, targets, kept):
    """Step 5 of sync: one action per repo; the plan names the outgoing commits."""
    for item in targets:
        d = root if item.path == "." else root / item.path
        ahead = outgoing(d)
        if ahead is None and item.path != ".":
            continue
        lines = [f"{s} {a}: {t}" for s, a, t in (ahead or [])]
        text = f"push {item.path}" + (f": {len(lines)} commit(s)" if lines else " (if workspace.yaml was added)")
        plan.add(text, lambda item=item, d=d: push(item.path, d, kept))
        for line in lines:
            plan.add(line)


def try_clone(item, d, cloned, failed):
    """Clone one project; a failure is reported and the others go on (B30). A project below a
    project that could not be cloned is passed over, so that the parent can be cloned later."""
    blocked = next((f for f in failed if Path(f) in Path(item.path).parents), None)
    if blocked:
        report(item.path, "not cloned", f"{blocked} is not cloned")
        failed.append(item.path)
        return
    try:
        clone(item, d)
    except Abort as e:
        report(item.path, "not cloned", str(e))
        failed.append(item.path)
        return
    cloned.append(d)
    report(item.path, "cloned", item.revision)


def plan_sync(plan, root, rel=".", groups=(), accept=()):
    """Add the steps of sync for the projects of root at or below rel to plan (spec 06, sync)."""
    items = [i for i in selected(load(root), groups) if under(i, rel)]
    gone = detached(root)
    cloned, kept, failed = [], {}, []
    for item in items:                                  # step 1: clone what is missing
        d = root / item.path
        if is_detached(item.path, gone):
            continue
        if not d.exists():
            plan.add(f"clone {item.url} ({item.revision}) -> {item.path}",
                     lambda item=item, d=d: try_clone(item, d, cloned, failed))
    with_root = rel in ("", ".") and bool(origin_of(root))
    targets = ([root_item(root)] if with_root else []) + \
        [i for i in items if (root / i.path).exists() and not is_detached(i.path, gone)]

    sync_steps(plan, root, targets, kept, accept)        # steps 2, 3: save, fetch and merge
    if any(not (root / i.path).exists() for i in items if not is_detached(i.path, gone)):
        plan.add("make the newly cloned projects runnable (aios --fetch, registration)",
                 lambda: [runnable(d) for d in cloned])
    manifest_steps(plan, root, items, rel, gone)        # step 5
    push_steps(plan, root, targets, kept)               # step 6
    for d in gone:
        if under(Item("", "", "", d), rel):
            plan.add(f"{d}: detached on this machine, passed over")
    return items


def refuse_off(root):
    mode, why = sync_mode(root)
    if mode == "off":
        raise Abort(f"the workspace sync is off for {root} ({why}); plain git stays allowed")
    return mode


def project_of(root, start):
    """B33: without a path the project of the working directory counts: the nearest entry of
    workspace.yaml at or above start, else the vault root (the whole workspace)."""
    paths_ = {i.path for i in load(root)}
    d = start
    while d != root and root in d.parents:
        rel = d.relative_to(root).as_posix()
        if rel in paths_:
            return d
        d = d.parent
    return root


def do_sync(path=None, groups=(), accept=()):
    """aios --workspace sync [<path>] [--group <g>…] (spec 06, sync)."""
    start = Path(os.path.realpath(path or paths.cwd()))
    if find_root(start) is None and config.vault_root(start) == start:
        return sync_new(start)
    root = root_of(start)
    activated(root)
    refuse_off(root)
    if path is None:
        start = project_of(root, start)                 # B33: the project, at the vault root all
    rel = start.relative_to(root).as_posix() if start != root else "."
    plan = Plan()
    accept = [Path(os.path.realpath(a)).relative_to(root).as_posix() if os.path.isabs(a) or os.path.exists(a)
              else a for a in accept]
    items = plan_sync(plan, root, rel, groups, accept)
    if not items and rel != ".":
        raise Abort(f"no project of {root / FILE} at or below {start}")
    if ui.MODE != "yes":
        say(f"=> sync the workspace {root}" + ("" if rel == "." else f" at {rel}"))
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> workspace {root.name} synchronized")
    return 0


def sync_new(root):
    """sync at a vault root without workspace.yaml: create it in the same plan (B29)."""
    activated(root)
    cloud = cloud_folder(root)
    if cloud:
        raise Abort(f"the vault lies in a cloud folder ({cloud}); the workspace sync is off there (spec 06)")
    cfg = config.load(root)
    if cfg.values.get("sync") == "off":
        raise Abort(f"sync: off in {cfg.source.get('sync')}; no workspace is created")
    plan = Plan()
    new_workspace(plan, root)
    if ui.MODE != "yes":
        say(f"=> make {root} a workspace and sync it")
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> workspace {root.name} created and synchronized")
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


def handover(target, bound):
    """H30: the sync after attach runs in the bound version, not in the calling one; True if handed
    over. A bound version without workspace commands (< 0.6.4) cannot take over: warn, go on here."""
    from . import version as running
    from .install import semver_key
    if bound in (None, running()):
        return False
    if semver_key(bound) < semver_key("0.6.4-rc1"):
        warn(f"the vault binds AIOS {bound}, which has no workspace sync; the sync runs with {running()}")
        return False
    from .install import installations
    found = installations().get(f"v{bound}")
    if not found:
        warn(f"AIOS {bound} is bound but not installed; the sync runs with {running()}")
        return False
    say(f"=> hand over to the bound version {bound}: aios --workspace sync")
    env = {k: v for k, v in os.environ.items() if k != "AIOS_HOME"}
    r = subprocess.run([str(Path(found[0]) / "bin" / "aios"), "--workspace", "sync", "--yes"],
                       cwd=str(target), env=env)
    if r.returncode:
        raise Abort(f"the sync in {bound} failed; run aios --workspace sync in {target}")
    return True


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
        if handover(target, cfg.aios):
            return
        inner = Plan()
        plan_sync(inner, target)
        keep = ui.MODE
        ui.MODE = "yes"
        try:
            inner.run()
        finally:
            ui.MODE = keep

    plan.add(f"clone {repo} -> {target} (vault root)", run)
    plan.add("install the bound kernel version if it is missing (aios --install), hand over to it")
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
    sub, rest, groups, accept, opts, i = args[0], [], [], [], {}, 1
    while i < len(args):
        if args[i] == "--group" and i + 1 < len(args):
            groups.append(args[i + 1])
            i += 2
            continue
        if args[i] == "--accept-deletion" and i + 1 < len(args):
            accept.append(args[i + 1])
            i += 2
            continue
        if args[i] == "--at" and i + 1 < len(args):
            opts["at"] = args[i + 1]
            i += 2
            continue
        if args[i] == "--deleted":
            opts["deleted"] = True
            i += 1
            continue
        rest.append(args[i])
        i += 1
    if sub == "attach" and 1 <= len(rest) <= 2 and not groups:
        if is_repo(rest[0]):
            return attach(rest[0], rest[1] if len(rest) == 2 else None)
        if len(rest) == 1:
            return attach_path(rest[0])
        raise Abort(USAGE)
    if sub == "detach" and len(rest) <= 1 and not groups:
        return detach(rest[0] if rest else None)
    if sub == "sync" and len(rest) <= 1:
        return do_sync(rest[0] if rest else None, groups, accept)
    if sub == "history" and len(rest) == 1 and not groups:
        return history(rest[0], opts.get("deleted", False))
    if sub == "restore" and len(rest) == 1 and not groups:
        return restore(rest[0], opts.get("at"))
    if sub == "freeze" and len(rest) <= 1 and not groups:
        return freeze(rest[0] if rest else None)
    if sub == "status" and len(rest) <= 1 and not groups:
        return status(rest[0] if rest else None)
    if sub in ("init", "update"):
        raise Abort(f"--workspace {sub} is gone since v0.6.4: use "
                    + ("attach <repo> [<vault-folder>]" if sub == "init" else "sync [<path>]"))
    raise Abort(USAGE)


# ---------------------------------------------------------------------------
# history, restore (spec 06, Zurückholen; V0.6, memos 204, 205: F229, F237)
# ---------------------------------------------------------------------------

def repo_of(target):
    """(repo top, path relative to it) for a file or folder that may be gone."""
    d = target if target.is_dir() else target.parent
    while not d.exists():
        d = d.parent
    top = git(d, "rev-parse", "--show-toplevel").stdout.strip()
    if not top:
        raise Abort(f"{target} is not in a git repo of the workspace")
    top = Path(os.path.realpath(top))
    rel = Path(os.path.realpath(target.parent) if not target.exists() else os.path.realpath(target))
    rel = (rel / target.name if not target.exists() else rel).relative_to(top).as_posix()
    return top, ("." if rel == "" else rel)


def when(top, at):
    """Commit of a time (date, date and time) or a short SHA (F229)."""
    sha = git(top, "rev-parse", "--verify", "-q", f"{at}^{{commit}}").stdout.strip()
    if sha:
        return sha
    before = at + (" 23:59:59" if re.fullmatch(r"\d{4}-\d{2}-\d{2}", at) else "")
    sha = git(top, "rev-list", "-1", f"--before={before}", "HEAD").stdout.strip()
    if not sha:
        raise Abort(f"no saved version at or before {at}")
    return sha


def history(path, deleted=False):
    """aios --workspace history <path> [--deleted]: versions of a file or project, newest first."""
    target = Path(os.path.abspath(path))
    top, rel = repo_of(target)
    fmt = "--format=%h%x09%ad%x09%an%x09%s"
    if deleted:
        out = git(top, "log", "--diff-filter=D", "--name-only", fmt, "--date=format:%Y-%m-%d %H:%M",
                  "--", rel).stdout
        say(f"=> deleted files in {target}")
        head = ""
        for line in out.splitlines():
            if "\t" in line:
                h, date, _, _ = line.split("\t", 3)
                head = f"{date} ({h})"
            elif line.strip() and not (top / line).exists():
                say(f"   {line}  deleted {head}")
        return 0
    out = git(top, "log", fmt, "--date=format:%Y-%m-%d %H:%M", "--", rel).stdout
    say(f"=> versions of {target} (newest first)")
    for line in out.splitlines():
        h, date, author, subject = line.split("\t", 3)
        say(f"   {h}  {date}  {author}: {subject}")
    if not out.strip():
        say("   (no saved version)")
    return 0


def restore(path, at=None):
    """aios --workspace restore <path> [--at <time>]: only the working tree changes; what is not
    saved and would be overwritten or removed goes to the trash first (F237)."""
    target = Path(os.path.abspath(path))
    top, rel = repo_of(target)
    tracked_now = git(top, "ls-files", "--", rel).stdout.splitlines()
    is_dir = rel == "." or target.is_dir() or git(top, "cat-file", "-t", f"HEAD:{rel}").stdout.strip() == "tree"
    if is_dir and at is None:
        raise Abort(f"{target} is a folder; restore it with --at <time> (e.g. --at 2026-11-06)")
    if at:
        src = when(top, at)
    elif git(top, "cat-file", "-e", f"HEAD:{rel}").returncode == 0:
        src = "HEAD"
    else:
        gone = git(top, "rev-list", "-1", "HEAD", "--", rel).stdout.strip()
        if not gone:
            raise Abort(f"{rel} has no saved version")
        src = f"{gone}^"
    files = git(top, "ls-tree", "-r", "--name-only", src, "--", rel).stdout.splitlines()
    if not files:
        raise Abort(f"{rel} does not exist in the version {at or src}")
    touched = sorted(set(files) | set(tracked_now))
    unsaved = [f for f in touched if (top / f).is_file() and
               (git(top, "ls-files", "--error-unmatch", "--", f).returncode != 0
                or git(top, "diff", "--quiet", "HEAD", "--", f).returncode != 0)]
    short = git(top, "rev-parse", "--short", src).stdout.strip()
    plan = Plan()

    def run():
        if unsaved:
            import shutil
            stamp = datetime.datetime.now().strftime("%Y-%m-%d %H-%M")
            bin_ = paths.home() / ".Trash" / f"{top.name} {stamp}"
            for f in unsaved:
                (bin_ / f).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(top / f, bin_ / f)
            say(f"   unsaved files copied to the trash: {bin_}")
        r = git(top, "restore", f"--source={src}", "--worktree", "--", rel)
        if r.returncode:
            raise Abort(f"restore failed: {(r.stderr or r.stdout).strip()}")
        say(f"   {rel}: restored from {short}")
    if unsaved:
        plan.add(f"copy {len(unsaved)} unsaved file(s) to the trash first: {', '.join(unsaved[:5])}")
    plan.add(f"restore {rel} from the version {short} ({len(files)} file(s)); the next sync saves it", run)
    if ui.MODE != "yes":
        say(f"=> restore {target}")
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> {rel} restored")
    return 0


# ---------------------------------------------------------------------------
# detach [<path>], attach <path> (spec 06, detach; V0.6, memos 170, 172, 175: F162-F169, F173, F174)
# ---------------------------------------------------------------------------

REGENERABLE = (".claude/skills/", ".aios/registry", ".aios/workspace.local.yaml")   # F193, F219


def write_local(root, entries):
    import yaml
    f = Path(root) / LOCAL
    if not entries:
        if f.exists():
            f.unlink()
        return
    f.parent.mkdir(parents=True, exist_ok=True)
    body = yaml.safe_dump({"schema": 1, "detached": entries}, sort_keys=False, allow_unicode=True)
    f.write_text(LOCAL_HEAD + body, encoding="utf-8")


def local_entries(root):
    import yaml
    f = Path(root) / LOCAL
    if not f.is_file():
        return []
    data = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
    return [e for e in data.get("detached") or [] if isinstance(e, dict) and e.get("path")]


def repos_in(d):
    """d and every git repo below it (nested projects too), deepest last."""
    found = [Path(d)] if (Path(d) / ".git").exists() else []
    for base, dirs, files in os.walk(d):
        b = Path(base)
        if b != Path(d) and (b / ".git").exists():
            found.append(b)
        dirs[:] = sorted(x for x in dirs if x != ".git")
    return found


def obstacles(d):
    """Why the repo d cannot be dropped safely (F165, F193); empty when nothing would be lost."""
    if not origin_of(d):
        return ["no remote"]
    if git(d, "fetch", "-q", "--tags", "origin").returncode:
        return ["fetch failed, the remote is not reachable"]
    why = []
    st = [x for x in git(d, "status", "--porcelain").stdout.splitlines() if x]
    if st:
        why.append(f"{len(st)} uncommitted or untracked: {', '.join(x[3:] for x in st[:3])}"
                   + (" …" if len(st) > 3 else ""))
    if git(d, "stash", "list").stdout.strip():
        why.append("entries in git stash")
    if outgoing(d):
        why.append(f"{len(outgoing(d))} commit(s) not pushed")
    on_remote = git(d, "for-each-ref", "--contains", "HEAD", "refs/remotes").stdout.strip()
    if not on_remote:                                   # ws/<tag>: the commit of a tag at the remote
        head = git(d, "rev-parse", "HEAD").stdout.strip()
        on_remote = head and head in git(d, "ls-remote", "--tags", "origin").stdout
    if not on_remote:
        why.append("the checked out state is not on the remote")
    nested = {Path(r).relative_to(d).as_posix() + "/" for r in repos_in(d) if Path(r) != Path(d)}
    ignored = git(d, "ls-files", "--others", "--ignored", "--exclude-standard").stdout
    lost = [f for f in ignored.splitlines()
            if f and Path(f).name != ".DS_Store"
            and not any(f.startswith(n) for n in nested)
            and not any(f == r or f.startswith(r) for r in REGENERABLE)]
    if lost:
        why.append(f"ignored file that cannot be restored: {', '.join(lost[:3])}" + (" …" if len(lost) > 3 else ""))
    return why


def check_all(top):
    """{repo: [obstacle]} for top and every repo below it."""
    found = {}
    for r in repos_in(top):
        w = obstacles(r)
        if w:
            found[r] = w
    return found


def trash_target(d):
    """~/.Trash/<name> <date time> (F173, F194)."""
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H.%M.%S")
    return paths.home() / ".Trash" / f"{Path(d).name} {stamp}"


def to_trash(d):
    import shutil
    target = trash_target(d)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(d), str(target))
    return target


DETACHED_MD = """# {name} — ausgelagert

**Seit:** {since}
**Workspace:** {root}

Dieser Ordner ist auf diesem Rechner ausgelagert (`aios --workspace detach`). Sein Inhalt liegt vollständig an den Remotes und kommt mit seiner Geschichte zurück:

| Repo | Remote |
|---|---|
{rows}

**Zurückholen:**

- im Chat: `/aios-attach {path}`
- im Terminal: `~/.aios/bin/aios --workspace attach "{abs}"`
- im Finder (macOS): Doppelklick auf `DETACHED.command`

Andere Rechner sind davon nicht betroffen. Geschrieben von AIOS; nicht ändern.
"""

DETACHED_COMMAND = """#!/bin/bash
# DETACHED.command: written by AIOS (aios --workspace detach); a double-click gets this subtree back
cd "$(dirname "$0")" || exit 1
"$HOME/.aios/bin/aios" --workspace attach "$(pwd)"
echo
read -n 1 -s -r -p "Press any key to close this window"
"""


def placeholder(root, d, rel, origins):
    d.mkdir(parents=True, exist_ok=True)
    since = datetime.date.today().isoformat()
    rows = "\n".join(f"| `{r}` | `{u}` |" for r, u in origins) or "| — | — |"
    (d / "DETACHED.md").write_text(DETACHED_MD.format(name=d.name, since=since, root=root, rows=rows,
                                                      path=rel, abs=d), encoding="utf-8")
    cmd = d / "DETACHED.command"
    cmd.write_text(DETACHED_COMMAND, encoding="utf-8")
    cmd.chmod(0o755)


def detach(path=None):
    """aios --workspace detach [<path>]: detach the subtree of the project; at the vault root (or
    with its path) detach the workspace. Without a path the project of the working directory (B33)."""
    start = Path(os.path.realpath(path or paths.cwd()))
    root = root_of(start)
    activated(root)
    if path is None:
        start = project_of(root, start)
    if start == root:
        return detach_all(root)
    rel = start.relative_to(root).as_posix()
    items = {i.path: i for i in load(root)}
    if rel not in items:
        raise Abort(f"{rel} is not a project of {root / FILE}; detach takes a project of the workspace")
    if is_detached(rel, detached(root)):
        raise Abort(f"{rel} is detached already; get it back with: aios --workspace attach {start}")
    found = check_all(start)
    if found:
        lines = [f"{Path(r).relative_to(root).as_posix() or '.'}: {'; '.join(w)}" for r, w in found.items()]
        raise Abort("nothing detached, something would be lost:\n      " + "\n      ".join(lines))
    origins = [(Path(r).relative_to(root).as_posix(), origin_of(r)) for r in repos_in(start)]
    plan = Plan()

    def run():
        target = to_trash(start)
        placeholder(root, start, rel, origins)
        write_local(root, local_entries(root) + [{"path": rel, "since": datetime.date.today().isoformat()}])
        report(rel, "detached", f"moved to {target}")
    plan.add(f"move {rel} with {len(origins)} repo(s) to the trash (~/.Trash), checked: nothing is lost", run)
    plan.add(f"placeholder {rel}/DETACHED.md and {rel}/DETACHED.command; entry in {LOCAL}")
    if ui.MODE != "yes":
        say(f"=> detach {rel} on this machine")
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> {rel} detached; get it back with: aios --workspace attach {start}")
    return 0


def detach_all(root):
    found = check_all(root)
    if found:
        lines = [f"{Path(r).relative_to(root).as_posix() or '.'}: {'; '.join(w)}" for r, w in found.items()]
        raise Abort("nothing detached, something would be lost:\n      " + "\n      ".join(lines))
    plan = Plan()

    def run():
        target = to_trash(root)
        report(".", "detached", f"moved to {target}")
    plan.add(f"move the vault {root} to the trash (~/.Trash), checked: nothing is lost", run)
    plan.add("the installation, the hooks and other vaults stay")
    if ui.MODE != "yes":
        say(f"=> detach the workspace {root} from this machine")
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> workspace {root.name} detached; attach it again with: aios --workspace attach <repo>")
    return 0


def attach_path(path):
    """aios --workspace attach <path>: get a detached subtree back (F162, F167)."""
    start = Path(os.path.abspath(path))
    root = root_of(start.parent if not start.exists() else start)
    activated(root)
    rel = start.relative_to(root).as_posix()
    entries = local_entries(root)
    if not any(e["path"] == rel for e in entries):
        raise Abort(f"{rel} is not detached on this machine ({root / LOCAL})")
    extra = [x.name for x in start.iterdir() if x.name not in ("DETACHED.md", "DETACHED.command", ".DS_Store")] \
        if start.is_dir() else []
    if extra:
        raise Abort(f"{start} holds more than the placeholder ({', '.join(extra)}); nothing changed")
    items = [i for i in load(root) if under(i, rel)]
    plan = Plan()
    cloned = []

    def unplace():
        for n in ("DETACHED.md", "DETACHED.command", ".DS_Store"):
            if (start / n).exists():
                (start / n).unlink()
        if start.is_dir():
            start.rmdir()
        write_local(root, [e for e in entries if e["path"] != rel])
    plan.add(f"remove the placeholder of {rel} and its entry in {LOCAL}", unplace)
    failed = []
    for item in items:
        plan.add(f"clone {item.url} ({item.revision}) -> {item.path}",
                 lambda item=item, d=root / item.path: try_clone(item, d, cloned, failed))
    plan.add("make the cloned projects runnable (aios --fetch, registration)",
             lambda: [runnable(d) for d in cloned])
    if ui.MODE != "yes":
        say(f"=> attach {rel} again")
    ui.confirm(plan, "go on?", "cancelled")
    say(f"=> {rel} attached")
    return 0


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
    gone = detached(root)
    for item in items:
        d = (root / item.path).resolve() if (root / item.path).exists() else root / item.path
        if start != d and start not in d.parents:
            continue
        depth = sum(1 for r in results if r.path != d and r.path in d.parents)   # projects above it
        if is_detached(item.path, gone):            # F169, F198: integer, the projects below not checked
            if any(Path(g) == Path(item.path) for g in gone):
                results[:] = [r for r in results if r.path != d]
                results.append(Result(d, depth, repo=True, init_note="detached"))
            continue
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
