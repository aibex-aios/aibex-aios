# t02-forwarder.sh: forwarder (spec 04); v0.5 step 1: aios --context; v0.6 step 2: forwarder 0.4.0 (vault root only, legacy: ai-brain)

#===============================================================================
# setup: forwarders in ~/bin, fake installations, fake ai-brain, PATH without real ~/bin
#===============================================================================

   mkdir -p "$HOME/bin" "$HOME/.aios" "$SANDBOX/fake"
   cp "$SRC/templates/forwarder" "$HOME/bin/aios"
   chmod +x "$HOME/bin/aios"
   export PATH="$HOME/bin:$SANDBOX/fake:/usr/bin:/bin:/usr/sbin:/sbin"

   fake_install() {                                 # fake_install <dir> <label>
      mkdir -p "$1/bin"
      for T in aios; do
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

   assert_eq "$(aios ---version)" "0.4.0" "---version"
   assert_exit 1 aios ---help
   assert_contains "$(aios ---help)" "aios ---which" "---help names the tool"

   AIOS_HOME="$AIOS_PREFIX/v0.2.0" assert_eq "$(AIOS_HOME="$AIOS_PREFIX/v0.2.0" run "$V" aios -? "a b")" "sys-0.2.0 aios -? a b" "arguments passed unchanged"

#===============================================================================
# rank 1: AIOS_HOME
#===============================================================================

   printf 'aios: 0.1.0\n' > "$V/.aios.tmp"; mkdir -p "$V/.aios"; mv "$V/.aios.tmp" "$V/.aios/config.yaml"
   assert_eq "$(AIOS_HOME="$HOME/dev/v0.10.0" run "$V/Garten" aios --x)" "dev-0.10.0 aios --x" "AIOS_HOME beats the chain (aios)"
   assert_eq "$(AIOS_HOME="$HOME/dev/v0.10.0" run "$SANDBOX/outside" aios --context --id)" "dev-0.10.0 aios --context --id" "AIOS_HOME outside a vault (aios --context)"
   assert_exit 1 env AIOS_HOME="$SANDBOX/nowhere" aios --x

#===============================================================================
# binding only at the vault root (spec 04, Weiterleiter; I14)
#===============================================================================

   assert_eq "$(run "$V/Garten/Beet/tief" aios --context --id)" "sys-0.1.0 aios --context --id" "vault config, deep cwd"
   assert_eq "$(run "$V" aios --y)" "sys-0.1.0 aios --y" "vault config, cwd = vault root"

   mkdir -p "$V/Garten/.aios"; printf 'skills:\n  memo: 6.0.0\naios: "0.2.0"   # quoted\n' > "$V/Garten/.aios/config.yaml"
   assert_eq "$(run "$V/Garten/Beet" aios --context --id)" "sys-0.1.0 aios --context --id" "project config does not bind (I14)"
   printf 'aios: "0.2.0"   # quoted\n' > "$V/.aios/config.yaml"
   assert_eq "$(run "$V/Sterne" aios --context --id)" "sys-0.2.0 aios --context --id" "quoted version at the vault root"
   printf 'aios: 0.1.0\n' > "$V/.aios/config.yaml"

#===============================================================================
# user installations.yaml wins over the system one, ~ and quotes are resolved
#===============================================================================

   printf 'v0.1.0: "~/dev/aios clone"\n' > "$HOME/.aios/installations.yaml"
   assert_eq "$(run "$V/Sterne" aios --context --id)" "dev-0.1.0 aios --context --id" "user entry wins, ~ expanded"
   assert_contains "$(run "$V/Sterne" aios ---which)" "why=aios: 0.1.0 in $V/.aios/config.yaml" "---which explains"

#===============================================================================
# bound, but version not installed: --context quiet with a line in the log, else exit 1
#===============================================================================

   printf 'aios: 0.9.0\n' > "$V/.aios/config.yaml"
   OUT="$(run "$V/Sterne" aios --context --session)"; RC=$?
   assert_eq "$RC:$OUT" "0:" "missing version: hook quiet, exit 0"
   assert_contains "$(cat "$HOME/.aios/log/context.log")" "forwarder cwd=$V/Sterne AIOS v0.9.0 is not installed" "missing version: line in the log"
   assert_eq "$(run "$V/Sterne" aios --context --id)" "id=- files=0 cwd=$V/Sterne mode=none" "missing version: --id mode=none"
   OUT="$(run "$V/Sterne" aios --fetch)"; RC=$?
   assert_eq "$RC" "1" "missing version, other command: exit 1"
   assert_contains "$OUT" "aios --install v0.9.0" "missing version, other command: hint"

#===============================================================================
# no binding: quiet, legacy only with legacy: ai-brain at the vault root
#===============================================================================

   rm -rf "$V/.aios" "$V/Garten/.aios"
   printf 'aios: 0.1.0\n' > "$SANDBOX/work/.aios/config.yaml"
   printf 'aios: 0.1.0\n' > "$HOME/.aios/config.yaml"
   OUT="$(run "$V/Garten" aios --context --session)"; RC=$?
   assert_eq "$RC:$OUT" "0:" "vault without binding: no output (I12)"
   assert_eq "$(run "$SANDBOX/outside" aios --context --advise)" "" "outside a vault: no output"
   assert_eq "$(run "$V/Garten" aios --context --id)" "id=- files=0 cwd=$V/Garten mode=none" "vault without binding: mode=none"
   assert_eq "$(run "$SANDBOX/outside" aios --context --list)" "No AIBOS workspace — no master context." "--list outside an A/W"
   assert_eq "$(run "$V/Garten" aios --fetch)" "sys-0.2.0 aios --fetch" "other commands: the highest version"
   mkdir -p "$V/Garten/.aios"; printf 'legacy: ai-brain\n' > "$V/Garten/.aios/config.yaml"
   assert_eq "$(run "$V/Garten" aios --context --session)" "" "legacy: in a project does not mark (I14)"
   rm -rf "$V/Garten/.aios"

   mkdir -p "$V/.aios"; printf 'legacy: ai-brain\n' > "$V/.aios/config.yaml"
   assert_eq "$(run "$V/Garten" aios --context --session)" "ai-brain --session" "legacy: ai-brain with same arguments"
   assert_eq "$(run "$V/Garten" aios --context)" "ai-brain --context" "legacy: aios --context is ai-brain --context"
   assert_eq "$(run "$V/Garten" aios --context "$V/Garten")" "ai-brain --context" "legacy: path argument, ai-brain gets no path"
   assert_eq "$(run "$V/Garten" aios --context --permit)" "" "legacy: no permission from ai-brain"
   mkdir -p "$V/Anderes/sub"
   assert_eq "$(HOME="$V/Anderes" run "$V/Anderes/sub" "$HOME/bin/aios" --context)" "ai-brain --context" "~/.aios/config.yaml never binds, even inside a vault"

   printf '#!/bin/bash\n[ "$*" == "--id" ] && echo "id=abcd1234 files=3 cwd=$PWD" || echo "ai-brain $*"\n' > "$SANDBOX/fake/ai-brain"
   assert_eq "$(run "$V/Garten" aios --context --id)" "id=abcd1234 files=3 cwd=$V/Garten mode=legacy" "legacy --id: ai-brain output plus mode=legacy"
   assert_eq "$(run "$SANDBOX/outside" aios --context --id)" "id=- files=0 cwd=$SANDBOX/outside mode=none" "--id outside a vault: mode=none"
   A2="$SANDBOX/work/§Aktiv"; mkdir -p "$A2/.aios" "$A2/@"; printf 'aios: 0.1.0\n' > "$A2/.aios/config.yaml"
   assert_eq "$(run "$SANDBOX/outside" aios --context --id "$A2")" "dev-0.1.0 aios --context --id $A2" "path argument: version follows the path, not cwd"
   assert_eq "$(run "$A2" aios --context --id "$V/Garten")" "id=abcd1234 files=3 cwd=$V/Garten mode=legacy" "path argument: legacy path, ai-brain runs in it"
   assert_eq "$(run "$A2" aios --context --load "$V/Garten")" "ai-brain --load" "path argument: ai-brain gets no path"
   assert_eq "$(run "$A2" aios --context --id "$SANDBOX/outside")" "id=- files=0 cwd=$SANDBOX/outside mode=none" "path argument: quiet path"
   assert_eq "$(run "$V/Garten" aios --context --list)" "Legacy mode (ai-brain, legacy: ai-brain at the vault root) — see /masterspace." "legacy --list"
   rm -rf "$A2"
   rm "$SANDBOX/fake/ai-brain"
   assert_eq "$(run "$V/Garten" aios --context --id)" "id=- files=0 cwd=$V/Garten mode=legacy" "legacy --id without ai-brain"
   OUT="$(run "$V/Garten" aios --context --session)"; RC=$?
   assert_eq "$RC:$OUT" "0:" "legacy without ai-brain: no output, exit 0"
   rm -rf "$V/.aios"

#===============================================================================
# not bound: aios calls the highest installed version (semver)
#===============================================================================

   printf 'v0.10.0: %s\nv0.2.0-dev: %s\n' "$HOME/dev/v0.10.0" "$HOME/dev/v0.2.0-dev" > "$HOME/.aios/installations.yaml"
   assert_eq "$(run "$V/Garten" aios --z)" "dev-0.10.0 aios --z" "0.10.0 is higher than 0.2.0"

   printf 'v0.2.0-dev: %s\n' "$HOME/dev/v0.2.0-dev" > "$HOME/.aios/installations.yaml"
   assert_eq "$(run "$SANDBOX/outside" aios --z)" "sys-0.2.0 aios --z" "0.2.0 is higher than 0.2.0-dev"

#===============================================================================
# aios --activate v<version>: that version, whatever cwd is bound to (V0.3, memo 54, A1)
#===============================================================================

   mkdir -p "$V/.aios"; printf 'aios: 0.1.0\n' > "$V/.aios/config.yaml"
   assert_eq "$(run "$V/Sterne" aios --z)" "sys-0.1.0 aios --z" "bound vault: its version"
   assert_eq "$(run "$V/Sterne" aios --activate v0.2.0 /x)" "sys-0.2.0 aios --activate v0.2.0 /x" "--activate v0.2.0 from a 0.1.0 vault: v0.2.0"
   assert_contains "$(run "$V/Sterne" aios ---which)" "why=aios: 0.1.0" "---which: other commands follow cwd"
   assert_eq "$(run "$V/Sterne" aios --activate v9.9.9 /x)" "sys-0.1.0 aios --activate v9.9.9 /x" "--activate of a version not installed: cwd decides (it reports the missing version)"
   assert_eq "$(run "$V/Sterne" aios --context --activate v0.2.0)" "sys-0.1.0 aios --context --activate v0.2.0" "only aios --activate, not aios --context --activate"

#===============================================================================
# aios --install distribution-*: the highest installed version, at least 0.5 (V0.5, step 9)
#===============================================================================

   OUT="$(run "$V/Sterne" aios --install distribution-demo)"; RC=$?
   assert_eq "$RC" "1" "distribution below 0.5: exit 1"
   assert_contains "$OUT" "distributions need AIOS 0.5 or later, highest installed v0.2.0" "distribution below 0.5: message"
   fake_install "$AIOS_PREFIX/v0.5.0" "sys-0.5.0"
   printf 'v0.5.0: %s\n' "$AIOS_PREFIX/v0.5.0" >> "$AIOS_PREFIX/installations.yaml"
   assert_eq "$(run "$V/Sterne" aios --install distribution-demo "$V")" "sys-0.5.0 aios --install distribution-demo $V" "distribution: highest version, not that of cwd"
   assert_eq "$(run "$V/Sterne" aios --install aibex-aios/distribution-demo==1.0.0)" "sys-0.5.0 aios --install aibex-aios/distribution-demo==1.0.0" "distribution with hub and version"
   assert_eq "$(run "$V/Sterne" aios --install v0.2.0)" "sys-0.1.0 aios --install v0.2.0" "--install of a version: cwd decides as before"
   rm -rf "$V/.aios" "$AIOS_PREFIX/v0.5.0"

#===============================================================================
# aios --context with a version below 0.5: its aios-context (V0.5, memo 63, B3)
#===============================================================================

   fake_install "$AIOS_PREFIX/v0.4.0" "sys-0.4.0"; echo "0.4.0" > "$AIOS_PREFIX/v0.4.0/VERSION"
   printf '#!/bin/bash\necho "sys-0.4.0 aios-context $*"\n' > "$AIOS_PREFIX/v0.4.0/bin/aios-context"
   chmod +x "$AIOS_PREFIX/v0.4.0/bin/aios-context"
   printf 'v0.4.0: %s\n' "$AIOS_PREFIX/v0.4.0" >> "$AIOS_PREFIX/installations.yaml"
   mkdir -p "$V/.aios"; printf 'aios: 0.4.0\n' > "$V/.aios/config.yaml"
   assert_eq "$(run "$V/Sterne" aios --context --session)" "sys-0.4.0 aios-context --session" "0.4: aios --context --session -> aios-context --session"
   assert_eq "$(run "$V/Sterne" aios --context)" "sys-0.4.0 aios-context " "0.4: aios --context -> aios-context (no arguments)"
   assert_eq "$(run "$V/Sterne" aios --fetch)" "sys-0.4.0 aios --fetch" "0.4: other commands unchanged"
   echo "0.5.0" > "$AIOS_PREFIX/v0.4.0/VERSION"
   assert_eq "$(run "$V/Sterne" aios --context --session)" "sys-0.4.0 aios --context --session" "0.5 or later: aios --context stays"
   rm -rf "$V/.aios" "$AIOS_PREFIX/v0.4.0"

   rm -f "$HOME/.aios/installations.yaml" "$AIOS_PREFIX/installations.yaml"
   assert_exit 1 aios --z
   assert_contains "$(aios --z 2>&1)" "no installation of AIOS found" "no installation: message"
