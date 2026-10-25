# t17-worker.sh: workhorses (spec 07) - v0.5 step 6: installation per version, workers.yaml,
# forwarders in ~/.aios/bin, aios --worker (state, repair), kind python and script; commands
# (aios --run, spec 06); workers: of v0.4 rejected

#===============================================================================
# setup: python3 with PyYAML, test hubs with wheels, vault §Demo on 0.5.0
#===============================================================================

   PYDIR=""
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import yaml, venv, ensurepip" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t17 needs a python3 with PyYAML, venv and ensurepip"
   export PATH="$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
   "$SRC/tests/hub/build" "$SANDBOX/hubs" >/dev/null
   export AIOS_HUBS="aibex-aios=file://$SANDBOX/hubs/aibex-aios"
   export AIOS_PIP_FIND_LINKS="$SANDBOX/hubs/wheels"
   D="$SANDBOX/work/§Demo"; G="$D/G-Garten"
   mkdir -p "$D/@" "$D/.aios" "$G/@" "$SANDBOX/outside"; printf 'aios: 0.5.0\n' > "$D/.aios/config.yaml"
   at() { (cd "$1" && shift && "$@" 2>&1); }
   A() { local d="$1"; shift; at "$d" "$SRC/bin/aios" "$@"; }
   T="$HOME/.aios/bin/aios-test-tool"; I="$HOME/.aios/workers/worker-test/v0.1.0"

#===============================================================================
# workers: of v0.4 is rejected (spec 06, Prüfung beim Holen; V0.5, memo 30, L9)
#===============================================================================

   OUT="$(A "$D" --fetch test-worker --yes)"
   assert_contains "$OUT" "workers: is gone since AIOS 0.5; a workhorse is a package of type: worker (spec 07)" "fetch: workers: rejected"
   [ ! -e "$D/@/@!Package/test-worker" ] && ok || fail "fetch: nothing fetched"

#===============================================================================
# kind python: fetch, state, setup with plan, installation read-only, workers.yaml
#===============================================================================

   A "$D" --fetch 'worker-test==0.1.0' --yes >/dev/null
   assert_dir "$D/@/@!Package/worker-test"
   assert_contains "$(A "$D" --worker)" "worker-test 0.1.0  not installed (fetched in $D); run: aios --worker worker-test setup" "--worker: fetched, not installed"
   OUT="$(A "$D" --worker worker-test setup --plan)"
   assert_contains "$OUT" "setup worker-test 0.1.0 -> $I" "plan: target of the version"
   assert_contains "$OUT" "1 packages from worker/requirements.lock:" "plan: number of packages"
   assert_contains "$OUT" "| aios-test-tool==1.0.0" "plan: package==version without hash (L7)"
   assert_contains "$OUT" "check: aios-test-tool --check" "plan: check"
   [ ! -e "$I" ] && ok || fail "plan: nothing installed"
   OUT="$(A "$D" --worker worker-test setup </dev/null)"
   assert_contains "$OUT" "cancelled" "no input: nothing runs"
   OUT="$(A "$D" --worker worker-test setup --yes)"
   assert_contains "$OUT" "worker-test 0.1.0 set up; programs in $HOME/.aios/bin: aios-test-tool" "setup: done"
   assert_exec "$I/bin/aios-test-tool"
   [ ! -w "$I" ] && [ ! -e "$I.new" ] && ok || fail "setup: installation read-only, no .new left (N1)"
   W="$(cat "$HOME/.aios/workers.yaml")"
   assert_contains "$W" "programs:
  aios-test-tool: [worker-test]" "workers.yaml: program -> packages (N4)"
   assert_contains "$W" "    0.1.0:
      kind: python
      programs: [aios-test-tool]
      check: ok" "workers.yaml: version, kind, programs, check"
   assert_contains "$W" "projects: [\"$D\"]" "workers.yaml: project that uses it"
   assert_contains "$(cat "$T")" "# worker-forwarder: ~/.aios/bin/<program>" "forwarder in ~/.aios/bin"
   assert_contains "$(A "$D" --worker)" "worker-test 0.1.0  $I  programs aios-test-tool  check ok" "--worker: installed"

#===============================================================================
# forwarder: version from the nearest lock.yaml, errors with exit 127, never a setup (I10)
#===============================================================================

   assert_eq "$(at "$D" "$T" hallo)" "aios-test-tool 1.0.0 hallo" "forwarder: locked version called with arguments"
   assert_eq "$(at "$G" "$T")" "aios-test-tool 1.0.0" "forwarder: lock.yaml of the project above"
   assert_contains "$(at "$G" "$T" ---which)" "package=worker-test version=0.1.0 target=$I/bin/aios-test-tool why=worker-test 0.1.0 in $D/.aios/lock.yaml" "forwarder: ---which"
   OUT="$(at "$SANDBOX/outside" "$T")"; RC=$?
   assert_eq "$RC" "127" "outside the chain: exit 127"
   assert_contains "$OUT" "no project of the chain from $SANDBOX/outside has worker-test in lock.yaml" "outside the chain: message"
   mkdir -p "$G/.aios"; printf 'schema: 1\npackages:\n  worker-test:\n    version: 0.1.1\n' > "$G/.aios/lock.yaml"
   OUT="$(at "$G" "$T")"; RC=$?
   assert_eq "$RC:$OUT" "127:*** aios-test-tool: worker-test 0.1.1 is not fully loaded; aios --fetch" "version not installed: message, no setup (I10)"
   [ ! -e "$HOME/.aios/workers/worker-test/v0.1.1" ] && ok || fail "forwarder never installs"
   rm "$G/.aios/lock.yaml"
   printf '#!/bin/bash\necho fremd\n' > "$HOME/.aios/bin/fremd"
   assert_eq "$(PYTHONPATH="$SRC/lib" python3 -c "from aios import worker; worker.put_forwarder('fremd')" 2>&1)" "   warning: $HOME/.aios/bin/fremd is not an AIOS forwarder, left untouched" "foreign file in ~/.aios/bin stays"

#===============================================================================
# repair: aios --worker <package> setup rebuilds the version
#===============================================================================

   chmod -R u+w "$I"; rm "$I/bin/aios-test-tool"
   A "$D" --worker worker-test setup --yes >/dev/null
   assert_eq "$(at "$D" "$T")" "aios-test-tool 1.0.0" "repair: rebuilt"
   assert_contains "$(A "$D" --worker nope setup)" "no fetched worker package nope in $D" "repair: unknown package"
   assert_contains "$(A "$D" --worker worker-test nope)" "usage: aios --worker [<package> setup]" "--worker: usage"

#===============================================================================
# kind script: setup in AIOS_WORKER_DIR, failing setup leaves nothing
#===============================================================================

   A "$D" --fetch worker-test-script --yes >/dev/null
   S="$HOME/.aios/workers/worker-test-script/v0.1.0"
   OUT="$(A "$D" --worker worker-test-script setup --plan)"
   assert_contains "$OUT" "bash worker/setup.sh:" "script: plan names the script"
   assert_contains "$OUT" '| printf' "script: plan shows its content (P3)"
   OUT="$(AIOS_TEST_SETUP_FAIL=1 A "$D" --worker worker-test-script setup --yes)"
   assert_contains "$OUT" "setup of worker-test-script 0.1.0 failed" "script: failing setup reported"
   [ ! -e "$S" ] && [ ! -e "$S.new" ] && ok || fail "script: failing setup leaves nothing"
   [ ! -e "$HOME/.aios/bin/aios-test-script" ] && ok || fail "script: no forwarder after a failure"
   A "$D" --worker worker-test-script setup --yes >/dev/null
   assert_eq "$(at "$D" "$HOME/.aios/bin/aios-test-script" a b)" "aios-test-script a b" "script: program from AIOS_WORKER_DIR/bin"

#===============================================================================
# remove: the forwarder goes with the last version of its program (spec 07, remove)
#===============================================================================

   PYTHONPATH="$SRC/lib" python3 -c "from aios import worker; worker.remove('worker-test-script', '0.1.0')" >/dev/null
   [ ! -e "$S" ] && [ ! -e "$HOME/.aios/bin/aios-test-script" ] && ok || fail "remove: version and forwarder gone"
   assert_not_contains "$(cat "$HOME/.aios/workers.yaml")" "worker-test-script" "remove: entry gone from workers.yaml"
   assert_exec "$T"

#===============================================================================
# aios --run: deployed commands of the chain, environment, not deployed
#===============================================================================

   A "$D" --fetch test-befehl --yes >/dev/null
   assert_eq "$(A "$G" --run hallo Welt)" "hallo Welt" "run a command of a package in the chain"
   assert_contains "$(A "$D" --deploy test-befehl --only nichts --yes)" "test-befehl has no element nichts" "only existing elements"
   unset AIOS_HUBS AIOS_PIP_FIND_LINKS
