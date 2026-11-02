# t16-fetch.sh: step 4 of the plan v0.4 (V0.4, memos 18, 37) - aios --fetch: fetch, reconcile,

   case "$SANDBOX" in */aios-test.*) ;; *) echo "*** run via tests/run, never directly (it would touch the real HOME)" >&2; exit 1;; esac
# --upgrade, --remove, --hub, --from, offline from the cache (spec 06, Holen)

#===============================================================================
# setup: a python3 with PyYAML, test hubs, vault §Demo with aios 0.4.0
#===============================================================================

   PYDIR=""
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import yaml" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t16 needs a python3 with PyYAML (pip install pyyaml)"
   export PATH="$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
   export AIOS_HUBS="$("$SRC/tests/hub/build" "$SANDBOX/hubs")"
   ONLY_AIOS="aibex-aios=file://$SANDBOX/hubs/aibex-aios"
   D="$SANDBOX/work/§Demo"; S="$D/S-Sternwarte"
   mkdir -p "$D/@" "$D/.aios" "$S/@" "$SANDBOX/outside/@"
   printf 'aios: 0.4.0\n' > "$D/.aios/config.yaml"
   at() { (cd "$1" && shift && "$@" 2>&1); }
   F() { local d="$1"; shift; at "$d" "$SRC/bin/aios" --fetch "$@"; }
   PKG="$D/@/@!Package"
   LOCK() { python3 -c "import yaml,sys; d=yaml.safe_load(open('$1/.aios/lock.yaml'))['packages']; print(' '.join(f'{n}={e[\"version\"]}@{e.get(\"hub\") or \"from\"}' for n, e in d.items()))"; }

#===============================================================================
# checks before anything is written
#===============================================================================

   assert_contains "$(F "$SANDBOX/outside" skill-memo)" "is not in a vault" "outside a vault"
   assert_contains "$(F "$D" 'Bad Name')" "expected [<hub>/]<package>[<range>]" "invalid package spec"
   assert_contains "$(F "$D" skill-memo)" "package skill-memo is in several hubs: aibex-aios, aibex-hub" "name in two hubs"
   assert_exit 3 env PWD="$D" sh -c "cd '$D' && '$SRC/bin/aios' --fetch skill-memo"
   assert_contains "$(F "$D" gibtsnicht)" "package gibtsnicht not found in the hubs aibex-aios, aibex-hub" "unknown package"
   assert_contains "$(F "$D" test-konflikt)" "- skill-memo: no version fulfils the ranges" "conflict of versions"
   [ ! -e "$PKG" ] && [ ! -e "$D/.aios/lock.yaml" ] && ok || fail "checks: nothing written"

#===============================================================================
# fetch an app with a dependency: plan, packages:, lock.yaml, @!Package/ with marker
#===============================================================================

   export AIOS_HUBS="$ONLY_AIOS aibex-hub=file://$SANDBOX/hubs/aibex-hub"
   OUT="$(F "$D" aibex-aios/app-taschenrechner --plan)"
   assert_contains "$OUT" "new        skill-memo 6.1.0 (aibex-aios)" "plan: dependency memo from the hub of the package"
   assert_contains "$OUT" "new        app-taschenrechner 0.5.0 (aibex-aios)" "plan: highest version"
   assert_contains "$OUT" "packages: app-taschenrechner: {range: \"~=0.5.0\", hub: aibex-aios}" "plan: packages: with default range ~=0.Y.Z and hub"
   [ ! -e "$PKG" ] && ok || fail "--plan writes nothing"
   OUT="$(F "$D" aibex-aios/app-taschenrechner --yes)"
   assert_contains "$OUT" "open the app app-taschenrechner with /taschenrechner-gui or the tile Apps of /aios-gui" "hint: surface of the app"
   assert_eq "$(LOCK "$D")" "app-taschenrechner=0.5.0@aibex-aios skill-memo=6.1.0@aibex-aios" "lock.yaml: resolved packages with hub"
   assert_contains "$(cat "$D/.aios/lock.yaml")" "    required_by: [app-taschenrechner]" "lock.yaml: required_by, one line (S3)"
   assert_eq "$(sed -n 2,3p "$PKG/app-taschenrechner/.aios-deploy")" $'name: app-taschenrechner\nversion: 0.5.0' "marker of the package"
   assert_contains "$(cat "$PKG/app-taschenrechner/.aios-deploy")" "commit: " "marker: commit"
   assert_file "$PKG/app-taschenrechner/knowledge/@!Funktionstasten/plus-19.yaml"
   [ ! -e "$PKG/app-taschenrechner/.git" ] && ok || fail "mirrored without .git"
   assert_contains "$(F "$D")" "match lock.yaml, nothing to do" "reconcile: nothing to do (I8)"
   assert_contains "$(F "$D" aibex-aios/app-taschenrechner)" "nothing to do" "fetch again: nothing to do"

#===============================================================================
# reconcile: missing and directly changed copies, offline from the cache
#===============================================================================

   printf 'x\n' >> "$PKG/skill-memo/skills/memo/SKILL.md"; rm -r "$PKG/app-taschenrechner"
   OUT="$(F "$D" --plan)"
   assert_contains "$OUT" "changed directly, restored skill-memo 6.1.0" "reconcile: directly changed copy"
   assert_contains "$OUT" "missing    app-taschenrechner 0.5.0" "reconcile: missing copy"
   AIOS_HUBS="aibex-aios=file:///nicht/da aibex-hub=file:///nicht/da" F "$D" --yes >/dev/null
   assert_file "$PKG/app-taschenrechner/manifest.yaml"
   assert_eq "$(tail -1 "$PKG/skill-memo/skills/memo/SKILL.md")" "Memo-Stil, Attrappe 6.1.0" "offline: restored from the cache"

#===============================================================================
# no silent update, --upgrade, --remove
#===============================================================================

   assert_contains "$(F "$D" aibex-aios/app-taschenrechner'==0.4.0' --plan)" "downgrade 0.5.0 -> 0.4.0 app-taschenrechner" "plan names a downgrade"
   F "$D" aibex-aios/app-taschenrechner'==0.4.0' --yes >/dev/null
   assert_eq "$(LOCK "$D")" "app-taschenrechner=0.4.0@aibex-aios skill-memo=6.1.0@aibex-aios" "explicit version"
   sed -i.bak 's/"==0.4.0"/"~=0.4.0"/' "$D/.aios/config.yaml"; rm "$D/.aios/config.yaml.bak"
   OUT="$(F "$D" --yes)"
   assert_eq "$(LOCK "$D")" "app-taschenrechner=0.4.0@aibex-aios skill-memo=6.1.0@aibex-aios" "range allows 0.4.3, but no silent update"
   OUT="$(F "$D" --upgrade --yes)"
   assert_eq "$(LOCK "$D")" "app-taschenrechner=0.4.3@aibex-aios skill-memo=6.1.0@aibex-aios" "--upgrade chooses anew"
   assert_contains "$(F "$D" --remove skill-memo)" "skill-memo is not in packages:" "--remove: only packages of packages:"
   mkdir -p "$D/@Data/app-taschenrechner"; printf 'A: {}\n' > "$D/@Data/app-taschenrechner/funktionstasten.yaml"
   F "$D" --remove app-taschenrechner --yes >/dev/null
   [ ! -e "$PKG/app-taschenrechner" ] && [ ! -e "$PKG/skill-memo" ] && ok || fail "--remove: package and its dependency removed"
   assert_file "$D/@Data/app-taschenrechner/funktionstasten.yaml"
   assert_eq "$(cat "$D/.aios/config.yaml")" "aios: 0.4.0" "--remove: entry of packages: removed"

#===============================================================================
# hub outside the hub list, --hub, --from, assistant (A5), hook
#===============================================================================

   export AIOS_HUBS="$ONLY_AIOS" AIOS_GITHUB="file://$SANDBOX/hubs"
   F "$S" aibex-hub/knowledge-scorpio --yes >/dev/null
   assert_eq "$(LOCK "$S")" "knowledge-scorpio=0.1.1@aibex-hub" "hub outside the hub list, without hint"
   assert_contains "$(cat "$S/.aios/config.yaml")" "knowledge-scorpio: {range: \"~=0.1.1\", hub: aibex-hub}" "packages: binds the hub"
   F "$S" skill-memo --hub aibex-hub --yes >/dev/null
   assert_eq "$(LOCK "$S")" "knowledge-scorpio=0.1.1@aibex-hub skill-memo=6.0.0@aibex-hub" "--hub"
   OUT="$(F "$S" test-assistent --yes)"
   assert_contains "$OUT" "assign the assistant to a project of the chain with /aios-assistant Testassistent" "assistant: hint (A5)"
   OUT="$(F "$S" test-hook --yes)"
   assert_contains "$OUT" "hooks session-start have no effect in v0.5" "hook: reported"
   F "$S" test-befehl --from "$SANDBOX/hubs/aibex-aios/test-befehl" --yes >/dev/null
   assert_contains "$(cat "$S/.aios/lock.yaml")" "from: $SANDBOX/hubs/aibex-aios/test-befehl" "--from: repo in lock.yaml"
   assert_contains "$(cat "$S/@/@!Package/test-befehl/.aios-deploy")" "repo: $SANDBOX/hubs/aibex-aios/test-befehl" "--from: repo in the marker"
   assert_eq "$(ls "$D/@/@!Package" 2>/dev/null | wc -l | tr -d ' ')" "0" "packages of S-Sternwarte stay there"

#===============================================================================
# v0.5 step 5: all or nothing - backup, restore on failure, restore after a crash (spec 06, I11)
#===============================================================================

   SNAP() { (cd "$S" && find "@/@!Package" -maxdepth 2 | sort; cat .aios/config.yaml .aios/lock.yaml; ls .claude/skills 2>/dev/null); }
   BEFORE="$(SNAP)"
   assert_contains "$(F "$S" knowledge-orion --plan)" "back up what the plan changes -> $S/.aios/backup" "plan: names the backup"
   OUT="$(AIOS_TEST_FAIL=3 F "$S" knowledge-orion --yes)"
   assert_contains "$OUT" "the plan failed (RuntimeError: AIOS_TEST_FAIL: step 3 fails); the state before the plan is restored" "failure: restored"
   assert_eq "$(SNAP)" "$BEFORE" "failure: config, lock, @!Package and registration as before"
   [ ! -e "$S/.aios/backup" ] && ok || fail "failure: no backup left"
   AIOS_TEST_FAIL=4:crash F "$S" knowledge-orion --yes >/dev/null; RC=$?
   assert_eq "$RC" "70" "crash: process ended"
   assert_file "$S/.aios/backup/index.txt"
   OUT="$(F "$S" knowledge-orion --plan)"
   assert_contains "$OUT" "restore from the backup of" "after a crash: only the restore is offered"
   assert_not_contains "$OUT" "knowledge-orion 0.1.0" "after a crash: no new plan"
   F "$S" --yes >/dev/null
   assert_eq "$(SNAP)" "$BEFORE" "after a crash: restored to the state before the plan"
   [ ! -e "$S/.aios/backup" ] && ok || fail "after a crash: backup removed after the restore"
   F "$S" knowledge-orion --yes >/dev/null
   [ -d "$S/@/@!Package/knowledge-orion" ] && [ ! -e "$S/.aios/backup" ] && ok || fail "success: package there, backup removed"
   unset AIOS_HUBS AIOS_GITHUB

#===============================================================================
# v0.6 step 8: B1, cache of --from per source and commit (K1), registration in the target (K2),
# open files named (memo 02) (spec 06, Holen; V0.6, memos 02, 03, 42, 50)
#===============================================================================

   export AIOS_HUBS="$("$SRC/tests/hub/build" "$SANDBOX/hubs8")"
   V4="$SANDBOX/work/§Vier"; mkdir -p "$V4/@" "$V4/.aios"; printf 'aios: 0.4.0\n' > "$V4/.aios/config.yaml"
   OUT="$(F "$V4" test-b1 --yes)"; RC=$?
   assert_eq "$RC" "0" "B1: fetch works although the highest version needs 0.6"
   assert_contains "$(cat "$V4/.aios/config.yaml")" 'test-b1: "~=0.1.0"' "B1: range from the highest fitting version"

   E="$SANDBOX/work/§Acht"; P="$E/P-Projekt"; mkdir -p "$E/@" "$E/.aios" "$P/@"
   printf 'aios: 0.6.0\n' > "$E/.aios/config.yaml"
   git -C "$E" init -q; git -C "$E" add -A; git -C "$E" -c user.name=t -c user.email=t@t commit -qm init
   for N in 1 2; do
      R="$SANDBOX/src$N"; mkdir -p "$R/skills/eins"
      printf 'name: skill-eins\nversion: 0.1.0\ntype: skill\ndescription: Quelle %s\nrequires:\n  aios: ">=0.6,<0.7"\ncontents:\n  skills: [eins]\n' "$N" > "$R/manifest.yaml"
      printf -- '---\nname: eins\nversion: 0.1.0\ndescription: d\n---\n\n# Quelle %s\n' "$N" > "$R/skills/eins/SKILL.md"
      git -C "$R" init -q; git -C "$R" add -A; git -C "$R" -c user.name=t -c user.email=t@t commit -qm 0.1.0; git -C "$R" tag v0.1.0
   done
   F "$E" skill-eins --from "$SANDBOX/src1" --yes >/dev/null
   F "$E" skill-eins --from "$SANDBOX/src2" --yes >/dev/null
   assert_contains "$(cat "$E/@/@!Package/skill-eins/skills/eins/SKILL.md")" "# Quelle 2" "K1: the second source, not the cache of the first"
   assert_contains "$(cat "$E/.aios/lock.yaml")" "commit: $(git -C "$SANDBOX/src2" rev-parse HEAD)" "K1: lock.yaml names the commit of the second source"
   assert_eq "$(ls -d "$HOME"/.aios/packages/_from/*/skill-eins | wc -l | tr -d ' ')" "2" "K1: one cache per source"
   printf '\n# neu\n' >> "$SANDBOX/src2/skills/eins/SKILL.md"
   git -C "$SANDBOX/src2" -c user.name=t -c user.email=t@t commit -qam neu; git -C "$SANDBOX/src2" tag -f v0.1.0 >/dev/null
   rm -rf "$E/@/@!Package/skill-eins"
   F "$E" --yes >/dev/null
   assert_contains "$(cat "$E/@/@!Package/skill-eins/skills/eins/SKILL.md")" "# neu" "K1: tag moved in the source: fetched anew"

   OUT="$(at "$SANDBOX" "$SRC/bin/aios" --fetch knowledge-orion --to "$P" --yes)"
   assert_dir "$P/.claude/skills/aios-init"
   [ ! -e "$SANDBOX/.claude" ] && ok || fail "K2: nothing registered in the folder of the session"

   printf 'aios: 0.6.0\n# offen\n' > "$E/.aios/config.yaml"
   OUT="$(F "$E" knowledge-orion --plan)"
   assert_contains "$OUT" "note: open changes in $E: .aios/config.yaml" "memo 02: open file of the target named"
   assert_contains "$OUT" "aios --fetch commits nothing" "memo 02: not committed"

   # H3: open files below a package folder as one entry (V0.6, memo 81)
   git -C "$E" add -A; git -C "$E" -c user.name=t -c user.email=t@t commit -qm stand
   printf '\n# lokal\n' >> "$E/@/@!Package/skill-eins/skills/eins/SKILL.md"
   printf 'x\n' > "$E/@/@!Package/skill-eins/notiz.md"
   OUT="$(F "$E" skill-eins --from "$SANDBOX/src1" --plan)"
   assert_contains "$OUT" "note: open changes in $E: @/@!Package/skill-eins/ (2 files)" "H3: one entry per package folder"
   assert_not_contains "$OUT" "SKILL.md," "H3: files of the folder not named one by one"
   unset AIOS_HUBS
