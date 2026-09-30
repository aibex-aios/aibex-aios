"""aios - command line of AIbex AIOS (spec 04, CLI aios). Dispatches to the modules."""

import subprocess
import sys

from . import install

USAGE = "usage: aios --prepare | --install [v<version>] | --versions | --remove-version v<version> | --uninstall"

LATER = {                                           # commands of later steps (memo 18)
    "--activate": 4, "--deactivate": 4, "--register": 7, "--skill": 8, "--deploy": 9,
}


def main(argv):
    if not argv:
        print(USAGE, file=sys.stderr)
        return 1
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
        if cmd in LATER:
            print(f"aios {cmd}: not implemented yet (step {LATER[cmd]})", file=sys.stderr)
            return 2
    except install.Abort as e:
        print(f"*** aios {cmd}: {e}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as e:
        print(f"*** aios {cmd}: command failed ({e.returncode}): {e.cmd}", file=sys.stderr)
        return 1
    print(USAGE, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
