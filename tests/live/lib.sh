#!/bin/bash
# lib.sh: sandbox of the live tests with headless Claude sessions (V0.6, step 11); sourced by tests/live/*.sh
# HOME of AIOS in the sandbox with the real forwarder ~/.aios/bin/aios and v0.6.0 = this repo; Claude keeps the
# real HOME (login), the forwarder sets HOME for AIOS; --setting-sources project keeps the user's settings and
# personal skills out of the sessions

   REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
   T="${TMPDIR:-/tmp}"; SB="$(cd "$(mktemp -d "${T%/}/aios-live.XXXXXX")" && pwd -P)" || exit 1
   FWD="$SB/home/.aios/bin/aios"                    # absolute path in hooks, wrappers, master context (spec 02)
   mkdir -p "$SB/home/.aios/bin" "$SB/bin" "$SB/forwarder"
   cp "$REPO/templates/forwarder" "$SB/forwarder/aios"; chmod +x "$SB/forwarder/aios"
   printf '#!/bin/bash\nHOME="%s/home" exec "%s/forwarder/aios" "$@"\n' "$SB" "$SB" > "$FWD"; chmod +x "$FWD"
   printf 'v0.6.0: %s\n' "$REPO" > "$SB/home/.aios/installations.yaml"
   ln -s "$FWD" "$SB/bin/aios"                      # typed aios (PATH="$SB/bin:$PATH")

#===============================================================================
# hooks: settings with the hooks of AIBOS
#===============================================================================

   hooks() {                                        # hooks [session] [advise] [permit]: default all three
      python3 -c '
import json, sys
fwd, want = sys.argv[1], sys.argv[2:] or ["session", "advise", "permit"]
h = {}
if "session" in want: h["SessionStart"] = [{"hooks": [{"type": "command", "command": fwd + " --context --session"}]}]
if "advise" in want: h["UserPromptSubmit"] = [{"hooks": [{"type": "command", "command": fwd + " --context --advise"}]}]
if "permit" in want: h["PreToolUse"] = [{"matcher": "Bash", "hooks": [{"type": "command", "command": fwd + " --context --permit"}]}]
print(json.dumps({"hooks": h}))' "$FWD" "$@"
   }

#===============================================================================
# assertions on the answers
#===============================================================================

   PASS=0; FAIL=0
   check() {                                        # check <name> <answer> <expected> [<expected> …]
      local N="$1" ANS="$2" E; shift 2
      for E in "$@"; do
         case "$ANS" in *"$E"*) ;; *) FAIL=$((FAIL+1)); printf '\033[31mFAIL\033[0m %s: [%s] missing\n%s\n' "$N" "$E" "$ANS"; return;; esac
      done
      PASS=$((PASS+1)); printf '\033[32mok\033[0m   %s\n' "$N"
   }
   refuse() {                                       # refuse <name> <answer> <forbidden>
      case "$2" in *"$3"*) FAIL=$((FAIL+1)); printf '\033[31mFAIL\033[0m %s: [%s] must not appear\n%s\n' "$1" "$3" "$2";;
                   *) PASS=$((PASS+1)); printf '\033[32mok\033[0m   %s\n' "$1";; esac
   }
   finish() {                                       # summary, sandbox removed, exit code
      echo "=> $PASS passed, $FAIL failed"
      chmod -R u+w "$SB" 2>/dev/null; rm -rf "$SB"
      [ "$FAIL" == "0" ] || exit 1
      exit 0
   }
