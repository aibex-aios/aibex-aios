# t03-install.sh: step 3 of the plan (memo 18) - aios --prepare/--install/--versions/--remove-version/--uninstall

   case "$SANDBOX" in */aios-test.*) ;; *) echo "*** run via tests/run, never directly (it would touch the real HOME)" >&2; exit 1;; esac

#===============================================================================
# setup: PATH without the real ~/bin, fake stup, no real sudo, no pip, no network
#===============================================================================

   PYDIR=""                                      # basic kit: python3 >= 3.11 (V0.5, memo 91: B11)
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import sys, venv, ensurepip; sys.exit(sys.version_info < (3, 11))" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t03 needs a python3 >= 3.11 with venv and ensurepip"
   mkdir -p "$SANDBOX/fake" "$SANDBOX/stup-src" "$HOME/bin" "$HOME/etc/aios"
   export PATH="$HOME/bin:$SANDBOX/fake:$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
   export AIOS_SUDO="$SANDBOX/fake/no-sudo"         # does not exist: no sudo
   export AIOS_PIP=true                             # requirements are not installed
   export AIOS_STUP_URL="file://$SANDBOX/stup-src/stup"
   cat > "$SANDBOX/stup-src/stup" <<'EOF'
#!/bin/bash
[ "$*" == "--version" ] && { echo "9.9"; exit 0; }
[ "$*" == "--profile" ] && { echo "# profile" > "$BIN/profile.sh"; exit 0; }
exit 1
EOF

   printf '#!/bin/bash\n# aios: prototype\n   ETC="$HOME/etc/aios"\necho prototype\n' > "$HOME/bin/aios"
   chmod +x "$HOME/bin/aios"; echo "0.1.0" > "$HOME/etc/aios/version"

   SET="$AIOS_CLAUDE_DIR/settings.json"; mkdir -p "$AIOS_CLAUDE_DIR"
   cat > "$SET" <<'EOF'
{
  "model": "opus",
  "hooks": {
    "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "ai-brain --advise" } ] } ],
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "ai-brain --session" } ] },
      { "hooks": [ { "type": "command", "command": "python3 \"/x/zeiterfassung.py\" export --quiet", "timeout": 30 } ] }
    ]
  }
}
EOF
   cp "$SET" "$SANDBOX/settings.orig"

   S="$SANDBOX/repo"                                # sandbox clone with release tags
   (cd "$REPO" && git -c core.quotePath=false ls-files -co --exclude-standard) | while IFS= read -r F; do
      mkdir -p "$S/$(dirname "$F")"; cp -p "$REPO/$F" "$S/$F"
   done
   mkdir -p "$S/skills/aios/aios-demo" "$S/skills/basic/memo"
   printf -- '---\nname: aios-demo\ndescription: >\n  Demo skill of AIOS,\n  two lines.\n---\n\n# Demo\n' > "$S/skills/aios/aios-demo/SKILL.md"
   printf -- '---\nname: memo\ndescription: Memo style\nversion: 6.0.0\n---\n\n# Memo\n' > "$S/skills/basic/memo/SKILL.md"
   G() { git -C "$S" -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1; }
   G init -q; G add -A; G commit -q -m v0.1.0; G tag v0.1.0
   sed -i '' 's/version: 6.0.0/version: 6.1.0/' "$S/skills/basic/memo/SKILL.md" 2>/dev/null || sed -i 's/version: 6.0.0/version: 6.1.0/' "$S/skills/basic/memo/SKILL.md"
   G commit -q -am v0.2.0; G tag v0.2.0; G tag v0.3.0-rc1
   S="$(cd "$S" && pwd -P)"

   P="$AIOS_PREFIX"                                 # /opt/aios: --prepare (legacy) and --system
   U="$HOME/.aios/versions"                         # standard place of installations (V0.6, F26)
   ro() { [ -e "$1" ] && [ ! -w "$1" ]; }

#===============================================================================
# --prepare: plan, cancel, execute, idempotent
#===============================================================================

   OUT="$(echo n | "$S/bin/aios" --prepare 2>&1)"; RC=$?
   assert_eq "$RC" "1" "prepare cancelled: exit 1"
   assert_contains "$OUT" "stup: install 9.9 -> ~/bin/stup" "prepare plan: stup"
   [ ! -e "$HOME/git" ] && [ ! -e "$P" ] && ok || fail "prepare cancelled: nothing written"

   OUT="$(echo y | "$S/bin/aios" --prepare 2>&1)"; RC=$?
   assert_eq "$RC" "0" "prepare: exit 0"
   for D in bin etc tmp git; do assert_dir "$HOME/$D"; done
   assert_dir "$P"
   assert_exec "$HOME/bin/stup"
   assert_file "$HOME/bin/profile.sh"
   assert_eq "$("$S/bin/aios" --prepare </dev/null 2>&1)" "=> machine prepared, nothing to do" "prepare again: nothing to do, no question"

#===============================================================================
# v0.5 step 3: basic kit and developer kit (spec 04, aios --prepare; V0.5, memo 31)
#===============================================================================

   mkdir -p "$SANDBOX/kit-none" "$SANDBOX/kit-ok"
   ln -s "$(command -v python3)" "$SANDBOX/kit-ok/python3"; ln -s "$(command -v git)" "$SANDBOX/kit-ok/git"
   printf '#!/bin/bash\nexit 1\n' > "$SANDBOX/kit-none/python3"; chmod +x "$SANDBOX/kit-none/python3"
   OUT="$(AIOS_PREPARE_PATH="$SANDBOX/kit-none" "$S/bin/aios" --prepare </dev/null 2>&1)"; RC=$?
   assert_eq "$RC" "1" "kit missing: exit 1"
   assert_contains "$OUT" "missing: python3 >= 3.11 with venv and pip" "kit: python3 without venv/pip reported"
   assert_contains "$OUT" "missing: git — " "kit: git reported with the way to it"
   assert_contains "$OUT" "machine not prepared" "kit: not prepared"
   assert_eq "$(AIOS_PREPARE_PATH="$SANDBOX/kit-ok" "$S/bin/aios" --prepare </dev/null 2>&1)" "=> machine prepared, nothing to do" "kit complete: nothing to do"
   OUT="$(AIOS_PREPARE_PATH="$SANDBOX/kit-ok" "$S/bin/aios" --prepare --dev </dev/null 2>&1)"; RC=$?
   assert_eq "$RC:$(grep -c 'missing: gh (developer kit)' <<< "$OUT")" "1:1" "--dev: gh reported"
   OUT="$(AIOS_PREPARE_PATH="$SANDBOX/kit-none" "$S/bin/aios" --install v0.2.0 </dev/null 2>&1)"; RC=$?
   assert_eq "$RC" "1" "install without the basic kit: exit 1"
   assert_contains "$OUT" "the basic kit is missing" "install without the basic kit: aborted"
   [ ! -e "$U/v0.2.0" ] && ok || fail "install without the basic kit: nothing installed"
   assert_contains "$OUT" "install it, then run aios --install again" "install without the basic kit: no hint to aios --prepare"
   mkdir -p "$SANDBOX/kit-old"; ln -s "$(command -v git)" "$SANDBOX/kit-old/git"        # v0.5.1, B11
   printf '#!/bin/bash\necho "3 10"\n' > "$SANDBOX/kit-old/python3"; chmod +x "$SANDBOX/kit-old/python3"
   OUT="$(AIOS_PREPARE_PATH="$SANDBOX/kit-old" "$S/bin/aios" --prepare </dev/null 2>&1)"; RC=$?
   assert_eq "$RC:$(grep -c 'missing: python3 >= 3.11 with venv and pip' <<< "$OUT")" "1:1" "B11: python3 3.10 is too old"

#===============================================================================
# --install: errors, cancel, highest release tag
#===============================================================================

   assert_contains "$("$S/bin/aios" --install v9.9.9 2>&1)" "no tag v9.9.9" "unknown version"
   assert_exit 1 "$S/bin/aios" --install v9.9.9

   OUT="$(echo n | "$S/bin/aios" --install 2>&1)"
   assert_contains "$OUT" "install v0.2.0 from $S" "highest release tag, rc ignored"
   assert_contains "$OUT" "legacy: ~/bin/aios stays untouched" "plan: the prototype in ~/bin stays (legacy, V0.6)"
   assert_contains "$OUT" "remove the ai-brain hooks" "plan: hooks"
   [ ! -e "$U/v0.2.0" ] && cmp -s "$SET" "$SANDBOX/settings.orig" && ok || fail "install cancelled: nothing written"

   OUT="$(echo y | "$S/bin/aios" --install 2>&1)"; RC=$?
   assert_eq "$RC" "0" "install v0.2.0: exit 0"

#===============================================================================
# --install: installation directory (spec 04, Abbildung)
#===============================================================================

   I="$U/v0.2.0"
   assert_eq "$(cat "$I/VERSION")" "0.2.0" "VERSION of the tag"
   [ ! -e "$I/bin/aios-context" ] && ok || fail "no bin/aios-context in the installation"
   for F in bin/aios lib/aios/install.py templates/forwarder templates/gitignore \
            skills/aios/aios-demo/SKILL.md python/requirements.txt manifest.yaml; do
      assert_file "$I/$F"
   done
   [ ! -e "$I/skills/basic" ] && [ ! -e "$I/assistants" ] && ok || fail "no library in the installation (v0.4)"
   assert_eq "$(sed -n 's/^version: //p' "$I/manifest.yaml")" "0.2.0" "manifest.yaml: version of the tag"
   assert_file "$I/doc/spec/04 Installation und Konfiguration.md"
   assert_file "$I/doc/tutorials/01 Erste Schritte mit den Demo-Assistenten.md"
   assert_exec "$I/python/bin/python"
   [ ! -e "$I/tests" ] && [ ! -e "$I/dev" ] && [ ! -e "$I/CLAUDE.md" ] && [ ! -e "$I/.git" ] && ok || fail "only the mapped parts are installed"
   ro "$I" && ro "$I/bin/aios" && ro "$I/lib/aios" && ok || fail "installation is read-only"
   assert_eq "$(cat "$HOME/.aios/installations.yaml")" "v0.2.0: $I" "installations.yaml under ~/.aios"
   [ ! -e "$P/v0.2.0" ] && ok || fail "nothing under /opt/aios without --system"

#===============================================================================
# --install: user setup
#===============================================================================

   F="$HOME/.aios/bin/aios"                         # forwarder of v0.6 (spec 04, Weiterleiter)
   assert_contains "$(cat "$F")" "# forwarder: ~/.aios/bin/aios" "forwarder in ~/.aios/bin"
   assert_contains "$(cat "$HOME/bin/aios")" "# aios: prototype" "~/bin/aios untouched (legacy)"
   [ ! -e "$HOME/bin/aios-context" ] && ok || fail "no forwarder ~/bin/aios-context"
   [ -e "$HOME/etc/aios" ] && ok || fail "~/etc/aios untouched (nothing outside ~/.aios)"
   assert_eq "$(cat "$HOME/.aios/config.yaml")" "hosts: [claude-code]" "~/.aios/config.yaml"
   assert_eq "$(cat "$HOME/.aios/repo")" "$S" "~/.aios/repo"
   J() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print($1)" "$2"; }
   CMDS='" ".join(h["command"] for e in ("SessionStart","UserPromptSubmit") for g in d.get("hooks",{}).get(e,[]) for h in g["hooks"])'
   assert_eq "$(J "$CMDS" "$SET")" "$F --context --session python3 \"/x/zeiterfassung.py\" export --quiet $F --context --advise" "hooks: AIOS in with the absolute path, ai-brain out, others kept"
   assert_eq "$(J '" ".join(g.get("matcher","-")+":"+h["command"] for g in d["hooks"]["PreToolUse"] for h in g["hooks"])' "$SET")" "Bash|Skill|Read:$F --context --permit" "hooks: PreToolUse with the matcher Bash|Skill|Read (B18)"
   assert_eq "$(J 'd["model"]' "$SET")" "opus" "other settings kept"
   assert_eq "$(J "$CMDS" "$HOME/.aios/hooks-backup.json")" "ai-brain --session ai-brain --advise" "ai-brain hooks saved"
   [ ! -e "$AIOS_CLAUDE_DIR/skills" ] && ok || fail "install: no global wrappers (I3, V0.6)"

   assert_eq "$(cd "$SANDBOX" && "$F" --version)" "0.2.0" "forwarder: not activated, highest version"
   assert_contains "$(cd "$SANDBOX" && "$F" --versions)" "v0.2.0" "--versions"

#===============================================================================
# --install via the forwarder: older version, idempotent user setup
#===============================================================================

   cp "$SET" "$SANDBOX/settings.1"; cp "$HOME/.aios/hooks-backup.json" "$SANDBOX/backup.1"
   OUT="$(cd "$SANDBOX" && echo y | "$F" --install v0.1.0 2>&1)"; RC=$?
   assert_eq "$RC" "0" "install v0.1.0 via forwarder (clone from ~/.aios/repo)"
   assert_eq "$(sed -n 's/^version: //p' "$U/v0.1.0/manifest.yaml")" "0.1.0" "v0.1.0: manifest.yaml with the version of the tag"
   cmp -s "$SET" "$SANDBOX/settings.1" && cmp -s "$HOME/.aios/hooks-backup.json" "$SANDBOX/backup.1" && ok || fail "second install: hooks and backup unchanged"
   assert_eq "$(cd "$SANDBOX" && "$F" --install v0.1.0 </dev/null 2>&1)" "=> AIbex AIOS v0.1.0: nothing to do" "installed version: nothing to do, no question"
   assert_eq "$(cd "$SANDBOX" && "$F" --version)" "0.2.0" "forwarder still calls the highest version"

#===============================================================================
# --remove-version: installation directory and clone entry
#===============================================================================

   OUT="$(cd "$SANDBOX" && echo n | "$F" --remove-version v0.1.0 2>&1)"
   assert_dir "$U/v0.1.0"
   OUT="$(cd "$SANDBOX" && echo y | "$F" --remove-version v0.1.0 2>&1)"; RC=$?
   assert_eq "$RC" "0" "remove-version: exit 0"
   [ ! -e "$U/v0.1.0" ] && ok || fail "v0.1.0 removed"
   assert_eq "$(cat "$HOME/.aios/installations.yaml")" "v0.2.0: $I" "entry removed"

   printf 'v0.3.0-dev: "%s"\n' "$S" > "$HOME/.aios/installations.yaml"
   OUT="$(cd "$SANDBOX" && echo y | "$F" --remove-version v0.3.0-dev 2>&1)"
   assert_contains "$OUT" "is not an installation directory, it is kept" "clone entry: directory kept"
   assert_file "$S/bin/aios"
   assert_eq "$(cat "$HOME/.aios/installations.yaml")" "" "clone entry removed"
   assert_exit 1 "$S/bin/aios" --remove-version v7.0.0

#===============================================================================
# --uninstall: user setup removed, ai-brain hooks restored, installations kept
#===============================================================================

   OUT="$(echo y | "$S/bin/aios" --uninstall 2>&1)"; RC=$?
   assert_eq "$RC" "0" "uninstall: exit 0"
   [ ! -e "$F" ] && [ -e "$HOME/bin/aios" ] && ok || fail "forwarder removed, ~/bin/aios untouched"
   assert_contains "$OUT" "legacy: ~/bin/aios stays untouched" "uninstall names ~/bin/aios"
   [ ! -e "$AIOS_CLAUDE_DIR/skills/aios-demo" ] && ok || fail "AIOS skill removed"
   [ ! -e "$AIOS_CLAUDE_DIR/skills/gui" ] && ok || fail "uninstall: alias /gui removed"
   [ ! -e "$HOME/.aios/hooks-backup.json" ] && ok || fail "backup removed"
   assert_eq "$(J "$CMDS" "$SET")" 'ai-brain --session python3 "/x/zeiterfassung.py" export --quiet ai-brain --advise' "ai-brain hooks restored"
   assert_dir "$I"
   assert_file "$HOME/.aios/config.yaml"
   assert_eq "$("$S/bin/aios" --uninstall </dev/null 2>&1)" "=> nothing to uninstall" "uninstall again: nothing to do"

#===============================================================================
# --system: /opt/aios only on request, with sudo (spec 04, Installationen; V0.6, F26)
#===============================================================================

   mkdir -p "$SANDBOX/ro"; chmod a-w "$SANDBOX/ro"
   OUT="$(echo y | AIOS_SUDO="$SANDBOX/fake/no-sudo" AIOS_PREFIX="$SANDBOX/ro/opt/aios" "$S/bin/aios" --install v0.1.0 --system 2>&1)"; RC=$?
   assert_eq "$RC" "1" "--system without sudo: exit 1"
   assert_contains "$OUT" "--system needs sudo" "--system without sudo: message"
   [ ! -e "$SANDBOX/ro/opt/aios" ] && ok || fail "--system without sudo: nothing written"

   printf '#!/bin/bash\nchmod u+w "%s"; "$@"; RC=$?; chmod a-w "%s"; exit $RC\n' "$SANDBOX/ro" "$SANDBOX/ro" > "$SANDBOX/fake/fake-sudo"
   chmod +x "$SANDBOX/fake/fake-sudo"
   OUT="$(echo y | AIOS_SUDO="$SANDBOX/fake/fake-sudo" AIOS_PREFIX="$SANDBOX/ro/sys/aios" "$S/bin/aios" --install v0.1.0 --system 2>&1)"; RC=$?
   assert_eq "$RC" "0" "--system with sudo: exit 0"
   assert_contains "$OUT" "sudo may ask for your password" "--system: plan warns about the password"
   assert_file "$SANDBOX/ro/sys/aios/v0.1.0/VERSION"
   assert_eq "$(cat "$SANDBOX/ro/sys/aios/installations.yaml")" "v0.1.0: $SANDBOX/ro/sys/aios/v0.1.0" "--system: entry in the installations.yaml of /opt/aios"
   OUT="$(echo y | AIOS_SUDO="$SANDBOX/fake/fake-sudo" AIOS_PREFIX="$SANDBOX/ro/sudo/aios" "$S/bin/aios" --prepare 2>&1)"
   assert_contains "$OUT" "sudo may ask for your password" "--prepare (legacy): plan warns about the password"
   assert_dir "$SANDBOX/ro/sudo/aios"

#===============================================================================
# broken settings.json: abort before anything is written
#===============================================================================

   echo "{ broken" > "$SET"; rm -f "$F"
   OUT="$(echo y | "$S/bin/aios" --install v0.2.0 2>&1)"; RC=$?
   assert_eq "$RC" "1" "invalid settings.json: exit 1"
   assert_contains "$OUT" "is not valid JSON" "invalid settings.json: message"
   [ ! -e "$F" ] && [ "$(cat "$SET")" == "{ broken" ] && ok || fail "invalid settings.json: nothing written"

#===============================================================================
# documentation in the installation (step 11)
#===============================================================================

   for SP in "$S"/spec/0*.md; do
      F="$(basename "$SP")"
      [ -f "$I/doc/spec/$F" ] && assert_eq "$(cat "$I/doc/spec/$F")" "$(cat "$SP")" "doc/spec: $F" || fail "doc/spec: $F missing"
   done

#===============================================================================
# v0.6 step 7: changeover of a v0.5.1 setup - hooks in place with the absolute path, PreToolUse,
# ~/bin and the global wrappers stay, vaults named, legacy marker with its own question
# (spec 04, Umstieg auf v0.6; V0.6, memos 17, 19, 24, 49)
#===============================================================================

   cat > "$SET" <<'EOF2'
{
  "hooks": {
    "SessionStart": [ { "hooks": [ { "type": "command", "command": "other --hook" } ] },
                      { "hooks": [ { "type": "command", "command": "aios --context --session" } ] } ],
    "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "aios --context --advise" } ] } ]
  }
}
EOF2
   mkdir -p "$AIOS_CLAUDE_DIR/skills/aios-init" "$AIOS_CLAUDE_DIR/skills/gui" "$AIOS_CLAUDE_DIR/skills/synced"
   printf -- '---\nname: aios-init\n---\n\n!`aios --skill aios-init`\n' > "$AIOS_CLAUDE_DIR/skills/aios-init/SKILL.md"
   printf -- '---\nname: gui\n---\n\n!`aios --gui --session ${CLAUDE_SESSION_ID}`\n' > "$AIOS_CLAUDE_DIR/skills/gui/SKILL.md"
   printf 'mine\n' > "$AIOS_CLAUDE_DIR/skills/synced/SKILL.md"
   V5="$SANDBOX/work/§Alt5"; NB="$SANDBOX/work/§Nachbar"
   mkdir -p "$V5/.aios" "$V5/G-Garten" "$NB/@" "$HOME/.aios/sessions" "$SANDBOX/fake"
   printf 'aios: 0.5.1\n' > "$V5/.aios/config.yaml"
   printf 'cwd: "%s"\nassistant: none\nused: 2026-10-25T10:00:00\n' "$V5/G-Garten" > "$HOME/.aios/sessions/s5.yaml"
   printf '#!/bin/bash\necho ai-brain\n' > "$SANDBOX/fake/ai-brain"; chmod +x "$SANDBOX/fake/ai-brain"
   G -C "$S" tag v0.6.0; F="$HOME/.aios/bin/aios"
   OUT="$("$S/bin/aios" --install v0.6.0 --plan 2>&1)"
   assert_contains "$OUT" "$F --context --session (in place of aios --context --session)" "v0.6: hook replaced in place"
   assert_contains "$OUT" "$F --context --permit" "v0.6: PreToolUse added"
   assert_contains "$OUT" "vault $V5: binding 0.5.1 below 0.6; change over with: aios --activate v0.6.0 $V5" "v0.6: vault with a binding below 0.6 named"
   assert_contains "$OUT" "(then with its own question: mark $NB with legacy: ai-brain)" "v0.6: sibling without binding offered for legacy: ai-brain"
   case "$OUT" in *"$V5 with legacy"*) fail "v0.6: a bound vault is not offered for the marker" ;; *) ok ;; esac
   OUT="$(printf 'y\ny\n' | "$S/bin/aios" --install v0.6.0 2>&1)"; RC=$?
   assert_eq "$RC" "0" "v0.6: install exit 0"
   assert_eq "$(J "$CMDS" "$SET")" "other --hook $F --context --session $F --context --advise" "v0.6: AIOS hooks at their place with the absolute path, others kept"
   assert_eq "$(head -1 "$NB/.aios/config.yaml")" "legacy: ai-brain" "v0.6: marked after the own question"
   [ -e "$AIOS_CLAUDE_DIR/skills/aios-init" ] && [ -e "$AIOS_CLAUDE_DIR/skills/gui" ] && ok || fail "v0.6: install leaves the global wrappers (a vault is still on 0.5)"
   rm "$NB/.aios/config.yaml"
   OUT="$("$S/bin/aios" --install v0.6.0 --yes 2>&1)"
   assert_contains "$OUT" "not marked: $NB" "v0.6: --yes marks nothing, names the line (F32)"
   [ ! -e "$NB/.aios/config.yaml" ] && ok || fail "v0.6: --yes wrote no marker"
   rm "$SANDBOX/fake/ai-brain"
   OUT="$(echo y | "$S/bin/aios" --uninstall 2>&1)"
   case "$(cat "$SET")" in *"aios --context"*) fail "uninstall: AIOS hooks removed" ;; *) ok ;; esac
   [ ! -e "$AIOS_CLAUDE_DIR/skills/aios-init" ] && [ ! -e "$AIOS_CLAUDE_DIR/skills/gui" ] && [ -e "$AIOS_CLAUDE_DIR/skills/synced" ] && ok || fail "uninstall: wrappers of earlier versions removed, foreign skills kept"

#===============================================================================
# v0.5.1 step 3 (O1): pip of the kernel and of the workhorses without the version notice
#===============================================================================

   for F in install.py worker.py; do
      grep -q -- '"--disable-pip-version-check"' "$SRC/lib/aios/$F" && ok || fail "O1: pip in $F with --disable-pip-version-check"
   done
