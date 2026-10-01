"""aios --deploy, aios --library (spec 03, Ausrollen und Versionen).

A deployed blueprint carries the marker .aios-deploy (name, version, source, digest of the
deployed files). It travels with the blueprint through git and tells deployed blueprints
from local ones, direct changes from the deployed state and the source for a reconcile.
"""

from __future__ import annotations

import io
import os
import re
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path

from . import config, paths, registry, version
from .install import frontmatter, make_writable, semver_key
from .ui import Abort, Plan, confirm, say, warn

MARKER = ".aios-deploy"
SPEC = re.compile(r"^([a-z0-9][a-z0-9-]{0,63})==v?(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)$")
LIBRARY = "library"


# ---------------------------------------------------------------------------
# sources: library of the running version, maintenance projects (git tags)
# ---------------------------------------------------------------------------

def library_root():
    return Path(__file__).resolve().parents[2] / "skills"


def library():
    """{name: {version: dir}} of the bundled skills (all groups except aios)."""
    found = {}
    root = library_root()
    if not root.is_dir():
        return found
    for group in sorted(p for p in root.iterdir() if p.is_dir() and p.name != "aios"):
        for skill in sorted(p for p in group.iterdir() if p.is_dir()):
            if (skill / "SKILL.md").is_file():                       # clone: version in the frontmatter
                v = frontmatter(skill / "SKILL.md").get("version")
                if v:
                    found.setdefault(skill.name, {})[v] = skill
            for vdir in sorted(p for p in skill.iterdir() if (p / "SKILL.md").is_file()):
                found.setdefault(skill.name, {})[vdir.name] = vdir   # installation: <name>/<version>/
    return found


def from_library(name, ver):
    versions = library().get(name)
    if not versions:
        raise Abort(f"AIOS {version()} has no bundled skill {name} (aios --library)")
    if ver not in versions:
        raise Abort(f"{name} {ver} is not bundled with AIOS {version()}; available: "
                    + ", ".join(sorted(versions, key=semver_key)))
    return versions[ver]


def from_repo(repo, name, ver, stage):
    """Extract @Skill/<name>/ at the tag <name>-v<version> into stage, check the frontmatter."""
    repo = Path(os.path.abspath(repo))
    tag = f"{name}-v{ver}"
    git = ["git", "-C", str(repo)]
    if subprocess.run(git + ["rev-parse", "-q", "--verify", f"refs/tags/{tag}"],
                      capture_output=True).returncode:
        raise Abort(f"no tag {tag} in {repo}")
    r = subprocess.run(git + ["archive", "--format=tar", tag, f"@Skill/{name}"], capture_output=True)
    if r.returncode:
        raise Abort(f"{repo} has no @Skill/{name}/ at the tag {tag}")
    with tarfile.open(fileobj=io.BytesIO(r.stdout)) as t:
        if hasattr(tarfile, "data_filter"):
            t.extractall(stage, filter="data")
        else:
            t.extractall(stage)
    src = stage / "@Skill" / name
    meta = frontmatter(src / "SKILL.md") if (src / "SKILL.md").is_file() else {}
    if meta.get("name") != name or meta.get("version") != ver:
        raise Abort(f"@Skill/{name}/SKILL.md at {tag} says name {meta.get('name')!r}, "
                    f"version {meta.get('version')!r}; expected {name} {ver}")
    return src


# ---------------------------------------------------------------------------
# marker and file comparison
# ---------------------------------------------------------------------------

def files_of(d):
    """{relative path: bytes} of a skill directory without the marker."""
    out = {}
    for root, dirs, files in os.walk(d):
        for f in files:
            p = Path(root) / f
            rel = p.relative_to(d).as_posix()
            if rel != MARKER:
                out[rel] = p.read_bytes()
    return out


def digest_of(d):
    import hashlib
    h = hashlib.sha256()
    for rel, data in sorted(files_of(d).items()):
        h.update(f"{rel}\n".encode())
        h.update(data)
        h.update(b"\n")
    return "sha256:" + h.hexdigest()


def read_marker(d):
    f = d / MARKER
    if not f.is_file():
        return None
    out = {}
    for line in f.read_text(encoding="utf-8").splitlines():
        if ":" in line and not line.startswith("#"):
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip().strip('"')
    return out


def write_marker(d, name, ver, source, dig):
    (d / MARKER).write_text(
        f"# written by aios --deploy, do not edit\nname: {name}\nversion: {ver}\n"
        f'source: "{source}"\ndigest: {dig}\n', encoding="utf-8")


def differences(src, dst):
    """Lines new/changed/remove per file between source and existing blueprint."""
    a, b = files_of(src), files_of(dst) if dst.is_dir() else {}
    out = [f"new      {r}" for r in sorted(set(a) - set(b))]
    out += [f"changed  {r}" for r in sorted(set(a) & set(b)) if a[r] != b[r]]
    out += [f"remove   {r}" for r in sorted(set(b) - set(a))]
    return out


def writable_copy(src, dst, ignore=None):
    """Copy a skill folder with normal permissions: the library of an installation is read-only."""
    shutil.copytree(src, dst, ignore=ignore, copy_function=shutil.copyfile)
    make_writable(dst)


def mirror(src, dst, name, ver, source):
    """Replace dst by a copy of src (only this one folder) and write the marker."""
    tmp = Path(tempfile.mkdtemp(prefix=f".{name}.", dir=dst.parent))
    try:
        writable_copy(src, tmp / name, ignore=shutil.ignore_patterns(MARKER))
        write_marker(tmp / name, name, ver, source, digest_of(src))
        if dst.exists():
            make_writable(dst)
            shutil.rmtree(dst)
        os.rename(tmp / name, dst)
    finally:
        make_writable(tmp)
        shutil.rmtree(tmp, ignore_errors=True)


# ---------------------------------------------------------------------------
# target
# ---------------------------------------------------------------------------

def target_project(to):
    p = Path(os.path.abspath(to or paths.cwd()))
    root = config.vault_root(p)
    if root is None:
        raise Abort(f"{p} is not in a vault")
    if not (p / "@").is_dir():
        raise Abort(f"{p} is not a project (no @/); give --to <project> or initialize it with /aios-init")
    if not config.load(p).aios:
        raise Abort(f"{p} is not activated (legacy mode); run: aios --activate v<version> {root}")
    return p


def blueprint_dir(project, name, assistant):
    if assistant:
        a = project / "@" / "@!Assistant" / assistant
        if not a.is_dir():
            raise Abort(f"no assistant {assistant} in {project / '@' / '@!Assistant'}")
        return a / "@!Skill" / name, f"{assistant}/{name}"
    return project / "@" / "@!Skill" / name, name


# ---------------------------------------------------------------------------
# commands
# ---------------------------------------------------------------------------

def show_library():
    lib = library()
    if not lib:
        say(f"AIOS {version()} bundles no skills")
        return 0
    for name in sorted(lib):
        say(f"{name:24} {', '.join(sorted(lib[name], key=semver_key))}")
    return 0


def register_session(plan):
    """Step 5 of the deploy: register the project skills of the session (spec 03)."""
    cwd = paths.cwd()

    def run():
        ctx, s = registry.sync_for(cwd)
        if s:
            s.apply()
            say(f"   registered in {cwd}: {s.summary()}")
    ctx, s = registry.sync_for(cwd)
    if s is not None:
        plan.add(f"register the project skills of {cwd}", run)


def deploy(spec, to=None, assistant=None, source=None):
    m = SPEC.match(spec)
    if not m:
        raise Abort(f"{spec}: expected <name>==<version>, e.g. memo==6.0.0")
    name, ver = m.group(1), m.group(2)
    if name.startswith("aios-"):
        raise Abort(f"{name} is an AIOS skill; aios --install provides it")
    project = target_project(to)
    dst, key = blueprint_dir(project, name, assistant)
    stage = Path(tempfile.mkdtemp(prefix="aios-deploy."))
    try:
        src = from_repo(source, name, ver, stage) if source else from_library(name, ver)
        origin = str(Path(os.path.abspath(source))) if source else LIBRARY
        file = project / ".aios" / "config.yaml"
        try:
            old = config.read(file).get("skills", {}) if file.is_file() else {}
        except config.ConfigError as e:
            raise Abort(f"{e}; fix the file first")
        old = old if isinstance(old, dict) else {}
        plan = Plan()
        diff = differences(src, dst)
        mark = read_marker(dst) if dst.is_dir() else None
        if dst.is_dir() and mark is None:
            plan.add(f"note: {dst} is a local skill without {MARKER}; it is replaced")
        elif mark and digest_of(dst) != mark.get("digest"):
            plan.add(f"note: {dst} was changed directly (differs from {name} {mark.get('version')}); "
                     f"the changes are replaced")
        if diff or not mark or mark.get("version") != ver or mark.get("source") != origin:
            plan.add(f"blueprint {dst}: {name} {ver} from {origin}"
                     + "".join(f"\n         {d}" for d in diff),
                     lambda: (dst.parent.mkdir(parents=True, exist_ok=True), mirror(src, dst, name, ver, origin)))
        if old.get(key) != ver:
            plan.add(f"manifest {file}: {key}: {old.get(key, '(new)')} -> {ver}",
                     lambda: config.set_skill(file, key, ver))
        if not plan:
            say(f"=> {name} {ver} is already deployed in {dst}, nothing to do")
            return 0
        if not assistant:
            register_session(plan)
        say(f"=> deploy {name} {ver} to {project}" + (f" (assistant {assistant})" if assistant else ""))
        confirm(plan, "deploy?", "deployment cancelled")
    finally:
        shutil.rmtree(stage, ignore_errors=True)
    say(f"=> {name} {ver} deployed")
    say("   the skill is available from the next chat (or after /reload-skills)")
    return 0


def reconcile(to=None, source=None):
    """aios --deploy without a name: the blueprints follow the manifest skills: of the project."""
    project = target_project(to)
    file = project / ".aios" / "config.yaml"
    try:
        wanted = config.read(file).get("skills", {}) if file.is_file() else {}
    except config.ConfigError as e:
        raise Abort(f"{e}; fix the file first")
    wanted = wanted if isinstance(wanted, dict) else {}
    plan = Plan()
    stages = []
    try:
        for key, ver in sorted(wanted.items()):
            assistant, _, name = key.rpartition("/")
            dst, _ = blueprint_dir(project, name, assistant or None)
            mark = read_marker(dst) if dst.is_dir() else None
            if mark and mark.get("version") == ver and digest_of(dst) == mark.get("digest"):
                continue
            origin = source or (mark.get("source") if mark and mark.get("source") != LIBRARY else None)
            try:
                if origin:
                    st = Path(tempfile.mkdtemp(prefix="aios-deploy."))
                    stages.append(st)
                    src = from_repo(origin, name, ver, st)
                else:
                    src = from_library(name, ver)
            except Abort as e:
                warn(f"{key} {ver}: {e}")
                continue
            why = ("missing" if not dst.is_dir() else "local skill, replaced" if not mark else
                   f"{mark.get('version')} -> {ver}" if mark.get("version") != ver else "changed directly, restored")
            src_name = str(Path(os.path.abspath(origin))) if origin else LIBRARY
            plan.add(f"blueprint {dst}: {key} {ver} ({why})",
                     lambda src=src, dst=dst, name=name, ver=ver, o=src_name:
                     (dst.parent.mkdir(parents=True, exist_ok=True), mirror(src, dst, name, ver, o)))
        for base, assistant in [(project / "@" / "@!Skill", None)] + \
                [(a / "@!Skill", a.name) for a in sorted((project / "@" / "@!Assistant").glob("*")) if a.is_dir()]:
            for d in sorted(base.glob("*")) if base.is_dir() else []:
                key = f"{assistant}/{d.name}" if assistant else d.name
                if (d / MARKER).is_file() and key not in wanted:
                    plan.add(f"remove {d}: deployed, but no longer in the manifest",
                             lambda d=d: shutil.rmtree(d))
        if not plan:
            say(f"=> the blueprints of {project} match the manifest")
            return 0
        register_session(plan)
        say(f"=> reconcile the blueprints of {project} with skills: in {file}")
        confirm(plan, "reconcile?", "reconcile cancelled")
    finally:
        for st in stages:
            shutil.rmtree(st, ignore_errors=True)
    say("=> blueprints match the manifest; skills are available from the next chat (or after /reload-skills)")
    return 0


def command(args):
    """Parse aios --deploy [<name>==<version>] [--to <p>] [--assistant <a>] [--from <repo>]."""
    opts, spec, i = {}, None, 0
    while i < len(args):
        a = args[i]
        if a in ("--to", "--assistant", "--from") and i + 1 < len(args):
            opts[a[2:]] = args[i + 1]
            i += 2
            continue
        if a.startswith("--") or spec is not None:
            raise Abort(f"unexpected argument {a}")
        spec = a
        i += 1
    if spec:
        return deploy(spec, opts.get("to"), opts.get("assistant"), opts.get("from"))
    if "assistant" in opts:
        raise Abort("--assistant needs <name>==<version>")
    return reconcile(opts.get("to"), opts.get("from"))
