# t04-activate.sh: step 4 of the plan (memo 18) - aios --activate/--deactivate/--config, configuration chain

#===============================================================================
# setup: two fake installations, forwarders, a vault with projects and a container
#===============================================================================

   mkdir -p "$HOME/bin" "$HOME/.aios"
   export PATH="$HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin"
   export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
   cp "$SRC/templates/forwarder" "$HOME/bin/aios"; chmod +x "$HOME/bin/aios"
   for V in 0.1.0 0.2.0; do
      mkdir -p "$AIOS_PREFIX/v$V/bin"
      printf '#!/bin/bash\necho "%s $*"\n' "$V" > "$AIOS_PREFIX/v$V/bin/aios"
      chmod +x "$AIOS_PREFIX/v$V/bin/aios"
      echo "v$V: $AIOS_PREFIX/v$V" >> "$AIOS_PREFIX/installations.yaml"
   done

   W="$SANDBOX/work"; D="$W/§Demo"
   mkdir -p "$D/Garten/@" "$D/Garten/Beet/@" "$D/Garten/Beet/Reihe" "$D/Wiese" "$SANDBOX/outside" "$W/.aios"
   A() { "$SRC/bin/aios" "$@" 2>&1; }               # aios of the clone
   at() { (cd "$1" && shift && "$@" 2>&1); }        # run in a directory
   CFG() { PYTHONPATH="$SRC/lib" python3 -c "from aios import config; c=config.load('$1'); print(($2))"; }

#===============================================================================
# --activate: checks before anything is written
#===============================================================================

   assert_contains "$(A --activate v0.1.0 "$SANDBOX/outside")" "is not in a vault" "outside a vault"
   assert_contains "$(A --activate v0.9.0 "$D")" "run: aios --install v0.9.0" "version not installed"
   assert_contains "$(A --activate 0.x "$D")" "is not a version" "no version"
   assert_contains "$(A --activate v0.1.0 "$D/Wiese")" "/aios-init" "container: hint to /aios-init"
   assert_exit 1 "$SRC/bin/aios" --activate v0.1.0 "$D/Wiese"
   [ ! -e "$D/.aios" ] && [ ! -e "$D/Wiese/.aios" ] && ok || fail "checks: nothing written"

#===============================================================================
# --activate the vault root (cwd): creates @/, writes aios:
#===============================================================================

   OUT="$(at "$D" sh -c "echo n | '$SRC/bin/aios' --activate v0.1.0")"
   [ ! -e "$D/@" ] && [ ! -e "$D/.aios" ] && ok || fail "activation cancelled: nothing written"
   OUT="$(at "$D" sh -c "echo y | '$SRC/bin/aios' --activate v0.1.0")"
   assert_contains "$OUT" "create @/ (with .gitkeep)" "plan: root masterspace"
   assert_contains "$OUT" "git init (branch main)" "plan: repo of the root project"
   assert_contains "$OUT" ".gitignore: .DS_Store, .claude/skills/, .claude/worktrees/, .agents/, .aios/registry, .aios/backup/" "plan: .gitignore"
   assert_contains "$OUT" "from the next chat" "hint: next chat"
   assert_dir "$D/@"
   assert_eq "$(cat "$D/.aios/config.yaml")" "aios: 0.1.0" "vault config written"
   assert_eq "$(git -C "$D" log --format=%s)" "AIOS: Projekt initialisiert" "root project: first commit"
   assert_eq "$(git -C "$D" show --name-only --format= | sort | tr '\n' ' ')" ".aios/config.yaml .gitignore @/.gitkeep " "root project: committed files"
   assert_eq "$(at "$D/Garten/Beet/Reihe" aios --context --id)" "0.1.0 --context --id" "forwarder agrees with the activation"
   assert_eq "$(at "$D" sh -c "'$SRC/bin/aios' --activate 0.1.0 </dev/null")" "=> $D runs with AIOS 0.1.0 ($D/.aios/config.yaml), nothing to do" "same version again: nothing to do, no question"

#===============================================================================
# --activate a project: other keys and comments stay, aios: replaced once
#===============================================================================

   mkdir -p "$D/Garten/.aios"
   printf '# Garten\nskills:\n  memo: 6.1.0   # newer memo\n' > "$D/Garten/.aios/config.yaml"
   OUT="$(echo y | A --activate v0.2.0 "$D/Garten")"
   assert_eq "$(cat "$D/Garten/.aios/config.yaml")" "$(printf 'aios: 0.2.0\n# Garten\nskills:\n  memo: 6.1.0   # newer memo')" "aios: added on top"
   OUT="$(echo y | A --activate v0.1.0 "$D/Garten")"
   assert_contains "$OUT" "(was 0.2.0)" "plan shows the old version"
   assert_eq "$(grep -c '^aios:' "$D/Garten/.aios/config.yaml")" "1" "only one aios: line"
   assert_eq "$(head -1 "$D/Garten/.aios/config.yaml")" "aios: 0.1.0" "aios: replaced in place"
   echo y | A --activate v0.2.0 "$D/Garten" >/dev/null
   assert_eq "$(at "$D/Garten/Beet/Reihe" aios --context --id)" "0.2.0 --context --id" "forwarder: nearest activation wins"

#===============================================================================
# configuration chain: per key the nearest entry, skills per name
#===============================================================================

   printf 'aios: 0.1.0\nskills:\n  memo: 6.0.0\n  astro: 1.0.0\nhosts: [claude-code]\n' > "$D/.aios/config.yaml"
   printf 'aios: 0.2.0\ninline_limit: 100\nfoo: bar\nskills:\n  memo: 6.1.0\n' > "$D/Garten/.aios/config.yaml"
   printf 'aios: 0.2.0\nhosts:\n  - codex\n  - claude-code\ninline_limit: 5000\n' > "$HOME/.aios/config.yaml"
   printf 'aios: 0.9.0\nskills:\n  outside: 9.9.9\n' > "$W/.aios/config.yaml"
   C="$D/Garten/Beet/Reihe"
   assert_eq "$(CFG "$C" 'c.aios, str(c.source["aios"])')" "('0.1.0', '$D/.aios/config.yaml')" "aios: only from the vault root (I14)"
   assert_contains "$(CFG "$C" '"|".join(c.warnings)')" "Garten/.aios/config.yaml: aios: is only allowed at the vault root, ignored" "warning: aios in a project (I14)"
   assert_eq "$(CFG "$C" 'sorted(c.skills.items())')" "[('astro', '1.0.0'), ('memo', '6.1.0')]" "skills merged per name, nothing from above the vault"
   assert_eq "$(CFG "$C" 'str(c.skill_source["astro"])')" "$D/.aios/config.yaml" "skill origin"
   assert_eq "$(CFG "$C" 'c.hosts')" "['claude-code']" "hosts: vault beats home"
   assert_eq "$(CFG "$C" 'c.inline_limit')" "5000" "inline_limit only from home"
   W3="$(CFG "$C" '"|".join(c.warnings)')"
   assert_contains "$W3" "Garten/.aios/config.yaml: inline_limit is not allowed here" "warning: inline_limit in a project"
   assert_contains "$W3" "foo" "warning: unknown key"
   assert_contains "$W3" "$HOME/.aios/config.yaml: aios is not allowed here" "warning: aios in ~/.aios"
   assert_eq "$(CFG "$SANDBOX/outside" 'c.aios, c.hosts, c.inline_limit')" "(None, ['codex', 'claude-code'], 5000)" "outside a vault: only home"
   assert_eq "$(at "$SANDBOX/outside" aios --context --id)" "id=- files=0 cwd=$SANDBOX/outside mode=none" "forwarder outside a vault: mode=none"

   OUT="$(A --config "$C")"
   assert_contains "$OUT" "aios      0.1.0 ($D/.aios/config.yaml)" "--config: aios with origin"
   assert_contains "$OUT" "kind      alt" "--config: kind of the vault"
   assert_contains "$OUT" "skill     astro 1.0.0 ($D/.aios/config.yaml)" "--config: skills with origin"
   assert_contains "$(A --config "$SANDBOX/outside")" "aios      - (no binding)" "--config: no binding outside a vault"

#===============================================================================
# parser: subset of YAML, errors are reported with the line
#===============================================================================

   P() { PYTHONPATH="$SRC/lib" python3 -c "from aios import config; print(config.parse('''$1'''))" 2>&1; }
   assert_eq "$(P $'aios: "0.1.0"  # c\nhosts: [a, \'b\']\nskills:\n  x: 1.0.0')" "{'aios': '0.1.0', 'hosts': ['a', 'b'], 'skills': {'x': '1.0.0'}}" "quotes, comments, flow list, mapping"
   assert_contains "$(P $'aios: 1\naios: 2')" "key aios appears twice" "duplicate key"
   assert_contains "$(P $'  x: 1')" "indented line without a key" "indent without key"

   printf 'aios 0.1.0\n' > "$D/Garten/Beet/.aios.cfg"; mkdir -p "$D/Garten/Beet/.aios"; mv "$D/Garten/Beet/.aios.cfg" "$D/Garten/Beet/.aios/config.yaml"
   OUT="$(echo y | A --activate v0.1.0 "$D/Garten/Beet")"
   assert_contains "$OUT" "expected 'key: value'" "broken config: activate aborts"
   assert_eq "$(cat "$D/Garten/Beet/.aios/config.yaml")" "aios 0.1.0" "broken config: unchanged"
   assert_contains "$(CFG "$D/Garten/Beet" '"|".join(c.warnings)')" "file ignored" "broken config: chain ignores the file"
   rm -rf "$D/Garten/Beet/.aios"

#===============================================================================
# --deactivate: other keys stay, empty file and .aios/ are removed
#===============================================================================

   OUT="$(echo y | A --deactivate "$D/Garten")"
   assert_contains "$OUT" "(inline_limit, foo, skills stay)" "plan names the remaining keys"
   assert_eq "$(grep -c '^aios:' "$D/Garten/.aios/config.yaml")" "0" "aios: removed"
   assert_contains "$(cat "$D/Garten/.aios/config.yaml")" "memo: 6.1.0" "skills stay"
   assert_contains "$OUT" "runs with AIOS 0.1.0 ($D/.aios/config.yaml)" "now the vault decides"
   assert_eq "$(at "$D/Garten" aios --context --id)" "0.1.0 --context --id" "forwarder follows"

   printf 'aios: 0.1.0\n' > "$D/.aios/config.yaml"
   OUT="$(at "$D" sh -c "echo y | '$SRC/bin/aios' --deactivate")"
   [ ! -e "$D/.aios" ] && ok || fail "empty config and .aios/ removed"
   assert_contains "$OUT" "legacy mode" "vault in legacy mode"
   assert_contains "$(A --deactivate "$D" </dev/null)" "nothing to do" "deactivate again: nothing to do"
   assert_eq "$(at "$D/Garten" aios --context --id)" "id=- files=0 cwd=$D/Garten mode=legacy" "forwarder: legacy (no ai-brain here)"
