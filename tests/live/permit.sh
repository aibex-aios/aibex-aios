#!/bin/bash
# permit.sh: live test of the PreToolUse hook with real headless Claude sessions (spec 02, Freigabe E1-E4;
# V0.6, memos 20, 22; step 11): one call of the forwarder in an A/W runs without a rule, everything else does not

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/permit.sh [<model>]   # headless sessions R1-R8, default model haiku'
      echo '          tests/live/permit.sh --version   # print version'
      echo '   not part of tests/run: needs a logged-in claude CLI and uses tokens'
      echo '   see also: tests/t22-permit.sh, aios --context --permit'
      exit 1
   fi

#===============================================================================
# print version: tests/live/permit.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.2.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/permit.sh [<model>]
#===============================================================================

   if [ "$2" == "" ]; then
      MODEL="${1:-haiku}"
      . "$(dirname "$0")/lib.sh"
      V="$SB/§Live"; G="$V/Garten"; ALT="$SB/§Alt"; OUT="$SB/Draussen"
      mkdir -p "$V/.aios" "$V/@" "$G/@" "$ALT/.aios" "$ALT/@" "$OUT"
      printf 'aios: 0.6.0\n' > "$V/.aios/config.yaml"
      printf 'aios: 0.5.0\n' > "$ALT/.aios/config.yaml"   # bound below 0.6: no release (E1)
      HOOKS="$(hooks)"
      ask() {                                       # ask <dir> <command>: answer and the denied commands
         local P="Führe genau diesen einen Befehl mit dem Bash-Tool aus, unverändert und ohne weitere Befehle, und gib nur seine Ausgabe wieder: $2"
         (cd "$1" && claude -p "$P" --model "$MODEL" --settings "$HOOKS" --setting-sources project \
            --add-dir "$SB" --output-format json </dev/null 2>/dev/null) | python3 -c '
import json, sys
try:
    r = json.loads(sys.stdin.read())
except ValueError:
    print("no json"); sys.exit()
print(r.get("result", ""))
for d in r.get("permission_denials") or []:
    print("DENIED:", (d.get("tool_input") or {}).get("command", d.get("tool_name", "")))'
      }
      read() {                                      # read <dir> <file>: first line and the denied reads
         local P="Lies genau diese eine Datei mit dem Read-Tool, ohne andere Werkzeuge, und gib nur ihre erste Zeile wieder: $2"
         (cd "$1" && claude -p "$P" --model "$MODEL" --settings "$HOOKS" --setting-sources project \
            --output-format json </dev/null 2>/dev/null) | python3 -c '
import json, sys
try:
    r = json.loads(sys.stdin.read())
except ValueError:
    print("no json"); sys.exit()
print(r.get("result", ""))
for d in r.get("permission_denials") or []:
    print("DENIED:", d.get("tool_name", ""), (d.get("tool_input") or {}).get("file_path", ""))'
      }
      rules() { mkdir -p "$G/.claude"; printf '%s\n' "$1" > "$G/.claude/settings.json"; }   # project settings (E4)
      echo "=> live permit test with model $MODEL in $SB"

      ID="$(cd "$G" && "$FWD" --context --id | sed 's/^id=\([^ ]*\).*/\1/')"
      A="$(ask "$G" "$FWD --context --id")"
      check "R1 A/W: the forwarder runs without a rule (E1-E4)" "$A" "$ID"
      refuse "R1 A/W: nothing denied" "$A" "DENIED:"

      A="$(ask "$G" "$FWD --context --id; echo fertig")"
      check "R2 chained command: no release (E3)" "$A" "DENIED: $FWD --context --id; echo fertig"

      rules "{\"permissions\":{\"deny\":[\"Bash($FWD --context --id)\"]}}"
      A="$(ask "$G" "$FWD --context --id")"
      check "R3 deny rule beats the release (E4, memo 22)" "$A" "DENIED: $FWD --context --id"
      refuse "R3 deny rule: no id" "$A" "$ID"

      rules "{\"permissions\":{\"ask\":[\"Bash($FWD --context:*)\"]}}"
      A="$(ask "$G" "$FWD --context --id")"
      check "R4 ask rule beats the release (E4, memo 22; headless: denied)" "$A" "DENIED: $FWD --context --id"
      rm -rf "$G/.claude"

      A="$(ask "$OUT" "$FWD --context --id")"
      check "R5 outside a vault: no release (E1)" "$A" "DENIED: $FWD --context --id"

      A="$(ask "$ALT" "$FWD --context --id")"
      check "R6 vault bound to 0.5: no release (E1)" "$A" "DENIED: $FWD --context --id"

      DOC="$REPO/doc/tutorials/01 Erste Schritte mit den Demo-Assistenten.md"   # doc/ of the installation v0.6.0
      A="$(read "$G" "$DOC")"
      check "R7 A/W: doc/ of the bound version readable without a rule (R2, H9)" "$A" "Erste Schritte mit den Demo-Assistenten"
      refuse "R7 A/W: nothing denied" "$A" "DENIED:"

      A="$(read "$ALT" "$DOC")"
      check "R8 vault bound to 0.5: doc/ not released (R1)" "$A" "DENIED: Read $DOC"

      finish
   fi

#===============================================================================
# cannot deal with anything else ...
#===============================================================================

   "$0" -?
   exit 1
