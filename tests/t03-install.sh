# t03-install.sh: step 3 of the plan (memo 18) - aios --prepare/--install/--versions/--remove-version/--uninstall

#===============================================================================
# setup: PATH without the real ~/bin, fake stup, no real sudo, no pip, no network
#===============================================================================

   mkdir -p "$SANDBOX/fake" "$SANDBOX/stup-src" "$HOME/bin" "$HOME/etc/aios"
   export PATH="$HOME/bin:$SANDBOX/fake:/usr/bin:/bin:/usr/sbin:/sbin"
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

   P="$AIOS_PREFIX"
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
# --install: errors, cancel, highest release tag
#===============================================================================

   assert_contains "$("$S/bin/aios" --install v9.9.9 2>&1)" "no tag v9.9.9" "unknown version"
   assert_exit 1 "$S/bin/aios" --install v9.9.9

   OUT="$(echo n | "$S/bin/aios" --install 2>&1)"
   assert_contains "$OUT" "install v0.2.0 from $S" "highest release tag, rc ignored"
   assert_contains "$OUT" "replaces the prototype" "plan: prototype"
   assert_contains "$OUT" "remove the ai-brain hooks" "plan: hooks"
   [ ! -e "$P/v0.2.0" ] && cmp -s "$SET" "$SANDBOX/settings.orig" && ok || fail "install cancelled: nothing written"

   OUT="$(echo y | "$S/bin/aios" --install 2>&1)"; RC=$?
   assert_eq "$RC" "0" "install v0.2.0: exit 0"

#===============================================================================
# --install: installation directory (spec 04, Abbildung)
#===============================================================================

   I="$P/v0.2.0"
   assert_eq "$(cat "$I/VERSION")" "0.2.0" "VERSION of the tag"
   for F in bin/aios bin/aios-context lib/aios/install.py templates/forwarder templates/gitignore \
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
   assert_eq "$(cat "$P/installations.yaml")" "v0.2.0: $I" "installations.yaml"

#===============================================================================
# --install: user setup
#===============================================================================

   assert_contains "$(cat "$HOME/bin/aios")" "# forwarder: ~/bin/aios" "prototype replaced by the forwarder"
   assert_exec "$HOME/bin/aios-context"
   [ ! -e "$HOME/etc/aios" ] && ok || fail "~/etc/aios of the prototype removed"
   assert_eq "$(cat "$HOME/.aios/config.yaml")" "hosts: [claude-code]" "~/.aios/config.yaml"
   assert_eq "$(cat "$HOME/.aios/repo")" "$S" "~/.aios/repo"
   J() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print($1)" "$2"; }
   CMDS='" ".join(h["command"] for e in ("SessionStart","UserPromptSubmit") for g in d.get("hooks",{}).get(e,[]) for h in g["hooks"])'
   assert_eq "$(J "$CMDS" "$SET")" 'aios-context --session python3 "/x/zeiterfassung.py" export --quiet aios-context --advise' "hooks: AIOS in, ai-brain out, others kept"
   assert_eq "$(J 'd["model"]' "$SET")" "opus" "other settings kept"
   assert_eq "$(J "$CMDS" "$HOME/.aios/hooks-backup.json")" "ai-brain --session ai-brain --advise" "ai-brain hooks saved"
   W="$AIOS_CLAUDE_DIR/skills/aios-demo/SKILL.md"
   assert_contains "$(cat "$W")" 'description: "Demo skill of AIOS, two lines."' "wrapper: description from the version"
   assert_contains "$(cat "$W")" '!`aios --skill aios-demo`' "wrapper: body"
   [ ! -e "$AIOS_CLAUDE_DIR/skills/memo" ] && ok || fail "basic skills are not registered by --install"
   assert_contains "$(cat "$AIOS_CLAUDE_DIR/skills/gui/SKILL.md" 2>/dev/null)" '!`aios --gui --session ${CLAUDE_SESSION_ID}`' "install: alias /gui"

   assert_eq "$(cd "$SANDBOX" && aios --version)" "0.2.0" "forwarder: not activated, highest version"
   assert_contains "$(cd "$SANDBOX" && aios --versions)" "v0.2.0" "--versions"

#===============================================================================
# --install via the forwarder: older version, idempotent user setup
#===============================================================================

   cp "$SET" "$SANDBOX/settings.1"; cp "$HOME/.aios/hooks-backup.json" "$SANDBOX/backup.1"
   OUT="$(cd "$SANDBOX" && echo y | aios --install v0.1.0 2>&1)"; RC=$?
   assert_eq "$RC" "0" "install v0.1.0 via forwarder (clone from ~/.aios/repo)"
   assert_eq "$(sed -n 's/^version: //p' "$P/v0.1.0/manifest.yaml")" "0.1.0" "v0.1.0: manifest.yaml with the version of the tag"
   cmp -s "$SET" "$SANDBOX/settings.1" && cmp -s "$HOME/.aios/hooks-backup.json" "$SANDBOX/backup.1" && ok || fail "second install: hooks and backup unchanged"
   assert_eq "$(cd "$SANDBOX" && aios --install v0.1.0 </dev/null 2>&1)" "=> AIbex AIOS v0.1.0: nothing to do" "installed version: nothing to do, no question"
   assert_eq "$(cd "$SANDBOX" && aios --version)" "0.2.0" "forwarder still calls the highest version"

#===============================================================================
# --remove-version: installation directory and clone entry
#===============================================================================

   OUT="$(cd "$SANDBOX" && echo n | aios --remove-version v0.1.0 2>&1)"
   assert_dir "$P/v0.1.0"
   OUT="$(cd "$SANDBOX" && echo y | aios --remove-version v0.1.0 2>&1)"; RC=$?
   assert_eq "$RC" "0" "remove-version: exit 0"
   [ ! -e "$P/v0.1.0" ] && ok || fail "v0.1.0 removed"
   assert_eq "$(cat "$P/installations.yaml")" "v0.2.0: $I" "entry removed"

   printf 'v0.3.0-dev: "%s"\n' "$S" > "$HOME/.aios/installations.yaml"
   OUT="$(cd "$SANDBOX" && echo y | aios --remove-version v0.3.0-dev 2>&1)"
   assert_contains "$OUT" "is not an installation directory, it is kept" "clone entry: directory kept"
   assert_file "$S/bin/aios"
   assert_eq "$(cat "$HOME/.aios/installations.yaml")" "" "clone entry removed"
   assert_exit 1 "$S/bin/aios" --remove-version v7.0.0

#===============================================================================
# --uninstall: user setup removed, ai-brain hooks restored, installations kept
#===============================================================================

   OUT="$(echo y | "$S/bin/aios" --uninstall 2>&1)"; RC=$?
   assert_eq "$RC" "0" "uninstall: exit 0"
   [ ! -e "$HOME/bin/aios" ] && [ ! -e "$HOME/bin/aios-context" ] && ok || fail "forwarders removed"
   [ ! -e "$AIOS_CLAUDE_DIR/skills/aios-demo" ] && ok || fail "AIOS skill removed"
   [ ! -e "$AIOS_CLAUDE_DIR/skills/gui" ] && ok || fail "uninstall: alias /gui removed"
   [ ! -e "$HOME/.aios/hooks-backup.json" ] && ok || fail "backup removed"
   assert_eq "$(J "$CMDS" "$SET")" 'ai-brain --session python3 "/x/zeiterfassung.py" export --quiet ai-brain --advise' "ai-brain hooks restored"
   assert_dir "$I"
   assert_file "$HOME/.aios/config.yaml"
   assert_eq "$("$S/bin/aios" --uninstall </dev/null 2>&1)" "=> nothing to uninstall" "uninstall again: nothing to do"

#===============================================================================
# without sudo: /opt/aios not writable -> ~/.aios/versions
#===============================================================================

   mkdir -p "$SANDBOX/ro"; chmod a-w "$SANDBOX/ro"
   OUT="$(echo y | AIOS_PREFIX="$SANDBOX/ro/opt/aios" "$S/bin/aios" --install v0.1.0 2>&1)"; RC=$?
   assert_eq "$RC" "0" "install without sudo: exit 0"
   assert_contains "$OUT" "no sudo: installations go to $HOME/.aios/versions" "plan names the fallback"
   assert_file "$HOME/.aios/versions/v0.1.0/VERSION"
   assert_eq "$(cat "$HOME/.aios/installations.yaml")" "v0.1.0: $HOME/.aios/versions/v0.1.0" "entry in ~/.aios/installations.yaml"
   assert_eq "$(cd "$SANDBOX" && AIOS_PREFIX="$SANDBOX/ro/opt/aios" "$HOME/bin/aios" ---which | sed 's/.*kind=//; s/ .*//')" "aios" "forwarder finds the fallback installation"

#===============================================================================
# with sudo: the plan says so and sudo creates /opt/aios
#===============================================================================

   cat > "$SANDBOX/fake/fake-sudo" <<EOF
#!/bin/bash
chmod u+w "$SANDBOX/ro"; "\$@"; RC=\$?; chmod a-w "$SANDBOX/ro"; exit \$RC
EOF
   chmod +x "$SANDBOX/fake/fake-sudo"
   OUT="$(echo y | AIOS_SUDO="$SANDBOX/fake/fake-sudo" AIOS_PREFIX="$SANDBOX/ro/sudo/aios" "$S/bin/aios" --prepare 2>&1)"
   assert_contains "$OUT" "sudo may ask for your password" "plan warns about the password"
   assert_dir "$SANDBOX/ro/sudo/aios"

#===============================================================================
# broken settings.json: abort before anything is written
#===============================================================================

   echo "{ broken" > "$SET"; rm "$HOME/bin/aios-context"
   OUT="$(echo y | "$S/bin/aios" --install v0.2.0 2>&1)"; RC=$?
   assert_eq "$RC" "1" "invalid settings.json: exit 1"
   assert_contains "$OUT" "is not valid JSON" "invalid settings.json: message"
   [ ! -e "$HOME/bin/aios-context" ] && [ "$(cat "$SET")" == "{ broken" ] && ok || fail "invalid settings.json: nothing written"

#===============================================================================
# documentation in the installation (step 11)
#===============================================================================

   for P in "$S"/spec/0*.md; do
      F="$(basename "$P")"
      [ -f "$I/doc/spec/$F" ] && assert_eq "$(cat "$I/doc/spec/$F")" "$(cat "$P")" "doc/spec: $F" || fail "doc/spec: $F missing"
   done
