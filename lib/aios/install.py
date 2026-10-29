"""aios --prepare, --install, --versions, --remove-version, --uninstall (spec 04).

Standard library only: this module runs from a clone with the system python,
before the venv of an installation exists.
"""

from __future__ import annotations

import getpass
import io
import json
import os
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

from . import paths
from .ui import Abort, Plan, confirm, say, warn  # noqa: F401 - Abort is part of the API


FORWARDER_MARKS = ("# forwarder: ~/bin/aios",          # up to 0.3.1, also ~/bin/aios-context of v0.4
                   "# forwarder: ~/.aios/bin/aios")    # from 0.4.0 (V0.6)


def is_forwarder(text):
    return any(m in text for m in FORWARDER_MARKS)
PROTOTYPE_MARK = 'ETC="$HOME/etc/aios"'
WRAPPER_MARK = "!`aios --skill "
ALIAS_MARK = "!`aios --gui "
ALIAS = ('---\nname: gui\ndescription: "Zeigt die Oberfläche des aktiven Assistenten (AIbex AIOS). '
         'Auslöser: /gui, „Oberfläche“, „Menü“."\nallowed-tools: Bash(aios --gui *), Bash(aios --context *)\n'
         '---\n\n!`aios --gui --session ${CLAUDE_SESSION_ID}`\n')
AIOS_HOOKS = {"SessionStart": "aios --context --session", "UserPromptSubmit": "aios --context --advise"}
OLD_AIOS_HOOKS = {"SessionStart": "aios-context --session", "UserPromptSubmit": "aios-context --advise"}  # v0.3, v0.4
LEGACY_HOOKS = {"SessionStart": "ai-brain --session", "UserPromptSubmit": "ai-brain --advise"}
RELEASE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
ENTRY = re.compile(r"^(v\d[^:\s]*):\s*(.*?)\s*$")
TOOLS = ("aios",)
OLD_TOOLS = ("aios-context",)                          # forwarders up to v0.4 (V0.5, memo 04)



# ---------------------------------------------------------------------------
# versions and installations.yaml
# ---------------------------------------------------------------------------

def semver_key(name):
    core, _, pre = name.lstrip("v").partition("-")
    nums = [int(x) if x.isdigit() else 0 for x in core.split(".")] + [0, 0, 0]
    return (nums[0], nums[1], nums[2], 0 if pre else 1, pre)


def user_entries():
    return paths.user_dir() / "installations.yaml"


def system_entries():
    return paths.prefix() / "installations.yaml"


def read_entries(file):
    """[(name, path)] of one installations.yaml; quotes, comments and ~/ are resolved."""
    result = []
    if not file.is_file():
        return result
    for line in file.read_text(encoding="utf-8").splitlines():
        m = ENTRY.match(line.rstrip("\r"))
        if not m:
            continue
        value = re.sub(r"\s+#.*$", "", m.group(2)).strip().strip("\"'")
        if value == "~" or value.startswith("~/"):
            value = str(paths.home()) + value[1:]
        result.append((m.group(1), Path(value)))
    return result


def installations():
    """{name: (path, file)}; the entry of the user wins (spec 04)."""
    found = {}
    for file in (user_entries(), system_entries()):
        for name, path in read_entries(file):
            found.setdefault(name, (path, file))
    return found


def set_entry(file, name, path):
    file.parent.mkdir(parents=True, exist_ok=True)
    lines = file.read_text(encoding="utf-8").splitlines() if file.is_file() else []
    value = f'"{path}"' if re.search(r"[\s#'\"]", str(path)) else str(path)
    new = f"{name}: {value}"
    out, done = [], False
    for line in lines:
        m = ENTRY.match(line)
        if m and m.group(1) == name:
            if not done:
                out.append(new)
                done = True
            continue
        out.append(line)
    if not done:
        out.append(new)
    file.write_text("\n".join(out) + "\n", encoding="utf-8")


def drop_entry(file, name):
    if not file.is_file():
        return
    lines = [line for line in file.read_text(encoding="utf-8").splitlines()
             if not (ENTRY.match(line) and ENTRY.match(line).group(1) == name)]
    file.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def normalize(version):
    return version if version.startswith("v") else "v" + version


# ---------------------------------------------------------------------------
# files
# ---------------------------------------------------------------------------

def make_readonly(root):
    """Remove write permission below root; symlinks are skipped (they point outside)."""
    for dirpath, dirnames, filenames in os.walk(root, topdown=False):
        for name in filenames + dirnames:
            p = os.path.join(dirpath, name)
            st = os.lstat(p)
            if not stat.S_ISLNK(st.st_mode):
                os.chmod(p, stat.S_IMODE(st.st_mode) & ~0o222)
    os.chmod(root, stat.S_IMODE(os.lstat(root).st_mode) & ~0o222)


def make_writable(root):
    if not os.path.lexists(root):
        return
    os.chmod(root, stat.S_IMODE(os.lstat(root).st_mode) | 0o200)
    for dirpath, dirnames, filenames in os.walk(root):
        for name in dirnames + filenames:
            p = os.path.join(dirpath, name)
            st = os.lstat(p)
            if not stat.S_ISLNK(st.st_mode):
                os.chmod(p, stat.S_IMODE(st.st_mode) | 0o200)


def remove_tree(root):
    make_writable(root)
    shutil.rmtree(root)


def frontmatter(file):
    """Minimal YAML frontmatter reader for SKILL.md: plain values and block scalars."""
    text = file.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    lines = text[3:end if end > 0 else len(text)].splitlines()
    result, key, block = {}, None, []
    for line in lines + ["end: "]:
        if key and (line.startswith((" ", "\t")) or not line.strip()):
            block.append(line.strip())
            continue
        if key:
            result[key] = " ".join(x for x in block if x)
            key, block = None, []
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if not m:
            continue
        name, value = m.group(1), m.group(2).strip()
        if value in (">", "|", ">-", "|-", ">+", "|+"):
            key = name
        else:
            result[name] = value.strip("\"'")
    result.pop("end", None)
    return result


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


# ---------------------------------------------------------------------------
# prepare
# ---------------------------------------------------------------------------

def existing_parent(path):
    p = path
    while not p.exists() and p != p.parent:
        p = p.parent
    return p


def plan_root(plan, system=False, prepare=False):
    """Where installations go: (root, installations.yaml), with the steps to set it up.
    Standard is ~/.aios/versions; /opt/aios only with --system (spec 04, Installationen; V0.6, F26).
    prepare: aios --prepare, legacy of v0.5, sets up /opt/aios with the fallback of v0.5."""
    if not system and not prepare:
        root = paths.user_versions()
        if not root.is_dir():
            plan.add(f"create {root}", lambda: root.mkdir(parents=True))
        return root, user_entries()
    prefix = paths.prefix()
    if prefix.is_dir() and os.access(prefix, os.W_OK):
        return prefix, system_entries()
    if not prefix.exists() and os.access(existing_parent(prefix), os.W_OK):
        plan.add(f"create {prefix}", lambda: prefix.mkdir(parents=True))
        return prefix, system_entries()
    sudo = shutil.which(paths.sudo_cmd())
    user = os.environ.get("USER") or getpass.getuser()
    if sudo:
        def setup():
            run([sudo, "mkdir", "-p", str(prefix)])
            run([sudo, "chown", user, str(prefix)])
        plan.add(f"create {prefix} for {user}: sudo mkdir -p {prefix} && sudo chown {user} {prefix}"
                 f" (sudo may ask for your password)", setup)
        return prefix, system_entries()
    if prepare:                                     # aios --prepare (legacy of v0.5): fall back
        fallback = paths.user_versions()
        if not fallback.is_dir():
            plan.add(f"no sudo: installations go to {fallback} instead of {prefix}",
                     lambda: fallback.mkdir(parents=True))
        return fallback, user_entries()
    raise Abort(f"--system needs sudo to set up {prefix}; without --system AIOS installs into "
                f"{paths.user_versions()}")


def plan_prepare(plan):
    home = paths.home()
    root = plan_root(plan, prepare=True)
    for d in ("bin", "etc", "tmp", "git"):
        if not (home / d).is_dir():
            plan.add(f"create ~/{d}", lambda d=d: (home / d).mkdir(parents=True))

    current = shutil.which("stup")
    have = subprocess.run([current, "--version"], capture_output=True, text=True).stdout.strip() \
        if current else ""
    url = paths.stup_url()
    try:
        data = urllib.request.urlopen(url, timeout=20).read()
    except Exception as e:                          # noqa: BLE001 - any fetch problem
        if not current:
            raise Abort(f"cannot fetch stup from {url}: {e}")
        warn(f"cannot check stup for updates ({url}): {e}")
        data = None
    target = None
    if data is not None:
        tmp = Path(tempfile.mkdtemp()) / "stup"
        tmp.write_bytes(data)
        new = subprocess.run(["bash", str(tmp), "--version"], capture_output=True, text=True).stdout.strip()
        if not current:
            target = home / "bin" / "stup"
            what = f"stup: install {new} -> ~/bin/stup"
        elif have != new:
            target = Path(current)
            what = f"stup: update {have} -> {new} ({current})"
        if target:
            def put(target=target, tmp=tmp):
                if os.access(target.parent, os.W_OK):
                    shutil.copyfile(tmp, target)
                    target.chmod(0o755)
                else:
                    run([paths.sudo_cmd(), "cp", str(tmp), str(target)])
                    run([paths.sudo_cmd(), "chmod", "755", str(target)])
            plan.add(what, put)

    if not (home / "bin" / "profile.sh").exists():
        def profile():
            stup = shutil.which("stup") or str(home / "bin" / "stup")
            (home / (".bash_profile" if sys.platform == "darwin" else ".bashrc")).touch()
            env = dict(os.environ, BIN=str(home / "bin"), PATH=f"{home / 'bin'}:{os.environ.get('PATH', '')}")
            run([stup, "--profile"], env=env)
        plan.add("create ~/bin/profile.sh with stup --profile", profile)
    return root


KIT_HINTS = {                                       # spec 04, aios --prepare: the way to it, as text
    "darwin": {"python3": "brew install python (or python.org)", "git": "xcode-select --install",
               "gh": "brew install gh or cli.github.com"},
    "linux": {"python3": "sudo apt install python3 python3-venv python3-pip (dnf: python3 python3-pip)",
              "git": "sudo apt install git (dnf: git)", "gh": "cli.github.com"},
}
KIT_NAMES = {"python3": "python3 >= 3.11 with venv and pip", "git": "git", "gh": "gh (developer kit)"}


def basic_kit(dev=False):
    """Missing parts of the basic kit (python3 >= 3.11 with venv and pip, git) and, with dev, of
    the developer kit (gh); spec 04, aios --prepare; V0.5, memos 31, 91 (B11: workhorses need 3.11). AIOS_PREPARE_PATH replaces
    PATH for this check (tests)."""
    path = os.environ.get("AIOS_PREPARE_PATH")
    missing = []
    py = shutil.which("python3", path=path)
    good = False
    if py:
        r = subprocess.run([py, "-c", "import sys, venv, ensurepip; print('%d %d' % sys.version_info[:2])"],
                           capture_output=True, text=True)
        good = r.returncode == 0 and tuple(int(x) for x in r.stdout.split()) >= (3, 11)
    if not good:
        missing.append("python3")
    if not shutil.which("git", path=path):
        missing.append("git")
    if dev and not shutil.which("gh", path=path):
        missing.append("gh")
    return missing


def kit_lines(missing):
    hints = KIT_HINTS.get("darwin" if sys.platform == "darwin" else "linux")
    return [f"missing: {KIT_NAMES[m]} — {hints[m]}" for m in missing]


def prepare(dev=False):
    plan = Plan()
    plan_prepare(plan)
    missing = basic_kit(dev)
    for line in kit_lines(missing):
        plan.add(line)                              # a note only: AIOS installs none of it
    if not plan:
        if missing:
            say("=> AIbex AIOS: prepare the machine")
            plan.show()
            say("=> machine not prepared: install what is missing, then run aios --prepare again")
            return 1
        say("=> machine prepared, nothing to do")
        return 0
    say("=> AIbex AIOS: prepare the machine")
    if not confirm(plan, "prepare?", "preparation cancelled"):
        return 1
    if missing:
        say("=> machine not prepared: install what is missing, then run aios --prepare again")
        return 1
    say("=> machine prepared (open a new shell to use ~/bin in PATH)")
    return 0


# ---------------------------------------------------------------------------
# install: repo, version, build
# ---------------------------------------------------------------------------

def clone_of_this():
    here = Path(__file__).resolve().parents[2]
    if (here / ".git").exists() and (here / "spec").is_dir() and (here / "bin" / "aios").is_file():
        return here
    return None


def find_repo():
    here = clone_of_this()
    if here:
        return here
    f = paths.user_dir() / "repo"
    if f.is_file():
        p = Path(f.read_text(encoding="utf-8").strip())
        if (p / ".git").exists() and (p / "bin" / "aios").is_file():
            return p
    raise Abort("cannot locate the clone of aibex-aios; run ./bin/aios --install in a clone")


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)


def choose_version(repo, version):
    if git(repo, "remote").stdout.strip():
        if git(repo, "fetch", "--tags", "-q").returncode:
            warn("git fetch --tags failed, using the local tags")
    if version:
        tag = normalize(version)
        if git(repo, "rev-parse", "-q", "--verify", f"refs/tags/{tag}").returncode:
            raise Abort(f"no tag {tag} in {repo}")
        return tag
    tags = [t for t in git(repo, "tag", "-l", "v*").stdout.split() if RELEASE.match(t)]
    if not tags:
        raise Abort(f"no release tag v<MAJOR.MINOR.PATCH> in {repo}; give a version")
    return max(tags, key=semver_key)


def extract(repo, tag):
    """Stage the tagged tree in a temporary directory (nothing is installed yet)."""
    stage = Path(tempfile.mkdtemp(prefix="aios-stage."))
    data = subprocess.run(["git", "-C", str(repo), "archive", "--format=tar", tag],
                          capture_output=True, check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(data)) as t:
        if hasattr(tarfile, "data_filter"):
            t.extractall(stage, filter="data")
        else:
            t.extractall(stage)
    return stage


def skills_of(src):
    """[(name, dir)] of the AIOS skills skills/aios/<name>/SKILL.md (spec 04). Other skills and the
    library of v0.3 are not part of the kernel any more; they are packages (spec 06)."""
    result = []
    base = src / "skills" / "aios"
    if not base.is_dir():
        return result
    for skill in sorted(p for p in base.iterdir() if (p / "SKILL.md").is_file()):
        if not skill.name.startswith("aios-"):
            raise Abort(f"AIOS skill {skill.name} must start with aios-")
        result.append((skill.name, skill))
    return result


def build(stage, tag, root, entries):
    """Copy the staged tree into <root>/<tag> (spec 04, Abbildung), venv, read-only, entry."""
    final = root / tag
    tmp = Path(tempfile.mkdtemp(prefix=f".{tag}.", dir=root))
    inst = tmp / tag
    try:
        inst.mkdir()
        for d in ("bin", "lib", "templates"):
            if (stage / d).is_dir():
                shutil.copytree(stage / d, inst / d, symlinks=True)
        (inst / "VERSION").write_text(tag[1:] + "\n", encoding="utf-8")
        if (stage / "manifest.yaml").is_file():           # package manifest of the kernel (spec 06)
            text = (stage / "manifest.yaml").read_text(encoding="utf-8")
            text = re.sub(r"(?m)^version:.*$", f"version: {tag[1:]}", text, count=1)
            (inst / "manifest.yaml").write_text(text, encoding="utf-8")
        for name, src in skills_of(stage):
            shutil.copytree(src, inst / "skills" / "aios" / name)
        if (stage / "spec").is_dir():
            shutil.copytree(stage / "spec", inst / "doc" / "spec")
        for d in ("tutorials", "wiki"):
            if (stage / "doc" / d).is_dir():
                shutil.copytree(stage / "doc" / d, inst / "doc" / d)
        pip = paths.pip_cmd()
        run([sys.executable, "-m", "venv", *(["--without-pip"] if pip else []), str(inst / "python")])
        req = inst / "python" / "requirements.txt"
        if (stage / "python" / "requirements.txt").is_file():
            shutil.copyfile(stage / "python" / "requirements.txt", req)
            if pip:
                run(f"{pip} {shlex.quote(str(req))}", shell=True)
            else:
                run([str(inst / "python" / "bin" / "python"), "-m", "pip", "install", "-q",
                     "--disable-pip-version-check", "-r", str(req)])      # no [notice] lines (O1)
        run([str(inst / "python" / "bin" / "python"), "-m", "compileall", "-q", str(inst / "lib")],
            stdout=subprocess.DEVNULL)
        os.rename(inst, final)
    finally:
        remove_tree(tmp)
    make_readonly(final)
    set_entry(entries, tag, final)


# ---------------------------------------------------------------------------
# install: user setup (forwarders, config, hooks, AIOS skills)
# ---------------------------------------------------------------------------

def forwarder_version(text):
    m = re.search(r'---version" \]; then\s*\n\s*echo "([^"]+)"', text)
    return m.group(1) if m else "0"


def plan_forwarders(plan, src):
    text = (src / "templates" / "forwarder").read_text(encoding="utf-8")
    new = forwarder_version(text)
    bindir = paths.bin_dir()
    for tool in TOOLS:
        target = bindir / tool
        what = None
        if not target.exists():
            what = f"forwarder ~/bin/{tool} {new}"
        else:
            old = target.read_text(encoding="utf-8", errors="replace")
            if PROTOTYPE_MARK in old:
                what = f"forwarder ~/bin/{tool} {new}, replaces the prototype"
            elif is_forwarder(old):
                if semver_key(new) > semver_key(forwarder_version(old)):
                    what = f"forwarder ~/bin/{tool}: update {forwarder_version(old)} -> {new}"
            else:
                warn(f"~/bin/{tool} is not an AIOS forwarder, left untouched")
        if what:
            def put(target=target):
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(text, encoding="utf-8")
                target.chmod(0o755)
            plan.add(what, put)
    for tool in OLD_TOOLS:
        target = bindir / tool
        if target.is_file() and is_forwarder(target.read_text(encoding="utf-8", errors="replace")):
            plan.add(f"remove the forwarder ~/bin/{tool} (replaced by aios --context)", target.unlink)
    etc = paths.home() / "etc" / "aios"
    if etc.is_dir():
        plan.add("remove ~/etc/aios of the prototype", lambda: shutil.rmtree(etc))


def is_command(hook, cmd):
    c = str(hook.get("command", "")).strip()
    return hook.get("type") == "command" and (c == cmd or c.endswith("/" + cmd))


def merge_hooks(settings):
    """Remove the ai-brain hooks and the aios-context hooks of v0.3/v0.4, add the AIOS hooks;
    other keys and hooks stay. Only the ai-brain hooks are reported as removed (they are saved)."""
    new = json.loads(json.dumps(settings))
    hooks = new.setdefault("hooks", {})
    removed = {}
    for event, old in OLD_AIOS_HOOKS.items():
        if event in hooks:
            groups = []
            for group in hooks[event]:
                rest = [h for h in group.get("hooks", []) if not is_command(h, old)]
                if rest or not group.get("hooks"):
                    groups.append(dict(group, hooks=rest))
            hooks[event] = groups
    for event, legacy in LEGACY_HOOKS.items():
        groups = []
        for group in hooks.get(event, []):
            gone = [h for h in group.get("hooks", []) if is_command(h, legacy)]
            rest = [h for h in group.get("hooks", []) if not is_command(h, legacy)]
            if gone:
                removed.setdefault(event, []).append(dict(group, hooks=gone))
            if rest or not gone:
                groups.append(dict(group, hooks=rest) if gone else group)
        if event in hooks:
            hooks[event] = groups
    added = []
    for event, cmd in AIOS_HOOKS.items():
        groups = hooks.setdefault(event, [])
        if not any(is_command(h, cmd) for g in groups for h in g.get("hooks", [])):
            groups.insert(0, {"hooks": [{"type": "command", "command": cmd}]})
            added.append(cmd)
    return new, removed, added


def unmerge_hooks(settings, backup):
    """Remove the AIOS hooks, put the saved ai-brain hooks back."""
    new = json.loads(json.dumps(settings))
    hooks = new.get("hooks", {})
    for event, cmd in AIOS_HOOKS.items():
        if event not in hooks:
            continue
        groups = []
        for group in hooks[event]:
            rest = [h for h in group.get("hooks", []) if not is_command(h, cmd)
                    and not is_command(h, OLD_AIOS_HOOKS[event])]
            if rest or not group.get("hooks"):
                groups.append(dict(group, hooks=rest))
        hooks[event] = groups
    for event, groups in backup.items():
        hooks.setdefault(event, [])
        for group in groups:
            if group not in hooks[event]:
                hooks[event].insert(0, group)
    for event in [e for e, g in hooks.items() if g == []]:
        del hooks[event]
    if "hooks" in new and not new["hooks"]:
        del new["hooks"]
    return new


def settings_file():
    return paths.claude_dir() / "settings.json"


def backup_file():
    return paths.user_dir() / "hooks-backup.json"


def load_json(file):
    if not file.is_file():
        return {}
    try:
        return json.loads(file.read_text(encoding="utf-8") or "{}")
    except ValueError as e:
        raise Abort(f"{file} is not valid JSON ({e}); nothing changed")


def write_json(file, data):
    file.parent.mkdir(parents=True, exist_ok=True)
    tmp = file.with_name(file.name + ".aios-tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(tmp, file)


def plan_hooks(plan):
    settings = load_json(settings_file())
    new, removed, added = merge_hooks(settings)
    if new == settings:
        return
    parts = [f"add {', '.join(added)}"] if added else []
    if removed:
        parts.append("remove the ai-brain hooks (saved in ~/.aios/hooks-backup.json)")

    def apply():
        if removed:
            backup = load_json(backup_file())
            saved = backup.setdefault("hooks", {})
            for event, groups in removed.items():
                saved.setdefault(event, []).extend(g for g in groups if g not in saved.get(event, []))
            write_json(backup_file(), backup)
        write_json(settings_file(), new)
    plan.add(f"hooks in {settings_file()}: " + "; ".join(parts), apply)


SESSION_LINE = "Session-ID dieses Chats: `${CLAUDE_SESSION_ID}`"


def wrapper(name, description, tools="", session=False):
    """Version-neutral wrapper: the body comes from the valid version at load time (spec 04).
    A skill that needs the session id gets it as a line of text after the call (Claude Code
    replaces the placeholder in the text); the call itself stays `aios --skill <name>`, which
    every version understands."""
    allowed = ", ".join(t for t in ["Bash(aios --skill *)", tools] if t)
    return (f"---\nname: {name}\ndescription: {json.dumps(description, ensure_ascii=False)}\n"
            f"allowed-tools: {allowed}\n---\n\n!`aios --skill {name}`\n"
            + (f"\n{SESSION_LINE}\n" if session else ""))


def plan_skills(plan, src):
    for name, skill in skills_of(src):
        meta = frontmatter(skill / "SKILL.md")
        session = "<session-id>" in (skill / "SKILL.md").read_text(encoding="utf-8").split("\n---", 1)[-1]
        text = wrapper(name, meta.get("description", ""), meta.get("allowed-tools", ""), session)
        target = paths.claude_dir() / "skills" / name / "SKILL.md"
        if target.is_file():
            old = target.read_text(encoding="utf-8", errors="replace")
            if old == text:
                continue
            if WRAPPER_MARK not in old:
                warn(f"{target} is not an AIOS skill wrapper, left untouched")
                continue

        def put(target=target, text=text):
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8")
        plan.add(f"AIOS skill /{name} -> {target.parent}", put)
    plan_alias(plan)


def plan_alias(plan):
    """The alias /gui in ~/.claude/skills/gui/ (spec 04); a folder AIOS did not write stays."""
    target = paths.claude_dir() / "skills" / "gui" / "SKILL.md"
    if target.parent.exists():
        old = target.read_text(encoding="utf-8", errors="replace") if target.is_file() else ""
        if old == ALIAS:
            return
        if ALIAS_MARK not in old:
            warn(f"{target.parent} was not written by AIOS, left untouched; /gui is not available")
            return

    def put():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(ALIAS, encoding="utf-8")
    plan.add(f"alias /gui -> {target.parent}", put)


def plan_user(plan, src, repo):
    plan_forwarders(plan, src)
    config = paths.user_dir() / "config.yaml"
    if not config.exists():
        def create():
            config.parent.mkdir(parents=True, exist_ok=True)
            config.write_text("hosts: [claude-code]\n", encoding="utf-8")
        plan.add("create ~/.aios/config.yaml (hosts: [claude-code])", create)
    plan_hooks(plan)
    plan_skills(plan, src)
    record = paths.user_dir() / "repo"
    if repo and (not record.is_file() or record.read_text(encoding="utf-8").strip() != str(repo)):
        def remember():
            record.parent.mkdir(parents=True, exist_ok=True)
            record.write_text(f"{repo}\n", encoding="utf-8")
        plan.add(f"remember the clone {repo} in ~/.aios/repo", remember)


def older_vaults(tag):
    """Vaults known from the markers of the sessions that are bound to a version below 0.5: they
    have no aios --context and need aios --activate (spec 04, Umstieg auf v0.5; V0.5, memo 41, N7)."""
    if semver_key(tag) < semver_key("v0.5.0"):
        return []
    from . import config
    seen, lines = set(), []
    for f in sorted((paths.user_dir() / "sessions").glob("*.yaml")):
        m = re.search(r'^cwd:\s*"?(.*?)"?\s*$', f.read_text(encoding="utf-8", errors="replace"), re.M)
        if not m or not os.path.isdir(m.group(1)):
            continue
        try:
            cfg = config.load(m.group(1))
        except Exception:                           # noqa: BLE001 - a hint only
            continue
        if cfg.vault and cfg.aios and semver_key("v" + str(cfg.aios)) < semver_key("v0.5.0") \
                and str(cfg.vault) not in seen:
            seen.add(str(cfg.vault))
            lines.append(f"note: vault {cfg.vault} is bound to aios {cfg.aios}; after this install "
                         f"run: aios --activate {tag} {cfg.vault}")
    return lines


def install(version, system=False):
    repo = find_repo()
    tag = choose_version(repo, version)
    missing = basic_kit()
    if missing:                                     # checked by aios --install itself (V0.6, memo 07)
        raise Abort("the basic kit is missing (" + "; ".join(kit_lines(missing))
                    + "); install it, then run aios --install again")
    plan = Plan()
    root, entries = plan_root(plan, system=system)
    known = installations()
    stage = None
    try:
        if tag in known and known[tag][0].is_dir():
            src = known[tag][0]
            plan.add(f"{tag} is already installed in {src}")
        else:
            stage = src = extract(repo, tag)
            plan.add(f"install {tag} from {repo} -> {root / tag} (read-only)",
                     lambda: build(stage, tag, root, entries))
        plan_user(plan, src, repo if clone_of_this() else None)
        for line in older_vaults(tag):
            plan.add(line)
        if not plan:
            say(f"=> AIbex AIOS {tag}: nothing to do")
            return 0
        say(f"=> AIbex AIOS {tag}")
        if not confirm(plan, "install?", "installation cancelled"):
            return 1
    finally:
        if stage:
            shutil.rmtree(stage, ignore_errors=True)
    say(f"=> AIbex AIOS {tag} installed")
    say(f"   activate a vault with: aios --activate {tag} <vault>; hooks and skills apply from the next chat")
    return 0


# ---------------------------------------------------------------------------
# versions, remove-version, uninstall
# ---------------------------------------------------------------------------

def versions():
    listed = []
    for file, origin in ((user_entries(), "user"), (system_entries(), "system")):
        for name, path in read_entries(file):
            listed.append((name, path, origin))
    if not listed:
        say("no installation of AIOS")
        return 0
    effective = installations()
    for name, path, origin in sorted(listed, key=lambda e: semver_key(e[0])):
        notes = [origin]
        if effective[name][0] != path:
            notes.append("shadowed by the user entry")
        if not path.is_dir():
            notes.append("missing")
        say(f"{name:14} {path}  ({', '.join(notes)})")
    return 0


def managed(path):
    """Is path an installation directory created by aios (not e.g. a clone)?"""
    try:
        parent = path.parent.resolve()
    except OSError:
        return False
    roots = []
    for r in (paths.prefix(), paths.user_versions()):
        try:
            roots.append(r.resolve())
        except OSError:
            pass
    return parent in roots and RELEASE.match(path.name.split("-")[0]) is not None


def remove_version(version):
    tag = normalize(version)
    hits = [(file, path) for file in (user_entries(), system_entries())
            for name, path in read_entries(file) if name == tag]
    if not hits:
        raise Abort(f"{tag} is not installed (aios --versions)")
    plan = Plan()
    for file, path in hits:
        if managed(path) and path.is_dir():
            if not os.access(path.parent, os.W_OK):
                raise Abort(f"{path.parent} is not writable")
            plan.add(f"remove {path}", lambda path=path: remove_tree(path))
        elif path.is_dir():
            plan.add(f"{path} is not an installation directory, it is kept")
        plan.add(f"remove the entry {tag} from {file}", lambda file=file: drop_entry(file, tag))
    say(f"=> remove AIbex AIOS {tag}; vaults bound to {tag[1:]} stop working until it is installed again")
    if not confirm(plan, "remove?", "removal cancelled"):
        return 1
    if not installations():
        say("   this was the last installation; remove the user setup with: aios --uninstall")
    say(f"=> {tag} removed")
    return 0


def uninstall():
    plan = Plan()
    for tool in TOOLS + OLD_TOOLS:
        target = paths.bin_dir() / tool
        if target.is_file() and is_forwarder(target.read_text(encoding="utf-8", errors="replace")):
            plan.add(f"remove the forwarder ~/bin/{tool}", target.unlink)
    skills = paths.claude_dir() / "skills"
    if skills.is_dir():
        for d in sorted(skills.glob("aios-*")):
            f = d / "SKILL.md"
            if f.is_file() and WRAPPER_MARK in f.read_text(encoding="utf-8", errors="replace"):
                plan.add(f"remove the AIOS skill {d}", lambda d=d: shutil.rmtree(d))
        alias = skills / "gui" / "SKILL.md"
        if alias.is_file() and ALIAS_MARK in alias.read_text(encoding="utf-8", errors="replace"):
            plan.add(f"remove the alias {alias.parent}", lambda: shutil.rmtree(alias.parent))
    sessions = paths.user_dir() / "sessions"
    if sessions.is_dir():
        plan.add(f"remove the markers of the sessions {sessions}", lambda: shutil.rmtree(sessions))
    settings = load_json(settings_file())
    backup = load_json(backup_file()).get("hooks", {})
    new = unmerge_hooks(settings, backup)
    if new != settings:
        plan.add(f"hooks in {settings_file()}: remove the AIOS hooks"
                 + ("; restore the ai-brain hooks from ~/.aios/hooks-backup.json" if backup else ""),
                 lambda: write_json(settings_file(), new))
    if backup_file().is_file():
        plan.add("remove ~/.aios/hooks-backup.json", backup_file().unlink)
    plan.add("installations, ~/.aios/config.yaml and all .aios/ in vaults are kept")
    if not plan:
        say("=> nothing to uninstall")
        return 0
    say("=> uninstall the user setup of AIbex AIOS")
    if not confirm(plan, "uninstall?", "uninstall cancelled"):
        return 1
    say("=> user setup removed; ai-brain runs as before from the next chat")
    return 0
