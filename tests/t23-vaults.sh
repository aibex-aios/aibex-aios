# t23-vaults.sh: v0.6.2 step 1 - aios --vaults, the vaults AIOS finds (spec 04, aios --vaults; V0.6, memos 115, 120, H8)
#               v0.6.3 step 1 - of /opt/aios/workers.yaml only projects of the current user (B26; V0.6, memos 153, 154)

   case "$SANDBOX" in */aios-test.*) ;; *) echo "*** run via tests/run, never directly (it would touch the real HOME)" >&2; exit 1;; esac

#===============================================================================
# setup: vaults from each source in their own folders a-d, beside, inside and above them, all kinds of binding
#===============================================================================

   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   V() { (cd "$SANDBOX" && "$SRC/bin/aios" --vaults 2>&1); }
   W="$SANDBOX/w"
   assert_eq "$(V)" "no vault found" "nothing known: no vault found"

   mk "$W/a/§Outer/.aios/config.yaml" $'aios: 0.6.1\n'                   # above §Known
   mk "$W/a/§Outer/§Known/.aios/config.yaml" $'aios: 0.6.2\n'            # from a session marker
   mk "$W/a/§Outer/§Known/P/x.md" $'# x\n'
   mk "$W/a/§Outer/§Sibling/.aios/config.yaml" $'legacy: ai-brain\n'     # beside §Known
   mk "$W/a/§Outer/§Known/A/B/§Deep/.aios/config.yaml" $'aios: 0.5.1\n'  # inside, level 3
   mk "$W/a/§Outer/§Known/A/B/C/§Deeper/x.md" $'# x\n'                   # inside, level 4: not searched
   mk "$W/a/§Outer/§Known/.git/§Hidden/x.md" $'# x\n'                    # hidden folders are not searched
   mk "$W/b/§Repo/.aios/config.yaml" $'aios: 0.6.1\n'                    # from ~/.aios/repo
   mk "$W/b/§Repo/aibex-aios/VERSION" $'0.6.2\n'
   mk "$W/c/§Work/P/x.md" $'# x\n'                                       # from workers.yaml, no binding
   mk "$HOME/.aios/sessions/a.yaml" "cwd: \"$W/a/§Outer/§Known/P\""$'\n'
   mk "$HOME/.aios/sessions/b.yaml" "cwd: \"$W/d/§Gone/P\""$'\n'          # path no longer exists
   mk "$HOME/.aios/repo" "$W/b/§Repo/aibex-aios"$'\n'
   mk "$HOME/.aios/workers.yaml" "worker-x:"$'\n'"  0.1.0:"$'\n'"    projects: [\"$W/c/§Work/P\"]"$'\n'

#===============================================================================
# aios --vaults: binding and sources per vault, sorted by path
#===============================================================================

   OUT="$(V)"
   assert_contains "$OUT" "=> 7 vaults" "seven vaults found"
   assert_contains "$OUT" "   aios 0.6.1   $W/a/§Outer  (above)" "above a known vault (F97)"
   assert_contains "$OUT" "   aios 0.6.2   $W/a/§Outer/§Known  (session)" "from a session marker"
   assert_contains "$OUT" "   alt 0.5.1    $W/a/§Outer/§Known/A/B/§Deep  (inside)" "inside, binding below 0.6"
   assert_contains "$OUT" "   legacy       $W/a/§Outer/§Sibling  (beside)" "beside, legacy vault"
   assert_contains "$OUT" "   aios 0.6.1   $W/b/§Repo  (repo)" "from ~/.aios/repo"
   assert_contains "$OUT" "   none         $W/c/§Work  (workers)" "from workers.yaml, without binding"
   assert_contains "$OUT" "   missing      $W/d/§Gone  (session)" "path of a marker that no longer exists"
   assert_not_contains "$OUT" "§Deeper" "inside: not deeper than 3 levels (F104)"
   assert_not_contains "$OUT" "§Hidden" "inside: hidden folders skipped"
   assert_eq "$(printf '%s\n' "$OUT" | sed -n 2p)" "   aios 0.6.1   $W/a/§Outer  (above)" "sorted by path"

#===============================================================================
# several sources for one vault; reads only (I7)
#===============================================================================

   mk "$HOME/.aios/sessions/c.yaml" "cwd: \"$W/c/§Work\""$'\n'
   assert_contains "$(V)" "   none         $W/c/§Work  (session, workers)" "sources in a fixed order"
   find "$W" "$HOME" -type f | sort > "$SANDBOX/before"
   V >/dev/null
   find "$W" "$HOME" -type f | sort > "$SANDBOX/after"
   cmp -s "$SANDBOX/before" "$SANDBOX/after" && ok || fail "aios --vaults writes nothing"
   assert_exit 1 "$SRC/bin/aios" --vaults extra

#===============================================================================
# B26: /opt/aios/workers.yaml is computer-wide; only existing projects of the current user count (F150, F151)
#===============================================================================

   rm -f "$HOME/.aios/sessions/c.yaml"
   mk "$W/e/§Shared/P/x.md" $'# x\n'
   mk "$AIOS_PREFIX/workers.yaml" "worker-y:"$'\n'"  0.1.0:"$'\n'"    projects: [\"$W/e/§Shared/P\", \"$W/f/§Vanished/P\"]"$'\n'
   OUT="$(V)"
   assert_contains "$OUT" "   none         $W/e/§Shared  (workers)" "B26: own project from /opt/aios/workers.yaml"
   assert_not_contains "$OUT" "§Vanished" "B26: missing path from /opt/aios/workers.yaml not listed"
   assert_contains "$OUT" "   none         $W/c/§Work  (workers)" "B26: project from ~/.aios/workers.yaml"
   OUT="$(AIOS_TEST_UID=99999 V)"
   assert_not_contains "$OUT" "§Shared" "B26: project of another user not listed"
   assert_contains "$OUT" "   none         $W/c/§Work  (workers)" "B26: ~/.aios/workers.yaml counts for any owner"
   mk "$HOME/.aios/workers.yaml" "worker-x:"$'\n'"  0.1.0:"$'\n'"    projects: [\"$W/c/§Work/P\", \"$W/e/§Shared/P\"]"$'\n'
   assert_contains "$(AIOS_TEST_UID=99999 V)" "   none         $W/e/§Shared  (workers)" "B26: same project in ~/.aios/workers.yaml is listed"
