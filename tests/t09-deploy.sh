# t09-deploy.sh: step 9 of the plan (memo 18) - aios --deploy, --library, versions, maintenance projects

#===============================================================================
# setup: vault with root project, project Garten with an assistant, maintenance project with tags
#===============================================================================

   export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
   export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
   D="$SANDBOX/work/§Demo"; G="$D/Garten"; PF="$SANDBOX/PSM-Memo"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   mk "$D/.aios/config.yaml" $'aios: 0.1.0\n# Vault Demo\n'
   mkdir -p "$D/@" "$G/@/@!Assistant/obst" "$D/Wiese"
   pfl() { mk "$PF/@Skill/memo/SKILL.md" "$(printf -- '---\nname: memo\nversion: %s\ndescription: Pflege\n---\n\n# Memo %s\n' "$1" "$2")"; }
   pfl 7.0.0 7.0.0; mk "$PF/@Skill/memo/extra.md" $'# extra\n'
   git -C "$PF" init -q; git -C "$PF" add -A; git -C "$PF" commit -qm 7.0.0; git -C "$PF" tag memo-v7.0.0
   pfl 7.1.0 7.1.0; rm "$PF/@Skill/memo/extra.md"; git -C "$PF" add -A; git -C "$PF" commit -qm 7.1.0; git -C "$PF" tag memo-v7.1.0
   pfl 8.0.0 8.0.0; git -C "$PF" commit -qam 8; git -C "$PF" tag memo-v9.0.0                # tag and frontmatter differ
   A() { (cd "$G" && "$SRC/bin/aios" "$@" 2>&1); }                                        # session in Garten
   LIB="$SRC/skills/basic/memo/SKILL.md"

#===============================================================================
# --library and checks before anything is written
#===============================================================================

   assert_eq "$("$SRC/bin/aios" --library)" "memo                     skill      6.0.0
astronom                 assistant  0.1.0
gaertner                 assistant  0.2.0" "--library: skills and assistants of the clone"
   assert_contains "$(A --deploy memo-6.0.0)" "expected <name>==<version>" "bad spec"
   assert_contains "$(A --deploy aios-init==0.1.0)" "is an AIOS skill" "AIOS skill"
   assert_contains "$(A --deploy nix==1.0.0)" "has no bundled skill nix" "unknown skill"
   assert_contains "$(A --deploy memo==5.0.0 --to "$D")" "available: 6.0.0" "unknown version: available versions"
   assert_contains "$(A --deploy memo==6.0.0 --to "$D/Wiese")" "is not a project" "target without @/"
   assert_contains "$(A --deploy memo==7.5.0 --from "$PF" --to "$D")" "no tag memo-v7.5.0" "maintenance project: missing tag"
   assert_contains "$(A --deploy memo==9.0.0 --from "$PF" --to "$D")" "version '8.0.0'; expected memo 9.0.0" "maintenance project: frontmatter differs"
   assert_contains "$(A --deploy memo==6.0.0 --assistant nobody --to "$G")" "no assistant nobody" "unknown assistant"
   mkdir -p "$SANDBOX/work/§Alt/@"
   assert_contains "$(A --deploy memo==6.0.0 --to "$SANDBOX/work/§Alt")" "is not activated (legacy mode)" "vault without activation (I4)"
   [ ! -e "$D/@/@!Skill" ] && [ ! -e "$G/@/@!Skill" ] && [ ! -e "$SANDBOX/work/§Alt/@/@!Skill" ] && ok || fail "checks: nothing written"

#===============================================================================
# deploy from the library to the root project, registration in the session project
#===============================================================================

   OUT="$(A --deploy memo==6.0.0 --to "$D" --plan)"
   assert_contains "$OUT" "blueprint $D/@/@!Skill/memo: memo 6.0.0 from library" "plan: blueprint"
   assert_contains "$OUT" "new      SKILL.md" "plan: files"
   assert_contains "$OUT" "manifest $D/.aios/config.yaml: skills: memo: (new) -> 6.0.0" "plan: manifest"
   assert_contains "$OUT" "register the project skills of $G" "plan: registration of the session"
   [ ! -e "$D/@/@!Skill/memo" ] && ok || fail "--plan: nothing written"

   OUT="$(A --deploy memo==6.0.0 --to "$D" --yes)"; RC=$?
   assert_eq "$RC" "0" "deploy: exit 0"
   B="$D/@/@!Skill/memo"
   assert_eq "$(cat "$B/SKILL.md")" "$(cat "$LIB")" "blueprint = bundled skill"
   assert_eq "$(sed -n '2,4p' "$B/.aios-deploy")" "$(printf 'name: memo\nversion: 6.0.0\nsource: "library"')" "marker"
   assert_eq "$(cat "$D/.aios/config.yaml")" "$(printf 'aios: 0.1.0\n# Vault Demo\nskills:\n  memo: 6.0.0')" "manifest skills: in the vault, other lines kept"
   assert_file "$G/.claude/skills/memo/SKILL.md"
   assert_contains "$OUT" "available from the next chat" "hint: next chat"
   assert_contains "$(A --deploy memo==6.0.0 --to "$D" </dev/null)" "already deployed" "same version again: nothing to do"

   printf 'eigene Zeile\n' >> "$B/SKILL.md"
   OUT="$(A --deploy memo==6.0.0 --to "$D" --plan)"; A --deploy memo==6.0.0 --to "$D" --yes >/dev/null              # --yes prints only the result (spec 04)
   assert_contains "$OUT" "was changed directly (differs from memo 6.0.0)" "direct change reported"
   assert_eq "$(cat "$B/SKILL.md")" "$(cat "$LIB")" "direct change replaced"

#===============================================================================
# deploy from a maintenance project to Garten, upgrade, assistant
#===============================================================================

   OUT="$(A --deploy memo==7.0.0 --from "$PF" --yes)"
   GB="$G/@/@!Skill/memo"
   assert_contains "$(cat "$GB/SKILL.md")" "# Memo 7.0.0" "from the tag memo-v7.0.0"
   assert_file "$GB/extra.md"
   assert_contains "$(cat "$GB/.aios-deploy")" "source: \"$PF\"" "marker: source maintenance project"
   assert_eq "$(sed -n '/^skills:/,$p' "$G/.aios/config.yaml")" "$(printf 'skills:\n  memo: 7.0.0')" "manifest in Garten"
   assert_contains "$(cat "$G/.claude/skills/memo/SKILL.md")" "# Memo 7.0.0" "registered: Garten beats the vault"

   OUT="$(A --deploy memo==7.1.0 --from "$PF" --plan)"; YES="$(A --deploy memo==7.1.0 --from "$PF" --yes)"
   case "$YES" in *"plan:"*|*"changed  SKILL.md"*) fail "--yes: no plan, only the result (spec 04)" ;; *) ok ;; esac
   assert_contains "$OUT" "memo: 7.0.0 -> 7.1.0" "upgrade: manifest"
   assert_contains "$OUT" "changed  SKILL.md" "upgrade: changed file"
   assert_contains "$OUT" "remove   extra.md" "upgrade: removed file"
   [ ! -e "$GB/extra.md" ] && ok || fail "upgrade: file of the old version removed"

   OUT="$(A --deploy memo==6.0.0 --assistant obst --yes)"
   AB="$G/@/@!Assistant/obst/@!Skill/memo"
   assert_eq "$(cat "$AB/SKILL.md")" "$(cat "$LIB")" "assistant: blueprint"
   assert_contains "$(cat "$G/.aios/config.yaml")" "  obst/memo: 6.0.0" "assistant: manifest key assistant/name"
   case "$OUT" in *"register the project skills"*) fail "assistant: no registration" ;; *) ok ;; esac
   assert_contains "$(cd "$G" && "$SRC/bin/aios" --config)" "skill     obst/memo 6.0.0" "assistant entry read by the chain"

#===============================================================================
# reconcile: aios --deploy without a skill
#===============================================================================

   assert_contains "$(A --deploy </dev/null)" "match the manifest" "reconcile: nothing to do"

   rm -rf "$GB"                                                         # e.g. fresh clone without the blueprint
   assert_contains "$(A --deploy --plan)" "memo 7.1.0 is not bundled with AIOS" "reconcile: source unknown without --from (warning)"
   OUT="$(A --deploy --from "$PF" --plan)"; A --deploy --from "$PF" --yes >/dev/null              # --yes prints only the result (spec 04)
   assert_contains "$OUT" "memo 7.1.0 (missing)" "reconcile: missing blueprint restored"
   assert_contains "$(cat "$GB/SKILL.md")" "# Memo 7.1.0" "reconcile: from the maintenance project"

   sed -i '' 's/  memo: 7.1.0/  memo: 7.0.0/' "$G/.aios/config.yaml" 2>/dev/null || sed -i 's/  memo: 7.1.0/  memo: 7.0.0/' "$G/.aios/config.yaml"
   OUT="$(A --deploy --plan)"; A --deploy --yes >/dev/null              # --yes prints only the result (spec 04)
   assert_contains "$OUT" "memo 7.0.0 (7.1.0 -> 7.0.0)" "reconcile: manifest changed, source from the marker"
   assert_contains "$(cat "$GB/SKILL.md")" "# Memo 7.0.0" "reconcile: version of the manifest"

   mk "$G/@/@!Skill/lokal/SKILL.md" $'---\nname: lokal\n---\n'
   sed -i '' '/obst\/memo/d' "$G/.aios/config.yaml" 2>/dev/null || sed -i '/obst\/memo/d' "$G/.aios/config.yaml"
   OUT="$(A --deploy --plan)"; A --deploy --yes >/dev/null              # --yes prints only the result (spec 04)
   assert_contains "$OUT" "remove $AB: deployed, but no longer in skills:" "reconcile: removed from the manifest"
   [ ! -e "$AB" ] && ok || fail "reconcile: blueprint removed"
   assert_file "$G/@/@!Skill/lokal/SKILL.md"
   assert_contains "$(A --deploy </dev/null)" "match the manifest" "reconcile again: nothing to do"

#===============================================================================
# assistants of the library: deploy, skills inside, reconcile (spec 03, F2, F3)
#===============================================================================

   GA="$D/@/@!Assistant/gaertner"
   OUT="$(A --deploy gaertner==0.2.0 --to "$D" --plan)"
   assert_contains "$OUT" "deploy assistant gaertner 0.2.0 to $D" "assistant: plan"
   assert_contains "$OUT" "blueprint $GA: gaertner 0.2.0 from library" "assistant: blueprint in @!Assistant/"
   assert_contains "$OUT" "manifest $D/.aios/config.yaml: assistants: gaertner: (new) -> 0.2.0" "assistant: manifest assistants:"
   case "$OUT" in *"register the project skills"*) fail "assistant: no registration" ;; *) ok ;; esac
   [ ! -e "$GA" ] && ok || fail "assistant: --plan writes nothing"
   OUT="$(A --deploy gaertner==0.2.0 --to "$D" --yes)"
   assert_contains "$OUT" "activate it in a chat of the chain with /aios-assistant Gärtner" "assistant: hint"
   for F in ASSISTANT.md "@!Skill/apfel-birnen-algebra/SKILL.md" "@Wissen/@Grundlagen/grundlagen.md" "@Wissen/@@Sortenkunde/sortenkunde.md"; do
      assert_eq "$(cat "$GA/$F")" "$(cat "$SRC/assistants/demo/gaertner/$F")" "assistant: $F"
   done
   assert_eq "$(sed -n '2,4p' "$GA/.aios-deploy")" "$(printf 'name: gaertner\nversion: 0.2.0\nsource: "library"')" "assistant: marker"
   assert_contains "$(cat "$D/.aios/config.yaml")" $'assistants:\n  gaertner: 0.2.0' "assistant: config.yaml"
   assert_contains "$(cd "$G" && "$SRC/bin/aios" --config)" "assistant gaertner 0.2.0 ($D/.aios/config.yaml)" "assistant: entry read by the chain"
   assert_contains "$(cd "$G" && "$SRC/bin/aios-context" --assistants)" "gaertner             Gärtner 0.2.0" "assistant: resolved in the chain"
   assert_contains "$(A --deploy gaertner==0.2.0 --to "$D")" "already deployed" "assistant: second deploy, nothing to do"
   assert_contains "$(A --deploy gaertner==9.9.9 --to "$D")" "gaertner 9.9.9 is not bundled with AIOS" "assistant: unknown version"
   assert_contains "$(A --deploy gaertner==0.2.0 --assistant obst --to "$G")" "gaertner is an assistant; --assistant <name> is only for skills" "assistant: no --assistant"
   assert_contains "$(A --deploy astronom==0.1.0 --from "$PF" --to "$D")" "no tag astronom-v0.1.0" "assistant: --from only for skills"

   A --deploy memo==6.0.0 --assistant gaertner --to "$D" --yes >/dev/null
   assert_file "$GA/@!Skill/memo/.aios-deploy"
   assert_contains "$(cat "$D/.aios/config.yaml")" "  gaertner/memo: 6.0.0" "skill into the deployed assistant: manifest"
   assert_contains "$(A --deploy --to "$D" </dev/null)" "match the manifest" "skill inside: the assistant is not changed directly (F3)"

   printf 'eigene Notiz\n' >> "$GA/ASSISTANT.md"
   assert_contains "$(A --deploy --to "$D" --plan)" "blueprint $GA: gaertner 0.2.0 (changed directly, restored)" "assistant changed directly: reconcile"
   A --deploy --to "$D" --yes >/dev/null
   case "$(cat "$GA/ASSISTANT.md")" in *"eigene Notiz"*) fail "assistant restored" ;; *) ok ;; esac
   assert_file "$GA/@!Skill/memo/SKILL.md"
   assert_contains "$(A --deploy --to "$D" </dev/null)" "match the manifest" "assistant restored, its skill kept"

   rm -rf "$GA"                                                         # e.g. fresh clone
   assert_contains "$(A --deploy --to "$D" --plan)" "gaertner 0.2.0 (missing)" "assistant missing: restored"
   A --deploy --to "$D" --yes >/dev/null
   assert_file "$GA/ASSISTANT.md"
   assert_file "$GA/@!Skill/memo/SKILL.md"

   sed -i '' '/gaertner/d; /^assistants:/d' "$D/.aios/config.yaml" 2>/dev/null || sed -i '/gaertner/d; /^assistants:/d' "$D/.aios/config.yaml"
   OUT="$(A --deploy --to "$D" --plan)"; A --deploy --to "$D" --yes >/dev/null
   assert_contains "$OUT" "remove $GA: deployed, but no longer in assistants:" "assistant removed from the manifest"
   case "$OUT" in *"remove $GA/@!Skill/memo"*) fail "its skill goes with the assistant" ;; *) ok ;; esac
   [ ! -e "$GA" ] && ok || fail "assistant removed"
   assert_contains "$(A --deploy --to "$D" </dev/null)" "match the manifest" "after removal: nothing to do"

#===============================================================================
# config.yaml: skills: lines are edited in place
#===============================================================================

   P() { PYTHONPATH="$SRC/lib" python3 -c "
from pathlib import Path; from aios import config; f=Path('$SANDBOX/c.yaml'); config.$1; print(f.read_text() if f.exists() else '<gone>', end='')"; }
   printf 'aios: 0.1.0\nskills:\n  a: 1.0.0   # x\n  b: 2.0.0\nhosts: [claude-code]\n' > "$SANDBOX/c.yaml"
   assert_eq "$(P "set_skill(f, 'b', '2.1.0')")" "$(printf 'aios: 0.1.0\nskills:\n  a: 1.0.0   # x\n  b: 2.1.0\nhosts: [claude-code]')" "set_skill: replace"
   assert_eq "$(P "set_skill(f, 'c', '3.0.0')")" "$(printf 'aios: 0.1.0\nskills:\n  a: 1.0.0   # x\n  b: 2.1.0\n  c: 3.0.0\nhosts: [claude-code]')" "set_skill: insert inside the block"
   P "drop_skill(f, 'a')" >/dev/null; P "drop_skill(f, 'b')" >/dev/null
   assert_eq "$(P "drop_skill(f, 'c')")" "$(printf 'aios: 0.1.0\nhosts: [claude-code]')" "drop_skill: empty block removed"
   printf 'skills:\n  a: 1.0.0\n' > "$SANDBOX/c.yaml"
   assert_eq "$(P "drop_skill(f, 'a')")" "<gone>" "drop_skill: empty file removed"
   printf 'skills:\n  a: 1.0.0\n' > "$SANDBOX/c.yaml"
   assert_eq "$(P "set_skill(f, 'g', '0.1.0', 'assistants')")" "$(printf 'skills:\n  a: 1.0.0\nassistants:\n  g: 0.1.0')" "set_skill: section assistants:"
   assert_eq "$(P "drop_skill(f, 'g', 'assistants')")" "$(printf 'skills:\n  a: 1.0.0')" "drop_skill: section assistants:"
