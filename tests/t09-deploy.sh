# t09-deploy.sh: step 5 of the plan v0.4 (V0.4, memos 18, 39) - aios --deploy (deploy elements),
# .aios/registry, elements of fetched packages in the chain: skills, assistants, knowledge (K6),
# precedence (S6), not deployed elements (H3) (spec 02, 03, 06)

#===============================================================================
# setup: python3 with PyYAML, test hubs, vault §Demo with project G-Garten, packages fetched
#===============================================================================

   PYDIR=""
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import yaml" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t09 needs a python3 with PyYAML (pip install pyyaml)"
   export PATH="$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
   "$SRC/tests/hub/build" "$SANDBOX/hubs" >/dev/null
   export AIOS_HUBS="aibex-aios=file://$SANDBOX/hubs/aibex-aios"
   D="$SANDBOX/work/§Demo"; G="$D/G-Garten"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   mk "$D/.aios/config.yaml" $'aios: 0.4.0\n'
   mkdir -p "$D/@" "$G/@"
   at() { (cd "$1" && shift && "$@" 2>&1); }
   A() { local d="$1"; shift; at "$d" "$SRC/bin/aios" "$@"; }
   A "$D" --fetch app-taschenrechner --yes >/dev/null
   A "$D" --fetch knowledge-orion --yes >/dev/null
   A "$D" --fetch test-assistent --yes >/dev/null

#===============================================================================
# elements of fetched packages act in the chain: registration, knowledge, assistant
#===============================================================================

   at "$G" "$SRC/bin/aios-context" --sync --yes >/dev/null
   assert_eq "$(ls "$G/.claude/skills" | tr '\n' ' ')" "memo taschenrechner taschenrechner-gui " "skills of the packages registered in a project below"
   assert_file "$G/.aios/registry"
   assert_contains "$(cat "$G/.aios/registry")" "source: \"$D/@/@!Package/app-taschenrechner/skills/taschenrechner\"" "registry: source in @!Package/"
   OUT="$(at "$G" "$SRC/bin/aios-context" --context)"
   assert_contains "$OUT" "$D/@/@!Package/knowledge-orion/knowledge/@@Orion/Sterne.md — Die 20 hellsten Sterne des Orion" "K6: knowledge of a package available, path in @!Package/"
   [ "$(printf '%s' "$OUT" | grep -c 'Funktionstasten')" == "0" ] && ok || fail "K6: hidden knowledge of a package not in the context"
   assert_contains "$(at "$G" "$SRC/bin/aios-context" --assistants)" "Testassistent 0.1.0" "assistant of a package in the chain"
   assert_contains "$(at "$G" "$SRC/bin/aios-context" --assistants)" "(§Demo, package test-assistent)" "assistant: origin with package"
   assert_contains "$(at "$G" "$SRC/bin/aios-context" --assistant test-assistent)" "Du bist der Testassistent des Test-Hubs." "assistant of a package resolved"

#===============================================================================
# aios --deploy: show, --only, --all, checks
#===============================================================================

   OUT="$(A "$D" --deploy)"
   assert_contains "$OUT" "app-taschenrechner 0.4.2 (aibex-aios) — all elements deployed" "show: all elements deployed after fetching (H2)"
   assert_contains "$OUT" "      deployed      knowledge" "show: knowledge as an element"
   assert_contains "$(A "$D" --deploy skill-memo==6.0.0)" "to fetch skill-memo==6.0.0 use: aios --fetch skill-memo==6.0.0" "old form: hint to aios --fetch"
   assert_contains "$(A "$D" --deploy skill-memo --only memo)" "only packages fetched for this project can be deployed in part (H4)" "dependency: always whole"
   assert_contains "$(A "$D" --deploy app-taschenrechner --only gibtsnicht)" "app-taschenrechner has no element gibtsnicht" "unknown element"
   assert_contains "$(A "$D" --deploy app-taschenrechner)" "usage: aios --deploy" "neither --only nor --all"
   OUT="$(A "$D" --deploy app-taschenrechner --only taschenrechner-gui --plan)"
   assert_contains "$OUT" "packages: app-taschenrechner: {range: \"~=0.4.2\", only: [taschenrechner-gui]}" "plan: only: in packages:"
   A "$D" --deploy app-taschenrechner --only taschenrechner-gui --yes >/dev/null
   assert_contains "$(cat "$D/.aios/config.yaml")" "app-taschenrechner: {range: \"~=0.4.2\", only: [taschenrechner-gui]}" "--only written"
   assert_contains "$(A "$D" --deploy)" "      not deployed  skill taschenrechner" "show: not deployed element"
   at "$G" "$SRC/bin/aios-context" --sync --yes >/dev/null
   assert_eq "$(ls "$G/.claude/skills" | tr '\n' ' ')" "memo taschenrechner-gui " "H3: not deployed skill not registered"
   assert_contains "$(at "$G" "$SRC/bin/aios-context" --list)" "fetched, not deployed: skill taschenrechner" "/aios-context: fetched, not deployed"
   assert_contains "$(A "$D" --deploy app-taschenrechner --only taschenrechner-gui)" "nothing to do" "--only again: nothing to do (I8)"
   assert_contains "$(A "$D" --fetch)" "nothing to do" "fetch keeps the selection"
   A "$D" --deploy app-taschenrechner --all --yes >/dev/null
   assert_contains "$(cat "$D/.aios/config.yaml")" 'app-taschenrechner: "~=0.4.2"' "--all: back to the range"
   A "$D" --deploy test-assistent --only test-assistent --yes >/dev/null
   sed -i.bak 's/knowledge-orion: "~=0.1.0"/knowledge-orion: {range: "~=0.1.0", only: [nichts]}/' "$D/.aios/config.yaml"; rm "$D/.aios/config.yaml.bak"
   OUT="$(at "$G" "$SRC/bin/aios-context" --context)"
   [ "$(printf '%s' "$OUT" | grep -c 'Sterne.md')" == "0" ] && ok || fail "H3: knowledge not deployed, not in the context"
   sed -i.bak 's/knowledge-orion: {range: "~=0.1.0", only: \[nichts\]}/knowledge-orion: "~=0.1.0"/' "$D/.aios/config.yaml"; rm "$D/.aios/config.yaml.bak"

#===============================================================================
# precedence: local blueprint before the package in the same masterspace, nearest masterspace
#===============================================================================

   mk "$D/@/@!Skill/memo/SKILL.md" $'---\nname: memo\nversion: 9.0.0\ndescription: lokal\n---\n\n# Lokal\n'
   at "$G" "$SRC/bin/aios-context" --sync --yes >/dev/null
   assert_contains "$(cat "$G/.claude/skills/memo/SKILL.md")" "# Lokal" "local blueprint before the package (S6)"
   assert_contains "$(at "$G" "$SRC/bin/aios-context" --list)" "skill memo: covered by local blueprint (§Demo)" "/aios-context reports the covering"
   mk "$G/@/@!Skill/memo/SKILL.md" $'---\nname: memo\nversion: 9.1.0\ndescription: Garten\n---\n\n# Garten\n'
   at "$G" "$SRC/bin/aios-context" --sync --yes >/dev/null
   assert_contains "$(cat "$G/.claude/skills/memo/SKILL.md")" "# Garten" "nearest masterspace wins"

#===============================================================================
# .aios/registry replaces .aios/manifest of v0.3
#===============================================================================

   mv "$G/.aios/registry" "$G/.aios/manifest"
   OUT="$(at "$G" "$SRC/bin/aios" --register --plan)"
   assert_contains "$OUT" "rename   .aios/manifest -> .aios/registry" "register: plan renames the manifest"
   at "$G" "$SRC/bin/aios" --register --yes >/dev/null
   [ -f "$G/.aios/registry" ] && [ ! -e "$G/.aios/manifest" ] && ok || fail "manifest of v0.3 replaced by the registry"
   assert_eq "$(ls "$G/.claude/skills" | tr '\n' ' ')" "memo taschenrechner taschenrechner-gui " "skills of the old manifest stay managed"
   unset AIOS_HUBS
