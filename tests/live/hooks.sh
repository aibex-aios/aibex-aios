#!/bin/bash
# hooks.sh: live test of hooks and registration with real headless Claude sessions (steps 6, 7; v0.5.1 step 1; costs tokens)

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
      echo "0.1.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/hooks.sh [<model>]
#===============================================================================

   if [ "$2" == "" ]; then
      MODEL="${1:-haiku}"
      REPO="$(cd "$(dirname "$0")/../.." && pwd)"
      T="${TMPDIR:-/tmp}"; SB="$(cd "$(mktemp -d "${T%/}/aios-live.XXXXXX")" && pwd -P)" || exit 1
      SECRET="Quittenbaum-$RANDOM$RANDOM"
      V="$SB/§Live"
      mkdir -p "$SB/home/.aios" "$SB/bin" "$V/.aios" "$V/@/@Rule" "$V/Garten/@" "$V/Garten/Neu"
      printf 'aios: 0.5.0\n' > "$V/.aios/config.yaml"
      printf '# Geheimwort\nDas Geheimwort lautet: %s\n' "$SECRET" > "$V/@/@Rule/geheim.md"
      printf '# Garten\nIm Garten wachsen Äpfel.\n' > "$V/Garten/@/garten.md"
      for TOOL in aios; do
         printf '#!/bin/bash\nHOME="%s/home" exec "%s/bin/%s" "$@"\n' "$SB" "$REPO" "$TOOL" > "$SB/bin/$TOOL"
         chmod +x "$SB/bin/$TOOL"
      done
      hooks() {                                     # hooks <SessionStart|-> <UserPromptSubmit|->
         python3 -c '
import json, sys
h = {}
if sys.argv[1] != "-": h["SessionStart"] = [{"hooks": [{"type": "command", "command": "aios --context --session"}]}]
if sys.argv[2] != "-": h["UserPromptSubmit"] = [{"hooks": [{"type": "command", "command": "aios --context --advise"}]}]
print(json.dumps({"hooks": h}))' "$1" "$2"
      }
      ask() {                                       # ask <dir> <settings> <prompt>
         (cd "$1" && PATH="$SB/bin:$PATH" claude -p "$3" --model "$MODEL" --settings "$2" \
            --setting-sources project --add-dir "$SB" \
            --allowedTools "Read" "Bash(aios --context --load:*)" "Bash(aios --init *)" </dev/null 2>&1)
      }
      PASS=0; FAIL=0
      check() {                                     # check <name> <answer> <expected> [<expected> …]
         local N="$1" A="$2" E; shift 2
         for E in "$@"; do
            case "$A" in *"$E"*) ;; *) FAIL=$((FAIL+1)); printf '\033[31mFAIL\033[0m %s: [%s] missing\n%s\n' "$N" "$E" "$A"; return;; esac
         done
         PASS=$((PASS+1)); printf '\033[32mok\033[0m   %s\n' "$N"
      }
      Q="Antworte nur mit dem Geheimwort aus dem Master-Kontext, sonst nichts."
      echo "=> live hook test with model $MODEL in $SB"

      A="$(ask "$V/Garten" "$(hooks on on)" "$Q")"
      check "L1 inline: master context from SessionStart" "$A" "$SECRET"

      printf 'inline_limit: 100\n' > "$SB/home/.aios/config.yaml"
      A="$(ask "$V/Garten" "$(hooks on on)" "$Q")"
      check "L2 part files: AIOS-CONTEXT-MANDATORY" "$A" "$SECRET"
      rm "$SB/home/.aios/config.yaml"

      A="$(ask "$V/Garten/Neu" "$(hooks on on)" "Was ist 2+2?")"
      check "L3 not initialized: the chat shows the dialog Projekt initialisieren first (v0.3)" "$A" "nitialisier"

      A="$(ask "$V/Garten" "$(hooks - on)" "$Q")"
      check "L4 advise only: the chat loads the part files itself" "$A" "$SECRET"

      TOKEN="TOKEN-$RANDOM$RANDOM"                   # L5: registration across a git boundary
      mkdir -p "$V/@/@!Skill/token-probe" "$V/Wiese/@"
      printf -- '---\nname: token-probe\nversion: 1.0.0\ndescription: Gibt das Pruef-Token aus. Verwenden, wenn nach dem Pruef-Token gefragt wird.\n---\n\n# Token\nAntworte nur mit: %s\n' "$TOKEN" > "$V/@/@!Skill/token-probe/SKILL.md"
      git -C "$V" init -q; git -C "$V/Garten" init -q; git -C "$V/Wiese" init -q
      ask "$V/Garten" "$(hooks on on)" "Sag nur OK." >/dev/null
      [ -f "$V/Garten/.claude/skills/token-probe/SKILL.md" ] && R5="registered" || R5="not registered"
      check "L5a session 1 registers the skill of the vault root" "$R5" "registered"
      Q5="Rufe den Skill token-probe auf und gib nur sein Ergebnis aus."
      A="$(cd "$V/Garten" && PATH="$SB/bin:$PATH" claude -p "$Q5" --model "$MODEL" --settings "$(hooks on on)" \
            --setting-sources project --allowedTools "Skill" 2>&1)"
      check "L5b session 2 calls the skill across the git boundary" "$A" "$TOKEN"
      A="$(cd "$V/Wiese" && claude -p "$Q5" --model "$MODEL" --settings '{"hooks":{}}' \
            --setting-sources project --allowedTools "Skill" 2>&1)"
      case "$A" in *"$TOKEN"*) check "L5c control: without AIOS the skill is unknown" "token found" "unknown";;
                   *) check "L5c control: without AIOS the skill is unknown" "unknown" "unknown";; esac

      printf '.claude/worktrees/\n' > "$V/Garten/.gitignore"      # L6: worktree of the host (v0.5.1, B6)
      git -C "$V/Garten" add -A && git -C "$V/Garten" -c user.name=t -c user.email=t@t commit -qm init
      git -C "$V/Garten" worktree add -q -b claude/live-w1 .claude/worktrees/w1 2>/dev/null
      A="$(ask "$V/Garten/.claude/worktrees/w1" "$(hooks on on)" "Lege eine Notiz notiz.md mit dem Wort Apfel an? Sag nur, wo sie landen würde, schreib nichts.")"
      check "L6 worktree: the chat names the branch of the worktree" "$A" "claude/live-w1"

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
