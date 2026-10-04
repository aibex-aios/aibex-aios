# t02-forwarder.sh: step 2 of the plan (memo 18) - forwarders ~/bin/aios, ~/bin/aios-context (spec 04)

#===============================================================================
# setup: forwarders in ~/bin, fake installations, fake ai-brain, PATH without real ~/bin
#===============================================================================

   mkdir -p "$HOME/bin" "$HOME/.aios" "$SANDBOX/fake"
   cp "$SRC/templates/forwarder" "$HOME/bin/aios"
   cp "$SRC/templates/forwarder" "$HOME/bin/aios-context"
   chmod +x "$HOME/bin/aios" "$HOME/bin/aios-context"
   export PATH="$HOME/bin:$SANDBOX/fake:/usr/bin:/bin:/usr/sbin:/sbin"

   fake_install() {                                 # fake_install <dir> <label>
      mkdir -p "$1/bin"
      for T in aios aios-context; do
         printf '#!/bin/bash\necho "%s %s $*"\n' "$2" "$T" > "$1/bin/$T"
         chmod +x "$1/bin/$T"
      done
   }
   fake_install "$AIOS_PREFIX/v0.1.0" "sys-0.1.0"
   fake_install "$AIOS_PREFIX/v0.2.0" "sys-0.2.0"
   fake_install "$HOME/dev/aios clone" "dev-0.1.0"
   fake_install "$HOME/dev/v0.10.0" "dev-0.10.0"
   fake_install "$HOME/dev/v0.2.0-dev" "dev-0.2.0-dev"

   printf 'v0.1.0: %s\nv0.2.0: %s\n' "$AIOS_PREFIX/v0.1.0" "$AIOS_PREFIX/v0.2.0" > "$AIOS_PREFIX/installations.yaml"
   printf '#!/bin/bash\necho "ai-brain $*"\n' > "$SANDBOX/fake/ai-brain"; chmod +x "$SANDBOX/fake/ai-brain"

   V="$SANDBOX/work/§Demo Vault"                    # vault root with space in its name
   mkdir -p "$V/@" "$V/Garten/@" "$V/Garten/Beet/tief" "$V/Sterne/@" "$V/Anderes/@"
   mkdir -p "$SANDBOX/work/.aios" "$SANDBOX/outside"

   run() { (cd "$1" && shift && "$@" 2>&1); }       # run <dir> <command...>

#===============================================================================
# forwarder: own options, arguments passed unchanged
#===============================================================================

   assert_eq "$(aios ---version)" "0.1.4" "---version"
   assert_exit 1 aios ---help
   assert_contains "$(aios-context ---help)" "aios-context ---which" "---help names the tool"

   AIOS_HOME="$AIOS_PREFIX/v0.2.0" assert_eq "$(AIOS_HOME="$AIOS_PREFIX/v0.2.0" run "$V" aios -? "a b")" "sys-0.2.0 aios -? a b" "arguments passed unchanged"

#===============================================================================
# rank 1: AIOS_HOME
#===============================================================================

   printf 'aios: 0.1.0\n' > "$V/.aios.tmp"; mkdir -p "$V/.aios"; mv "$V/.aios.tmp" "$V/.aios/config.yaml"
   assert_eq "$(AIOS_HOME="$HOME/dev/v0.10.0" run "$V/Garten" aios --x)" "dev-0.10.0 aios --x" "AIOS_HOME beats the chain (aios)"
   assert_eq "$(AIOS_HOME="$HOME/dev/v0.10.0" run "$SANDBOX/outside" aios-context --id)" "dev-0.10.0 aios-context --id" "AIOS_HOME outside a vault (aios-context)"
   assert_exit 1 env AIOS_HOME="$SANDBOX/nowhere" aios --x

#===============================================================================
# rank 2-4: chain up to the vault root, nearest wins
#===============================================================================

   assert_eq "$(run "$V/Garten/Beet/tief" aios-context --id)" "sys-0.1.0 aios-context --id" "vault config, deep cwd"
   assert_eq "$(run "$V" aios --y)" "sys-0.1.0 aios --y" "vault config, cwd = vault root"

   mkdir -p "$V/Garten/.aios"; printf 'skills:\n  memo: 6.0.0\naios: "0.2.0"   # quoted\n' > "$V/Garten/.aios/config.yaml"
   assert_eq "$(run "$V/Garten/Beet" aios-context --id)" "sys-0.2.0 aios-context --id" "project config beats vault config"
   assert_eq "$(run "$V/Sterne" aios-context --id)" "sys-0.1.0 aios-context --id" "sibling project keeps vault config"

   mkdir -p "$V/Anderes/.aios"; printf 'hosts: [claude-code]\n' > "$V/Anderes/.aios/config.yaml"
   assert_eq "$(run "$V/Anderes" aios-context --id)" "sys-0.1.0 aios-context --id" "config without aios: is skipped"

#===============================================================================
# user installations.yaml wins over the system one, ~ and quotes are resolved
#===============================================================================

   printf 'v0.1.0: "~/dev/aios clone"\n' > "$HOME/.aios/installations.yaml"
   assert_eq "$(run "$V/Sterne" aios-context --id)" "dev-0.1.0 aios-context --id" "user entry wins, ~ expanded"
   assert_contains "$(run "$V/Sterne" aios-context ---which)" "why=aios: 0.1.0 in $V/.aios/config.yaml" "---which explains"

#===============================================================================
# activated, but version not installed
#===============================================================================

   printf 'aios: 0.9.0\n' > "$V/Sterne/.aios.yaml"; mkdir -p "$V/Sterne/.aios"; mv "$V/Sterne/.aios.yaml" "$V/Sterne/.aios/config.yaml"
   OUT="$(run "$V/Sterne" aios-context --session)"; RC=$?
   assert_eq "$RC" "1" "missing version: exit 1"
   assert_contains "$OUT" "aios --install v0.9.0" "missing version: hint"

#===============================================================================
# not activated: configs above the vault root and in ~/.aios never activate
#===============================================================================

   rm -rf "$V/.aios" "$V/Garten/.aios" "$V/Sterne/.aios"
   printf 'aios: 0.1.0\n' > "$SANDBOX/work/.aios/config.yaml"
   printf 'aios: 0.1.0\n' > "$HOME/.aios/config.yaml"
   assert_eq "$(run "$V/Garten" aios-context --session)" "ai-brain --session" "legacy: ai-brain with same arguments"
   assert_eq "$(run "$SANDBOX/outside" aios-context --advise)" "ai-brain --advise" "outside a vault: legacy"
   mkdir -p "$V/Anderes/.aios" "$V/Anderes/sub"; printf 'aios: 0.1.0\n' > "$V/Anderes/.aios/config.yaml"
   assert_eq "$(HOME="$V/Anderes" run "$V/Anderes/sub" "$HOME/bin/aios-context" --context)" "ai-brain --context" "~/.aios/config.yaml never activates, even inside a vault"
   rm -rf "$V/Anderes/.aios"

   printf '#!/bin/bash\n[ "$*" == "--id" ] && echo "id=abcd1234 files=3 cwd=$PWD" || echo "ai-brain $*"\n' > "$SANDBOX/fake/ai-brain"
   assert_eq "$(run "$V/Garten" aios-context --id)" "id=abcd1234 files=3 cwd=$V/Garten mode=legacy" "legacy --id: ai-brain output plus mode=legacy"
   assert_eq "$(run "$SANDBOX/outside" aios-context --id)" "id=- files=0 cwd=$SANDBOX/outside mode=none" "--id outside a vault: mode=none"
   mkdir -p "$V/Aktiv/.aios" "$V/Aktiv/@"; printf 'aios: 0.1.0\n' > "$V/Aktiv/.aios/config.yaml"
   assert_eq "$(run "$SANDBOX/outside" aios-context --id "$V/Aktiv")" "dev-0.1.0 aios-context --id $V/Aktiv" "path argument: version follows the path, not cwd"
   assert_eq "$(run "$V/Aktiv" aios-context --id "$V/Garten")" "id=abcd1234 files=3 cwd=$V/Garten mode=legacy" "path argument: legacy path, ai-brain runs in it"
   assert_eq "$(run "$V/Aktiv" aios-context --load "$V/Garten")" "ai-brain --load" "path argument: ai-brain gets no path"
   assert_eq "$(run "$V/Garten" aios-context --list)" "Legacy mode (ai-brain, no aios: in the chain) — see /masterspace." "legacy --list"
   assert_eq "$(run "$SANDBOX/outside" aios-context --list)" "No vault — no master context." "--list outside a vault"
   rm -rf "$V/Aktiv"
   rm "$SANDBOX/fake/ai-brain"
   assert_eq "$(run "$V/Garten" aios-context --id)" "id=- files=0 cwd=$V/Garten mode=legacy" "legacy --id without ai-brain"
   OUT="$(run "$V/Garten" aios-context --session)"; RC=$?
   assert_eq "$RC:$OUT" "0:" "legacy without ai-brain: no output, exit 0"

#===============================================================================
# not activated: aios calls the highest installed version (semver)
#===============================================================================

   printf 'v0.10.0: %s\nv0.2.0-dev: %s\n' "$HOME/dev/v0.10.0" "$HOME/dev/v0.2.0-dev" > "$HOME/.aios/installations.yaml"
   assert_eq "$(run "$V/Garten" aios --z)" "dev-0.10.0 aios --z" "0.10.0 is higher than 0.2.0"

   printf 'v0.2.0-dev: %s\n' "$HOME/dev/v0.2.0-dev" > "$HOME/.aios/installations.yaml"
   assert_eq "$(run "$SANDBOX/outside" aios --z)" "sys-0.2.0 aios --z" "0.2.0 is higher than 0.2.0-dev"

#===============================================================================
# aios --activate v<version>: that version, whatever cwd is bound to (V0.3, memo 54, A1)
#===============================================================================

   mkdir -p "$V/Sterne/.aios"; printf 'aios: 0.1.0\n' > "$V/Sterne/.aios/config.yaml"
   assert_eq "$(run "$V/Sterne" aios --z)" "sys-0.1.0 aios --z" "activated project: its version"
   assert_eq "$(run "$V/Sterne" aios --activate v0.2.0 /x)" "sys-0.2.0 aios --activate v0.2.0 /x" "--activate v0.2.0 from a 0.1.0 project: v0.2.0"
   assert_contains "$(run "$V/Sterne" aios ---which)" "why=aios: 0.1.0" "---which: other commands follow cwd"
   assert_eq "$(run "$V/Sterne" aios --activate v9.9.9 /x)" "sys-0.1.0 aios --activate v9.9.9 /x" "--activate of a version not installed: cwd decides (it reports the missing version)"
   assert_eq "$(run "$V/Sterne" aios-context --activate v0.2.0)" "sys-0.1.0 aios-context --activate v0.2.0" "only aios, not aios-context"
   rm -rf "$V/Sterne/.aios"

   rm -f "$HOME/.aios/installations.yaml" "$AIOS_PREFIX/installations.yaml"
   assert_exit 1 aios --z
   assert_contains "$(aios --z 2>&1)" "no installation of AIOS found" "no installation: message"
