# t21-distribution.sh: aios --install distribution-<name> (spec 06, Distributionen; spec 04) - v0.5
# step 9: machine part (kernel from the clone, workhorses) before the vault part (binding with
# changeover, fetching, registering), one per vault with kernel:, without kernel:, upgrade,
# overriding only with only:, --from, failures, removal; v0.5.1 step 2: without PyYAML (B7)

#===============================================================================
# setup: python3 with PyYAML, fake stup, no sudo, no pip for the kernel, sandbox clone with v0.6.0
#===============================================================================

   PYDIR=""
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import yaml, venv, ensurepip" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t21 needs a python3 with PyYAML, venv and ensurepip"
   mkdir -p "$SANDBOX/fake" "$SANDBOX/stup-src" "$HOME/bin" "$AIOS_PREFIX"
   export PATH="$HOME/bin:$PYDIR:$SANDBOX/fake:/usr/bin:/bin:/usr/sbin:/sbin"
   export AIOS_SUDO="$SANDBOX/fake/no-sudo" AIOS_PIP=true AIOS_STUP_URL="file://$SANDBOX/stup-src/stup"
   printf '#!/bin/bash\n[ "$*" == "--version" ] && { echo "9.9"; exit 0; }\n[ "$*" == "--profile" ] && { echo "# profile" > "$BIN/profile.sh"; exit 0; }\nexit 1\n' > "$SANDBOX/stup-src/stup"
   "$SRC/tests/hub/build" "$SANDBOX/hubs" >/dev/null
   export AIOS_HUBS="aibex-aios=file://$SANDBOX/hubs/aibex-aios"
   export AIOS_PIP_FIND_LINKS="$SANDBOX/hubs/wheels"
   S="$SANDBOX/repo"
   (cd "$SRC" && git -c core.quotePath=false ls-files -co --exclude-standard) | while IFS= read -r F; do
      mkdir -p "$S/$(dirname "$F")"; cp -p "$SRC/$F" "$S/$F"
   done
   git -C "$S" init -q; git -C "$S" add -A
   git -C "$S" -c user.name=t -c user.email=t@t commit -q -m v0.6.0; git -C "$S" tag v0.6.0
   S="$(cd "$S" && pwd -P)"
   W="$HOME/.aios/workers/worker-test/v0.1.1"; K="$HOME/.aios/versions"   # V0.6, F26, F35
   I() { local v="$1"; shift; (cd "$v" && "$S/bin/aios" --install "$@" 2>&1); }
   V="$SANDBOX/work/§Rothirsch"; mkdir -p "$V"

#===============================================================================
# plan: machine part first (kernel, workhorses), then the vault part; nothing written
#===============================================================================

   OUT="$(I "$V" 'distribution-demo==1.0.0' --plan)"
   assert_contains "$OUT" "=> install distribution-demo 1.0.0 into $V (kernel 0.6.0)" "plan: title"
   assert_contains "$OUT" "(machine part: kernel and workhorses)" "plan: machine part"
   assert_contains "$OUT" "install AIOS v0.6.0 from $S -> $K/v0.6.0 (read-only)" "plan: kernel from the clone"
   assert_contains "$OUT" "setup      worker-test 0.1.1 -> $W" "plan: workhorse of a package of the distribution"
   assert_contains "$OUT" "(vault part: $V)" "plan: vault part"
   assert_contains "$OUT" "create $V/.aios/config.yaml with aios: 0.6.0" "plan: binding of the vault root"
   assert_contains "$OUT" "new        distribution-demo 1.0.0" "plan: the distribution"
   assert_contains "$OUT" "new        skill-test-nutzer 0.1.0" "plan: its package"
   [ "$(printf '%s\n' "$OUT" | grep -n 'machine part' | cut -d: -f1)" -lt "$(printf '%s\n' "$OUT" | grep -n 'vault part' | cut -d: -f1)" ] \
      && ok || fail "plan: machine part before the vault part"
   [ ! -e "$K/v0.6.0" ] && [ ! -e "$V/.aios" ] && [ ! -e "$W" ] && ok || fail "plan: nothing written"
   OUT="$(AIOS_PREFIX="$SANDBOX/opt-neu" I "$V" 'distribution-demo==1.0.0' --plan)"     # V0.6: /opt only with --system
   assert_not_contains "$OUT" "$SANDBOX/opt-neu" "distribution: nothing under /opt/aios"
   [ ! -e "$SANDBOX/opt-neu" ] && ok || fail "distribution: /opt/aios not created"

#===============================================================================
# install: kernel, workhorse, binding, packages: and lock.yaml of the vault root
#===============================================================================

   OUT="$(I "$V" 'distribution-demo==1.0.0' --yes)"; RC=$?
   assert_eq "$RC" "0" "install: exit 0"
   assert_dir "$K/v0.6.0"
   assert_exec "$W/bin/aios-test-tool"
   C="$(cat "$V/.aios/config.yaml")"
   assert_contains "$C" "aios: 0.6.0" "vault root bound to the kernel"
   assert_contains "$C" 'distribution-demo: "==1.0.0"' "packages: the distribution with its exact version"
   assert_contains "$(cat "$V/.aios/lock.yaml")" "required_by: [distribution-demo]" "lock.yaml: package required by the distribution"
   assert_file "$V/.claude/skills/nutzer/SKILL.md"                  # vault root of the session, bound in the same plan
   assert_eq "$(cd "$V" && "$HOME/.aios/bin/aios-test-tool")" "aios-test-tool 1.1.0" "workhorse of the distribution runs in the vault"
   assert_contains "$(I "$V" 'distribution-demo==1.0.0' --yes)" "match lock.yaml, nothing to do" "install again: nothing to do"

#===============================================================================
# upgrade, one distribution with kernel per vault, without kernel, overriding only with only:
#===============================================================================

   OUT="$(echo y | I "$V" distribution-demo)"
   assert_contains "$OUT" "=> upgrade distribution-demo 1.0.0 -> 1.0.1 into $V" "upgrade: highest version"
   assert_contains "$OUT" "new        test-befehl 0.1.0" "upgrade: new package of the distribution"
   assert_not_contains "$OUT" "machine part" "upgrade: kernel and workhorse on the machine, no machine part"
   assert_contains "$(cat "$V/.aios/config.yaml")" 'distribution-demo: "==1.0.1"' "upgrade: packages: follows"
   OUT="$(I "$V" distribution-zwei --yes)"; RC=$?
   assert_eq "$RC:$(grep -c 'distribution-demo in .* also brings a kernel; one distribution with kernel: per vault' <<< "$OUT")" "1:1" "second distribution with kernel: conflict"
   assert_eq "$(I "$V" distribution-sammlung --yes >/dev/null; echo $?)" "0" "distribution without kernel next to it"
   assert_contains "$(cat "$V/.aios/config.yaml")" 'distribution-sammlung: "==1.0.0"' "without kernel: in packages:"
   cp "$V/.aios/config.yaml" "$SANDBOX/config.keep"
   printf '  skill-test-nutzer: "~=0.2.0"\n' >> "$V/.aios/config.yaml"
   OUT="$(I "$V" distribution-demo --yes)"
   assert_contains "$OUT" "a package of a distribution is overridden only with only: (spec 06, Übersteuern)" "own entry against the distribution: conflict"
   cp "$SANDBOX/config.keep" "$V/.aios/config.yaml"
   printf '  skill-test-nutzer: "~=0.1.0"\n' >> "$V/.aios/config.yaml"
   OUT="$(I "$V" distribution-demo --yes)"; RC=$?
   assert_eq "$RC:$(grep -c 'overridden only' <<< "$OUT")" "0:0" "own entry that admits the version: no conflict"
   cp "$SANDBOX/config.keep" "$V/.aios/config.yaml"

#===============================================================================
# failures: kernel without tag, failing machine part, vault bound to 0.4 (changeover), --from
#===============================================================================

   V2="$SANDBOX/work/§Kaputt"; mkdir -p "$V2"
   OUT="$(I "$V2" distribution-kaputt --yes)"; RC=$?
   assert_eq "$RC:$(grep -c 'no tag v0.6.9' <<< "$OUT")" "1:1" "kernel without tag: aborted"
   [ ! -e "$V2/.aios" ] && ok || fail "kernel without tag: vault untouched"
   chmod -R u+w "$W"; rm -rf "$W"
   OUT="$(AIOS_TEST_FAIL=1 I "$V2" distribution-demo --yes)"; RC=$?
   assert_eq "$RC:$(grep -c 'the machine part failed (.*); the vault is unchanged, what is installed stays' <<< "$OUT")" "1:1" "machine part fails: reported"
   [ ! -e "$V2/.aios" ] && [ ! -e "$V2/@" ] && ok || fail "machine part fails: vault untouched"
   V3="$SANDBOX/work/§Alt"; mkdir -p "$V3/@" "$V3/.aios"; printf 'aios: 0.4.0\n' > "$V3/.aios/config.yaml"
   OUT="$(I "$V3" distribution-demo --plan)"
   assert_contains "$OUT" "aios: 0.6.0 in $V3/.aios/config.yaml (was 0.4.0)" "vault on 0.4: changeover in the same plan"
   R="$SANDBOX/dist-repo"; cp -R "$SRC/tests/hub/aibex-aios/distribution-zwei/1.0.0" "$R"
   git -C "$R" init -q; git -C "$R" add -A; git -C "$R" -c user.name=t -c user.email=t@t commit -q -m 1.0.0; git -C "$R" tag v1.0.0
   OUT="$(I "$V3" distribution-zwei --from "$R" --yes)"; RC=$?
   assert_eq "$RC" "0" "--from: distribution from a local repo"
   assert_contains "$(cat "$V3/.aios/config.yaml")" "from: $R" "--from: noted in packages:"
   assert_contains "$(cat "$V3/.aios/config.yaml")" "aios: 0.6.0" "--from: vault changed over to 0.6.0"

#===============================================================================
# v0.5.1 step 2 (B7): clone with a python3 without PyYAML - kernel first, then the installation
#===============================================================================

   NY="$SANDBOX/noyaml"; mkdir -p "$NY"
   printf 'import runpy, sys\nsys.modules["yaml"] = None\na = sys.argv[1:]\nif a[:1] == ["-c"]:\n    sys.argv = ["-c"] + a[2:]; exec(a[1])\nelif a[:1] == ["-m"]:\n    sys.argv = a[1:]; runpy.run_module(a[1], run_name="__main__", alter_sys=True)\nelse:\n    sys.argv = a; runpy.run_path(a[0], run_name="__main__")\n' > "$NY/run.py"
   printf '#!/bin/bash\nexec "%s/python3" "%s/run.py" "$@"\n' "$PYDIR" "$NY" > "$NY/python3"; chmod +x "$NY/python3"
   YD="$("$PYDIR/python3" -c 'import os, yaml; print(os.path.dirname(yaml.__file__))')"
   printf '#!/bin/bash\ncp -R "%s" "$(dirname "$1")"/lib/python3*/site-packages/\n' "$YD" > "$SANDBOX/fake/pip-yaml"; chmod +x "$SANDBOX/fake/pip-yaml"
   assert_contains "$(PATH="$NY:$PATH" python3 -c 'import yaml' 2>&1)" "ModuleNotFoundError" "python3 without PyYAML"
   HB="$SANDBOX/home-b7"; mkdir -p "$HB/.aios"; cp "$HOME/.aios/config.yaml" "$HB/.aios/" 2>/dev/null   # fresh machine
   NI() { local v="$1"; shift; (cd "$v" && HOME="$HB" PATH="$NY:$PATH" AIOS_PIP="$SANDBOX/fake/pip-yaml" "$S/bin/aios" --install "$@" 2>&1); }
   V4="$SANDBOX/work/§Frisch"; mkdir -p "$V4"
   OUT="$(NI "$V4" 'distribution-demo==1.0.0' --plan)"
   assert_contains "$OUT" "=> AIbex AIOS v0.6.0 first (kernel: of distribution-demo 1.0.0; PyYAML is missing in" "B7 plan: kernel first, from kernel:"
   assert_contains "$OUT" "install AIOS v0.6.0 from $S -> $HB/.aios/versions/v0.6.0 (read-only)" "B7 plan: kernel from the clone"
   assert_contains "$OUT" "then: aios --install distribution-demo==1.0.0 with AIOS v0.6.0 (plan of the distribution)" "B7 plan: second plan announced"
   assert_not_contains "$OUT" "ModuleNotFoundError" "B7 plan: no PyYAML needed"
   [ ! -e "$HB/.aios/versions/v0.6.0" ] && [ ! -e "$V4/.aios" ] && ok || fail "B7 plan: nothing written"
   OUT="$(NI "$V4" 'distribution-demo==1.0.0' --yes)"; RC=$?
   assert_eq "$RC" "0" "B7 --yes: exit 0"
   assert_dir "$HB/.aios/versions/v0.6.0"
   assert_exec "$HB/.aios/workers/worker-test/v0.1.1/bin/aios-test-tool"
   assert_contains "$(cat "$V4/.aios/config.yaml")" 'distribution-demo: "==1.0.0"' "B7 --yes: distribution installed by the new installation"
   OUT="$(NI "$V4" 'distribution-demo==1.0.0' --plan)"
   assert_contains "$OUT" "match lock.yaml, nothing to do" "B7 kernel installed: hand over at once"
   assert_not_contains "$OUT" "first (" "B7 kernel installed: no plan of the kernel"

#===============================================================================
# removal: aios --fetch --remove, the binding stays
#===============================================================================

   (cd "$V" && "$S/bin/aios" --fetch --remove distribution-demo --yes >/dev/null 2>&1)
   C="$(cat "$V/.aios/config.yaml")"
   assert_not_contains "$C" "distribution-demo" "remove: distribution gone from packages:"
   assert_contains "$C" "aios: 0.6.0" "remove: the binding stays"
   unset AIOS_HUBS AIOS_PIP_FIND_LINKS AIOS_PIP AIOS_SUDO AIOS_STUP_URL
