#!/bin/bash
# hooks.sh: live test of hooks and registration with real headless Claude sessions (steps 6, 7; v0.5.1 step 1;
# V0.6 step 11: three hooks with the absolute forwarder, the PreToolUse hook releases its calls; costs tokens)

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/hooks.sh [<model>]   # headless sessions L1-L6, default model haiku'
      echo '          tests/live/hooks.sh --version   # print version'
      echo '   not part of tests/run: needs a logged-in claude CLI and uses tokens'
      echo '   see also: tests/run, aios --context'
      exit 1
   fi

#===============================================================================
# print version: tests/live/hooks.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.2.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/hooks.sh [<model>]
#===============================================================================

   if [ "$2" == "" ]; then
      MODEL="${1:-haiku}"
      . "$(dirname "$0")/lib.sh"
      SECRET="Quittenbaum-$RANDOM$RANDOM"
      V="$SB/§Live"
      mkdir -p "$SB/home/.aios" "$SB/bin" "$V/.aios" "$V/@/@Rule" "$V/Garten/@" "$V/Garten/Neu"
      printf 'aios: 0.6.0\n' > "$V/.aios/config.yaml"
      printf '# Geheimwort\nDas Geheimwort lautet: %s\n' "$SECRET" > "$V/@/@Rule/geheim.md"
      printf '# Garten\nIm Garten wachsen Äpfel.\n' > "$V/Garten/@/garten.md"
      ask() {                                       # ask <dir> <settings> <prompt>: calls of the forwarder only via PreToolUse
         (cd "$1" && PATH="$SB/bin:$PATH" claude -p "$3" --model "$MODEL" --settings "$2" \
            --setting-sources project --add-dir "$SB" --allowedTools "Read" </dev/null 2>&1)
      }
      Q="Antworte nur mit dem Geheimwort aus dem Master-Kontext, sonst nichts."
      echo "=> live hook test with model $MODEL in $SB"

      A="$(ask "$V/Garten" "$(hooks)" "$Q")"
      check "L1 inline: master context from SessionStart" "$A" "$SECRET"

      printf 'inline_limit: 100\n' > "$SB/home/.aios/config.yaml"
      A="$(ask "$V/Garten" "$(hooks)" "$Q")"
      check "L2 part files: AIOS-CONTEXT-MANDATORY" "$A" "$SECRET"
      rm "$SB/home/.aios/config.yaml"

      A="$(ask "$V/Garten/Neu" "$(hooks)" "Was ist 2+2?")"
      check "L3 not initialized: the chat shows the dialog Projekt initialisieren first (v0.3)" "$A" "nitialisier"

      A="$(ask "$V/Garten" "$(hooks advise permit)" "$Q")"
      check "L4 advise only: the chat loads the part files itself" "$A" "$SECRET"

      TOKEN="TOKEN-$RANDOM$RANDOM"                   # L5: registration across a git boundary
      mkdir -p "$V/@/@!Skill/token-probe" "$V/Wiese/@"
      printf -- '---\nname: token-probe\nversion: 1.0.0\ndescription: Gibt das Pruef-Token aus. Verwenden, wenn nach dem Pruef-Token gefragt wird.\n---\n\n# Token\nAntworte nur mit: %s\n' "$TOKEN" > "$V/@/@!Skill/token-probe/SKILL.md"
      git -C "$V" init -q; git -C "$V/Garten" init -q; git -C "$V/Wiese" init -q
      ask "$V/Garten" "$(hooks)" "Sag nur OK." >/dev/null
      [ -f "$V/Garten/.claude/skills/token-probe/SKILL.md" ] && R5="registered" || R5="not registered"
      check "L5a session 1 registers the skill of the vault root" "$R5" "registered"
      [ -f "$V/Garten/.claude/skills/aios-status/SKILL.md" ] && grep -q "Bash($FWD --skill aios-status)" "$V/Garten/.claude/skills/aios-status/SKILL.md" \
         && R5="kernel wrapper" || R5="no kernel wrapper"
      check "L5a session 1 registers the kernel wrappers with the absolute forwarder (V0.6, F18)" "$R5" "kernel wrapper"
      Q5="Rufe den Skill token-probe auf und gib nur sein Ergebnis aus."
      A="$(cd "$V/Garten" && PATH="$SB/bin:$PATH" claude -p "$Q5" --model "$MODEL" --settings "$(hooks)" \
            --setting-sources project --allowedTools "Skill" 2>&1)"
      check "L5b session 2 calls the skill across the git boundary" "$A" "$TOKEN"
      A="$(cd "$V/Wiese" && claude -p "$Q5" --model "$MODEL" --settings '{"hooks":{}}' \
            --setting-sources project --allowedTools "Skill" 2>&1)"
      case "$A" in *"$TOKEN"*) check "L5c control: without AIOS the skill is unknown" "token found" "unknown";;
                   *) check "L5c control: without AIOS the skill is unknown" "unknown" "unknown";; esac

      printf '.claude/worktrees/\n' > "$V/Garten/.gitignore"      # L6: worktree of the host (v0.5.1, B6)
      git -C "$V/Garten" add -A && git -C "$V/Garten" -c user.name=t -c user.email=t@t commit -qm init
      git -C "$V/Garten" worktree add -q -b claude/live-w1 .claude/worktrees/w1 2>/dev/null
      A="$(ask "$V/Garten/.claude/worktrees/w1" "$(hooks)" "Lege eine Notiz notiz.md mit dem Wort Apfel an? Sag nur, wo sie landen würde, schreib nichts.")"
      check "L6 worktree: the chat names the branch of the worktree" "$A" "claude/live-w1"

      finish
   fi

#===============================================================================
# cannot deal with anything else ...
#===============================================================================

   "$0" -?
   exit 1
