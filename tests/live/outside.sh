#!/bin/bash
# outside.sh: live test of a session outside an AIBOS workspace with the hooks of AIBOS (spec 01, I15; V0.6,
# memos 27, 33; step 11): Claude behaves as if AIBOS were not installed

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/outside.sh [<model>]   # headless sessions O1-O3, default model haiku'
      echo '          tests/live/outside.sh --version   # print version'
      echo '   not part of tests/run: needs a logged-in claude CLI and uses tokens'
      echo '   see also: tests/live/permit.sh, aios --skill'
      exit 1
   fi

#===============================================================================
# print version: tests/live/outside.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.1.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/outside.sh [<model>]
#===============================================================================

   if [ "$2" == "" ]; then
      MODEL="${1:-haiku}"
      . "$(dirname "$0")/lib.sh"
      V="$SB/§Live"; G="$V/Garten"; OUT="$SB/Draussen"
      mkdir -p "$V/.aios" "$V/@/@Rule" "$G/@" "$OUT"
      printf 'aios: 0.6.0\n' > "$V/.aios/config.yaml"
      printf '# Stil\nSchreib kurz.\n' > "$V/@/@Rule/stil.md"
      (cd "$G" && "$FWD" --register --yes >/dev/null 2>&1)   # wrappers only in the vault (V0.6, F18)
      HOOKS="$(hooks)"
      ask() {                                       # ask <dir> <prompt>
         (cd "$1" && PATH="$SB/bin:$PATH" claude -p "$2" --model "$MODEL" --settings "$HOOKS" \
            --setting-sources project --add-dir "$SB" --allowedTools "Read" </dev/null 2>&1)
      }
      echo "=> live outside test with model $MODEL in $SB"

      A="$(cd "$OUT" && "$FWD" --context --session </dev/null 2>&1)"
      check "O0 hooks outside print nothing (no tokens)" "[$A]" "[]"
      A="$(cd "$OUT" && "$FWD" --skill aios-status 2>&1)"
      check "O0 aios --skill outside: no A/W (no tokens)" "$A" "Kein AIBOS-Workspace: $OUT"

      A="$(ask "$OUT" "Enthält dein Kontext Anweisungen oder Texte von AIOS oder AIBOS (z. B. aios-context, AIOS-CONTEXT)? Antworte nur mit JA oder NEIN.")"
      check "O1 session outside: no master context" "$A" "NEIN"

      A="$(ask "$OUT" "/aios-status")"
      refuse "O2 /aios-status outside: no project status" "$A" "Projektstatus"
      refuse "O2 /aios-status outside: no call of the forwarder" "$A" "Kein AIBOS-Workspace"

      A="$(ask "$G" "Enthält dein Kontext einen Block <aios-kernel-skills>? Antworte nur mit JA oder NEIN.")"
      check "O3 control in the vault: block of the kernel skills" "$A" "JA"

      [ -s "$SB/home/.aios/log/context.log" ] && cat "$SB/home/.aios/log/context.log"
      finish
   fi

#===============================================================================
# cannot deal with anything else ...
#===============================================================================

   "$0" -?
   exit 1
