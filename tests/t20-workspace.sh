# t20-workspace.sh: step 11 of the plan v0.4 (V0.4, memos 18, 57) - aios --workspace: init, update,
# freeze, status, groups, branch ws/<revision>, fast-forward only, foreign repos (spec 06, Workspaces;
# spec 05, F2)

#===============================================================================
# setup: python3 with PyYAML, repos under file://, an activated vault with its own repo
#===============================================================================

   PYDIR=""
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import yaml" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t20 needs a python3 with PyYAML (pip install pyyaml)"
   export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
   export PATH="$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
   RM="$SANDBOX/remotes"; mkdir -p "$RM"
   repo() {                                         # repo <name> <file>...: a bare repo with one commit
      local n="$1" w="$SANDBOX/src/$1"; shift
      mkdir -p "$w"; git -C "$w" init -q -b main
      for f in "$@"; do mkdir -p "$(dirname "$w/$f")"; echo "$n" > "$w/$f"; done
      git -C "$w" add -A; git -C "$w" commit -q -m "$n 1"
      git clone -q --bare "$w" "$RM/$n"; git -C "$w" remote add origin "$RM/$n"
   }
   repo lib-a @/README.md
   repo lib-b src/main.c
   git -C "$SANDBOX/src/lib-b" tag v1.0; git -C "$SANDBOX/src/lib-b" push -q origin v1.0
   repo docs @/README.md
   repo root @/README.md
   W="$SANDBOX/src/root"; mkdir -p "$W/.aios"
   cat > "$W/.aios/workspace.yaml" <<YAML
remotes:
  local: file://$RM
projects:
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
   git -C "$W" add -A; git -C "$W" commit -q -m "workspace"; git -C "$W" push -q origin main
   V="$SANDBOX/v/§V"; mkdir -p "$V/@" "$V/.aios"; printf 'aios: 0.4.0\n' > "$V/.aios/config.yaml"
   git -C "$V" init -q -b main; git -C "$V" add -A; git -C "$V" commit -q -m vault
   at() { (cd "$1" && shift && "$@" 2>&1); }
   A() { local d="$1"; shift; at "$d" "$SRC/bin/aios" "$@" </dev/null; }

#===============================================================================
# init: plan, root project like a project of the workspace, groups, exclusions with own commit
#===============================================================================

   assert_contains "$(A "$V" --workspace)" "usage: aios --workspace" "usage"
   U="$SANDBOX/u"; mkdir -p "$U"
   assert_contains "$(A "$U" --workspace init "file://$RM/root")" "is not in a vault" "init outside a vault"
   OUT="$(A "$V" --workspace init "file://$RM/root" --plan)"
   assert_contains "$OUT" "clone file://$RM/root -> $V/root" "plan of init"
   [ ! -e "$V/root" ] && ok || fail "--plan clones nothing"
   OUT="$(A "$V" --workspace init "file://$RM/root" ws --group none --yes)"
   assert_contains "$OUT" "import has no effect" "import reported"
   assert_contains "$OUT" "libs/lib-a: cloned (main)" "lib-a cloned"
   assert_contains "$OUT" "libs/lib-b: cloned (v1.0)" "lib-b cloned"
   assert_not_contains "$OUT" "docs: cloned" "group doc not selected"
   assert_eq "$(git -C "$V/ws/libs/lib-b" rev-parse --abbrev-ref HEAD)" "ws/v1.0" "tag as branch ws/<revision>"
   assert_eq "$(git -C "$V/ws/libs/lib-a" rev-parse --abbrev-ref HEAD)" "main" "branch main"
   assert_contains "$(cat "$V/.gitignore")" "/ws/" "root excluded in the vault repo"
   assert_eq "$(git -C "$V" log -1 --format=%s)" "AIOS: ws als Projekt des Workspace ausgeschlossen" "commit of the exclusion"
   assert_contains "$(cat "$V/ws/.gitignore")" "/libs/lib-a/" "lib-a excluded in the root"
   assert_eq "$(git -C "$V/ws" status --porcelain)" "" "root clean after the exclusions"
   assert_contains "$(A "$V" --workspace init "file://$RM/root" ws)" "exists already" "init into an existing folder"

#===============================================================================
# update: groups, fast-forward, own commits, dirty tree, other branch, wrong origin
#===============================================================================

   echo 2 >> "$SANDBOX/src/lib-a/@/README.md"; git -C "$SANDBOX/src/lib-a" commit -qam "lib-a 2"
   git -C "$SANDBOX/src/lib-a" push -q origin main
   OUT="$(A "$V/ws" --workspace update --yes)"
   assert_contains "$OUT" "docs: cloned (main)" "update clones the missing docs"
   assert_contains "$OUT" "libs/lib-a: moved (fast-forward to main)" "fast-forward"
   assert_eq "$(git -C "$V/ws/libs/lib-a" log -1 --format=%s)" "lib-a 2" "lib-a at the new commit"
   assert_contains "$OUT" "libs/lib-b: ok" "tag unchanged"
   OUT="$(A "$V/ws/libs/lib-a" --workspace update --plan)"
   assert_contains "$OUT" "update libs/lib-a (main, fast-forward only)" "<path> finds the workspace above"
   echo x > "$V/ws/libs/lib-a/x.txt"; git -C "$V/ws/libs/lib-a" add x.txt; git -C "$V/ws/libs/lib-a" commit -qm own
   echo 3 >> "$SANDBOX/src/lib-a/@/README.md"; git -C "$SANDBOX/src/lib-a" commit -qam "lib-a 3"
   git -C "$SANDBOX/src/lib-a" push -q origin main
   echo dirty >> "$V/ws/docs/@/README.md"
   OUT="$(A "$V/ws" --workspace update --yes)"
   assert_contains "$OUT" "libs/lib-a: kept (own commits, no fast-forward possible)" "own commits kept"
   assert_eq "$(git -C "$V/ws/libs/lib-a" log -1 --format=%s)" "own" "own commit stays"
   assert_contains "$OUT" "docs: kept (uncommitted changes)" "dirty tree kept"
   assert_contains "$(cat "$V/ws/docs/@/README.md")" "dirty" "change stays"
   git -C "$V/ws/docs" checkout -q -- .; git -C "$V/ws/docs" checkout -q -b other
   assert_contains "$(A "$V/ws" --workspace update --group doc --yes)" "docs: kept (branch other is checked out, not main)" "other branch kept"
   git -C "$V/ws/docs" checkout -q main
   git -C "$V/ws/docs" remote set-url origin "file://$RM/lib-b"
   assert_contains "$(A "$V/ws" --workspace update --group doc --yes)" "docs: kept (origin is file://$RM/lib-b" "wrong origin kept"
   git -C "$V/ws/docs" remote set-url origin "file://$RM/docs"

#===============================================================================
# status, integrity, freeze
#===============================================================================

   OUT="$(A "$V/ws" --workspace status)"
   assert_contains "$OUT" "Project" "status: header"
   assert_contains "$(echo "$OUT" | grep '^lib-a')" "1 ahead, 1 behind" "status: lib-a ahead and behind"
   assert_contains "$(echo "$OUT" | grep '^lib-b')" "ws/v1.0" "status: lib-b on ws/v1.0"
   OUT="$(A "$V/ws" --integrity)"
   assert_contains "$(echo "$OUT" | grep 'lib-b')" "foreign repo" "integrity: foreign repo"
   assert_contains "$OUT" "
  lib-b " "integrity: one level below the root, sorted as a tree"
   assert_contains "$OUT" "workspace: revision main is not in the checked out branch" "integrity: revision behind"
   rm -rf "$V/ws/docs"
   OUT="$(A "$V/ws" --integrity)"
   assert_contains "$(echo "$OUT" | grep 'docs')" "missing: clone" "integrity: missing clone"
   A "$V/ws" --workspace update --group doc --yes >/dev/null
   A "$V/ws" --fetch --yes >/dev/null 2>&1
   OUT="$(A "$V/ws" --workspace freeze --yes)"
   assert_contains "$OUT" "frozen: lib-a" "freeze"
   LOCK="$(cat "$V/ws/.aios/lock.yaml")"
   assert_contains "$LOCK" "lib-b: $(git -C "$V/ws/libs/lib-b" rev-parse HEAD)" "lock: commit of lib-b"
   assert_contains "$LOCK" "schema: 1" "lock: schema"
   assert_contains "$(A "$V/ws" --workspace freeze --yes)" "nothing to do" "freeze twice"
