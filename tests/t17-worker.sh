# t17-worker.sh: workhorses (spec 07) - installation per version, workers.yaml, forwarders in
# ~/.aios/bin, aios --worker (state, repair), kind python and script (step 6); loading with setup in
# the plan, dependencies, upgrade, reconcile, removal of unused versions, conflict, AIOS-WORKERS
# (step 7); commands (aios --run, spec 06); workers: of v0.4 rejected

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
# kind python: setup in the plan of aios --fetch, installation read-only, workers.yaml (step 7)
#===============================================================================

   OUT="$(A "$D" --fetch 'worker-test==0.1.0' --plan)"
   assert_contains "$OUT" "setup      worker-test 0.1.0 -> $I" "fetch plan: setup of the workhorse"
   assert_contains "$OUT" "1 packages from worker/requirements.lock:" "plan: number of packages"
   assert_contains "$OUT" "| aios-test-tool==1.0.0" "plan: package==version without hash (L7)"
   assert_contains "$OUT" "check: aios-test-tool --check" "plan: check"
   [ ! -e "$I" ] && [ ! -e "$D/@/@!Package/worker-test" ] && ok || fail "plan: nothing installed or fetched"
   OUT="$(A "$D" --fetch 'worker-test==0.1.0' </dev/null)"
   assert_contains "$OUT" "cancelled" "no input: nothing runs"
   A "$D" --fetch 'worker-test==0.1.0' --yes >/dev/null
   assert_dir "$D/@/@!Package/worker-test"
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
   assert_contains "$(A "$D" --fetch --yes)" "match lock.yaml, nothing to do" "reconcile: nothing to do when installed"

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
# reconcile (second machine, L5), AIOS-WORKERS, repair with aios --worker <package> setup
#===============================================================================

   chmod -R u+w "$I"; rm -rf "$I"
   assert_contains "$(A "$D" --worker)" "worker-test 0.1.0  not installed (fetched in $D); run: aios --worker worker-test setup" "--worker: fetched, not installed"
   assert_contains "$(at "$G" "$SRC/bin/aios" --context --advise </dev/null)" "AIOS-WORKERS: missing worker-test 0.1.0 — run aios --fetch" "advise: missing workhorse of the chain (N3)"
   OUT="$(echo y | A "$D" --fetch)"
   assert_contains "$OUT" "setup      worker-test 0.1.0 -> $I" "reconcile: setup of the missing version"
   assert_eq "$(at "$D" "$T")" "aios-test-tool 1.0.0" "reconcile: installed again"
   assert_not_contains "$(at "$G" "$SRC/bin/aios" --context --advise </dev/null)" "AIOS-WORKERS" "advise: nothing missing"
   chmod -R u+w "$I"; rm "$I/bin/aios-test-tool"
   OUT="$(A "$D" --worker worker-test setup --plan)"
   assert_contains "$OUT" "setup worker-test 0.1.0 -> $I" "repair: plan"
   A "$D" --worker worker-test setup --yes >/dev/null
   assert_eq "$(at "$D" "$T")" "aios-test-tool 1.0.0" "repair: rebuilt"
   assert_contains "$(A "$D" --worker nope setup)" "no fetched worker package nope in $D" "repair: unknown package"
   assert_contains "$(A "$D" --worker worker-test nope)" "usage: aios --worker [<package> setup]" "--worker: usage"

#===============================================================================
# dependency: a skill that needs a workhorse, two versions side by side, conflict (F9)
#===============================================================================

   J="$HOME/.aios/workers/worker-test/v0.1.1"
   OUT="$(echo y | A "$G" --fetch skill-test-nutzer)"
   assert_contains "$OUT" "setup      worker-test 0.1.1 -> $J" "dependency: workhorse set up with the skill"
   assert_eq "$(at "$G" "$T"):$(at "$D" "$T")" "aios-test-tool 1.1.0:aios-test-tool 1.0.0" "two versions, each project its own"
   OUT="$(A "$G" --fetch worker-test-anders --yes)"
   assert_contains "$OUT" "the packages worker-test and worker-test-anders both bring the program aios-test-tool in the chain of $G; nothing is fetched" "conflict in the chain"
   [ ! -e "$G/@/@!Package/worker-test-anders" ] && ok || fail "conflict: nothing fetched"

#===============================================================================
# upgrade and removal: a version goes when no project uses it any more (A3)
#===============================================================================

   OUT="$(echo y | A "$D" --fetch 'worker-test~=0.1.0')"
   assert_not_contains "$OUT" "setup      worker-test" "upgrade: version already on the machine, no setup"
   assert_contains "$OUT" "remove     worker-test 0.1.0 -> $I (no project uses it)" "upgrade: old version removed"
   [ ! -e "$I" ] && [ -d "$J" ] && ok || fail "upgrade: 0.1.0 gone, 0.1.1 stays"
   assert_contains "$(cat "$HOME/.aios/workers.yaml")" "projects: [\"$D\", \"$G\"]" "upgrade: both projects use 0.1.1"
   OUT="$(echo y | A "$G" --fetch --remove skill-test-nutzer)"
   assert_not_contains "$OUT" "remove     worker-test 0.1.1 ->" "remove: version still used by §Demo stays"
   assert_contains "$(cat "$HOME/.aios/workers.yaml")" "projects: [\"$D\"]" "remove: project gone from workers.yaml"
   X="$D/X-Weg"; mkdir -p "$X/@"
   A "$X" --fetch 'worker-test~=0.1.0' --yes >/dev/null
   assert_contains "$(cat "$HOME/.aios/workers.yaml")" "projects: [\"$D\", \"$X\"]" "third project noted"
   chmod u+w "$HOME/.aios/workers.yaml"; sed -i.bak "s|, \"$X\"||" "$HOME/.aios/workers.yaml"   # v0.5.1, B8
   OUT="$(A "$X" --fetch --plan)"
   assert_contains "$OUT" "$HOME/.aios/workers.yaml: $X uses worker-test 0.1.1" "B8: missing entry in workers.yaml alone gives a plan"
   assert_not_contains "$OUT" "nothing to do" "B8: not nothing to do"
   A "$X" --fetch --yes >/dev/null
   assert_contains "$(cat "$HOME/.aios/workers.yaml")" "projects: [\"$D\", \"$X\"]" "B8: project noted again"
   assert_contains "$(A "$X" --fetch --plan)" "nothing to do" "B8: then nothing to do"
   OUT="$(A "$X" --context --list)"                                     # v0.5.1, O3
   assert_contains "$OUT" "worker-test 0.1.1 (aibex-aios, X-Weg) — no elements" "O3: package without elements"
   assert_not_contains "$OUT" "no elements deployed" "O3: not 'no elements deployed'"
   rm -rf "$X"
   OUT="$(echo y | A "$D" --fetch --remove worker-test)"
   assert_contains "$OUT" "remove     worker-test 0.1.1 -> $J (no project uses it)" "orphaned project does not count"
   [ ! -e "$J" ] && [ ! -e "$T" ] && ok || fail "removal: installation and forwarder gone"
   [ ! -e "$(dirname "$J")" ] && ok || fail "removal: no empty folder of the package under workers/ (B5)"

#===============================================================================
# kind script: plan shows the script, failing setup restores everything (I11)
#===============================================================================

   S="$HOME/.aios/workers/worker-test-script/v0.1.0"
   OUT="$(A "$D" --fetch worker-test-script --plan)"
   assert_contains "$OUT" "bash worker/setup.sh:" "script: plan names the script"
   assert_contains "$OUT" '| printf' "script: plan shows its content (P3)"
   LOCK="$(cat "$D/.aios/lock.yaml")"
   OUT="$(AIOS_TEST_SETUP_FAIL=1 A "$D" --fetch worker-test-script --yes)"
   assert_contains "$OUT" "the plan failed" "script: failing setup fails the plan"
   [ ! -e "$S" ] && [ ! -e "$S.new" ] && [ ! -e "$D/@/@!Package/worker-test-script" ] && ok || fail "script: failing setup leaves nothing"
   [ ! -e "$(dirname "$S")" ] && ok || fail "script: no empty folder of the package under workers/ (B5)"
   [ ! -e "$HOME/.aios/bin/aios-test-script" ] && ok || fail "script: no forwarder after a failure"
   assert_eq "$(cat "$D/.aios/lock.yaml")" "$LOCK" "script: lock.yaml as before"
   A "$D" --fetch worker-test-script --yes >/dev/null
   assert_eq "$(at "$D" "$HOME/.aios/bin/aios-test-script" a b)" "aios-test-script a b" "script: program from AIOS_WORKER_DIR/bin"
   A "$D" --fetch --remove worker-test-script --yes >/dev/null
   [ ! -e "$S" ] && [ ! -e "$HOME/.aios/bin/aios-test-script" ] && ok || fail "script: removed with the package"
   assert_not_contains "$(cat "$HOME/.aios/workers.yaml")" "worker-test-script" "remove: entry gone from workers.yaml"

#===============================================================================
# aios --run: deployed commands of the chain, environment, not deployed
#===============================================================================

   A "$D" --fetch test-befehl --yes >/dev/null
   assert_eq "$(A "$G" --run hallo Welt)" "hallo Welt" "run a command of a package in the chain"
   assert_contains "$(A "$D" --deploy test-befehl --only nichts --yes)" "test-befehl has no element nichts" "only existing elements"
   unset AIOS_HUBS AIOS_PIP_FIND_LINKS
