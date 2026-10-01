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
gaertner                 assistant  0.1.0" "--library: skills and assistants of the clone"
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
   assert_contains "$OUT" "manifest $D/.aios/config.yaml: memo: (new) -> 6.0.0" "plan: manifest"
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
   OUT="$(A --deploy memo==6.0.0 --to "$D" --yes)"
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

   OUT="$(A --deploy memo==7.1.0 --from "$PF" --yes)"
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
   OUT="$(A --deploy --from "$PF" --yes)"
   assert_contains "$OUT" "memo 7.1.0 (missing)" "reconcile: missing blueprint restored"
   assert_contains "$(cat "$GB/SKILL.md")" "# Memo 7.1.0" "reconcile: from the maintenance project"

   sed -i '' 's/  memo: 7.1.0/  memo: 7.0.0/' "$G/.aios/config.yaml" 2>/dev/null || sed -i 's/  memo: 7.1.0/  memo: 7.0.0/' "$G/.aios/config.yaml"
   OUT="$(A --deploy --yes)"
   assert_contains "$OUT" "memo 7.0.0 (7.1.0 -> 7.0.0)" "reconcile: manifest changed, source from the marker"
   assert_contains "$(cat "$GB/SKILL.md")" "# Memo 7.0.0" "reconcile: version of the manifest"

   mk "$G/@/@!Skill/lokal/SKILL.md" $'---\nname: lokal\n---\n'
   sed -i '' '/obst\/memo/d' "$G/.aios/config.yaml" 2>/dev/null || sed -i '/obst\/memo/d' "$G/.aios/config.yaml"
   OUT="$(A --deploy --yes)"
   assert_contains "$OUT" "remove $AB: deployed, but no longer in the manifest" "reconcile: removed from the manifest"
   [ ! -e "$AB" ] && ok || fail "reconcile: blueprint removed"
   assert_file "$G/@/@!Skill/lokal/SKILL.md"
   assert_contains "$(A --deploy </dev/null)" "match the manifest" "reconcile again: nothing to do"

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
