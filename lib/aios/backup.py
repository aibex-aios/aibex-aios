"""Backup of a plan with "all or nothing" (spec 06, Holen; spec 01, I11; V0.5, memos 28, 29).

Before the first write a plan saves exactly what it changes under <project>/.aios/backup/:
small files and folders are copied, package folders in @/@!Package/ that the plan replaces or
removes are moved (fast also for large packages). index.txt lists every saved path, also paths
that did not exist before, so that a restore after a crash (another process) brings back the
state before the plan. After success the backup is removed.
"""

from __future__ import annotations

import datetime
import os
import shutil
from pathlib import Path

from .install import make_writable


def folder(project):
    return Path(project) / ".aios" / "backup"


def exists(project):
    return (folder(project) / "index.txt").is_file()


def created(project):
    f = folder(project) / "created"
    return f.read_text(encoding="utf-8").strip() if f.is_file() else "?"


def _remove(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        make_writable(path)
        shutil.rmtree(path)


class Backup:
    def __init__(self, project):
        self.dir = folder(project)
        self.started = False

    def start(self, copy=(), move=()):
        """Save the paths in copy (files or folders, copied) and move (folders, moved)."""
        if self.dir.exists():
            raise RuntimeError(f"{self.dir} exists; run aios --fetch to restore it first")
        (self.dir / "data").mkdir(parents=True)
        (self.dir / "created").write_text(datetime.datetime.now().isoformat(timespec="seconds") + "\n",
                                          encoding="utf-8")
        lines = []

        def write():                                # the index is written before every move and
            (self.dir / "index.txt").write_text("".join(x + "\n" for x in lines), encoding="utf-8")
        write()                                     # after every copy, so a crash loses nothing
        self.started = True
        for i, path in enumerate(list(copy) + list(move)):
            path = Path(path)
            kept = self.dir / "data" / str(i)
            if not path.exists():
                lines.append(f"absent\t{path}\t-")
                write()
            elif i < len(copy):
                if path.is_dir():
                    shutil.copytree(path, kept, symlinks=True)
                else:
                    shutil.copy2(path, kept)
                lines.append(f"copied\t{path}\t{kept}")
                write()
            else:
                lines.append(f"moved\t{path}\t{kept}")
                write()
                os.rename(path, kept)

    def finish(self):
        _remove(self.dir)
        self.started = False


def restore(project):
    """Bring back the state before the plan from the backup of project, then remove it."""
    d = folder(project)
    index = d / "index.txt"
    for line in reversed(index.read_text(encoding="utf-8").splitlines() if index.is_file() else []):
        kind, path, kept = line.split("\t")
        path, kept = Path(path), Path(kept)
        if kind == "moved" and not kept.exists():
            continue                                # crash before the move: path is still the original
        if path.exists() or path.is_symlink():
            _remove(path)
        if kind == "copied":
            path.parent.mkdir(parents=True, exist_ok=True)
            if kept.is_dir():
                shutil.copytree(kept, path, symlinks=True)
            else:
                shutil.copy2(kept, path)
        elif kind == "moved":
            path.parent.mkdir(parents=True, exist_ok=True)
            os.rename(kept, path)
    _remove(d)
