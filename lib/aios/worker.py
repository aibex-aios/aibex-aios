"""Workhorses (spec 07) and aios --run (spec 06).

A workhorse is a package of type worker. Every version is installed once per machine under
<root>/workers/<package>/v<version>/ (root: AIOS_PREFIX if it is a writable folder, else ~/.aios)
and listed in <root>/workers.yaml. Which version applies is decided by lock.yaml of the nearest
project of the chain; the forwarders in ~/.aios/bin/ (templates/worker-forwarder) choose it.
setup and remove run only after a confirmation that shows what they install (P3, A1). A command
of a package runs with aios --run when the user calls it, without a question (P3).
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

from . import deploy, elements, package, paths, ui
from .install import make_readonly, make_writable
from .ui import Abort, Plan, say, warn

FORWARDER_MARK = "# worker-forwarder: ~/.aios/bin/<program>"


# ---------------------------------------------------------------------------
# where: root, workers.yaml, installation of a version
# ---------------------------------------------------------------------------

def root():
    """AIOS_PREFIX (/opt/aios) if it is a writable folder, else ~/.aios (spec 07, Installation)."""
    prefix = paths.prefix()
    if prefix.is_dir() and os.access(prefix, os.W_OK):
        return prefix
    return paths.user_dir()


def state_file():
    return root() / "workers.yaml"


def install_dir(pkg, version):
    return root() / "workers" / pkg / f"v{version}"


def bin_dir():
    return paths.user_dir() / "bin"


def read_state():
    import yaml
    f = state_file()
    if not f.is_file():
        return {"schema": 1, "programs": {}, "workers": {}}
    try:
        data = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as e:
        raise Abort(f"{f}: {e}")
    data["programs"] = data.get("programs") or {}
    data["workers"] = {k: {str(v): e for v, e in (vs or {}).items()} for k, vs in (data.get("workers") or {}).items()}
    return data


def write_state(data):
    """workers.yaml in the subset of spec 04 (read by the forwarders without PyYAML)."""
    from . import yamlsub
    programs, workers = {}, {}
    for pkg, versions in sorted((data.get("workers") or {}).items()):
        if not versions:
            continue
        workers[pkg] = {}
        for ver, e in sorted(versions.items()):
            workers[pkg][str(ver)] = {"kind": e.get("kind"), "programs": sorted(e.get("programs") or []),
                                      "check": e.get("check", "-"),
                                      "projects": sorted(set(e.get("projects") or []))}
            for prog in e.get("programs") or []:
                programs.setdefault(prog, [])
                if pkg not in programs[prog]:
                    programs[prog].append(pkg)
    f = state_file()
    f.parent.mkdir(parents=True, exist_ok=True)
    out = {"schema": 1, "programs": {k: sorted(v) for k, v in sorted(programs.items())}, "workers": workers}
    f.write_text(yamlsub.dump(out, "written by AIOS (worker setup), do not edit"), encoding="utf-8")


def installed(pkg, version):
    e = (read_state()["workers"].get(pkg) or {}).get(str(version))
    return e is not None and install_dir(pkg, version).is_dir()


# ---------------------------------------------------------------------------
# python of the kernel (spec 07, setup; V0.5, memo 41, N2)
# ---------------------------------------------------------------------------

def kernel_python():
    """The python3 the venv of the active kernel installation is built with; in a development
    state (clone without venv) the python3 AIOS runs with."""
    if sys.prefix != sys.base_prefix:
        cfg = Path(sys.prefix) / "pyvenv.cfg"
        if cfg.is_file():
            for line in cfg.read_text(encoding="utf-8").splitlines():
                key, _, value = line.partition("=")
                if key.strip() == "home":
                    for name in ("python3", "python"):
                        cand = Path(value.strip()) / name
                        if cand.is_file():
                            return str(cand)
        base = getattr(sys, "_base_executable", None)
        if base:
            return base
    return sys.executable


def requirement_lines(text):
    """paket==version of a requirements file with hashes, without the hashes (plan, L7)."""
    out = []
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith(("#", "--")):
            out.append(line.split()[0])
    return out


# ---------------------------------------------------------------------------
# setup and remove of one version
# ---------------------------------------------------------------------------

def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    for line in (r.stdout + r.stderr).splitlines():
        say(f"   | {line}")
    if r.returncode:
        raise RuntimeError(f"{' '.join(map(str, cmd[:3]))} … ended with exit {r.returncode}")
    return r


def env_for(d, target):
    return dict(os.environ, AIOS_PACKAGE=str(d), AIOS_WORKER_DIR=str(target),
                PATH=f"{bin_dir()}{os.pathsep}{os.environ.get('PATH', '')}")


def plan_lines(d, m):
    """What setup installs, for the plan (spec 07, Abläufe; P3)."""
    w = m.worker
    if w["kind"] == "python":
        reqs = requirement_lines((d / w["requirements"]).read_text(encoding="utf-8"))
        lines = [f"python {kernel_python()}, {len(reqs)} packages from {w['requirements']}:"]
        lines += [f"| {r}" for r in reqs]
    else:
        lines = [f"bash {w['setup']}:"]
        lines += [f"| {x}" for x in (d / w["setup"]).read_text(encoding="utf-8").splitlines()]
    if w.get("check"):
        lines.append(f"check: {w['check']}")
    return lines


def relocate(old, new):
    """Rewrite the path of the build folder in the text files of bin/ (shebangs of pip, activate)."""
    for f in (new / "bin").iterdir():
        if f.is_symlink() or not f.is_file():
            continue
        data = f.read_bytes()
        if b"\0" not in data[:1024] and str(old).encode() in data:
            f.write_bytes(data.replace(str(old).encode(), str(new).encode()))


def setup(d, m, project):
    """Build the version of m from the package folder d in v<version>.new, then rename (N1)."""
    w = m.worker
    target = install_dir(m.name, m.version)
    new = target.with_name(target.name + ".new")
    if new.exists():
        make_writable(new)
        shutil.rmtree(new)
    new.parent.mkdir(parents=True, exist_ok=True)
    try:
        if w["kind"] == "python":
            run([kernel_python(), "-m", "venv", str(new)])
            pip = [str(new / "bin" / "python"), "-m", "pip", "install", "-q", "--disable-pip-version-check",
                   "--require-hashes", "--no-deps", "-r", str(d / w["requirements"])]
            links = os.environ.get("AIOS_PIP_FIND_LINKS")
            if links:
                pip += ["--no-index", "--find-links", links]
            run(pip, cwd=d)
        else:
            new.mkdir(parents=True)
            run(["bash", str(d / w["setup"])], cwd=d, env=env_for(d, new))
        missing = [p for p in w["programs"] if not os.access(new / "bin" / p, os.X_OK)]
        if missing:
            raise RuntimeError("programs missing in bin/: " + ", ".join(missing))
        if w["kind"] == "python":
            run([str(new / "bin" / "python"), "-m", "compileall", "-q", str(new / "lib")])
        if w.get("check"):
            env = env_for(d, new)
            env["PATH"] = f"{new / 'bin'}{os.pathsep}{env['PATH']}"
            run(["bash", "-c", w["check"]], env=env)
        if target.exists():
            make_writable(target)
            shutil.rmtree(target)
        os.rename(new, target)
        relocate(new, target)
        make_readonly(target)
    except BaseException:
        if w["kind"] == "script" and w.get("remove") and new.exists():
            subprocess.run(["bash", str(d / w["remove"])], cwd=d, env=env_for(d, new), capture_output=True)
        if new.exists():
            make_writable(new)
            shutil.rmtree(new)
        raise
    data = read_state()
    entry = data["workers"].setdefault(m.name, {}).setdefault(str(m.version), {})
    entry.update(kind=w["kind"], programs=list(w["programs"]), check="ok" if w.get("check") else "-")
    entry["projects"] = sorted(set(entry.get("projects") or []) | {str(project)})
    write_state(data)
    for prog in w["programs"]:
        put_forwarder(prog)


def remove(pkg, version, d=None, m=None):
    """Remove one installed version; the forwarders go with the last version (spec 07, remove)."""
    target = install_dir(pkg, version)
    if target.exists():
        make_writable(target)
        if m is not None and m.worker.get("kind") == "script" and m.worker.get("remove") and d:
            subprocess.run(["bash", str(d / m.worker["remove"])], cwd=d, env=env_for(d, target),
                           capture_output=True)
        shutil.rmtree(target)
    data = read_state()
    versions = data["workers"].get(pkg) or {}
    gone = versions.pop(str(version), None) or {}
    if not versions:
        data["workers"].pop(pkg, None)
    write_state(data)
    still = {p for vs in data["workers"].values() for e in vs.values() for p in e.get("programs") or []}
    for prog in gone.get("programs") or []:
        if prog not in still:
            f = bin_dir() / prog
            if f.is_file() and FORWARDER_MARK in f.read_text(encoding="utf-8", errors="replace"):
                f.unlink()


def put_forwarder(prog):
    src = Path(__file__).resolve().parents[2] / "templates" / "worker-forwarder"
    text = src.read_text(encoding="utf-8")
    target = bin_dir() / prog
    if target.exists():
        old = target.read_text(encoding="utf-8", errors="replace")
        if FORWARDER_MARK not in old:
            warn(f"{target} is not an AIOS forwarder, left untouched")
            return
        if old == text:
            return
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")
    target.chmod(0o755)


# ---------------------------------------------------------------------------
# loading a package: the part of the workhorses in the plan of aios --fetch (spec 07, Abläufe)
# ---------------------------------------------------------------------------

def subset_entries(f, section):
    """{name: {key: value}} of the two-level mappings below section: of a file in the subset of
    spec 04, read line by line without PyYAML (the hook AIOS-WORKERS runs without it, like the
    forwarders)."""
    out, name, inside = {}, None, False
    try:
        text = Path(f).read_text(encoding="utf-8")
    except OSError:
        return out
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if not line.startswith(" "):
            inside, name = line.rstrip() == f"{section}:", None
        elif inside and line.startswith("  ") and not line.startswith("   "):
            name = line.strip().rstrip(":").strip('"')
            out[name] = {}
        elif inside and name and line.startswith("    ") and not line.startswith("     "):
            key, _, val = line.strip().partition(":")
            out[name][key.strip('"')] = val.strip().strip('"')
    return out


def locked_workers(project):
    """{package: version} of the worker packages (worker-<name>) in lock.yaml of project."""
    entries = subset_entries(Path(project) / ".aios" / "lock.yaml", "packages")
    return {n: e["version"] for n, e in entries.items() if n.startswith("worker-") and e.get("version")}


def users(pkg, version, data, but=None):
    """Projects of workers.yaml whose lock.yaml still names pkg version, without but (Fragepaket
    zu Schritt 7: workers.yaml, checked against lock.yaml; orphaned entries do not count)."""
    e = (data["workers"].get(pkg) or {}).get(str(version)) or {}
    return [p for p in e.get("projects") or []
            if p != str(but) and locked_workers(p).get(pkg) == str(version)]


def order(picks):
    """Worker picks with the workhorses they depend on first (spec 07, setup)."""
    out, seen = [], set()

    def visit(name):
        if name in seen or name not in picks:
            return
        seen.add(name)
        for d in picks[name].manifest.depends:
            visit(d)
        out.append(name)
    for name in sorted(picks):
        visit(name)
    return out


def conflicts(project, picks, programs_of):
    """Two different packages with the same program in the chain of project (F9): the lock.yaml
    from the parent of project up to the vault root and the picks of the plan."""
    from . import config
    owner = {}
    for name in sorted(picks):
        for prog in programs_of(name):
            owner.setdefault(prog, set()).add(name)
    data = read_state()
    for d in config.chain_dirs(project)[1:]:
        for pkg, ver in locked_workers(d).items():
            e = (data["workers"].get(pkg) or {}).get(ver)
            progs = e.get("programs") if e else None
            if progs is None:
                try:
                    progs = package.load(Path(d) / "@" / "@!Package" / pkg).worker["programs"]
                except (package.ManifestError, OSError, TypeError, KeyError):
                    progs = []
            for prog in progs:
                owner.setdefault(prog, set()).add(pkg)
    return {prog: sorted(pkgs) for prog, pkgs in owner.items() if len(pkgs) > 1}


def note_projects(project, now, before):
    """workers.yaml: project uses the versions in now and no longer those of before."""
    data = read_state()
    for pkg, ver in before.items():
        if now.get(pkg) != ver:
            e = (data["workers"].get(pkg) or {}).get(ver)
            if e:
                e["projects"] = [p for p in e.get("projects") or [] if p != str(project)]
    for pkg, ver in now.items():
        e = (data["workers"].get(pkg) or {}).get(ver)
        if e is not None:
            e["projects"] = sorted(set(e.get("projects") or []) | {str(project)})
    write_state(data)


def missing(dirs):
    """(package, version) locked in the lock.yaml of dirs but not on the machine: the folder and
    the entry in workers.yaml must both exist (AIOS-WORKERS, spec 02; without PyYAML)."""
    known = subset_entries(state_file(), "workers")
    out = []
    for d in dirs:
        for pkg, ver in sorted(locked_workers(d).items()):
            ok = ver in known.get(pkg, {}) and install_dir(pkg, ver).is_dir()
            if not ok and (pkg, ver) not in out:
                out.append((pkg, ver))
    return out


# ---------------------------------------------------------------------------
# aios --worker
# ---------------------------------------------------------------------------

def fetched_workers(project):
    """(package folder, manifest) of the fetched worker packages of a project."""
    out = []
    for p in elements.packages(project / "@"):
        if not (p.dir / "manifest.yaml").is_file():
            continue
        try:
            m = package.load(p.dir)
        except package.ManifestError:
            continue
        if m.type == "worker":
            out.append((p.dir, m))
    return out


def show(to=None):
    """aios --worker: installed workhorses with version, place, programs, projects, check."""
    project = deploy.target_project(to)
    data = read_state()
    rows = []
    for pkg, versions in sorted(data["workers"].items()):
        for ver, e in sorted(versions.items()):
            rows.append(f"   {pkg} {ver}  {install_dir(pkg, ver)}  programs {', '.join(e.get('programs') or [])}"
                        f"  check {e.get('check', '-')}")
            rows += [f"      used by {p}" + ("" if os.path.isdir(p) else " (orphaned)")
                     for p in e.get("projects") or []]
    for d, m in fetched_workers(project):
        if not installed(m.name, m.version):
            rows.append(f"   {m.name} {m.version}  not installed (fetched in {project}); "
                        f"run: aios --worker {m.name} setup")
    if not rows:
        say(f"=> no workhorses installed ({state_file()})")
        return 0
    say(f"=> workhorses ({state_file()})")
    for r in rows:
        say(r)
    return 0


def repair(pkg, to=None):
    """aios --worker <package> setup: (re)build the version fetched in the target project."""
    project = deploy.target_project(to)
    found = [(d, m) for d, m in fetched_workers(project) if m.name == pkg]
    if not found:
        raise Abort(f"no fetched worker package {pkg} in {project}; fetch it with aios --fetch {pkg}")
    d, m = found[0]
    plan = Plan()
    plan.add(f"setup {m.name} {m.version} -> {install_dir(m.name, m.version)}"
             + "".join(f"\n         {x}" for x in plan_lines(d, m)), lambda: setup(d, m, project))
    if ui.MODE != "yes":
        say(f"=> set up the workhorse {m.name} {m.version} for {project}")
    try:
        ui.confirm(plan, "set up?", "cancelled")
    except (ui.PlanOnly, Abort, SystemExit):
        raise
    except Exception as e:                          # noqa: BLE001 - report, nothing stays half done
        raise Abort(f"setup of {m.name} {m.version} failed: {e}; nothing installed")
    say(f"=> {m.name} {m.version} set up; programs in {bin_dir()}: {', '.join(m.worker['programs'])}")
    return 0


def command(args):
    to, rest, i = None, [], 0
    while i < len(args):
        if args[i] == "--to" and i + 1 < len(args):
            to = args[i + 1]
            i += 2
            continue
        rest.append(args[i])
        i += 1
    if not rest:
        return show(to)
    if len(rest) == 2 and rest[1] == "setup":
        return repair(rest[0], to)
    raise Abort("usage: aios --worker [<package> setup] [--to <project>]")


# ---------------------------------------------------------------------------
# aios --run
# ---------------------------------------------------------------------------

def run_command(args):
    """aios --run <command> [arguments]: a deployed command of a package of the chain, nearest
    masterspace first; the user calls it, so there is no question (P3)."""
    if not args:
        raise Abort("usage: aios --run <command> [arguments]")
    name, rest = args[0], args[1:]
    from . import context
    ctx = context.Context(paths.cwd())
    if ctx.mode != "aios":
        raise Abort(f"{paths.cwd()} is not in an activated vault")
    for ms in reversed(ctx.masterspaces):
        for p in elements.packages(ms):
            f = p.dir / "commands" / name
            if f.is_file() and p.deployed(name):
                env = dict(os.environ, AIOS_PACKAGE=str(p.dir), AIOS_PROJECT=str(ms.parent),
                           AIOS_DATA=str(ms.parent / "@Data" / p.name))
                return subprocess.run(["bash", str(f), *rest], env=env).returncode
    raise Abort(f"no deployed command {name} in the packages of the chain")
