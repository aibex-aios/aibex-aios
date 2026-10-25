"""Registration of the project skills (spec 03, Registrieren; registry format spec 04).

The blueprints @/@!Skill/<name>/ and the deployed skills of fetched packages
@/@!Package/<paket>/skills/<name>/ of the chain are copied to <project>/.claude/skills/<name>/
and recorded in <project>/.aios/registry (in v0.3: .aios/manifest). Standard library only.
"""

from __future__ import annotations

import hashlib
import os
import re
import shutil
import tempfile
from pathlib import Path

from . import context, elements
from .install import frontmatter, make_writable

NAME = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")
RESERVED = "aios-"


# ---------------------------------------------------------------------------
# blueprints of the chain
# ---------------------------------------------------------------------------

def digest(d):
    """sha256 over the relative paths and contents of all files of a skill directory."""
    h = hashlib.sha256()
    for root, dirs, files in os.walk(d):
        dirs.sort()
        for f in sorted(files):
            p = Path(root) / f
            h.update(f"{p.relative_to(d).as_posix()}\n".encode())
            h.update(p.read_bytes())
            h.update(b"\n")
    return "sha256:" + h.hexdigest()


def version_of(meta):
    return str(meta.get("version") or "").strip().strip("'\"")


def version_problem(kind, name, meta):
    """None if meta has a version MAJOR.MINOR.PATCH (spec 03: required for every skill and assistant)."""
    ver = version_of(meta)
    if not ver:
        return f"{kind} {name} has no version"
    if not SEMVER.match(ver):
        return f"{kind} {name} has an invalid version {ver!r} (MAJOR.MINOR.PATCH)"
    return None


def blueprints(ctx):
    """({name: (dir, version)}, [problems]); the nearest masterspace wins, within a masterspace
    the local blueprint before the skill of a package (spec 03, spec 06 Vorrang)."""
    found, problems = {}, []
    for _, d, _ in elements.candidates(ctx.masterspaces, "skills", "@!Skill"):
        if d.name.startswith(RESERVED):
            problems.append(f"{d}: the name {d.name} is reserved for AIOS skills, not registered")
            continue
        if d.name == "gui":
            problems.append(f"{d}: the name gui is reserved for the alias /gui, not registered")
            continue
        if not NAME.match(d.name):
            problems.append(f"{d}: {d.name} is not a valid skill name, not registered")
            continue
        if not (d / "SKILL.md").is_file():
            problems.append(f"{d}: no SKILL.md, not registered")
            continue
        meta = frontmatter(d / "SKILL.md")
        if meta.get("name") != d.name:
            problems.append(f"{d}: name in SKILL.md is {meta.get('name')!r}, not {d.name!r}; not registered")
            continue
        problem = version_problem("skill", d.name, meta)
        if problem:
            problems.append(f"{problem}, not registered ({d})")
            continue
        found[d.name] = (d, version_of(meta))
    return found, problems


# ---------------------------------------------------------------------------
# registry (fixed format of spec 04; .aios/manifest in v0.3)
# ---------------------------------------------------------------------------

def registry_file(project):
    return Path(project) / ".aios" / "registry"


def old_file(project):
    return Path(project) / ".aios" / "manifest"


def read_registry(project):
    """Registered skills of a project: .aios/registry, else the .aios/manifest of v0.3."""
    f = registry_file(project)
    return read_manifest(f if f.is_file() else old_file(project))


def read_manifest(file):
    """{name: {source, version, digest}}; an unreadable registry counts as empty."""
    result, name = {}, None
    if not file.is_file():
        return result
    for line in file.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^  ([^\s:][^:]*):\s*$", line)
        if m:
            name = m.group(1)
            result[name] = {}
            continue
        m = re.match(r"^    (source|version|digest):\s*(.*?)\s*$", line)
        if m and name:
            result[name][m.group(1)] = m.group(2).strip('"')
            continue
        if not line.startswith(" "):
            name = None
    return result


def read_manifest_marker(file):
    """Keys of a marker .aios-deploy (name, version, source, digest), read without PyYAML."""
    out = {}
    for line in Path(file).read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"^([a-z]+):\s*(.*?)\s*$", line)
        if m:
            out[m.group(1)] = m.group(2).strip('"')
    return out


def write_manifest(file, entries):
    lines = ["# written by AIOS (registration), do not edit", "schema: 1", "registered:"]
    for name in sorted(entries):
        e = entries[name]
        lines += [f"  {name}:", f'    source: "{e["source"]}"',
                  f"    version: {e.get('version') or ''}".rstrip(), f"    digest: {e['digest']}"]
    file.parent.mkdir(parents=True, exist_ok=True)
    tmp = file.with_name(file.name + ".tmp")
    tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.replace(tmp, file)


# ---------------------------------------------------------------------------
# plan and apply
# ---------------------------------------------------------------------------

class Sync:
    """Difference between the blueprints of the chain and the registered skills of a project."""

    def __init__(self, ctx):
        self.ctx = ctx
        self.project = ctx.cwd
        self.skills_dir = self.project / ".claude" / "skills"
        self.manifest_file = registry_file(self.project)
        self.manifest = read_registry(self.project)
        self.old = old_file(self.project).is_file()      # .aios/manifest of v0.3, removed on apply
        self.chain, self.problems = blueprints(ctx)
        self.new, self.changed, self.removed, self.foreign = [], [], [], []
        for name, (src, version) in self.chain.items():
            dig = digest(src)
            target = self.skills_dir / name
            entry = self.manifest.get(name)
            if entry is None:
                if target.exists():
                    self.foreign.append(name)
                else:
                    self.new.append((name, src, version, dig))
            elif (entry.get("digest") != dig or entry.get("source") != str(src)
                  or not target.is_dir() or digest(target) != dig):
                self.changed.append((name, src, version, dig))
        for name in self.manifest:
            if name not in self.chain:
                self.removed.append(name)
        for name in self.foreign:
            self.problems.append(f"{self.skills_dir / name} exists and is not managed by AIOS, left untouched")

    def __bool__(self):
        return bool(self.new or self.changed or self.removed or self.old)

    def lines(self):
        out = [f"new      {n} {v}".rstrip() + f"  ({s})" for n, s, v, _ in self.new]
        out += [f"changed  {n} {v}".rstrip() + f"  ({s})" for n, s, v, _ in self.changed]
        out += [f"remove   {n}" for n in self.removed]
        if self.old:
            out.append("rename   .aios/manifest -> .aios/registry")
        return out

    def summary(self):
        parts = []
        if self.new:
            parts.append("new " + ", ".join(n for n, *_ in self.new))
        if self.changed:
            parts.append("changed " + ", ".join(n for n, *_ in self.changed))
        if self.removed:
            parts.append("removed " + ", ".join(self.removed))
        if self.old and not parts:
            parts.append(".aios/manifest renamed to .aios/registry")
        return "; ".join(parts)

    def apply(self):
        entries = {k: v for k, v in self.manifest.items() if k in self.chain}
        self.skills_dir.mkdir(parents=True, exist_ok=True)
        for name, src, version, dig in self.new + self.changed:
            target = self.skills_dir / name
            tmp = Path(tempfile.mkdtemp(prefix=f".{name}.", dir=self.skills_dir))
            try:
                shutil.copytree(src, tmp / name, copy_function=shutil.copyfile)
                make_writable(tmp / name)
                if target.exists():
                    make_writable(target)
                    shutil.rmtree(target)
                os.rename(tmp / name, target)
            finally:
                make_writable(tmp)
                shutil.rmtree(tmp, ignore_errors=True)
            entries[name] = {"source": str(src), "version": version, "digest": dig}
        for name in self.removed:
            target = self.skills_dir / name
            if target.is_dir():
                make_writable(target)
                shutil.rmtree(target)
            entries.pop(name, None)
        if entries or self.manifest_file.exists() or self.old:
            write_manifest(self.manifest_file, entries)
        if self.old:
            old_file(self.project).unlink()


def sync_for(cwd):
    """Sync of the project cwd, None when nothing may be registered there."""
    ctx = context.Context(cwd)
    if ctx.mode != "aios" or not ctx.initialized:
        return ctx, None
    return ctx, Sync(ctx)


def register(cwd, yes=False):
    """aios --context --sync [--yes], aios --register: preview, (question), apply."""
    from . import ui
    from .ui import say, warn
    ctx, s = sync_for(cwd)
    if s is None:
        reason = {"none": "not in a vault", "legacy": "legacy mode (no aios: in the chain)"}.get(ctx.mode)
        say(f"=> nothing registered: {reason or f'{ctx.cwd} is not a project (no @/)'}")
        return 0
    for p in s.problems:
        warn(p)
    if not s:
        say(f"=> project skills of {ctx.cwd} are up to date")
        return 0
    say(f"=> register the project skills of {ctx.cwd} in .claude/skills/")
    for line in s.lines():
        say(f"      {line}")
    if yes:
        ui.MODE = "yes"
    try:
        ui.proceed("register?", "registration cancelled")
    except ui.PlanOnly:
        return 0
    except ui.Cancelled:
        return 1
    s.apply()
    say(f"=> registered: {s.summary()}")
    say("   the skills are available from the next chat (or after /reload-skills)")
    return 0
