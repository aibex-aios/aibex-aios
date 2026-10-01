# t06-hooks.sh: step 6 of the plan (memo 18) - aios-context --session/--advise (spec 02, Hooks)

#===============================================================================
# setup: activated vault, project, not initialized folder, legacy vault, fake ai-brain
#===============================================================================

   mkdir -p "$SANDBOX/fake" "$SANDBOX/outside" "$HOME/.aios"
   export PATH="$SANDBOX/fake:/usr/bin:/bin:/usr/sbin:/sbin"
   D="$SANDBOX/work/§Demo"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   mk "$D/.aios/config.yaml"      $'aios: 0.1.0\n'
   mk "$D/@/@Rule/stil.md"        $'# Stil\nschreib klar\n'
   mk "$D/Garten/@/garten.md"     $'# Garten\nApfel\n'
   mkdir -p "$D/Garten/Neu"
   mk "$SANDBOX/work/§Alt/@/a.md" $'# A\n'
   printf '#!/bin/bash\necho "ai-brain $* stdin=$(cat)"\n' > "$SANDBOX/fake/ai-brain"; chmod +x "$SANDBOX/fake/ai-brain"

   AC="$SRC/bin/aios-context"
   json() { printf '{"session_id":"t","hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$1"; }
   HOOK() { json "$2" | (cd "$SANDBOX" && "$AC" "$1"); }          # hook call, cwd only from JSON

#===============================================================================
# outside a vault and legacy mode
#===============================================================================

   assert_eq "$(HOOK --session "$SANDBOX/outside")" "" "outside a vault: session prints nothing"
   assert_eq "$(HOOK --advise "$SANDBOX/outside")" "" "outside a vault: advise prints nothing"
   OUT="$(HOOK --session "$SANDBOX/work/§Alt")"
   assert_eq "$OUT" "ai-brain --session stdin=$(json "$SANDBOX/work/§Alt")" "legacy: ai-brain gets the same hook JSON"
   assert_contains "$(HOOK --advise "$SANDBOX/work/§Alt")" "ai-brain --advise stdin=" "legacy: advise"

#===============================================================================
# --session: small master context inline, cwd taken from the hook JSON
#===============================================================================

   OUT="$(HOOK --session "$D/Garten"; echo x)"; OUT="${OUT%x}"
   CTX="$(cd "$D/Garten" && "$AC" --context; echo x)"; CTX="${CTX%x}"
   assert_eq "$OUT" "AIOS-CONTEXT (loaded automatically by SessionStart hook):
$CTX" "session: inline = header + --context"
   case "$OUT" in *PROJECT-UNINITIALIZED*|*AIOS-WARNING*) fail "session: no extra lines for an initialized project" ;; *) ok ;; esac
   [ ! -e "$HOME/.aios/cache" ] && ok || fail "session inline: no part files written"
   ID="$(cd "$D/Garten" && "$AC" --id | sed 's/^id=\([^ ]*\).*/\1/')"
   assert_eq "$("$AC" --id "$D/Garten" | sed 's/^id=\([^ ]*\).*/\1/')" "$ID" "--id <path> = --id in the directory"
   assert_contains "$OUT" "<aios-context id=\"$ID\"" "session: id of the hook cwd"

#===============================================================================
# --session: not initialized project
#===============================================================================

   OUT="$(HOOK --session "$D/Garten/Neu")"
   assert_eq "$(printf '%s\n' "$OUT" | head -3)" "PROJECT-UNINITIALIZED: $D/Garten/Neu has no local masterspace (@/). Before your first
answer, ask the user: (1) initialize this folder as a project (/aios-init),
(2) continue in the project $D/Garten. Give no other answer until the user decides." "uninitialized: message first, X = project above"
   assert_contains "$OUT" "src=\"$D/Garten/@/garten.md\"" "uninitialized: master context up to X"

#===============================================================================
# --session: master context larger than inline_limit -> part files
#===============================================================================

   printf 'inline_limit: 100\n' > "$HOME/.aios/config.yaml"
   OUT="$(HOOK --session "$D/Garten")"
   SIZE="$(printf '%s' "$CTX" | python3 -c 'import sys; print(len(sys.stdin.read()))')"   # characters, not bytes
   assert_contains "$OUT" "AIOS-CONTEXT-MANDATORY: the master context of this project is too large" "mandatory: header"
   assert_contains "$OUT" "($SIZE > 100 characters)" "mandatory: size and limit"
   assert_contains "$OUT" "\"Master-Kontext geladen (id $ID)\"" "mandatory: names the id"
   assert_contains "$OUT" "AIOS-CONTEXT-LOAD id=$ID files=2 parts=1" "mandatory: part file list"
   assert_file "$HOME/.aios/cache/$ID/part-1.md"
   case "$OUT" in *"<aios-file"*) fail "mandatory: no inline content" ;; *) ok ;; esac
   rm "$HOME/.aios/config.yaml"

#===============================================================================
# --advise: check line with the expected id and an explicit path
#===============================================================================

   OUT="$(HOOK --advise "$D/Garten")"
   assert_eq "$(printf '%s\n' "$OUT" | head -1)" "AIOS-CONTEXT-CHECK: expected id=$ID (files=2, cwd=$D/Garten)." "advise: first line"
   assert_contains "$OUT" "<aios-context id=\"$ID\"" "advise: start marker"
   assert_contains "$OUT" "</aios-context id=\"$ID\">" "advise: end marker"
   assert_contains "$OUT" "run \`aios-context --load \"$D/Garten\"\` via Bash" "advise: load with explicit path"
   assert_eq "$(cd "$D/Garten" && "$AC" --advise </dev/null | head -1)" "AIOS-CONTEXT-CHECK: expected id=$ID (files=2, cwd=$D/Garten)." "advise without JSON: cwd of the process"

#===============================================================================
# warnings and failures never break the session
#===============================================================================

   printf 'aios: 0.1.0\nfoo: 1\n' > "$D/.aios/config.yaml"
   assert_contains "$(HOOK --session "$D/Garten")" "AIOS-WARNING: $D/.aios/config.yaml: unknown key foo ignored" "session: config warning"
   chmod 000 "$D/Garten/@/garten.md"
   OUT="$(HOOK --session "$D/Garten")"; RC=$?
   chmod 644 "$D/Garten/@/garten.md"
   assert_eq "$RC" "0" "failure: exit 0"
   assert_contains "$OUT" "AIOS-WARNING: aios-context --session failed:" "failure: one warning line"
