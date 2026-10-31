# t22-permit.sh: v0.6 step 5 - aios --context --permit, PreToolUse hook for Bash and Skill (spec 02, Freigabe; V0.6, memos 20-23, 47, 65)

   case "$SANDBOX" in */aios-test.*) ;; *) echo "*** run via tests/run, never directly (it would touch the real HOME)" >&2; exit 1;; esac

#===============================================================================
# setup: A/W, vault with binding below 0.6, vault without binding, settings of the user
#===============================================================================

   export AIOS_MANAGED_SETTINGS="$SANDBOX/managed-settings.json"   # never the real managed settings
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   D="$SANDBOX/work/§Demo"; mk "$D/.aios/config.yaml" $'aios: 0.6.0\n'; mk "$D/@/a.md" $'# A\n'
   mk "$D/P/@/p.md" $'# P\n'
   O="$SANDBOX/work/§Alt"; mk "$O/.aios/config.yaml" $'aios: 0.5.1\n'; mk "$O/@/a.md" $'# A\n'
   N="$SANDBOX/work/§Ohne"; mk "$N/@/a.md" $'# A\n'
   F="$HOME/.aios/bin/aios"
   PJ() { python3 -c 'import json,sys; print(json.dumps({"session_id": "t", "hook_event_name": "PreToolUse", "tool_name": sys.argv[3], "tool_input": {"command": sys.argv[2]}, "cwd": sys.argv[1]}))' "$1" "$2" "${3:-Bash}"; }
   PERMIT() { PJ "$@" | (cd "$SANDBOX" && "$SRC/bin/aios" --context --permit); }
   ALLOW='{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "AIBOS: command of AIOS in an AIBOS workspace"}}'

#===============================================================================
# E1-E3: A/W, forwarder with absolute path, a single command
#===============================================================================

   assert_eq "$(PERMIT "$D/P" "$F --skill aios-status")" "$ALLOW" "A/W: forwarder call allowed"
   assert_eq "$(PERMIT "$D/P" "  $F --version")" "$ALLOW" "A/W: leading blanks"
   assert_eq "$(PERMIT "$D/P" "$F")" "$ALLOW" "A/W: forwarder without arguments"
   assert_eq "$(PERMIT "$D/P" "$AIOS_PREFIX/bin/aios --version")" "$ALLOW" "A/W: forwarder under /opt/aios"
   assert_eq "$(PERMIT "$D/P" "\"$F\" --context --load \"$D/P\"")" "$ALLOW" "E2: forwarder in double quotes (V0.6, B5)"
   assert_eq "$(PERMIT "$D/P" "'$F' --version")" "$ALLOW" "E2: forwarder in single quotes"
   assert_eq "$(PERMIT "$D/P" "\"$F-x\" --version")" "" "E2: quotes around another program"
   assert_eq "$(PERMIT "$D/P" "\"$F --version\"")" "" "E2: quotes around more than the path"
   assert_eq "$(PERMIT "$D/P" "cd \"$D/P\" && $F --version")" "" "E3: cd before the forwarder (V0.6, B6)"
   assert_eq "$(PERMIT "$D/P" "aios --version")" "" "E2: aios from the PATH is not allowed"
   assert_eq "$(PERMIT "$D/P" "$F-x --version")" "" "E2: another program with the same prefix"
   assert_eq "$(PERMIT "$D/P" "$HOME/.aios/bin/yt-dlp --version")" "" "E2: a workhorse is not allowed"
   for C in "$F --version; rm x" "$F --version && echo x" "$F --version || echo x" "$F --version | cat" \
            "$F --version & echo x" "$F --version > x" "$F --version < x" "$F \$(echo x)" "$F \`echo x\`" \
            "$F --version
echo x"; do
      assert_eq "$(PERMIT "$D/P" "$C")" "" "E3: no single command: $(printf '%s' "$C" | tr '\n' ' ')"
   done
   assert_eq "$(PERMIT "$O" "$F --version")" "" "E1: binding below 0.6"
   assert_eq "$(PERMIT "$N" "$F --version")" "" "E1: vault without binding"
   assert_eq "$(PERMIT "$SANDBOX" "$F --version")" "" "E1: outside a vault"
   assert_eq "$(PERMIT "$D/P" "$F --version" Read)" "" "another tool: nothing"

#===============================================================================
# E4: deny and ask rules of user, project and managed settings
#===============================================================================

   S="$AIOS_CLAUDE_DIR/settings.json"; mkdir -p "$AIOS_CLAUDE_DIR"
   for R in "Bash" "Bash($F --version)" "Bash($F:*)" "Bash($F *)" "Bash(*aios --vers*)" "Bash($F --[v]ersion)"; do
      printf '{"permissions": {"deny": ["%s"]}}' "$R" > "$S"
      assert_eq "$(PERMIT "$D/P" "$F --version")" "" "E4: deny $R"
   done
   printf '{"permissions": {"ask": ["Bash(%s --version)"]}}' "$F" > "$S"
   assert_eq "$(PERMIT "$D/P" "$F --version")" "" "E4: ask rule"
   assert_eq "$(PERMIT "$D/P" "$F --skill aios-init")" "$ALLOW" "E4: rule for another command"
   printf '{"permissions": {"deny": ["Read(./x)", "Bash(git push:*)"], "allow": ["Bash"]}}' > "$S"
   assert_eq "$(PERMIT "$D/P" "$F --version")" "$ALLOW" "E4: rules for other tools and commands do not count"
   rm "$S"
   mk "$D/P/.claude/settings.json" "{\"permissions\": {\"deny\": [\"Bash($F --version)\"]}}"
   assert_eq "$(PERMIT "$D/P" "$F --version")" "" "E4: deny of the project"
   rm "$D/P/.claude/settings.json"
   mk "$D/P/.claude/settings.local.json" "{\"permissions\": {\"ask\": [\"Bash($F:*)\"]}}"
   assert_eq "$(PERMIT "$D/P" "$F --version")" "" "E4: ask of the local project settings"
   rm "$D/P/.claude/settings.local.json"
   mk "$AIOS_MANAGED_SETTINGS" '{"permissions": {"deny": ["Bash"]}}'
   assert_eq "$(PERMIT "$D/P" "$F --version")" "" "E4: managed settings"
   rm "$AIOS_MANAGED_SETTINGS"

#===============================================================================
# Skill tool: registered wrappers of the kernel in an A/W (S1-S3; V0.6, memo 65, B10)
#===============================================================================

   SJ() { python3 -c 'import json,sys; print(json.dumps({"session_id": "t", "hook_event_name": "PreToolUse", "tool_name": "Skill", "tool_input": {"skill": sys.argv[2]}, "cwd": sys.argv[1]}))' "$1" "$2"; }
   SKILL() { SJ "$@" | (cd "$SANDBOX" && "$SRC/bin/aios" --context --permit); }
   SALLOW='{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "AIBOS: kernel skill in an AIBOS workspace"}}'
   E="$SANDBOX/work/§Leer"; mk "$E/.aios/config.yaml" $'aios: 0.6.0\n'; mk "$E/@/a.md" $'# A\n'
   (cd "$D/P" && "$SRC/bin/aios" --register --yes >/dev/null 2>&1)
   assert_eq "$(SKILL "$D/P" aios-status)" "$SALLOW" "Skill: registered kernel skill in the A/W"
   assert_eq "$(SKILL "$D/P" gui)" "$SALLOW" "Skill: the alias gui"
   assert_eq "$(SKILL "$D" aios-init)" "$SALLOW" "Skill: at the vault root"
   assert_eq "$(SKILL "$D/P" memo)" "" "S2: not a kernel skill"
   assert_eq "$(SKILL "$E" aios-status)" "" "S2: kernel skill not registered"
   assert_eq "$(SKILL "$O" aios-status)" "" "S1: binding below 0.6"
   assert_eq "$(SKILL "$N" aios-status)" "" "S1: vault without binding"
   for RULE in '"Skill"' '"Skill(aios-status)"' '"Skill(aios-*)"' '"Skill(aios:*)"'; do
      printf '{"permissions":{"ask":[%s]}}' "$RULE" > "$S"
      assert_eq "$(SKILL "$D/P" aios-status)" "" "S3: rule $RULE"
   done
   printf '{"permissions":{"deny":["Skill(memo)","Bash(git *)"]}}' > "$S"
   assert_eq "$(SKILL "$D/P" aios-status)" "$SALLOW" "S3: rules for other skills and tools do not hit"
   rm "$S"

#===============================================================================
# errors never allow, they go to the log
#===============================================================================

   printf '{ broken' > "$S"
   assert_eq "$(PERMIT "$D/P" "$F --version")" "" "unreadable settings: nothing allowed"
   assert_contains "$(cat "$HOME/.aios/log/context.log")" "--permit cwd=$D/P aios --context --permit failed:" "unreadable settings: line in the log"
   rm "$S"
   assert_eq "$(printf 'kein json' | (cd "$SANDBOX" && "$SRC/bin/aios" --context --permit); echo "rc=$?")" "rc=0" "broken hook JSON: no output, exit 0"

#===============================================================================
# forwarder: --permit below 0.6 and in a legacy vault quiet (V0.6, memo 47)
#===============================================================================

   mkdir -p "$HOME/bin" "$AIOS_PREFIX/v0.5.1/bin"
   cp "$SRC/templates/forwarder" "$HOME/bin/aios"; chmod +x "$HOME/bin/aios"
   printf '#!/bin/bash\necho "old kernel $*" >&2; exit 1\n' > "$AIOS_PREFIX/v0.5.1/bin/aios"; chmod +x "$AIOS_PREFIX/v0.5.1/bin/aios"
   echo "0.5.1" > "$AIOS_PREFIX/v0.5.1/VERSION"
   echo "v0.5.1: $AIOS_PREFIX/v0.5.1" > "$AIOS_PREFIX/installations.yaml"
   assert_eq "$(PJ "$O" "$F --version" | (cd "$O" && "$HOME/bin/aios" --context --permit 2>&1); echo "rc=$?")" "rc=0" "forwarder: binding below 0.6, --permit quiet"
   mk "$N/.aios/config.yaml" $'legacy: ai-brain\n'
   assert_eq "$(PJ "$N" "$F --version" | (cd "$N" && "$HOME/bin/aios" --context --permit 2>&1); echo "rc=$?")" "rc=0" "forwarder: legacy vault, --permit quiet"
   unset AIOS_MANAGED_SETTINGS
