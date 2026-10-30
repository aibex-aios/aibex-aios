#!/bin/bash
# skills.sh: live test of the AIOS skills with real headless Claude sessions (steps 8, 9; V0.6 step 11: kernel
# skills as registered wrappers with the absolute forwarder, released by the PreToolUse hook; costs tokens)

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/skills.sh [<model>]   # headless sessions S1-S9, default model haiku'
      echo '          tests/live/skills.sh --version   # print version'
      echo '   not part of tests/run: needs a logged-in claude CLI and uses tokens'
      echo '   see also: tests/live/hooks.sh, aios --skill'
      exit 1
   fi

#===============================================================================
# print version: tests/live/skills.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.6.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/skills.sh [<model>]
#===============================================================================

   if [ "$2" == "" ]; then
      MODEL="${1:-haiku}"
      . "$(dirname "$0")/lib.sh"
      V="$SB/§Live"; G="$V/Garten"
      mkdir -p "$SB/home/.aios" "$SB/bin" "$V/.aios" "$V/@/@Rule" "$G/@" "$G/@Memo" "$G/GN-Neu"
      printf 'aios: 0.6.0\n' > "$V/.aios/config.yaml"
      printf '# Stil\nSchreib kurz.\n' > "$V/@/@Rule/stil.md"
      printf '# Garten\nIm Garten wachsen Äpfel.\n' > "$G/@/garten.md"
      printf '# 01 Beete planen\n\n**Datum:** 2026-09-01\n**Status:** Entscheidung\n\n## Entscheidung\nDrei Beete.\n\n## Offen\n- Bewässerung der Beete klären\n' > "$G/@Memo/01 Beete planen.md"
      printf '# 02 Zaun\n\n**Datum:** 2026-09-10\n**Status:** Notiz\n\n## Ergebnis\nZaun gebaut.\n' > "$G/@Memo/02 Zaun.md"
      export AIOS_HUBS="$("$REPO/tests/hub/build" "$SB/hubs")"   # packages from the test hub (spec 04)
      export GIT_AUTHOR_NAME=live GIT_AUTHOR_EMAIL=live@test GIT_COMMITTER_NAME=live GIT_COMMITTER_EMAIL=live@test
      printf '.DS_Store\n.claude/skills/\n.claude/worktrees/\n.agents/\n.aios/registry\n.aios/backup/\n' > "$G/.gitignore"; git -C "$G" init -q   # Garten complete (S1-S4): no PROJECT-INCOMPLETE
      (cd "$G" && "$FWD" --register --yes >/dev/null 2>&1)   # wrappers of the kernel skills in Garten and the vault root (V0.6, F18)
      HOOKS="$(hooks)"
      ask() {                                       # ask <dir> <prompt>
         (cd "$1" && PATH="$SB/bin:$PATH" claude -p "$2" --model "$MODEL" --settings "$HOOKS" \
            --setting-sources project --add-dir "$SB" \
            --allowedTools "Skill" "Read" "Glob" "Bash(git log *)" </dev/null 2>&1)   # the forwarder: PreToolUse
      }
      echo "=> live skill test with model $MODEL in $SB"

      ID="$(cd "$G" && "$SB/bin/aios" --context --id | sed 's/^id=\([^ ]*\).*/\1/')"
      A="$(ask "$G" "/aios-context")"
      check "S1 /aios-context: loaded and listed" "$A" "$ID" "Garten"

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
            --allowedTools "Skill" "Bash($FWD *)" 2>&1)"
      [ -f "$G/.claude/skills/giesskanne/SKILL.md" ] && R4="registered" || R4="not registered: $A"
      check "S4 /aios-register: blueprint registered" "$R4" "registered"

      A="$(cd "$G" && PATH="$SB/bin:$PATH" claude -p "/aios-fetch skill-memo --to $V Ich bestätige schon jetzt ausdrücklich: ja, holen." \
            --model "$MODEL" --settings '{"hooks":{}}' --setting-sources project --add-dir "$SB" \
            --allowedTools "Skill" "Bash($FWD *)" 2>&1)"
      [ -f "$V/@/@!Package/skill-memo/.aios-deploy" ] && grep -q '^  skill-memo: ' "$V/.aios/config.yaml" && R5="fetched" || R5="not fetched: $A"
      check "S5 /aios-fetch skill-memo into the root project" "$R5" "fetched"

      A="$(ask "$G/GN-Neu" "/aios-integrity")"           # GN-Neu is complete since S2 (Garten would get PROJECT-INCOMPLETE first)
      check "S6 /aios-integrity: report with result line (English report, possibly summarized in German)" "$A" "nteg"

      A="$(ask "$G" "/aios-gui")"
      check "S7 /aios-gui: menu with the tiles of AIOS" "$A" "Integrität prüfen" "Projektstatus"

      (cd "$G" && PATH="$SB/bin:$PATH" aios --fetch app-taschenrechner --yes >/dev/null 2>&1)   # no tokens
      A="$(cd "$G" && PATH="$SB/bin:$PATH" claude -p '/taschenrechner Speichere die Funktionstaste A mit den Tasten ["ENTER", "×"] und dem Titel "Quadrat". Ich bestätige schon jetzt ausdrücklich: ja, so speichern.' \
            --model "$MODEL" --settings '{"hooks":{}}' --setting-sources project --add-dir "$SB" \
            --allowedTools "Skill" "Read" "Write" "Edit" "Glob" "Bash(mkdir *)" "Bash($FWD *)" 2>&1)"
      F="$G/@Data/app-taschenrechner/funktionstasten.yaml"
      [ -f "$F" ] && grep -q "ENTER" "$F" && grep -q "Quadrat" "$F" && R8="saved" || R8="not saved: $A"
      check "S8 /taschenrechner: function key A saved in @Data/" "$R8" "saved"

      A="$(cd "$G" && PATH="$SB/bin:$PATH" claude -p "Führe \`aios --gui --apps\` aus und nenne mir die Apps dieses Projekts mit dem Skill ihrer Oberfläche." \
            --model "$MODEL" --settings '{"hooks":{}}' --setting-sources project --add-dir "$SB" \
            --allowedTools "Bash(aios --gui *)" 2>&1)"
      check "S9 tile Apps: aios --gui --apps names the calculator" "$A" "taschenrechner-gui"

      finish
   fi

#===============================================================================
# cannot deal with anything else ...
#===============================================================================

   "$0" -?
   exit 1
