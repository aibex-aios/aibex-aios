# t12-integrity.sh: step 4 of the plan (V0.3, memo 32) - aios --integrity (spec 05, Integrität)

#===============================================================================
# setup: vault §Demo as root project, subprojects with and without gaps, a container
#===============================================================================

   export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
   export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
   D="$SANDBOX/work/§Demo"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   GI=$'.DS_Store\n.claude/skills/\n.aios/manifest\n'
   mkproj() { mkdir -p "$1/@"; touch "$1/@/.gitkeep"; mk "$1/.gitignore" "$GI$2"; git -C "$1" init -q -b main
              git -C "$1" add -A && git -C "$1" commit -qm init; }
   A() { "$SRC/bin/aios" "$@" 2>&1; }

   mkproj "$D" $'/G-Garten/\n/S-Sternwarte/\n/Notizen/\n'
   mkproj "$D/G-Garten" $'/GB-Beet/\n'
   mkdir -p "$D/G-Garten/GB-Beet/@"                       # no own repo
   mkproj "$D/S-Sternwarte"
   mkproj "$D/Notizen/N-Frei"                             # project in a container (excluded in §Demo by /Notizen/)
   mkproj "$D/Notizen/n-klein"                            # name rule violated
   mkdir -p "$D/.versteckt/X-Hidden/@" "$D/G-Garten/@Memo/Y-Memo/@" "$D/node_modules/Z-Mod/@"   # never searched

#===============================================================================
# all integer
#===============================================================================

   OUT="$(A --integrity "$D/S-Sternwarte")"
   assert_contains "$OUT" "Integrity S-Sternwarte — $(date +%F)" "header with name and date"
   assert_contains "$OUT" "Result: 1 of 1 project integer" "single project integer"
   assert_exit 0 "$SRC/bin/aios" --integrity "$D/S-Sternwarte"
   assert_eq "$(cd "$D/S-Sternwarte" && "$SRC/bin/aios" --integrity 2>&1 | sed -n 1p | cut -d' ' -f2)" "S-Sternwarte" "default path: cwd"

#===============================================================================
# gaps, changes, nesting
#===============================================================================

   rm "$D/S-Sternwarte/.gitignore"
   echo x >> "$D/S-Sternwarte/@/.gitkeep"
   mk "$D/S-Sternwarte/neu1.md" "a"; mk "$D/S-Sternwarte/sub/neu2.md" "b"
   OUT="$(A --integrity "$D")"
   assert_exit 1 "$SRC/bin/aios" --integrity "$D"
   assert_contains "$OUT" "Integrity §Demo" "header: vault root"
   assert_eq "$(printf '%s\n' "$OUT" | sed -n 3p | tr -s ' ')" "Project Init Commit" "column header"
   assert_eq "$(printf '%s\n' "$OUT" | grep -c '^§Demo ')" "1" "root project at depth 0"
   assert_eq "$(printf '%s\n' "$OUT" | grep -c '^  G-Garten ')" "1" "G-Garten indented once"
   assert_eq "$(printf '%s\n' "$OUT" | grep -c '^    GB-Beet ')" "1" "GB-Beet indented twice (subproject of a subproject)"
   assert_eq "$(printf '%s\n' "$OUT" | grep -c '^  N-Frei ')" "1" "project in a container: indented once, container not listed"
   case "$OUT" in *Notizen*|*X-Hidden*|*Y-Memo*|*Z-Mod*) fail "containers, hidden, @ and node_modules not listed" ;; *) ok ;; esac
   assert_contains "$(printf '%s\n' "$OUT" | grep '^ *GB-Beet')" "missing: " "GB-Beet: short init column (A15)"
   assert_contains "$OUT" "- GB-Beet: missing own git repo" "GB-Beet: missing repo under Notes (A15)"
   assert_contains "$(printf '%s\n' "$OUT" | grep GB-Beet)" "—" "GB-Beet: no own repo, commit —"
   assert_contains "$(printf '%s\n' "$OUT" | grep '^ *S-Sternwarte')" "missing: 1 part" "S-Sternwarte: one missing part (A15)"
   assert_contains "$OUT" "- S-Sternwarte: missing .gitignore lines: .DS_Store, .claude/skills/, .aios/manifest" "S-Sternwarte: gitignore lines under Notes"
   assert_contains "$(printf '%s\n' "$OUT" | grep S-Sternwarte)" "2 changed, 2 new" "changed and new separately (deleted .gitignore counts as changed, new files one by one)"
   assert_eq "$(printf '%s\n' "$OUT" | grep '^  G-Garten ' | tr -s ' ')" " G-Garten ok ok" "G-Garten integer"
   assert_contains "$OUT" "Result: 4 of 6 projects integer" "result line"

#===============================================================================
# hints: name rule, push state (local, without fetch); they do not affect integrity
#===============================================================================

   assert_contains "$OUT" "Notes" "hints section"
   assert_contains "$OUT" "- n-klein: name violates the name rule (" "name rule as hint"
   assert_contains "$OUT" "proposal N-Klein" "name hint with proposal"
   assert_contains "$(printf '%s\n' "$OUT" | grep '^  n-klein ' | tr -s ' ')" "ok ok" "name violation keeps the project integer"

   git init -q --bare "$SANDBOX/remote.git"
   git -C "$D/G-Garten" remote add origin "$SANDBOX/remote.git"
   git -C "$D/G-Garten" push -q -u origin main 2>/dev/null
   mk "$D/G-Garten/a.md" "a"; git -C "$D/G-Garten" add a.md; git -C "$D/G-Garten" commit -qm a
   mk "$D/G-Garten/b.md" "b"; git -C "$D/G-Garten" add b.md; git -C "$D/G-Garten" commit -qm b
   OUT="$(A --integrity "$D/G-Garten")"
   assert_contains "$OUT" "- G-Garten: 2 commits not pushed" "ahead of upstream"
   assert_contains "$OUT" "Result: 1 of 2 projects integer" "unpushed commits are only a hint"
   git -C "$D/G-Garten" push -q 2>/dev/null; git -C "$D/G-Garten" reset -q --hard HEAD~1
   assert_contains "$(A --integrity "$D/G-Garten")" "- G-Garten: 1 commit behind origin" "behind upstream"
   case "$(A --integrity "$D/S-Sternwarte")" in *pushed*|*behind*) fail "no upstream: no push hint" ;; *) ok ;; esac

#===============================================================================
# read only, container start, errors
#===============================================================================

   BEFORE="$(cd "$D" && find . | sort; git -C "$D/S-Sternwarte" status --porcelain)"
   A --integrity "$D" >/dev/null
   assert_eq "$(cd "$D" && find . | sort; git -C "$D/S-Sternwarte" status --porcelain)" "$BEFORE" "nothing written"
   OUT="$(A --integrity "$D/Notizen")"
   assert_eq "$(printf '%s\n' "$OUT" | grep -c '^N-Frei ')" "1" "container as start: projects below at depth 0"
   assert_contains "$OUT" "Result: 2 of 2 projects integer" "container: only projects below"
   mkdir -p "$SANDBOX/leer"
   assert_contains "$(A --integrity "$SANDBOX/leer")" "No projects in" "no projects"
   assert_contains "$(A --integrity "$SANDBOX/nope")" "*** aios --integrity:" "missing path"
   assert_exit 1 "$SRC/bin/aios" --integrity "$SANDBOX/nope"
   assert_exit 1 "$SRC/bin/aios" --integrity "$D" "$D"
