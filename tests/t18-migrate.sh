# t18-migrate.sh: step 8 of the plan v0.4 (V0.4, memos 18, 47) - changeover from v0.3: skills: and
# assistants: as packages, aios --activate v0.4.<n> offers the changeover (spec 06, Umstellung von v0.3);
# v0.5 step 11: changeover from v0.4 with aios --activate v0.5.<n> (spec 06, Umstellung von v0.4)

#===============================================================================
# setup: python3 with PyYAML, test hubs, installed v0.4.0 (stub), vault §Alt of v0.3.1
#===============================================================================

   PYDIR=""
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import yaml" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t18 needs a python3 with PyYAML (pip install pyyaml)"
   export PATH="$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
   export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
   "$SRC/tests/hub/build" "$SANDBOX/hubs" >/dev/null
   export AIOS_HUBS="aibex-aios=file://$SANDBOX/hubs/aibex-aios"
   mkdir -p "$AIOS_PREFIX/v0.4.0"; echo "v0.4.0: $AIOS_PREFIX/v0.4.0" >> "$AIOS_PREFIX/installations.yaml"
   V="$SANDBOX/work/§Alt"; G="$V/G-Garten"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   mark() {                                       # marker with the digest of the content (unchanged blueprint)
      local D; D="$(PYTHONPATH="$SRC/lib" python3 -c 'import sys; from pathlib import Path; from aios import deploy; print(deploy.digest_of(Path(sys.argv[1])))' "$1")"
      mk "$1/.aios-deploy" "# written by aios --deploy, do not edit"$'\n'"name: x"$'\n'"version: 0"$'\n'"source: \"library\""$'\n'"digest: $D"$'\n'
   }
   mk "$V/.aios/config.yaml" $'aios: 0.3.1\nskills:\n  memo: 6.0.0\n  gaertner/memo: 6.0.0\nassistants:\n  gaertner: 0.2.0\n  astronom: 0.1.0\n  gibtsnicht: 1.0.0\nassistant: gaertner\n'
   mk "$V/@/@!Skill/memo/SKILL.md" $'---\nname: memo\nversion: 6.0.0\ndescription: alt\n---\n'; mark "$V/@/@!Skill/memo"
   mk "$V/@/@!Skill/lokal/SKILL.md" $'---\nname: lokal\nversion: 0.1.0\ndescription: lokal\n---\n'
   mk "$V/@/@!Assistant/gaertner/ASSISTANT.md" $'---\nname: gaertner\nversion: 0.2.0\n---\n'; mark "$V/@/@!Assistant/gaertner"
   mk "$V/@/@!Assistant/astronom/ASSISTANT.md" $'---\nname: astronom\nversion: 0.1.0\n---\n'; mark "$V/@/@!Assistant/astronom"
   printf '\n## Eigener Abschnitt\n' >> "$V/@/@!Assistant/astronom/ASSISTANT.md"   # changed directly after deploying (B6)
   mk "$G/.aios/config.yaml" $'skills:\n  memo: 6.0.0\n'; mkdir -p "$G/@"
   at() { (cd "$1" && shift && "$@" 2>&1); }
   A() { local d="$1"; shift; at "$d" "$SRC/bin/aios" "$@"; }

#===============================================================================
# v0.4 reads skills: and assistants: as packages until the changeover
#===============================================================================

   mk "$SANDBOX/work/§Neu/.aios/config.yaml" $'aios: 0.4.0\nskills:\n  memo: 6.0.0\n'; mkdir -p "$SANDBOX/work/§Neu/@"
   OUT="$(A "$SANDBOX/work/§Neu" --fetch --plan)"
   assert_contains "$OUT" "new        skill-memo 6.1.0 (aibex-aios)" "skills: memo read as package skill-memo (default range ~=6.0 of the old version)"
   [ "$(printf '%s' "$OUT" | grep -c 'packages:')" == "0" ] && ok || fail "reading writes no packages:"

#===============================================================================
# aios --activate v0.4.0: plan with the changeover of all projects below
#===============================================================================

   OUT="$(A "$V" --activate v0.4.0 "$V" --plan)"
   assert_contains "$OUT" "aios: 0.4.0 in $V/.aios/config.yaml (was 0.3.1)" "plan: activation"
   assert_contains "$OUT" "$V: skills: memo -> packages: skill-memo: \"~=6.0\"" "plan: skill memo -> skill-memo, default range of the same version"
   assert_contains "$OUT" "$V: assistants: gaertner -> packages: assistant-gaertner: \"~=0.2.0\"" "plan: assistant gaertner"
   assert_contains "$OUT" "$V: note: assistant-astronom: 0.1.0 is not in the hub aibex-aios, takes 0.2.1" "plan: missing version, highest taken"
   assert_contains "$OUT" "$V: remove the deployed blueprint $V/@/@!Skill/memo (replaced by the package)" "plan: blueprint with marker removed"
   assert_contains "$OUT" "$V/@/@!Assistant/astronom changed directly, stays as local blueprint (covers the package)" "plan: changed blueprint stays (B6)"
   assert_not_contains "$OUT" "remove the deployed blueprint $V/@/@!Assistant/astronom" "plan: changed blueprint not removed (B6)"
   assert_contains "$OUT" "$G: skills: memo -> packages: skill-memo: \"~=6.0\"" "plan: project below"
   assert_contains "$OUT" "gaertner/memo (a skill inside an assistant) has no package, passed over" "assistant skill: warning"
   assert_contains "$OUT" "assistants: gibtsnicht 1.0.0: package assistant-gibtsnicht not found" "unknown package: reported, entry stays"
   assert_eq "$(sed -n 1p "$V/.aios/config.yaml")" "aios: 0.3.1" "--plan writes nothing"

#===============================================================================
# changeover: config, packages fetched, local blueprints stay
#===============================================================================

   A "$V" --activate v0.4.0 "$V" --yes >/dev/null
   assert_eq "$(cat "$V/.aios/config.yaml")" 'aios: 0.4.0
skills:
  gaertner/memo: 6.0.0
assistants:
  gibtsnicht: 1.0.0
assistant: gaertner
packages:
  skill-memo: "~=6.0"
  assistant-gaertner: "~=0.2.0"
  assistant-astronom: "~=0.2.1"' "config: packages:, unknown entries stay"
   [ ! -e "$V/@/@!Skill/memo" ] && [ ! -e "$V/@/@!Assistant/gaertner" ] && ok || fail "unchanged blueprints with marker removed"
   assert_contains "$(cat "$V/@/@!Assistant/astronom/ASSISTANT.md")" "## Eigener Abschnitt" "changed blueprint stays with its content (B6)"
   [ ! -e "$V/@/@!Assistant/astronom/.aios-deploy" ] && ok || fail "changed blueprint: marker removed, now local"
   assert_contains "$(at "$V" "$SRC/bin/aios" --context --list)" "covered by local blueprint" "local astronom covers the package"
   assert_file "$V/@/@!Skill/lokal/SKILL.md"
   assert_eq "$(ls "$V/@/@!Package" | tr '\n' ' ')" "assistant-astronom assistant-gaertner skill-memo " "packages fetched into the vault root"
   assert_file "$V/.aios/lock.yaml"
   assert_eq "$(cat "$G/.aios/config.yaml")" $'packages:\n  skill-memo: "~=6.0"' "project below changed over"
   assert_eq "$(ls "$G/@/@!Package")" "skill-memo" "project below: its own package (S9)"
   assert_contains "$(at "$G" "$SRC/bin/aios" --context --assistants)" "Gärtner 0.2.1" "assistant from the package"
   assert_contains "$(A "$V" --activate v0.4.0 "$V" </dev/null)" "nothing to do" "second activation: nothing to do (I8)"

#===============================================================================
# v0.5 step 11: changeover from v0.4 - renamed assistent-*, versions that fit v0.5, @Data/, conflict
#===============================================================================

   mkdir -p "$AIOS_PREFIX/v0.5.0"; echo "v0.5.0: $AIOS_PREFIX/v0.5.0" >> "$AIOS_PREFIX/installations.yaml"
   V4="$SANDBOX/work/§Vier"; mkdir -p "$V4/@" "$V4/@Data/assistent-gaertner"
   mk "$V4/.aios/config.yaml" $'aios: 0.4.0\n'; mk "$V4/@Data/assistent-gaertner/beete.txt" "drei"
   A "$V4" --fetch 'skill-memo==6.0.0' --yes >/dev/null; A "$V4" --fetch 'assistent-gaertner==0.2.0' --yes >/dev/null
   assert_dir "$V4/@/@!Package/assistent-gaertner"
   OUT="$(A "$V4" --activate v0.5.0 "$V4" --plan)"
   assert_contains "$OUT" "aios: 0.5.0 in $V4/.aios/config.yaml (was 0.4.0)" "v0.4: activation"
   assert_contains "$OUT" "changeover from v0.4:" "v0.4: changeover in the same plan"
   assert_contains "$OUT" "$V4: packages: assistent-gaertner 0.2.0 -> assistant-gaertner 0.3.0: \"~=0.3.0\" (renamed)" "v0.4: assistent-gaertner renamed, version for v0.5"
   assert_contains "$OUT" "$V4: packages: skill-memo 6.0.0 -> skill-memo 6.0.1: \"~=6.0\" (requires.aios)" "v0.4: highest version that fits v0.5 (N9)"
   assert_contains "$OUT" "$V4: rename $V4/@Data/assistent-gaertner -> $V4/@Data/assistant-gaertner" "v0.4: @Data/ renamed with the package"
   assert_eq "$(sed -n 1p "$V4/.aios/config.yaml")" "aios: 0.4.0" "v0.4: --plan writes nothing"
   A "$V4" --activate v0.5.0 "$V4" --yes >/dev/null
   C="$(cat "$V4/.aios/config.yaml")"
   assert_contains "$C" 'assistant-gaertner: "~=0.3.0"' "v0.4: packages: renamed"
   assert_not_contains "$C" "assistent-" "v0.4: old name gone"
   assert_eq "$(ls "$V4/@/@!Package" | tr '\n' ' ')" "assistant-gaertner skill-memo " "v0.4: packages fetched anew, old folder removed"
   assert_eq "$(cat "$V4/@Data/assistant-gaertner/beete.txt")" "drei" "v0.4: data stay with the assistant"
   assert_contains "$(cat "$V4/.aios/lock.yaml")" "version: 6.0.1" "v0.4: lock.yaml on 6.0.1"
   assert_contains "$(A "$V4" --activate v0.5.0 "$V4" </dev/null)" "nothing to do" "v0.4: second activation: nothing to do"
   V5="$SANDBOX/work/§Fuenf"; mkdir -p "$V5/@"; mk "$V5/.aios/config.yaml" $'aios: 0.4.0\n'
   A "$V5" --fetch 'assistent-astronom==0.2.1' --yes >/dev/null
   OUT="$(A "$V5" --activate v0.5.0 "$V5" --yes)"; RC=$?
   assert_eq "$RC" "1" "v0.4 without a fitting version: exit 1"
   assert_contains "$OUT" "$V5: assistent-astronom has no version that runs with AIOS 0.5.0 (requires.aios); remove it with aios --fetch --remove assistent-astronom --to $V5" "v0.4: conflict named"
   assert_eq "$(sed -n 1p "$V5/.aios/config.yaml")" "aios: 0.4.0" "v0.4: conflict changes nothing"
   unset AIOS_HUBS
