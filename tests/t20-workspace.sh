# t20-workspace.sh: v0.6.4 step 2 (V0.6, memos 163-177) - aios --workspace: attach <repo>, sync without
# push (clone, fast-forward, runnable), parents before children, key sync:, cloud folders,
# workspace.local.yaml, status, integrity, freeze (spec 06, Workspaces; spec 05, F2)

   case "$SANDBOX" in */aios-test.*) ;; *) echo "*** run via tests/run, never directly (it would touch the real HOME)" >&2; exit 1;; esac

#===============================================================================
# setup: python3 with PyYAML, repos under file://, a vault root as root of the workspace
#===============================================================================

   PYDIR=""
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import yaml" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t20 needs a python3 with PyYAML (pip install pyyaml)"
   export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
   export PATH="$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
   VER="$(cat "$SRC/VERSION")"
   RM="$SANDBOX/remotes"; mkdir -p "$RM"
   repo() {                                         # repo <name> <file>...: a bare repo with one commit
      local n="$1" w="$SANDBOX/src/$1"; shift
      mkdir -p "$w"; git -C "$w" init -q -b main
      for f in "$@"; do mkdir -p "$(dirname "$w/$f")"; echo "$n" > "$w/$f"; done
      cp "$SRC/templates/gitignore" "$w/.gitignore"  # registration writes there (spec 04, Vorlage)
      git -C "$w" add -A; git -C "$w" commit -q -m "$n 1"
      git clone -q --bare "$w" "$RM/$n"; git -C "$w" remote add origin "$RM/$n"
   }
   repo lib-a @/README.md
   printf '/sub/\n' >> "$SANDBOX/src/lib-a/.gitignore"; git -C "$SANDBOX/src/lib-a" add -A
   git -C "$SANDBOX/src/lib-a" commit -qm "exclude sub"; git -C "$SANDBOX/src/lib-a" push -q origin main
   repo sub @/README.md
   repo lib-b src/main.c
   printf 'build/\n' > "$SANDBOX/src/lib-b/.gitignore"  # a foreign repo: no AIOS template (B32)
   git -C "$SANDBOX/src/lib-b" commit -qam "foreign"; git -C "$SANDBOX/src/lib-b" push -q origin main
   git -C "$SANDBOX/src/lib-b" tag v1.0; git -C "$SANDBOX/src/lib-b" push -q origin v1.0
   repo docs @/README.md
   repo root @/README.md
   W="$SANDBOX/src/root"; mkdir -p "$W/.aios"
   printf 'aios: %s\n' "$VER" > "$W/.aios/config.yaml"
   cat > "$W/.aios/workspace.yaml" <<YAML
remotes:
  local: file://$RM
projects:
  - name: sub
    remote: local
    revision: main
    path: libs/lib-a/sub
  - name: lib-a
    remote: local
    revision: main
    path: libs/lib-a
    import: true
  - name: lib-b
    remote: local
    revision: v1.0
    path: libs/lib-b
  - name: docs
    repo: file://$RM/docs
    revision: main
    path: docs
    groups: [doc]
YAML
   printf '/libs/\n/docs/\n.claude/skills/\n.aios/registry\n.aios/workspace.local.yaml\n' > "$W/.gitignore"
   git -C "$W" add -A; git -C "$W" commit -q -m "workspace"; git -C "$W" push -q origin main
   at() { (cd "$1" && shift && "$@" 2>&1); }
   A() { local d="$1"; shift; at "$d" "$SRC/bin/aios" "$@" </dev/null; }
   U="$SANDBOX/u"; mkdir -p "$U"
   V="$U/§W"

#===============================================================================
# usage, commands that are gone, attach: plan, clone, parents before children, runnable
#===============================================================================

   assert_contains "$(A "$U" --workspace)" "usage: aios --workspace attach" "usage"
   assert_contains "$(A "$U" --workspace init "file://$RM/root")" "gone since v0.6.4: use attach" "init is gone"
   assert_contains "$(A "$U" --workspace update)" "gone since v0.6.4: use sync" "update is gone"
   assert_contains "$(A "$U" --workspace attach "file://$RM/root" "$U/W")" "starts with §" "vault folder needs §"
   OUT="$(A "$U" --workspace attach "file://$RM/root" "$V" --plan)"
   assert_contains "$OUT" "clone file://$RM/root -> $V (vault root)" "plan of attach"
   [ ! -e "$V" ] && ok || fail "--plan clones nothing"
   C="$HOME/Library/CloudStorage/GoogleDrive-x"; mkdir -p "$C"
   assert_contains "$(A "$C" --workspace attach "file://$RM/root" "$C/§W" --yes)" "cloud folder (CloudStorage)" "attach into a cloud folder refused"
   OUT="$(A "$U" --workspace attach "file://$RM/root" "$V" --yes)"
   assert_contains "$OUT" "import has no effect" "import reported"
   assert_contains "$OUT" "libs/lib-a: cloned (main)" "lib-a cloned"
   assert_contains "$OUT" "libs/lib-a/sub: cloned (main)" "sub cloned although listed before its parent (L35)"
   assert_contains "$OUT" "libs/lib-b: cloned (v1.0)" "lib-b cloned"
   assert_contains "$OUT" "docs: cloned (main)" "docs cloned"
   assert_contains "$OUT" "workspace $V attached" "attach done"
   assert_eq "$(git -C "$V/libs/lib-a/sub" rev-parse --abbrev-ref HEAD)" "main" "sub is a clone of its own"
   assert_eq "$(git -C "$V/libs/lib-a" status --porcelain)" "" "lib-a clean: sub excluded there"
   assert_eq "$(git -C "$V/libs/lib-b" rev-parse --abbrev-ref HEAD)" "ws/v1.0" "tag as branch ws/<revision>"
   assert_eq "$(git -C "$V" status --porcelain)" "" "vault root clean after attach"
   assert_file "$V/libs/lib-a/.claude/skills/aios-status/SKILL.md"
   assert_contains "$(A "$U" --workspace attach "file://$RM/root" "$V")" "exists already" "attach into an existing folder"

#===============================================================================
# sync: fast-forward, vault root, <path>, own commits (merge), local changes (saved), other branch,
# wrong origin (drive model, V0.6, memos 204, 205)
#===============================================================================

   echo 2 >> "$SANDBOX/src/lib-a/@/README.md"; git -C "$SANDBOX/src/lib-a" commit -qam "lib-a 2"
   git -C "$SANDBOX/src/lib-a" push -q origin main
   echo 2 >> "$W/@/README.md"; git -C "$W" commit -qam "root 2"; git -C "$W" push -q origin main
   rm -rf "$V/docs"
   OUT="$(A "$V" --workspace sync --yes)"
   assert_contains "$OUT" "docs: cloned (main)" "sync clones the missing docs"
   assert_contains "$OUT" "libs/lib-a: moved (fast-forward to main)" "fast-forward"
   assert_eq "$(git -C "$V/libs/lib-a" log -1 --format=%s)" "lib-a 2" "lib-a at the new commit"
   assert_contains "$OUT" ".: moved (fast-forward to main)" "the vault root is updated too"
   assert_eq "$(git -C "$V" log -1 --format=%s)" "root 2" "vault root at the new commit"
   assert_not_contains "$OUT" "libs/lib-b:" "H36: tag unchanged, not named"
   assert_contains "$OUT" "projects unchanged" "H36: unchanged counted in one line"
   OUT="$(A "$V/libs/lib-a" --workspace sync --plan)"
   assert_contains "$OUT" "fetch and merge 2 projects: libs/lib-a, libs/lib-a/sub" "<path> finds the workspace above; H36: one line"
   assert_not_contains "$OUT" "push " "H36: no push line without commits"
   echo x > "$V/libs/lib-a/x.txt"; git -C "$V/libs/lib-a" add x.txt; git -C "$V/libs/lib-a" commit -qm own
   echo 3 >> "$SANDBOX/src/lib-a/@/README.md"; git -C "$SANDBOX/src/lib-a" commit -qam "lib-a 3"
   git -C "$SANDBOX/src/lib-a" push -q origin main
   echo dirty >> "$V/docs/@/README.md"
   OUT="$(A "$V" --workspace sync --yes)"
   assert_contains "$OUT" "libs/lib-a: moved (merged with origin/main)" "F226: own commits merged"
   assert_contains "$(git -C "$V/libs/lib-a" log -1 --format=%s)" "AIOS: zusammengeführt auf" "F226: merge commit"
   assert_contains "$(git -C "$V/libs/lib-a" log --format=%s)" "own" "own commit stays"
   assert_contains "$OUT" "libs/lib-a: pushed" "merged repo pushed"
   assert_contains "$OUT" "docs: saved (0 new, 1 changed, 0 deleted)" "F225: local change saved"
   assert_contains "$(git -C "$V/docs" log -1 --format=%s)" "AIOS: gesichert von" "F225: commit of the save"
   assert_contains "$(git -C "$V/docs" log -1 --format=%s)" "gesichert von $(id -un)@" "H38: <user>@<machine>"
   assert_contains "$(git -C "$RM/docs" log -1 --format=%s main)" "AIOS: gesichert von" "F225: save pushed"
   assert_contains "$(cat "$V/docs/@/README.md")" "dirty" "change stays"
   git -C "$V/docs" checkout -q -b other
   assert_contains "$(A "$V" --workspace sync --group doc --yes)" "docs: kept (branch other is checked out, not main)" "other branch kept"
   git -C "$V/docs" checkout -q main
   git -C "$V/docs" remote set-url origin "file://$RM/lib-b"
   assert_contains "$(A "$V" --workspace sync --group doc --yes)" "docs: kept (origin is file://$RM/lib-b" "wrong origin kept"
   git -C "$V/docs" remote set-url origin "file://$RM/docs"

#===============================================================================
# key sync:, workspace.local.yaml, status
#===============================================================================

   printf 'aios: %s\nsync: off\n' "$VER" > "$V/.aios/config.yaml"
   assert_contains "$(A "$V" --workspace sync --yes)" "sync is off" "sync: off refused"
   assert_contains "$(A "$V" --workspace status)" "sync: off" "status names sync: off"
   printf 'aios: %s\nsync: sometimes\n' "$VER" > "$V/.aios/config.yaml"
   assert_contains "$(A "$V" --config)" "sync: sometimes is not one of auto, manual, off" "invalid sync: warned"
   printf 'aios: %s\n' "$VER" > "$V/.aios/config.yaml"
   assert_contains "$(A "$V" --workspace status)" "sync: auto" "default with workspace.yaml: auto"
   printf 'schema: 1\ndetached:\n  - path: docs\n    since: 2026-11-05\n' > "$V/.aios/workspace.local.yaml"
   OUT="$(A "$V" --workspace sync --plan)"
   assert_contains "$OUT" "docs: detached on this machine, passed over" "sync passes over a detached subtree"
   assert_not_contains "$(echo "$OUT" | grep 'fetch and merge')" "docs" "no update of the detached docs"
   assert_contains "$(A "$V" --workspace status | grep '^docs')" "detached" "status: detached"
   rm "$V/.aios/workspace.local.yaml"
   echo x2 > "$V/libs/lib-a/x2.txt"; git -C "$V/libs/lib-a" add x2.txt; git -C "$V/libs/lib-a" commit -qm own2
   git -C "$SANDBOX/src/lib-a" pull -q --no-rebase origin main; echo 4 >> "$SANDBOX/src/lib-a/@/README.md"
   git -C "$SANDBOX/src/lib-a" commit -qam "lib-a 4"; git -C "$SANDBOX/src/lib-a" push -q origin main
   git -C "$V/libs/lib-a" fetch -q origin                # diverged again, for status and integrity
   OUT="$(A "$V" --workspace status)"
   assert_contains "$OUT" "Project" "status: header"
   assert_contains "$(echo "$OUT" | grep '^lib-a')" "1 ahead, 1 behind" "status: lib-a ahead and behind"
   assert_contains "$(echo "$OUT" | grep '^lib-b')" "ws/v1.0" "status: lib-b on ws/v1.0"
   D="$HOME/Library/CloudStorage/GoogleDrive-x/§D"; mkdir -p "$D/.aios"
   printf 'aios: %s\nsync: auto\n' "$VER" > "$D/.aios/config.yaml"; cp "$V/.aios/workspace.yaml" "$D/.aios/"
   assert_contains "$(A "$D" --workspace sync --yes)" "cloud folder (CloudStorage)" "sync in a cloud folder refused"

#===============================================================================
# integrity, freeze
#===============================================================================

   OUT="$(A "$V" --integrity)"
   assert_contains "$(echo "$OUT" | grep 'lib-b')" "foreign repo" "integrity: foreign repo"
   assert_contains "$OUT" "workspace: revision main is not in the checked out branch" "integrity: revision behind"
   rm -rf "$V/docs"
   OUT="$(A "$V" --integrity)"
   assert_contains "$(echo "$OUT" | grep 'docs')" "missing: clone" "integrity: missing clone"
   OUT="$(A "$V" --workspace sync --group doc --yes)"
   assert_contains "$OUT" "libs/lib-a: moved (merged with origin/main)" "diverged repo merged (no group: in every group)"
   OUT="$(A "$V" --workspace freeze --yes)"
   assert_contains "$OUT" "frozen: docs" "freeze, parents before children"
   LOCK="$(cat "$V/.aios/lock.yaml")"
   assert_contains "$LOCK" "lib-b: $(git -C "$V/libs/lib-b" rev-parse HEAD)" "lock: commit of lib-b"
   assert_contains "$LOCK" "schema: 1" "lock: schema"
   assert_contains "$(A "$V" --workspace freeze --yes)" "nothing to do" "freeze twice"

#===============================================================================
# sync, steps 4 and 5: manifest, hints, push, never tags, secrets stop the push (F159, F172, F176-F182)
#===============================================================================

   git -C "$V" add .aios/lock.yaml; git -C "$V" commit -qm freeze
   printf '/new/\n/plain/\n/pkg/\n' >> "$V/.gitignore"; git -C "$V" commit -qam "exclude new, plain, pkg"
   repo new @/README.md
   git clone -q "file://$RM/new" "$V/new"
   mkdir -p "$V/plain/@"; git -C "$V/plain" init -q -b main
   mkdir -p "$V/pkg"; echo "name: skill-x" > "$V/pkg/manifest.yaml"; git -C "$V/pkg" init -q -b main
   OUT="$(A "$V" --workspace sync --plan)"
   assert_contains "$OUT" "workspace.yaml: add new; commit only workspace.yaml" "plan: new repo with origin added"
   assert_contains "$OUT" "note: plain: no remote; suggested name W-plain" "plan: name after the schema"
   assert_contains "$OUT" "note: pkg: no remote" "plan: package repo without remote"
   assert_not_contains "$OUT" "suggested name W-pkg" "no schema name for a package repo"
   assert_contains "$OUT" "note: libs/lib-a: remote lib-a differs from the schema (W-lib-a)" "plan: differs from the schema"
   OUT="$(A "$V" --workspace sync --yes)"
   assert_contains "$OUT" "new: added to workspace.yaml" "new added"
   assert_contains "$(cat "$V/.aios/workspace.yaml")" "name: new" "workspace.yaml has new"
   assert_contains "$(cat "$V/.aios/workspace.yaml")" "path: new" "workspace.yaml: path of new"
   assert_eq "$(git -C "$V" log -1 --format=%s)" "AIOS: workspace.yaml nachgeführt" "commit of only workspace.yaml"
   assert_contains "$OUT" ".: pushed" "vault root pushed"
   assert_eq "$(git -C "$RM/root" log -1 --format=%s main)" "AIOS: workspace.yaml nachgeführt" "remote of the root has the commit"
   assert_contains "$(git -C "$RM/lib-a" log --format=%s main)" "own2" "remote of lib-a has the own commit"
   echo y > "$V/docs/@/y.md"; git -C "$V/docs" add -A; git -C "$V/docs" commit -qm "docs 2"; git -C "$V/docs" tag t1
   OUT="$(A "$V" --workspace sync --yes)"
   assert_contains "$OUT" "docs: pushed (1 commit to origin/main)" "docs pushed"
   assert_eq "$(git -C "$RM/docs" log -1 --format=%s main)" "docs 2" "remote of docs has the commit"
   assert_eq "$(git -C "$RM/docs" tag)" "" "no tag pushed"
   echo s > "$V/docs/.env"; mkdir -p "$V/docs/@Secret"; echo k > "$V/docs/@Secret/k.txt"
   git -C "$V/docs" add -f .env @Secret/k.txt; git -C "$V/docs" commit -qm "oops"
   OUT="$(A "$V" --workspace sync --yes)"
   assert_contains "$OUT" "docs: push stopped (secret-like files: " "push stopped by secrets"
   assert_contains "$OUT" ".env in" "secret: .env named"
   assert_contains "$OUT" "@Secret/k.txt in" "secret: @Secret named"
   assert_eq "$(git -C "$RM/docs" log -1 --format=%s main)" "docs 2" "remote of docs unchanged"
   assert_contains "$(A "$V" --workspace sync --plan)" "push docs: 1 commit(s)" "plan names the outgoing commits"

#===============================================================================
# detach <path>, attach <path>, detach of the workspace (F162-F169, F173, F174, F193, F194)
#===============================================================================

   OUT="$(A "$V" --workspace detach "$V/docs" --yes)"
   assert_contains "$OUT" "nothing detached, something would be lost" "detach with an unpushed commit refused"
   assert_contains "$OUT" "aios --workspace sync saves open changes" "F238: detach points to sync"
   assert_contains "$OUT" "docs: 1 commit(s) not pushed" "obstacle: not pushed"
   assert_dir "$V/docs/.git"
   echo s > "$V/libs/lib-a/sub/secret.txt"; echo secret.txt >> "$V/libs/lib-a/sub/.git/info/exclude"
   OUT="$(A "$V" --workspace detach "$V/libs/lib-a/sub" --yes)"
   assert_contains "$OUT" "ignored file that cannot be restored: secret.txt" "obstacle: ignored file"
   rm "$V/libs/lib-a/sub/secret.txt"
   assert_contains "$(A "$V" --workspace detach "$V/plain" --yes)" "not a project of" "detach takes only a project of the workspace"
   OUT="$(A "$V" --workspace detach "$V/new" --plan)"
   assert_contains "$OUT" "move new with 1 repo(s) to the trash" "plan of detach"
   assert_dir "$V/new/.git"
   OUT="$(A "$V" --workspace detach "$V/new" --yes)"
   assert_contains "$OUT" "new detached" "detach new"
   assert_file "$V/new/DETACHED.md"
   assert_exec "$V/new/DETACHED.command"
   [ ! -e "$V/new/.git" ] && ok || fail "the clone of new is gone from the vault"
   assert_contains "$(ls "$HOME/.Trash")" "new 20" "new in the trash with date and time"
   assert_contains "$(cat "$V/.aios/workspace.local.yaml")" "path: new" "entry in workspace.local.yaml"
   assert_contains "$(cat "$V/new/DETACHED.md")" "file://$RM/new" "DETACHED.md names the remote"
   assert_contains "$(cat "$V/new/DETACHED.command")" '--workspace attach "$(pwd)"' "DETACHED.command calls attach"
   assert_contains "$(A "$V" --workspace status | grep '^new')" "detached" "status: new detached"
   assert_eq "$(git -C "$V" status --porcelain)" "" "vault root clean: placeholder excluded, local file ignored"
   assert_contains "$(A "$V" --workspace detach "$V/new" --yes)" "detached already" "detach twice"
   assert_contains "$(A "$V" --workspace attach "$V/docs")" "is not detached" "attach of a project that is not detached"
   touch "$V/new/extra.txt"
   assert_contains "$(A "$V" --workspace attach "$V/new" --yes)" "holds more than the placeholder" "attach with more than the placeholder"
   rm "$V/new/extra.txt"
   OUT="$(A "$U" --workspace attach "$V/new" --yes)"
   assert_contains "$OUT" "new: cloned (main)" "attach <path> clones again"
   assert_dir "$V/new/.git"
   [ ! -e "$V/new/DETACHED.md" ] && ok || fail "placeholder removed"
   [ ! -e "$V/.aios/workspace.local.yaml" ] && ok || fail "local file removed with the last entry"
   assert_contains "$(A "$V" --workspace detach --yes)" "nothing detached, something would be lost" "detach of the workspace refused while docs is not pushed"
   V2="$U/§W2"
   A "$U" --workspace attach "file://$RM/root" "$V2" --yes >/dev/null
   assert_dir "$V2/libs/lib-b/.git"
   OUT="$(A "$V2" --workspace detach --yes)"
   assert_contains "$OUT" "workspace §W2 detached" "detach of the workspace, ws/<tag> counts as on the remote"
   [ ! -e "$V2" ] && ok || fail "the vault is gone"
   assert_contains "$(ls "$HOME/.Trash")" "§W2 20" "the vault in the trash"

#===============================================================================
# hook and master context: <aios-workspace>, AIOS-SYNC, AIOS-DETACHED; integrity: detached (F168, F169,
# F183-F189, F198)
#===============================================================================

   S() { (cd "$1" && printf '{"source":"%s","session_id":"t20"}' "${2:-startup}" | "$SRC/bin/aios" --context --session 2>&1); }
   assert_contains "$(A "$V" --context)" "<aios-workspace>
This vault is an AIBOS workspace with sync: auto." "block with sync: auto"
   assert_contains "$(A "$D" --context)" "This vault lies in a cloud folder (CloudStorage)" "block in a cloud folder"
   echo 2 >> "$SANDBOX/src/sub/@/README.md"; git -C "$SANDBOX/src/sub" commit -qam "sub 2"; git -C "$SANDBOX/src/sub" push -q origin main
   OUT="$(S "$V/libs/lib-a/sub")"
   assert_contains "$OUT" "AIOS-SYNC: sub updated from origin/main (1 commits)." "hook: update at startup"
   assert_eq "$(git -C "$V/libs/lib-a/sub" log -1 --format=%s)" "sub 2" "sub at the new commit"
   assert_contains "$(S "$V/libs/lib-a/sub")" "AIOS-SYNC: sub is up to date with origin/main." "hook: up to date"
   assert_not_contains "$(S "$V/libs/lib-a/sub" resume)" "AIOS-SYNC" "hook: not at resume"
   echo here > "$V/libs/lib-a/@/README.md"; git -C "$V/libs/lib-a" commit -qam "here"
   git -C "$SANDBOX/src/lib-a" pull -q --no-rebase origin main; echo there > "$SANDBOX/src/lib-a/@/README.md"
   git -C "$SANDBOX/src/lib-a" commit -qam "there"; git -C "$SANDBOX/src/lib-a" push -q origin main
   assert_contains "$(S "$V/libs/lib-a")" "AIOS-SYNC: lib-a not updated: the same files changed here and on the remote" "F230: hook makes no conflict copy"
   assert_eq "$(git -C "$V/libs/lib-a" log -1 --format=%s)" "here" "F230: hook leaves the repo as it was"
   echo wip >> "$V/libs/lib-a/x2.txt"
   assert_contains "$(S "$V/libs/lib-a")" "not updated: local changes that are not saved yet" "F230: hook does not save"
   git -C "$V/libs/lib-a" checkout -q -- x2.txt
   printf 'aios: %s\nsync: manual\n' "$VER" > "$V/.aios/config.yaml"
   assert_not_contains "$(S "$V/libs/lib-a/sub")" "AIOS-SYNC" "hook: no fetch with sync: manual"
   assert_contains "$(A "$V" --context)" "with sync: manual." "block with sync: manual"
   printf 'aios: %s\nsync: off\n' "$VER" > "$V/.aios/config.yaml"
   assert_not_contains "$(A "$V" --context)" "<aios-workspace>" "no block with sync: off"
   printf 'aios: %s\n' "$VER" > "$V/.aios/config.yaml"
   A "$V" --workspace detach "$V/new" --yes >/dev/null
   OUT="$(S "$V/new")"
   assert_contains "$OUT" "AIOS-DETACHED: new is detached on this machine (since " "hook: AIOS-DETACHED"
   assert_not_contains "$OUT" "PROJECT-UNINITIALIZED" "hook: a placeholder is no project to initialize"
   assert_contains "$(A "$V" --integrity | grep ' new ')" "detached" "integrity: detached"
   assert_not_contains "$(A "$V" --integrity)" "new: " "integrity: no notes for a detached subtree"

#===============================================================================
# B29: sync at a vault root without workspace.yaml creates it in the same plan (spec 06, sync,
# Neuer Workspace)
#===============================================================================

   N="$U/§N"; mkdir -p "$N/.aios" "$N/@"; printf 'aios: %s\n' "$VER" > "$N/.aios/config.yaml"
   cp "$SRC/templates/gitignore" "$N/.gitignore"; printf '/P-Eins/\n/P-Zwei/\n' >> "$N/.gitignore"
   git -C "$N" init -q -b main; git -C "$N" add -A; git -C "$N" commit -qm vault
   git clone -q --bare "$N" "$RM/nroot"; git -C "$N" remote add origin "file://$RM/nroot"; git -C "$N" fetch -q origin; git -C "$N" branch -q -u origin/main
   repo p-eins @/README.md; git clone -q "file://$RM/p-eins" "$N/P-Eins"
   mkdir -p "$N/P-Zwei/@"; git -C "$N/P-Zwei" init -q -b main
   assert_contains "$(A "$N/P-Eins" --workspace sync --yes)" "no .aios/workspace.yaml at or above" "only at the vault root"
   OUT="$(A "$N" --workspace sync --plan)"
   assert_contains "$OUT" "create .aios/workspace.yaml (new workspace) with 1 projects: P-Eins" "plan: new workspace"
   assert_contains "$OUT" "note: P-Zwei: no remote; suggested name N-P-Zwei" "plan: hint for the project without remote"
   [ ! -e "$N/.aios/workspace.yaml" ] && ok || fail "--plan writes nothing"
   OUT="$(A "$N" --workspace sync --yes)"
   assert_contains "$OUT" ".: workspace.yaml created (1 projects)" "workspace.yaml created"
   assert_contains "$(cat "$N/.aios/workspace.yaml")" "path: P-Eins" "entry of P-Eins"
   assert_eq "$(git -C "$N" log -1 --format=%s)" "AIOS: workspace.yaml angelegt" "commit of only workspace.yaml"
   assert_contains "$OUT" ".: pushed" "vault root pushed"
   assert_contains "$(A "$N" --workspace status)" "sync: auto" "now a workspace with sync: auto"
   repo p-drei @/README.md; git clone -q "file://$RM/p-drei" "$N/P-Drei"; printf '/P-Drei/\n' >> "$N/.gitignore"
   git -C "$N" commit -qam "exclude P-Drei"
   OUT="$(A "$N" --workspace sync --yes)"
   assert_contains "$OUT" "P-Drei: added to workspace.yaml" "B35: entry added to a workspace.yaml written by AIOS"
   assert_contains "$(A "$N" --workspace status)" "P-Drei" "B35: the manifest stays readable"
   M="$U/§M"; mkdir -p "$M/.aios"; printf 'aios: %s\nsync: off\n' "$VER" > "$M/.aios/config.yaml"; git -C "$M" init -q -b main
   assert_contains "$(A "$M" --workspace sync --yes)" "no workspace is created" "sync: off: no new workspace"

#===============================================================================
# B30: a clone that fails is reported, the others go on; B31: uncommitted changes stop the
# update, not the push (V0.6, memos 194, 196)
#===============================================================================

   echo 3 >> "$V/libs/lib-a/sub/@/README.md"; git -C "$V/libs/lib-a/sub" commit -qam "sub 3"
   echo wip > "$V/libs/lib-a/sub/wip.txt"
   OUT="$(A "$V" --workspace sync --yes)"
   assert_contains "$OUT" "libs/lib-a/sub: saved (1 new, 0 changed, 0 deleted)" "F225: new file saved"
   assert_contains "$OUT" "libs/lib-a/sub: pushed (2 commits to origin/main)" "F225: commit and save pushed"
   assert_contains "$(git -C "$RM/sub" log --format=%s main)" "sub 3" "remote has the commit"
   assert_file "$V/libs/lib-a/sub/wip.txt"
   cp "$V/.aios/workspace.yaml" "$SANDBOX/ws.bak"
   printf '  - name: gone\n    repo: file://%s/nope\n    revision: main\n    path: gone\n  - name: gone-child\n    repo: file://%s/sub\n    revision: main\n    path: gone/child\n' "$RM" "$RM" >> "$V/.aios/workspace.yaml"
   printf '/gone/\n' >> "$V/.gitignore"
   OUT="$(A "$V" --workspace sync --yes)"
   assert_contains "$OUT" "gone: not cloned (cannot clone file://$RM/nope" "B30: failed clone reported"
   assert_contains "$OUT" "gone/child: not cloned (gone is not cloned)" "B30: child of a failed clone passed over"
   assert_contains "$OUT" "workspace §W synchronized" "B30: sync goes on"
   [ ! -e "$V/gone" ] && ok || fail "B30: no folder left for the failed parent"
   cp "$SANDBOX/ws.bak" "$V/.aios/workspace.yaml"; git -C "$V" checkout -q -- .gitignore

#===============================================================================
# B32: an @/ without a tracked file is missing in a clone; sync creates it and makes the project
# runnable; integrity names it. H31: one line per project for the registration. H30: attach
# hands over to the bound version (V0.6, memos 198, 199)
#===============================================================================

   repo bare README.md                               # an AIOS project whose @/ held no tracked file
   printf '  - name: bare\n    repo: file://%s/bare\n    revision: main\n    path: bare\n' "$RM" >> "$V/.aios/workspace.yaml"
   printf '/bare/\n' >> "$V/.gitignore"
   OUT="$(A "$V" --workspace sync --yes)"
   assert_contains "$OUT" "bare: cloned (main)" "B32: bare cloned"
   assert_contains "$OUT" "bare: @/ was missing in the clone (no tracked file in it), created" "B32: @/ created"
   assert_file "$V/bare/.claude/skills/aios-status/SKILL.md"
   assert_contains "$OUT" "bare: registered (" "H31: one line for the registration"
   assert_not_contains "$OUT" "      new      aios-status" "H31: no line per skill in sync"
   assert_contains "$(A "$V/bare" --integrity)" "@/ holds no tracked file" "B32: integrity names the untracked @/"
   cp "$SANDBOX/ws.bak" "$V/.aios/workspace.yaml"; git -C "$V" checkout -q -- .gitignore
   F="$SANDBOX/fake"; mkdir -p "$F/bin"
   printf '#!/bin/sh\necho "fake 0.6.4-rc9: $* in $(pwd)"\n' > "$F/bin/aios"; chmod +x "$F/bin/aios"
   printf 'v0.6.4-rc9: %s\n' "$F" >> "$HOME/.aios/installations.yaml"
   repo root9 @/README.md
   W9="$SANDBOX/src/root9"; mkdir -p "$W9/.aios"; printf 'aios: 0.6.4-rc9\n' > "$W9/.aios/config.yaml"
   printf 'projects: []\n' > "$W9/.aios/workspace.yaml"
   git -C "$W9" add -A; git -C "$W9" commit -qm "bound to rc9"; git -C "$W9" push -q origin main
   OUT="$(A "$U" --workspace attach "file://$RM/root9" "$U/§W9" --yes)"
   assert_contains "$OUT" "hand over to the bound version 0.6.4-rc9" "H30: attach hands over"
   assert_contains "$OUT" "fake 0.6.4-rc9: --workspace sync --yes in $U/§W9" "H30: sync runs in the bound version"
   printf 'aios: 0.6.2\n' > "$W9/.aios/config.yaml"; git -C "$W9" commit -qam "bound to 0.6.2"; git -C "$W9" push -q origin main
   printf 'v0.6.2: %s\n' "$F" >> "$HOME/.aios/installations.yaml"
   OUT="$(A "$U" --workspace attach "file://$RM/root9" "$U/§W8" --yes)"
   assert_contains "$OUT" "has no workspace sync; the sync runs with $VER" "H30: no hand over below 0.6.4"

#===============================================================================
# B33: without a path sync and detach take the project of the working directory, at the vault
# root the whole workspace (V0.6, memo 203)
#===============================================================================

   OUT="$(A "$V/libs/lib-a/@" --workspace sync --plan)"
   assert_contains "$OUT" "sync the workspace $V at libs/lib-a" "B33: sync without a path: the project of the working directory"
   assert_not_contains "$(echo "$OUT" | grep 'fetch and merge')" "docs" "B33: other projects stay out"
   OUT="$(A "$V" --workspace sync --plan)"
   assert_contains "$(echo "$OUT" | grep 'fetch and merge')" "docs" "B33: at the vault root the whole workspace"
   OUT="$(A "$V/libs/lib-a/sub" --workspace detach --plan)"
   assert_contains "$OUT" "move libs/lib-a/sub with" "B33: detach without a path: the project of the working directory"
   assert_not_contains "$OUT" "move $V to the trash" "B33: not the whole workspace from a project"
   assert_contains "$(A "$V/libs/lib-a/sub" --skill aios-sync)" "sync project" "B33: skill knows the words"
   assert_contains "$(A "$V" --context --load "$V" 2>/dev/null; cat "$HOME"/.aios/cache/*/part-1.md 2>/dev/null)" "offer /aios-sync for the project" "B33: rule of the workspace names the project"

#===============================================================================
# L38, drive model: conflict copy, deleted against changed, secrets, large deletion, history,
# restore (spec 06, sync and Zurückholen; V0.6, memos 204, 205: F225-F237)
#===============================================================================

   P="$V/libs/lib-a/sub"; SS="$SANDBOX/src/sub"
   A "$V" --workspace sync --yes >/dev/null
   git -C "$SS" pull -q --no-rebase origin main
   printf 'remote\n' > "$SS/@/README.md"; printf 'keep\n' > "$SS/gone.md"
   git -C "$SS" add -A; git -C "$SS" commit -qm "remote side"; git -C "$SS" push -q origin main
   A "$P" --workspace sync --yes >/dev/null
   git -C "$SS" rm -q gone.md; printf 'remote 2\n' > "$SS/@/README.md"
   git -C "$SS" commit -qam "remote deletes gone, changes README"; git -C "$SS" push -q origin main
   printf 'local\n' > "$P/@/README.md"; printf 'changed here\n' > "$P/gone.md"; printf 'n\n' > "$P/note.md"
   OUT="$(A "$P" --workspace sync --yes)"
   assert_contains "$OUT" "libs/lib-a/sub: saved (1 new, 2 changed, 0 deleted)" "F225: saved before the merge"
   assert_contains "$OUT" "conflict copies: @/README (Konflikt " "F227: conflict copy named"
   assert_eq "$(cat "$P/@/README.md")" "remote 2" "F227: the remote version wins"
   CP="$(ls "$P/@" | grep 'Konflikt')"
   assert_eq "$(cat "$P/@/$CP")" "local" "F227: the local version stays as a copy"
   assert_eq "$(cat "$P/gone.md")" "changed here" "F233: changed wins over deleted"
   assert_contains "$(git -C "$RM/sub" ls-tree -r --name-only main)" "Konflikt" "F227: copy is saved and pushed"
   printf 'SECRET=1\n' > "$P/.env"; printf 'x\n' > "$P/plain.md"
   OUT="$(A "$P" --workspace sync --plan)"
   assert_contains "$OUT" "save libs/lib-a/sub: 1 new, 0 changed, 0 deleted; not saved (secret): .env" "F232, H41: plan names the secret, does not count it"
   assert_contains "$OUT" "push libs/lib-a/sub after saving" "H39: the plan names the push after saving"
   OUT="$(A "$P" --workspace sync --yes)"
   assert_contains "$OUT" "not saved (secret) (.env)" "F232: secret not saved"
   assert_not_contains "$(git -C "$P" ls-files)" ".env" "F232: .env not in the repo"
   assert_contains "$(git -C "$RM/sub" ls-tree -r --name-only main)" "plain.md" "F232: the rest is saved"
   rm "$P/.env"
   for i in 1 2 3 4 5 6 7 8 9 10 11; do echo "$i" > "$P/f$i.md"; done
   A "$P" --workspace sync --yes >/dev/null
   rm "$P"/f*.md
   OUT="$(A "$P" --workspace sync --plan)"
   assert_contains "$OUT" "LARGE DELETION (11 files)" "F228: plan names the large deletion"
   OUT="$(A "$P" --workspace sync --yes)"
   assert_contains "$OUT" "restored (11 deleted files (large deletion, F228))" "F228: restored without a question"
   assert_file "$P/f5.md"
   rm "$P"/f*.md
   OUT="$(A "$P" --workspace sync --yes --accept-deletion libs/lib-a/sub)"
   assert_contains "$OUT" "saved (0 new, 0 changed, 11 deleted)" "F228: deletion taken over when accepted"
   rm "$P/@/README.md" "$P/@/$CP"
   OUT="$(A "$P" --workspace sync --yes)"
   assert_contains "$OUT" "restored (2 deleted files" "F236: all of @/ gone counts as large"
   rm "$P/plain.md"; A "$P" --workspace sync --yes >/dev/null
   OUT="$(A "$P" --workspace history "$P" --deleted)"
   assert_contains "$OUT" "plain.md  deleted" "F229: history --deleted lists the deleted note"
   assert_contains "$(A "$P" --workspace history "$P/gone.md")" "AIOS: gesichert von" "F229: versions of a file"
   OUT="$(A "$P" --workspace restore "$P/plain.md" --plan)"
   assert_contains "$OUT" "restore plain.md from the version" "F229: plan of restore"
   [ ! -e "$P/plain.md" ] && ok || fail "--plan restores nothing"
   OUT="$(A "$P" --workspace restore "$P/plain.md" --yes)"
   assert_eq "$(cat "$P/plain.md")" "x" "F229: deleted note restored"
   printf 'unsaved\n' > "$P/gone.md"
   OUT="$(A "$P" --workspace restore "$P/gone.md" --yes)"
   assert_contains "$OUT" "unsaved files copied to the trash" "F237: unsaved version to the trash first"
   assert_eq "$(cat "$P/gone.md")" "changed here" "F237: last saved version back"
   assert_contains "$(A "$P" --workspace restore "$P" --yes)" "restore it with --at" "F237: a folder only with --at"

#===============================================================================
# B34: paths with umlauts and spaces (git quotes them): a subproject with an umlaut is no lost
# ignored file for detach; a file with an umlaut and a space is saved and restored (V0.6, memo 211)
#===============================================================================

   repo fuenf @/README.md
   git -C "$SANDBOX/src/root" pull -q origin main 2>/dev/null
   printf '  - name: fuenf\n    repo: file://%s/fuenf\n    revision: main\n    path: libs/lib-a/Fünf-Acht\n' "$RM" >> "$V/.aios/workspace.yaml"
   git -C "$V" commit -qam "fuenf"
   printf '/Fünf-Acht/\n' >> "$V/libs/lib-a/.gitignore"; git -C "$V/libs/lib-a" commit -qam "exclude Fünf-Acht"
   A "$V" --workspace sync --yes >/dev/null
   [ -d "$V/libs/lib-a/Fünf-Acht/.git" ] && ok || fail "B34: subproject with an umlaut cloned"
   assert_not_contains "$(A "$V" --workspace detach "$V/libs/lib-a" --plan)" "ignored file that cannot be restored" "B34: subproject with an umlaut is no lost file"
   F="$V/libs/lib-a/Fünf-Acht/Größe und Maß.md"; printf 'eins\n' > "$F"
   OUT="$(A "$V/libs/lib-a/Fünf-Acht" --workspace sync --yes)"
   assert_contains "$OUT" "saved (1 new, 0 changed, 0 deleted)" "B34: file with umlaut and space saved"
   assert_not_contains "$OUT" "unchanged" "H40: a saved project is not counted as unchanged"
   rm "$F"; A "$V/libs/lib-a/Fünf-Acht" --workspace sync --yes >/dev/null
   assert_contains "$(A "$V" --workspace history "$V/libs/lib-a/Fünf-Acht" --deleted)" "Größe und Maß.md  deleted" "B34: history names it unescaped"
   A "$V" --workspace restore "$F" --yes >/dev/null
   assert_eq "$(cat "$F")" "eins" "B34: restored"
