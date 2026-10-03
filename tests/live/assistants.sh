#!/bin/bash
# assistants.sh: live test of the assignment of assistants (/aios-assistant, hooks, resume) with Gärtner and Astronom (costs tokens)

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/assistants.sh [<model>]   # headless sessions A1-A6, default model haiku'
      echo '          tests/live/assistants.sh --version   # print version'
      echo '   not part of tests/run: needs a logged-in claude CLI and uses tokens;'
      echo '   copies the demo assistants of the library (assistants/demo/) into a sandbox'
      echo '   see also: tests/live/skills.sh, aios-context --assistant'
      exit 1
   fi

#===============================================================================
# print version: tests/live/assistants.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.3.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/assistants.sh [<model>]
#===============================================================================

   if [ "$2" == "" ]; then
      MODEL="${1:-haiku}"
      REPO="$(cd "$(dirname "$0")/../.." && pwd)"
      LIB="$REPO/assistants/demo"
      T="${TMPDIR:-/tmp}"; SB="$(cd "$(mktemp -d "${T%/}/aios-live.XXXXXX")" && pwd -P)" || exit 1
      V="$SB/§Live"; G="$V/Garten"; O="$G/@/@!Assistant/gaertner"; A="$V/@/@!Assistant/astronom"
      mkdir -p "$SB/bin" "$SB/home" "$V/.aios" "$V/@/@Rule" "$G/@/@!Assistant" "$V/@/@!Assistant"
      printf 'aios: 0.3.0\n' > "$V/.aios/config.yaml"
      printf '# Stil\nAntworte auf Deutsch.\n' > "$V/@/@Rule/stil.md"
      cp -R "$LIB/gaertner" "$O"                    # demo assistants of the library (spec 03)
      cp -R "$LIB/astronom" "$A"
      SORTE="Sternreinette $RANDOM"
      printf '\n## Sandkasten\n\n| Sorte | Genussreife |\n|---|---|\n| %s | nur am 29. Februar eines Schaltjahres |\n' "$SORTE" >> "$O/@Wissen/@@Sortenkunde/sortenkunde.md"
      printf '# Garten\n' > "$G/@/garten.md"
      printf '.DS_Store\n.claude/skills/\n.aios/manifest\n' > "$G/.gitignore"; git -C "$G" init -q   # Garten complete (S1-S4): no PROJECT-INCOMPLETE
      for TOOL in aios aios-context; do
         printf '#!/bin/bash\nHOME="%s/home" exec "%s/bin/%s" "$@"\n' "$SB" "$REPO" "$TOOL" > "$SB/bin/$TOOL"; chmod +x "$SB/bin/$TOOL"
      done
      PYTHONPATH="$REPO/lib" python3 -c '
import sys
from pathlib import Path
from aios import install
f = Path(sys.argv[1]) / "skills/aios/aios-assistant/SKILL.md"
m = install.frontmatter(f)
d = Path(sys.argv[2]) / ".claude/skills/aios-assistant"; d.mkdir(parents=True)
(d / "SKILL.md").write_text(install.wrapper("aios-assistant", m["description"], m.get("allowed-tools", ""), session=True))' "$REPO" "$G"
      HOOKS="{\"hooks\":{\"SessionStart\":[{\"hooks\":[{\"type\":\"command\",\"command\":\"$SB/bin/aios-context --session\"}]}],\"UserPromptSubmit\":[{\"hooks\":[{\"type\":\"command\",\"command\":\"$SB/bin/aios-context --advise\"}]}]}}"
      TOOLS=("Skill" "Read" "Bash(aios --skill *)" "Bash(aios --assistant *)" "Bash(aios --gui *)" "Bash(aios-context *)")
      ask() {                                       # ask <prompt> [<claude options>]: new chat with the AIOS hooks
         local P="$1"; shift
         (cd "$G" && PATH="$SB/bin:$PATH" claude -p "$P" --model "$MODEL" --settings "$HOOKS" \
            --setting-sources project --add-dir "$SB" --allowedTools "${TOOLS[@]}" "$@" </dev/null 2>&1)
      }
      assign() { (cd "$G" && PATH="$SB/bin:$PATH" aios --assistant "$1" --yes >/dev/null 2>&1); }   # no tokens
      PASS=0; FAIL=0
      check() {                                     # check <name> <answer> <expected> [<expected> …]
         local N="$1" ANS="$2" E; shift 2
         for E in "$@"; do
            case "$ANS" in *"$E"*) ;; *) FAIL=$((FAIL+1)); printf '\033[31mFAIL\033[0m %s: [%s] missing\n%s\n' "$N" "$E" "$ANS"; return;; esac
         done
         PASS=$((PASS+1)); printf '\033[32mok\033[0m   %s\n' "$N"
      }
      refuse() {                                    # refuse <name> <answer> <forbidden>
         case "$2" in *"$3"*) FAIL=$((FAIL+1)); printf '\033[31mFAIL\033[0m %s: [%s] must not appear\n%s\n' "$1" "$3" "$2";;
                      *) PASS=$((PASS+1)); printf '\033[32mok\033[0m   %s\n' "$1";; esac
      }
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

      echo "=> $PASS passed, $FAIL failed"
      rm -rf "$SB"
      [ "$FAIL" == "0" ] || exit 1
      exit 0
   fi

#===============================================================================
# cannot deal with anything else ...
#===============================================================================

   "$0" -?
   exit 1
