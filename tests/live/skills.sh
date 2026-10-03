#!/bin/bash
# skills.sh: live test of the AIOS skills with real headless Claude sessions (steps 8, 9; costs tokens)

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/skills.sh [<model>]   # headless sessions S1-S5, default model haiku'
      echo '          tests/live/skills.sh --version   # print version'
      echo '   not part of tests/run: needs a logged-in claude CLI and uses tokens'
      echo '   see also: tests/live/hooks.sh, aios --skill'
      exit 1
   fi

#===============================================================================
# print version: tests/live/skills.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.1.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/skills.sh [<model>]
#===============================================================================

   if [ "$2" == "" ]; then
      MODEL="${1:-haiku}"
      REPO="$(cd "$(dirname "$0")/../.." && pwd)"
      T="${TMPDIR:-/tmp}"; SB="$(cd "$(mktemp -d "${T%/}/aios-live.XXXXXX")" && pwd -P)" || exit 1
      V="$SB/§Live"; G="$V/Garten"
      mkdir -p "$SB/home/.aios" "$SB/bin" "$V/.aios" "$V/@/@Rule" "$G/@" "$G/@Memo" "$G/GN-Neu"
      printf 'aios: 0.3.0\n' > "$V/.aios/config.yaml"
      printf '# Stil\nSchreib kurz.\n' > "$V/@/@Rule/stil.md"
      printf '# Garten\nIm Garten wachsen Äpfel.\n' > "$G/@/garten.md"
      printf '# 01 Beete planen\n\n**Datum:** 2026-09-01\n**Status:** Entscheidung\n\n## Entscheidung\nDrei Beete.\n\n## Offen\n- Bewässerung der Beete klären\n' > "$G/@Memo/01 Beete planen.md"
      printf '# 02 Zaun\n\n**Datum:** 2026-09-10\n**Status:** Notiz\n\n## Ergebnis\nZaun gebaut.\n' > "$G/@Memo/02 Zaun.md"
      for TOOL in aios aios-context; do
         printf '#!/bin/bash\nHOME="%s/home" exec "%s/bin/%s" "$@"\n' "$SB" "$REPO" "$TOOL" > "$SB/bin/$TOOL"
         chmod +x "$SB/bin/$TOOL"
      done
      export GIT_AUTHOR_NAME=live GIT_AUTHOR_EMAIL=live@test GIT_COMMITTER_NAME=live GIT_COMMITTER_EMAIL=live@test
      printf '.DS_Store\n.claude/skills/\n.aios/manifest\n' > "$G/.gitignore"; git -C "$G" init -q   # Garten complete (S1-S4): no PROJECT-INCOMPLETE
      wrappers() {                                  # version-neutral wrappers into <dir>/.claude/skills
         PYTHONPATH="$REPO/lib" python3 -c '
import sys
from pathlib import Path
from aios import install
repo, target = Path(sys.argv[1]), Path(sys.argv[2])
for f in sorted((repo / "skills" / "aios").glob("*/SKILL.md")):
    m = install.frontmatter(f)
    d = target / ".claude" / "skills" / f.parent.name
    d.mkdir(parents=True, exist_ok=True)
    session = "<session-id>" in f.read_text(encoding="utf-8").split("\n---", 1)[-1]
    (d / "SKILL.md").write_text(install.wrapper(f.parent.name, m["description"], m.get("allowed-tools", ""), session))' "$REPO" "$1"
      }
      wrappers "$G"; wrappers "$G/GN-Neu"
      HOOKS='{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"aios-context --session"}]}],"UserPromptSubmit":[{"hooks":[{"type":"command","command":"aios-context --advise"}]}]}}'
      ask() {                                       # ask <dir> <prompt>
         (cd "$1" && PATH="$SB/bin:$PATH" claude -p "$2" --model "$MODEL" --settings "$HOOKS" \
            --setting-sources project --add-dir "$SB" \
            --allowedTools "Skill" "Read" "Glob" "Bash(aios --skill *)" "Bash(aios-context *)" \
                           "Bash(aios --init *)" "Bash(aios --register *)" "Bash(aios --integrity *)" "Bash(aios --gui *)" "Bash(git log *)" </dev/null 2>&1)
      }
      PASS=0; FAIL=0
      check() {                                     # check <name> <answer> <expected> [<expected> …]
         local N="$1" A="$2" E; shift 2
         for E in "$@"; do
            case "$A" in *"$E"*) ;; *) FAIL=$((FAIL+1)); printf '\033[31mFAIL\033[0m %s: [%s] missing\n%s\n' "$N" "$E" "$A"; return;; esac
         done
         PASS=$((PASS+1)); printf '\033[32mok\033[0m   %s\n' "$N"
      }
      echo "=> live skill test with model $MODEL in $SB"

      ID="$(cd "$G" && "$SB/bin/aios-context" --id | sed 's/^id=\([^ ]*\).*/\1/')"
      A="$(ask "$G" "/aios-context")"
      check "S1 /aios-context: loaded and listed" "$A" "$ID" "Kette" "Garten"

      A="$(ask "$G/GN-Neu" "/aios-init Ich bestätige schon jetzt ausdrücklich: ja, bitte anlegen, Titel Neu, Assistent inherit.")"
      [ -d "$G/GN-Neu/@" ] && [ "$(git -C "$G/GN-Neu" log --format=%s 2>/dev/null)" == "AIOS: Projekt initialisiert" ] && R2="initialized" || R2="not initialized: $A"
      check "S2 /aios-init: project created with git and first commit" "$R2" "initialized"

      A="$(ask "$G" "/aios-status")"
      check "S3 /aios-status: from memos" "$A" "Projektstatus" "Bewässerung"

      mkdir -p "$V/@/@!Skill/giesskanne"
      printf -- '---\nname: giesskanne\nversion: 1.0.0\ndescription: Giessplan\n---\n\n# Giesskanne\n' > "$V/@/@!Skill/giesskanne/SKILL.md"
      rm -rf "$G/.claude/skills/giesskanne"
      A="$(cd "$G" && PATH="$SB/bin:$PATH" claude -p "/aios-register Ja, bitte registrieren." --model "$MODEL" \
            --settings '{"hooks":{}}' --setting-sources project --add-dir "$SB" \
            --allowedTools "Skill" "Bash(aios --skill *)" "Bash(aios --register *)" 2>&1)"
      [ -f "$G/.claude/skills/giesskanne/SKILL.md" ] && R4="registered" || R4="not registered: $A"
      check "S4 /aios-register: blueprint registered" "$R4" "registered"

      A="$(cd "$G" && PATH="$SB/bin:$PATH" claude -p "/aios-deploy memo==6.0.0 --to $V Ich bestätige schon jetzt ausdrücklich: ja, ausrollen." \
            --model "$MODEL" --settings '{"hooks":{}}' --setting-sources project --add-dir "$SB" \
            --allowedTools "Skill" "Bash(aios --skill *)" "Bash(aios --deploy *)" "Bash(aios --library *)" 2>&1)"
      [ -f "$V/@/@!Skill/memo/.aios-deploy" ] && grep -q '^  memo: 6.0.0$' "$V/.aios/config.yaml" && R5="deployed" || R5="not deployed: $A"
      check "S5 /aios-deploy memo==6.0.0 to the root project" "$R5" "deployed"

      A="$(ask "$G/GN-Neu" "/aios-integrity")"           # GN-Neu is complete since S2 (Garten would get PROJECT-INCOMPLETE first)
      check "S6 /aios-integrity: report with result line" "$A" "integer"

      A="$(ask "$G" "/aios-gui")"
      check "S7 /aios-gui: menu with the tiles of AIOS" "$A" "Integrität prüfen" "Projektstatus"

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
