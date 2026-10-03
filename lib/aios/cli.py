"""aios - command line of AIbex AIOS (spec 04, CLI aios). Dispatches to the modules."""

import subprocess
import sys

from . import activate, aiosinit, deploy, install, integrity, paths, registry, skills, ui

USAGE = ("usage: aios --prepare | --install [v<version>] | --versions | --remove-version v<version>"
         " | --uninstall | --activate v<version> [<path>] | --deactivate [<path>] | --config [<path>]"
         " | --register [<path>] | --init [<path>] [--assistant <value>] [--name <name>] [--accept-name]"
         " | --integrity [<path>]"
         " | --skill <name> | --library"
         " | --deploy [<name>==<version>] [--to <project>] [--assistant <name>] [--from <repo>]"
         "  (writing commands: --plan, --yes)")

LATER = {}                                          # commands of later steps (memo 18)


def init_command(args):
    """aios --init [<path>] [--assistant <value>] [--name <name>] [--accept-name] (spec 05)."""
    opts, rest, i = {}, [], 0
    while i < len(args):
        a = args[i]
        if a in ("--assistant", "--name") and i + 1 < len(args):
            opts[a[2:]] = args[i + 1]
            i += 2
            continue
        if a == "--accept-name":
            opts["accept_name"] = True
        else:
            rest.append(a)
        i += 1
    if len(rest) > 1 or any(r.startswith("--") for r in rest):
        raise ui.Abort("usage: aios --init [<path>] [--assistant <value>] [--name <name>] [--accept-name]")
    return aiosinit.init(rest[0] if rest else None, **opts)


def main(argv):
    if not argv:
        print(USAGE, file=sys.stderr)
        return 1
    for flag, mode in (("--plan", "plan"), ("--yes", "yes")):      # for skills (spec 03)
        if flag in argv[1:]:
            argv = [a for a in argv if a != flag]
            ui.MODE = mode
    cmd, args = argv[0], argv[1:]
    try:
        if cmd == "--prepare" and not args:
            return install.prepare()
        if cmd == "--install" and len(args) <= 1:
            return install.install(args[0] if args else None)
        if cmd == "--versions" and not args:
            return install.versions()
        if cmd == "--remove-version" and len(args) == 1:
            return install.remove_version(args[0])
        if cmd == "--uninstall" and not args:
            return install.uninstall()
        if cmd == "--activate" and len(args) in (1, 2):
            return activate.activate(*args)
        if cmd == "--deactivate" and len(args) <= 1:
            return activate.deactivate(*args)
        if cmd == "--config" and len(args) <= 1:
            return activate.show(*args)
        if cmd == "--deploy":
            return deploy.command(args)
        if cmd == "--library" and not args:
            return deploy.show_library()
        if cmd == "--skill" and len(args) == 1:
            return skills.body(args[0])
        if cmd == "--init":
            return init_command(args)
        if cmd == "--integrity" and len(args) <= 1:
            return integrity.run(*args)
        if cmd == "--register" and len(args) <= 1:
            return registry.register(args[0] if args else paths.cwd())
        if cmd in LATER:
            print(f"aios {cmd}: not implemented yet (step {LATER[cmd]})", file=sys.stderr)
            return 2
    except ui.PlanOnly:
        return 0
    except aiosinit.NameViolation:
        return 2
    except ui.Cancelled:
        return 1
    except ui.Abort as e:
        print(f"*** aios {cmd}: {e}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as e:
        print(f"*** aios {cmd}: command failed ({e.returncode}): {e.cmd}", file=sys.stderr)
        return 1
    print(USAGE, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
