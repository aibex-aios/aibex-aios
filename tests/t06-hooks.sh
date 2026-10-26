# t06-hooks.sh: step 6 of the plan (memo 18) - aios --context --session/--advise (spec 02, Hooks); v0.3 steps 3, 6

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
   mk "$D/Garten/.gitignore"      $'.DS_Store\n.claude/skills/\n.claude/worktrees/\n.agents/\n.aios/registry\n.aios/backup/\n'
   git -C "$D/Garten" init -q                      # Garten is a complete project (spec 05, S1-S4)
   mk "$D/Wiese/@/wiese.md"       $'# Wiese\n'
   mk "$SANDBOX/work/§Alt/@/a.md" $'# A\n'
   printf '#!/bin/bash\necho "ai-brain $* stdin=$(cat)"\n' > "$SANDBOX/fake/ai-brain"; chmod +x "$SANDBOX/fake/ai-brain"

   AC() { "$SRC/bin/aios" --context "$@"; }
   json() { printf '{"session_id":"t","hook_event_name":"SessionStart","source":"%s","cwd":"%s"}' "${SRCE:-startup}" "$1"; }
   HOOK() { json "$2" | (cd "$SANDBOX" && AC "$1"); }          # hook call, cwd only from JSON

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
   CTX="$(cd "$D/Garten" && AC --context; echo x)"; CTX="${CTX%x}"
   assert_eq "$OUT" "AIOS-CONTEXT (loaded automatically by SessionStart hook):
$CTX" "session: inline = header + --context"
   case "$OUT" in *PROJECT-UNINITIALIZED*|*AIOS-WARNING*) fail "session: no extra lines for an initialized project" ;; *) ok ;; esac
   [ ! -e "$HOME/.aios/cache" ] && ok || fail "session inline: no part files written"
   ID="$(cd "$D/Garten" && AC --id | sed 's/^id=\([^ ]*\).*/\1/')"
   assert_eq "$(AC --id "$D/Garten" | sed 's/^id=\([^ ]*\).*/\1/')" "$ID" "--id <path> = --id in the directory"
   assert_contains "$OUT" "<aios-context id=\"$ID\"" "session: id of the hook cwd"

#===============================================================================
# --session: not initialized project
#===============================================================================

   OUT="$(HOOK --session "$D/Garten/Neu")"
   assert_eq "$(printf '%s\n' "$OUT" | head -7)" "PROJECT-UNINITIALIZED: $D/Garten/Neu has no local masterspace (@/). Before your first
answer, call the skill /aios-init (Skill tool) and follow it: it runs
\`aios --init \"$D/Garten/Neu\" --plan\`, shows the dialog \"Projekt initialisieren\"
(title, assistant, initialize or continue in the project $D/Garten) and, after the user's choice,
runs aios --init with --yes. Without that skill, do the same yourself: run the plan,
ask these questions, then run with --yes. Never answer a question of aios yourself.
Give no other answer until the user decides." "uninitialized: skill /aios-init, dialog, X = project above, --yes (A2, A3)"
   assert_contains "$OUT" "src=\"$D/Garten/@/garten.md\"" "uninitialized: master context up to X"
   case "$OUT" in *PROJECT-INCOMPLETE*) fail "uninitialized: no consistency check" ;; *) ok ;; esac

#===============================================================================
# --session: consistency check at startup only (spec 02, Unvollstaendiges Projekt)
#===============================================================================

   OUT="$(HOOK --session "$D/Wiese")"
   assert_eq "$(printf '%s\n' "$OUT" | head -1)" "PROJECT-INCOMPLETE: $D/Wiese is an AIOS project but lacks: own git repo, .gitignore lines: .DS_Store, .claude/skills/, .claude/worktrees/, .agents/, .aios/registry, .aios/backup/." "incomplete: gaps named"
   assert_contains "$OUT" "call the skill /aios-init
(Skill tool) for \"$D/Wiese\" and follow it (plan from --plan, after yes run with
--yes; never answer a question of aios yourself)." "incomplete: offer /aios-init (A2, A3)"
   assert_contains "$OUT" "src=\"$D/Wiese/@/wiese.md\"" "incomplete: master context follows"
   for S in resume clear compact; do
      case "$(SRCE=$S HOOK --session "$D/Wiese")" in *PROJECT-INCOMPLETE*) fail "incomplete: no check at $S" ;; *) ok ;; esac
   done
   case "$(json "$D/Wiese" >/dev/null; cd "$D/Wiese" && AC --session </dev/null)" in *PROJECT-INCOMPLETE*) ok ;; *) fail "incomplete: without JSON counts as startup" ;; esac

#===============================================================================
# v0.5.1 step 1: worktree of the host (spec 02, Arbeitskopie; V0.5, memos 71, 73: B6)
#===============================================================================

   git -C "$D/Garten" add -A && git -C "$D/Garten" commit -qm init
   git -C "$D/Garten" worktree add -q -b claude/w1 .claude/worktrees/w1 2>/dev/null
   W="$D/Garten/.claude/worktrees/w1"
   OUT="$(HOOK --session "$W")"
   assert_eq "$(printf '%s\n' "$OUT" | head -6)" "AIOS-WORKTREE: this session runs in a git worktree on branch claude/w1
 ($W), not in the chosen folder $D/Garten.
 Before your first work, tell the user in one sentence that results land on
 branch claude/w1 and not in the chosen folder. After writing work (files
 changed or committed), offer to merge the branch into $D/Garten
 instead of only reporting it as done." "worktree: branch, worktree, chosen folder, instruction"
   case "$OUT" in *PROJECT-INCOMPLETE*) fail "worktree: no consistency check" ;; *) ok ;; esac
   for S in resume compact; do
      assert_contains "$(SRCE=$S HOOK --session "$W")" "AIOS-WORKTREE: this session runs in a git worktree on branch claude/w1" "worktree: also at $S"
   done
   mkdir -p "$W/Neu"
   OUT="$(HOOK --session "$W/Neu")"
   assert_contains "$OUT" "not in the chosen folder $D/Garten/Neu." "worktree: chosen folder keeps the subfolder"
   case "$OUT" in AIOS-WORKTREE*PROJECT-UNINITIALIZED*) ok ;; *) fail "worktree: before PROJECT-UNINITIALIZED" ;; esac
   git -C "$W" checkout -q --detach
   assert_contains "$(HOOK --session "$W")" "on branch detached HEAD" "worktree: detached HEAD"
   assert_eq "$(git -C "$D/Garten" status --porcelain)" "" "worktree: ignored in the chosen folder (.gitignore template)"
   case "$(HOOK --session "$D/Garten")" in *AIOS-WORKTREE*) fail "main folder: no worktree line" ;; *) ok ;; esac
   case "$(HOOK --session "$D/Wiese")" in *AIOS-WORKTREE*) fail "no repo: no worktree line" ;; *) ok ;; esac
   OUT="$(HOOK --session "$W")"                  # B9: the worktree takes the place of Garten
   assert_contains "$OUT" "src=\"$W/@/garten.md\"" "B9: masterspace of the worktree"
   case "$OUT" in *"src=\"$D/Garten/@/garten.md\""*) fail "B9: not the masterspace of the chosen folder" ;; *) ok ;; esac
   assert_contains "$OUT" "src=\"$D/@/@Rule/stil.md\"" "B9: chain continues above the chosen folder"
   assert_contains "$(AC --list "$W")" "§Demo → w1" "B9: chain §Demo → w1"
   H="$SANDBOX/work/§Hirsch"                       # B9: worktree of the vault root
   mk "$H/.aios/config.yaml" $'aios: 0.1.0\n'
   mk "$H/@/hirsch.md" $'# Hirsch\n'
   mk "$H/.gitignore" $'.claude/worktrees/\n'
   git -C "$H" init -q && git -C "$H" add -A && git -C "$H" commit -qm init
   git -C "$H" worktree add -q -b claude/h1 .claude/worktrees/h1 2>/dev/null
   OUT="$(HOOK --session "$H/.claude/worktrees/h1")"
   assert_contains "$OUT" "not in the chosen folder $H." "B9 root: chosen folder = vault root"
   assert_contains "$OUT" "src=\"$H/.claude/worktrees/h1/@/hirsch.md\"" "B9 root: masterspace of the worktree"
   case "$OUT" in *"src=\"$H/@/hirsch.md\""*|*AIOS-WARNING*) fail "B9 root: loaded once, aios: allowed in the worktree" ;; *) ok ;; esac
   git -C "$D/Garten" worktree remove --force "$W"

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
   assert_contains "$OUT" "run \`aios --context --load \"$D/Garten\"\` via Bash" "advise: load with explicit path"
   assert_eq "$(cd "$D/Garten" && AC --advise </dev/null | head -1)" "AIOS-CONTEXT-CHECK: expected id=$ID (files=2, cwd=$D/Garten)." "advise without JSON: cwd of the process"

#===============================================================================
# warnings and failures never break the session
#===============================================================================

   printf 'aios: 0.1.0\nfoo: 1\n' > "$D/.aios/config.yaml"
   assert_contains "$(HOOK --session "$D/Garten")" "AIOS-WARNING: $D/.aios/config.yaml: unknown key foo ignored" "session: config warning"
   chmod 000 "$D/Garten/@/garten.md"
   OUT="$(HOOK --session "$D/Garten")"; RC=$?
   chmod 644 "$D/Garten/@/garten.md"
   assert_eq "$RC" "0" "failure: exit 0"
   assert_contains "$OUT" "AIOS-WARNING: aios --context --session failed:" "failure: one warning line"

#===============================================================================
# v0.3 step 6: assistant of the session (spec 02, Assistent der Session)
#===============================================================================

   printf 'aios: 0.1.0\n' > "$D/.aios/config.yaml"
   mk "$D/@/@!Assistant/gaertner/ASSISTANT.md" $'---\nname: gaertner\ntitle: Gärtner\nversion: 0.1.0\ndescription: Gärtner\n---\n\nNur Äpfel und Birnen.\n'
   mk "$D/Garten/.aios/config.yaml" $'assistant: gaertner\n'
   SJ() { printf '{"session_id":"%s","source":"%s","cwd":"%s"}' "$1" "$2" "$3"; }
   SH() { SJ "$2" "$3" "$4" | (cd "$SANDBOX" && AC "$1"); }       # SH --session|--advise <sid> <source> <cwd>
   M="$HOME/.aios/sessions"
   OUT="$(SH --session s1 startup "$D/Garten")"
   assert_contains "$OUT" "AIOS-ASSISTANT (assistant of this session, from project $D/Garten/.aios/config.yaml):
 Take on this role for the whole session. In your first answer, confirm
 briefly \"Gärtner aktiv\" (and mention the model wish, if any).
<aios-assistant name=\"gaertner\" title=\"Gärtner\" version=\"0.1.0\"" "startup: assistant inline after the master context"
   assert_contains "$OUT" '</aios-assistant name="gaertner">' "startup: end marker"
   case "$OUT" in *"AIOS-CONTEXT (loaded"*"AIOS-ASSISTANT ("*) ok ;; *) fail "startup: master context first, then the assistant" ;; esac
   assert_eq "$(sed -n 2,3p "$M/s1.yaml")" "cwd: \"$D/Garten\"
assistant: gaertner" "startup: marker written"

   mk "$D/Garten/.aios/config.yaml" $'assistant: none\n'
   for S in resume compact; do
      OUT="$(SH --session s1 "$S" "$D/Garten")"
      assert_contains "$OUT" "AIOS-ASSISTANT (assistant of this session, from session):" "$S: assistant from the marker, not the new assignment"
   done
   OUT="$(SH --advise s1 x "$D/Garten")"
   assert_contains "$OUT" "AIOS-ASSISTANT-CHECK: expected assistant=gaertner version=0.1.0.
 Verify that BOTH markers <aios-assistant name=\"gaertner\" and
 </aios-assistant name=\"gaertner\"> are present in your context. If not: run
 \`aios --context --assistant gaertner --load\` via Bash in \"$D/Garten\", read every
 listed part file completely, and continue in this role." "advise: assistant check after the context check"
   case "$OUT" in AIOS-CONTEXT-CHECK*) ok ;; *) fail "advise: context check first" ;; esac
   OUT="$(SH --session s1 clear "$D/Garten")"
   case "$OUT" in *AIOS-ASSISTANT*) fail "clear: new chat, assignment none" ;; *) ok ;; esac
   assert_contains "$(cat "$M/s1.yaml")" "assistant: none" "clear: marker rewritten"
   case "$(SH --advise s1 x "$D/Garten")" in *AIOS-ASSISTANT-CHECK*) fail "advise: no check for none" ;; *) ok ;; esac

   mk "$D/Garten/.aios/config.yaml" $'assistant: gaertner\n'
   OUT="$(SH --session s2 resume "$D/Garten")"
   assert_contains "$OUT" "from project $D/Garten/.aios/config.yaml" "resume without marker: assignment of the project"
   assert_contains "$(cat "$M/s2.yaml")" "assistant: gaertner" "resume without marker: marker created"
   assert_contains "$(SH --advise s9 x "$D/Garten")" "AIOS-ASSISTANT-CHECK: expected assistant=gaertner" "advise without marker: assignment"
   [ ! -e "$M/s9.yaml" ] && ok || fail "advise writes no marker"

   printf '# written by AIOS (session), do not edit\ncwd: "%s"\nassistant: weg\nused: 2026-01-01T00:00:00\n' "$D/Garten" > "$M/s3.yaml"
   OUT="$(SH --session s3 resume "$D/Garten")"
   assert_contains "$OUT" "AIOS-WARNING: assistant weg not found, continuing without assistant" "unknown assistant: warning"
   case "$OUT" in *"AIOS-ASSISTANT ("*) fail "unknown assistant: no role" ;; *) ok ;; esac
   case "$(SH --advise s3 x "$D/Garten")" in *AIOS-ASSISTANT-CHECK*) fail "unknown assistant: no check" ;; *) ok ;; esac

   printf '# written by AIOS (session), do not edit\ncwd: "/x"\nassistant: none\nused: 2020-01-01T00:00:00\n' > "$M/alt.yaml"
   SH --session s4 resume "$D/Garten" >/dev/null
   [ -e "$M/alt.yaml" ] && ok || fail "resume: no cleaning"
   SH --session s4 startup "$D/Garten" >/dev/null
   [ ! -e "$M/alt.yaml" ] && [ -e "$M/s1.yaml" ] && ok || fail "startup: markers older than 30 days removed"

   OUT="$(SH --session s5 startup "$D/Garten/Neu")"
   case "$OUT" in *"AIOS-ASSISTANT ("*) fail "not initialized: no assistant" ;; *) ok ;; esac
   [ ! -e "$M/s5.yaml" ] && ok || fail "not initialized: no marker"
   OUT="$(printf '{"source":"startup","cwd":"%s"}' "$D/Garten" | (cd "$SANDBOX" && AC --session))"
   assert_contains "$OUT" "AIOS-ASSISTANT (assistant of this session" "without session_id: assignment, no marker"

   printf 'inline_limit: 2000\n' > "$HOME/.aios/config.yaml"
   python3 -c "print('x' * 3000)" >> "$D/@/@!Assistant/gaertner/ASSISTANT.md"
   OUT="$(SH --session s6 startup "$D/Garten")"
   assert_contains "$OUT" "AIOS-ASSISTANT-MANDATORY: the assistant gaertner of this session (from project $D/Garten/.aios/config.yaml) is too" "mandatory: header"
   assert_contains "$OUT" "AIOS-ASSISTANT-LOAD name=gaertner version=0.1.0 parts=1" "mandatory: part files"
   assert_contains "$OUT" 'The assistant is loaded once </aios-assistant name="gaertner"> (end of the last part) has been read.' "mandatory: end marker named"
   P1="$(printf '%s\n' "$OUT" | grep -o "$HOME/.aios/cache/a-gaertner-[0-9a-f]*/part-1.md")"
   assert_file "$P1"
   case "$OUT" in *"AIOS-ASSISTANT ("*) fail "mandatory: no inline assistant" ;; *) ok ;; esac
   rm "$HOME/.aios/config.yaml"
