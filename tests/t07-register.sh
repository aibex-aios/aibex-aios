# t07-register.sh: step 7 of the plan (memo 18) - registration of project skills (spec 03, Registrieren)

   case "$SANDBOX" in */aios-test.*) ;; *) echo "*** run via tests/run, never directly (it would touch the real HOME)" >&2; exit 1;; esac

#===============================================================================
# setup: vault with blueprints of every kind, project Garten as its own git repo
#===============================================================================

   mkdir -p "$SANDBOX/fake"
   export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
   D="$SANDBOX/work/§Demo"; G="$D/Garten"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   skill() { mk "$1/SKILL.md" "$(printf -- '---\nname: %s\ndescription: test\n%s---\n\n# %s\n%s\n' "$2" "${3:+version: $3
}" "$2" "${4:-}")"; }
   mk "$D/.aios/config.yaml" $'aios: 0.6.0\n'
   skill "$D/@/@!Skill/memo"        memo 6.0.0
   skill "$D/@/@!Skill/shared"      shared 0.1.0 "shared v1"
   skill "$D/@/@!Skill/noversion"   noversion
   skill "$D/@/@!Skill/badversion"  badversion 1.0
   skill "$D/@/@!Skill/aios-evil"   aios-evil
   skill "$D/@/@!Skill/Bad_Name"    Bad_Name
   mkdir -p "$D/@/@!Skill/noskill"
   skill "$D/@/@!Skill/wrongname"   other
   mk "$G/@/garten.md" $'# Garten\n'
   skill "$G/@/@!Skill/memo"        memo 6.1.0 "garten memo"
   mk "$G/@/@!Skill/memo/vorlagen/brief.md" $'# Brief\n'
   skill "$G/@/@!Assistant/obst/@!Skill/privat" privat
   skill "$G/.claude/skills/own"    own
   git -C "$G" init -q
   mkdir -p "$G/Neu"
   mk "$SANDBOX/work/§Alt/@/@!Skill/x/SKILL.md" $'---\nname: x\n---\n'
   mkdir -p "$SANDBOX/work/§Alt/P/@" "$SANDBOX/work/§Alt/.aios"; printf 'legacy: ai-brain\n' > "$SANDBOX/work/§Alt/.aios/config.yaml"

   SY() { (cd "$1" && shift && "$SRC/bin/aios" --context --sync "$@" 2>&1); }
   K="$G/.claude/skills"

#===============================================================================
# preview, cancel, register
#===============================================================================

   OUT="$(echo n | SY "$G")"; RC=$?
   assert_eq "$RC" "1" "cancelled: exit 1"
   assert_contains "$OUT" "new      memo 6.1.0  ($G/@/@!Skill/memo)" "preview: nearest masterspace wins"
   assert_contains "$OUT" "new      shared 0.1.0  ($D/@/@!Skill/shared)" "preview: skill of the vault"
   for X in aios-evil Bad_Name noskill wrongname privat noversion badversion; do
      case "$(printf '%s\n' "$OUT" | grep '^      ')" in *"new      $X"*|*"changed  $X"*) fail "preview must not list $X" ;; *) ok ;; esac
   done
   assert_contains "$OUT" "the name aios-evil is reserved" "reserved name reported"
   assert_contains "$OUT" "Bad_Name is not a valid skill name" "invalid name reported"
   assert_contains "$OUT" "noskill: no SKILL.md" "missing SKILL.md reported"
   assert_contains "$OUT" "name in SKILL.md is 'other', not 'wrongname'" "wrong name reported"
   assert_contains "$OUT" "skill noversion has no version, not registered ($D/@/@!Skill/noversion)" "skill without version reported"
   assert_contains "$OUT" "skill badversion has an invalid version '1.0' (MAJOR.MINOR.PATCH), not registered" "invalid version reported"
   [ ! -e "$K/memo" ] && [ ! -e "$G/.aios/registry" ] && ok || fail "cancelled: nothing written"

   OUT="$(echo y | SY "$G")"
   assert_contains "$OUT" "=> registered: new aios-assistant, aios-attach, aios-context, aios-deploy, aios-detach, aios-distribution, aios-fetch, aios-gui, aios-init, aios-integrity, aios-memo, aios-package, aios-register, aios-restore, aios-status, aios-sync, gui, memo, shared" "registered: wrappers of the kernel and project skills"
   assert_contains "$OUT" "from the next chat (or after /reload-skills)" "hint: next chat"
   assert_eq "$(cat "$K/memo/SKILL.md")" "$(cat "$G/@/@!Skill/memo/SKILL.md")" "memo copied from Garten"
   assert_file "$K/memo/vorlagen/brief.md"
   assert_eq "$(cat "$K/own/SKILL.md")" "$(printf -- '---\nname: own\ndescription: test\n---\n\n# own\n')" "foreign skill untouched"
   [ ! -e "$K/privat" ] && [ ! -e "$K/aios-evil" ] && ok || fail "assistant skill and reserved name not registered"
   DIG="$(cd "$G/@/@!Skill/memo" && find . -type f | sed 's|^\./||' | sort | while IFS= read -r F; do printf '%s\n' "$F"; cat "$F"; printf '\n'; done | shasum -a 256 | cut -c1-64)"
   assert_eq "$(grep -v -e '^  aios-' -e '^  gui:' "$G/.aios/registry" | awk '/^    source: "kernel"/{skip=3} skip>0{skip--; next} {print}')" "# written by AIOS (registration), do not edit
schema: 1
registered:
  memo:
    source: \"$G/@/@!Skill/memo\"
    version: 6.1.0
    digest: sha256:$DIG
  shared:
    source: \"$D/@/@!Skill/shared\"
    version: 0.1.0
    digest: $(sed -n 's/^    digest: //p' "$G/.aios/registry" | tail -1)" "manifest: format and digest"
   assert_contains "$(SY "$G" </dev/null)" "are up to date" "second sync: up to date, no question"

#===============================================================================
# changes: blueprint edited, build output edited, override removed, blueprint removed
#===============================================================================

   printf 'shared v2\n' >> "$D/@/@!Skill/shared/SKILL.md"
   OUT="$(SY "$G" --yes </dev/null)"
   assert_contains "$OUT" "changed  shared" "blueprint edited: changed"
   assert_contains "$(cat "$K/shared/SKILL.md")" "shared v2" "--yes: applied without question"

   printf 'hand edit\n' >> "$K/memo/SKILL.md"
   assert_contains "$(SY "$G" --yes)" "changed  memo" "build output edited: restored"
   case "$(cat "$K/memo/SKILL.md")" in *"hand edit"*) fail "build output restored" ;; *) ok ;; esac

   rm -rf "$G/@/@!Skill/memo"
   OUT="$(SY "$G" --yes)"
   assert_contains "$OUT" "changed  memo 6.0.0  ($D/@/@!Skill/memo)" "override removed: vault version"
   [ ! -e "$K/memo/vorlagen" ] && ok || fail "old files of the skill removed"

   sed -i.bak '/^version:/d' "$D/@/@!Skill/shared/SKILL.md" && rm "$D/@/@!Skill/shared/SKILL.md.bak"
   OUT="$(SY "$G" --yes)"
   assert_contains "$OUT" "remove   shared" "version removed: no longer valid, remove"
   assert_contains "$OUT" "skill shared has no version, not registered" "version removed: reported"
   [ ! -e "$K/shared" ] && ok || fail "version removed: registered copy deleted"
   skill "$D/@/@!Skill/shared" shared 0.1.0 "shared v3"
   assert_contains "$(SY "$G" --yes)" "new      shared 0.1.0" "version back: registered again"

   rm -rf "$D/@/@!Skill/shared"
   OUT="$(SY "$G" --yes)"
   assert_contains "$OUT" "remove   shared" "blueprint removed: remove"
   [ ! -e "$K/shared" ] && ok || fail "removed skill deleted"
   case "$(cat "$G/.aios/registry")" in *shared*) fail "manifest without shared" ;; *) ok ;; esac
   assert_file "$K/own/SKILL.md"

#===============================================================================
# session hook: registration for the next chat
#===============================================================================

   skill "$D/@/@!Skill/neu" neu 1.0.0
   json() { printf '{"hook_event_name":"SessionStart","cwd":"%s"}' "$1"; }
   OUT="$(json "$G" | "$SRC/bin/aios" --context --session)"
   assert_contains "$OUT" "AIOS-SKILLS: new neu" "session: AIOS-SKILLS line"
   assert_contains "$OUT" "— effective from the next chat" "session: AIOS-SKILLS line, next chat"
   assert_contains "$OUT" "AIOS-WARNING: $D/@/@!Skill/aios-evil: the name aios-evil is reserved" "session: problems as warnings"
   assert_file "$K/neu/SKILL.md"
   case "$(json "$G" | "$SRC/bin/aios" --context --session)" in *AIOS-SKILLS*) fail "second session: no AIOS-SKILLS line" ;; *) ok ;; esac

#===============================================================================
# nothing is registered outside an initialized project of an activated vault
#===============================================================================

   assert_contains "$(SY "$G/Neu")" "is not a project (no @/)" "not initialized: nothing registered"
   json "$G/Neu" | "$SRC/bin/aios" --context --session >/dev/null
   [ ! -e "$G/Neu/.claude" ] && [ ! -e "$G/Neu/.aios" ] && ok || fail "not initialized: hook writes nothing"
   assert_contains "$(SY "$SANDBOX/work/§Alt/P")" "legacy mode" "legacy: nothing registered"
   [ ! -e "$SANDBOX/work/§Alt/P/.claude" ] && ok || fail "legacy: nothing written"

#===============================================================================
# aios --register
#===============================================================================

   skill "$D/@/@!Skill/zwei" zwei 2.0.0
   OUT="$(echo y | "$SRC/bin/aios" --register "$G" 2>&1)"
   assert_contains "$OUT" "new      zwei 2.0.0" "aios --register <path>: preview"
   assert_file "$K/zwei/SKILL.md"
   assert_contains "$(cd "$G" && "$SRC/bin/aios" --register </dev/null 2>&1)" "are up to date" "aios --register in cwd"

#===============================================================================
# v0.6 step 6: wrappers of the kernel skills and of the alias in the vault (spec 03, 04; V0.6, memos 28-30, 48)
#===============================================================================

   FW="$HOME/.aios/bin/aios"
   assert_eq "$(ls "$K" | grep -c '^aios-')" "16" "16 wrappers of the kernel skills in the project"
   assert_eq "$(cat "$K/aios-init/SKILL.md" | sed -n '2p;4p;7p')" "name: aios-init
allowed-tools: Bash($FW --skill aios-init)
!\`$FW --skill aios-init\`" "wrapper: name, own call only, absolute path (F20, F27)"
   assert_contains "$(sed -n 3p "$K/aios-init/SKILL.md")" "description: \"Macht einen Ordner" "wrapper: description of the kernel skill"
   assert_contains "$(cat "$K/aios-assistant/SKILL.md")" 'Session-ID dieses Chats: `${CLAUDE_SESSION_ID}`' "wrapper: session id as a line of text"
   assert_eq "$(sed -n 4p "$K/gui/SKILL.md")" "allowed-tools: Bash($FW --gui --session *)" "alias gui: allowed-tools"
   assert_contains "$(cat "$K/gui/SKILL.md")" "!\`$FW --gui --session \${CLAUDE_SESSION_ID}\`" "alias gui: body"
   assert_eq "$(sed -n '/^  aios-init:/,/^  [a-z]/p' "$G/.aios/registry" | sed -n 2p)" '    source: "kernel"' "registry: source kernel"
   assert_contains "$(sed -n '/^  aios-init:/,/digest/p' "$G/.aios/registry")" "version: $(cat "$SRC/VERSION")" "registry: version of the kernel"
   assert_eq "$(ls "$D/.claude/skills" | grep -c '^aios-')" "16" "vault root brought up to date from a project below"
   assert_file "$D/.claude/skills/gui/SKILL.md"
   printf 'changed\n' >> "$K/aios-init/SKILL.md"
   assert_contains "$(SY "$G" --plan)" "changed  aios-init" "changed wrapper: written anew"
   SY "$G" --yes >/dev/null
   assert_contains "$(SY "$G" --plan)" "are up to date" "after the sync: up to date"
   sed -i.bak "/^  aios-init:/,/digest/s/^    version: .*/    version: 0.0.9/" "$G/.aios/registry" && rm "$G/.aios/registry.bak"
   assert_contains "$(SY "$G" --plan)" "changed  aios-init $(cat "$SRC/VERSION")  (kernel)" "B16: same wrapper of another kernel version: changed"
   SY "$G" --yes >/dev/null
   assert_contains "$(sed -n '/^  aios-init:/,/digest/p' "$G/.aios/registry")" "version: $(cat "$SRC/VERSION")" "B16: registry names the running kernel"
   mkdir -p "$G/.claude/skills/aios-fremd"
   rm -rf "$G/.claude/skills/aios-status"; mkdir -p "$G/.claude/skills/aios-status"; printf 'mine\n' > "$G/.claude/skills/aios-status/SKILL.md"
   assert_contains "$(SY "$G" --plan)" "changed  aios-status" "a wrapper in the registry is managed by AIOS"
