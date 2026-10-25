"""aios --run: commands of packages (spec 06); aios --worker is rebuilt for v0.5 (spec 07).

A command of a package runs with aios --run when the user calls it, without a question (P3).
The workers of v0.4 (workers: with install, remove, start, stop) are gone since v0.5; workhorses
are packages of type worker (spec 07). aios --worker comes back with step 6 of the plan v0.5.
"""

from __future__ import annotations

import os
import subprocess

from . import elements, paths
from .ui import Abort


def command(args):
    """aios --worker: rebuilt in step 6 of the plan v0.5 (V0.5, memo 44)."""
    raise Abort("aios --worker is rebuilt for AIOS 0.5 (spec 07, step 6 of the plan); "
                "workhorses are packages of type worker")


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
