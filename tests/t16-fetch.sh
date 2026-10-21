# t16-fetch.sh: step 4 of the plan v0.4 (V0.4, memos 18, 37) - aios --fetch: fetch, reconcile,
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
   assert_contains "$OUT" "new        app-taschenrechner 0.4.1 (aibex-aios)" "plan: highest version"
   assert_contains "$OUT" "packages: app-taschenrechner: {range: \"~=0.4.1\", hub: aibex-aios}" "plan: packages: with default range ~=0.Y.Z and hub"
   [ ! -e "$PKG" ] && ok || fail "--plan writes nothing"
   OUT="$(F "$D" aibex-aios/app-taschenrechner --yes)"
   assert_contains "$OUT" "open the app app-taschenrechner with /taschenrechner-gui or the tile Apps of /aios-gui" "hint: surface of the app"
   assert_eq "$(LOCK "$D")" "app-taschenrechner=0.4.1@aibex-aios skill-memo=6.1.0@aibex-aios" "lock.yaml: resolved packages with hub"
   assert_contains "$(cat "$D/.aios/lock.yaml")" "required_by:
    - app-taschenrechner" "lock.yaml: required_by"
   assert_eq "$(sed -n 2,3p "$PKG/app-taschenrechner/.aios-deploy")" $'name: app-taschenrechner\nversion: 0.4.1' "marker of the package"
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
   assert_contains "$OUT" "missing    app-taschenrechner 0.4.1" "reconcile: missing copy"
   AIOS_HUBS="aibex-aios=file:///nicht/da aibex-hub=file:///nicht/da" F "$D" --yes >/dev/null
   assert_file "$PKG/app-taschenrechner/manifest.yaml"
   assert_eq "$(tail -1 "$PKG/skill-memo/skills/memo/SKILL.md")" "Memo-Stil, Attrappe 6.1.0" "offline: restored from the cache"

#===============================================================================
# no silent update, --upgrade, --remove
#===============================================================================

   F "$D" aibex-aios/app-taschenrechner'==0.4.0' --yes >/dev/null
   assert_eq "$(LOCK "$D")" "app-taschenrechner=0.4.0@aibex-aios skill-memo=6.1.0@aibex-aios" "explicit version"
   sed -i.bak 's/"==0.4.0"/"~=0.4.0"/' "$D/.aios/config.yaml"; rm "$D/.aios/config.yaml.bak"
   OUT="$(F "$D" --yes)"
   assert_eq "$(LOCK "$D")" "app-taschenrechner=0.4.0@aibex-aios skill-memo=6.1.0@aibex-aios" "range allows 0.4.1, but no silent update"
   OUT="$(F "$D" --upgrade --yes)"
   assert_eq "$(LOCK "$D")" "app-taschenrechner=0.4.1@aibex-aios skill-memo=6.1.0@aibex-aios" "--upgrade chooses anew"
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
   assert_eq "$(LOCK "$S")" "knowledge-scorpio=0.1.0@aibex-hub" "hub outside the hub list, without hint"
   assert_contains "$(cat "$S/.aios/config.yaml")" "knowledge-scorpio: {range: \"~=0.1.0\", hub: aibex-hub}" "packages: binds the hub"
   F "$S" skill-memo --hub aibex-hub --yes >/dev/null
   assert_eq "$(LOCK "$S")" "knowledge-scorpio=0.1.0@aibex-hub skill-memo=6.0.0@aibex-hub" "--hub"
   OUT="$(F "$S" test-assistent --yes)"
   assert_contains "$OUT" "assign the assistant to a project of the chain with /aios-assistant Testassistent" "assistant: hint (A5)"
   OUT="$(F "$S" test-hook --yes)"
   assert_contains "$OUT" "hooks session-start have no effect in v0.4" "hook: reported"
   F "$S" test-befehl --from "$SANDBOX/hubs/aibex-aios/test-befehl" --yes >/dev/null
   assert_contains "$(cat "$S/.aios/lock.yaml")" "from: $SANDBOX/hubs/aibex-aios/test-befehl" "--from: repo in lock.yaml"
   assert_contains "$(cat "$S/@/@!Package/test-befehl/.aios-deploy")" "repo: $SANDBOX/hubs/aibex-aios/test-befehl" "--from: repo in the marker"
   assert_eq "$(ls "$D/@/@!Package" 2>/dev/null | wc -l | tr -d ' ')" "0" "packages of S-Sternwarte stay there"
   unset AIOS_HUBS AIOS_GITHUB
