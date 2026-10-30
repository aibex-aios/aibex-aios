#!/bin/bash
# assistants.sh: live test of the assignment of assistants (/aios-assistant, hooks, resume) with Gärtner and Astronom
# (V0.6 step 11: wrappers registered in the vault, PreToolUse releases the forwarder; costs tokens)

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/assistants.sh [<model>]   # headless sessions A1-A6, default model haiku'
      echo '          tests/live/assistants.sh --version   # print version'
      echo '   not part of tests/run: needs a logged-in claude CLI and uses tokens;'
      echo '   copies the demo assistants of the test hub (tests/hub/aibex-aios/assistant-*) into a sandbox'
      echo '   see also: tests/live/skills.sh, aios --context --assistant'
      exit 1
   fi

#===============================================================================
# print version: tests/live/assistants.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.4.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/assistants.sh [<model>]
#===============================================================================

   if [ "$2" == "" ]; then
      MODEL="${1:-haiku}"
      . "$(dirname "$0")/lib.sh"
      LIB="$REPO/tests/hub/aibex-aios"
      V="$SB/§Live"; G="$V/Garten"; O="$G/@/@!Assistant/gaertner"; A="$V/@/@!Assistant/astronom"
      mkdir -p "$SB/bin" "$SB/home" "$V/.aios" "$V/@/@Rule" "$G/@/@!Assistant" "$V/@/@!Assistant"
      printf 'aios: 0.6.0\n' > "$V/.aios/config.yaml"
      printf '# Stil\nAntworte auf Deutsch.\n' > "$V/@/@Rule/stil.md"
      cp -R "$LIB/assistant-gaertner/0.3.0/assistants/gaertner" "$O"   # demo assistants (packages, spec 03)
      cp -R "$LIB/assistant-astronom/0.3.0/assistants/astronom" "$A"
      SORTE="Sternreinette $RANDOM"
      printf '\n## Sandkasten\n\n| Sorte | Genussreife |\n|---|---|\n| %s | nur am 29. Februar eines Schaltjahres |\n' "$SORTE" >> "$O/@Wissen/@@Sortenkunde/sortenkunde.md"
      printf '# Garten\n' > "$G/@/garten.md"
      printf '.DS_Store\n.claude/skills/\n.claude/worktrees/\n.agents/\n.aios/registry\n.aios/backup/\n' > "$G/.gitignore"; git -C "$G" init -q   # Garten complete (S1-S4): no PROJECT-INCOMPLETE
      (cd "$G" && "$FWD" --register --yes >/dev/null 2>&1)   # aios-assistant and gui as wrappers of the kernel (V0.6, F18)
      HOOKS="$(hooks)"
      TOOLS=("Skill" "Read")                        # the forwarder: PreToolUse (V0.6, F11)
      ask() {                                       # ask <prompt> [<claude options>]: new chat with the AIOS hooks
         local P="$1"; shift
         (cd "$G" && PATH="$SB/bin:$PATH" claude -p "$P" --model "$MODEL" --settings "$HOOKS" \
            --setting-sources project --add-dir "$SB" --allowedTools "${TOOLS[@]}" "$@" </dev/null 2>&1)
      }
      assign() { (cd "$G" && PATH="$SB/bin:$PATH" aios --assistant "$1" --yes >/dev/null 2>&1); }   # no tokens
      echo "=> live assistant test with model $MODEL in $SB"

      ANS="$(ask "/aios-assistant Gärtner: Rechentest — und dann in der Rolle: Was ist ¬Apfel * Birne? Nenne nur das Ergebnis.")"
      check "A1 /aios-assistant: assignment written" "$(cat "$G/.aios/config.yaml" 2>/dev/null)" "assistant: gaertner"
      check "A1 Gärtner: private skill apfel-birnen-algebra" "$ANS" "Birne"
      refuse "A1 Gärtner: no 0/1 result" "$ANS" "= 1"

      ANS="$(ask "Was ist Mond * Mond?")"
      check "A2 new chat: the hook loads Gärtner" "$ANS" "Gärtner"
      refuse "A2 Gärtner: boundary, no result −Sonne" "$ANS" "−Sonne"
      refuse "A2 Gärtner: boundary, no result -Sonne" "$ANS" "-Sonne"

      assign astronom
      ANS="$(ask "Was ist Mond · Mond? Nur das Ergebnis.")"
      case "$ANS" in *"−Sonne"*|*"-Sonne"*|*"− Sonne"*) R3="−Sonne";; *) R3="$ANS";; esac
      check "A3 new chat after aios --assistant: Astronom (vault assistant), private skill" "$R3" "−Sonne"

      assign gaertner
      ANS="$(ask "Wann ist die Sorte $SORTE genussreif?")"
      check "A4 Gärtner: available knowledge read on demand" "$ANS" "29. Februar"

      SID="$(ask "Wer bist du? Nenne nur deinen Titel." --output-format json | python3 -c 'import sys, json; print(json.loads(sys.stdin.read()).get("session_id", ""))' 2>/dev/null)"
      assign astronom
      ANS="$(ask "Wer bist du? Nenne nur deinen Titel." --resume "$SID")"
      check "A5 resume keeps the assistant of the session (Gärtner), not the new assignment" "$ANS" "Gärtner"
      refuse "A5 resume: not Astronom" "$ANS" "Astronom"

      assign gaertner
      ANS="$(ask "/gui")"
      check "A7 /gui: surface of the Gärtner as a menu (headless), calculator only as a hint" "$ANS" "Sorte bestimmen" "Rechner"

      ANS="$(ask "/aios-assistant --none — und dann: Bist du gerade ein AIOS-Assistent? Antworte mit ja oder nein.")"
      check "A6 --none: assignment none" "$(cat "$G/.aios/config.yaml")" "assistant: none"
      check "A6 --none: no assistant" "$ANS" "ein"

      finish
   fi

#===============================================================================
# cannot deal with anything else ...
#===============================================================================

   "$0" -?
   exit 1
