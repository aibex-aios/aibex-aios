# t17-worker.sh: step 6 of the plan v0.4 (V0.4, memos 18, 41) - workers (aios --worker), commands
# (aios --run), hooks reported (spec 06, Arbeitspferde)

#===============================================================================
# setup: python3 with PyYAML, test hubs, vault §Demo, packages with worker and command
#===============================================================================

   PYDIR=""
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import yaml" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t17 needs a python3 with PyYAML (pip install pyyaml)"
   export PATH="$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
   "$SRC/tests/hub/build" "$SANDBOX/hubs" >/dev/null
   export AIOS_HUBS="aibex-aios=file://$SANDBOX/hubs/aibex-aios"
   D="$SANDBOX/work/§Demo"; G="$D/G-Garten"
   mkdir -p "$D/@" "$D/.aios" "$G/@"; printf 'aios: 0.4.0\n' > "$D/.aios/config.yaml"
   at() { (cd "$1" && shift && "$@" 2>&1); }
   A() { local d="$1"; shift; at "$d" "$SRC/bin/aios" "$@"; }
   W="$D/@/@!Package/test-worker"

#===============================================================================
# fetch runs no script, names the install command
#===============================================================================

   OUT="$(A "$D" --fetch test-worker --yes)"
   assert_contains "$OUT" "the package brings the worker db; install it with: aios --worker test-worker/db install" "fetch: hint to install"
   [ ! -e "$HOME/.aios/workers.yaml" ] && ok || fail "fetch runs no worker script"
   assert_contains "$(A "$D" --worker)" "test-worker/db  not installed — Testdatenbank" "--worker: list with state"

#===============================================================================
# install, start, stop, remove: plan with path and content, own confirmation
#===============================================================================

   assert_contains "$(A "$D" --worker test-worker/db start)" "is not installed; first: aios --worker test-worker/db install" "start before install"
   OUT="$(A "$D" --worker test-worker/db install --plan)"
   assert_contains "$OUT" "run $W/workers/db/install.sh (bash, in $W)" "plan: path of the script"
   assert_contains "$OUT" '| echo "db install $AIOS_PACKAGE"' "plan: content of the script"
   OUT="$(A "$D" --worker test-worker/db install </dev/null)"
   assert_contains "$OUT" "cancelled" "no input: nothing runs"
   OUT="$(A "$D" --worker test-worker/db install --yes)"
   assert_contains "$OUT" "| db install $W" "install runs with AIOS_PACKAGE"
   assert_contains "$(cat "$HOME/.aios/workers.yaml")" "$D|test-worker/db:" "state per computer in ~/.aios/workers.yaml"
   assert_contains "$(A "$D" --worker test-worker/db install)" "is installed, nothing to do" "install again: nothing to do (I8)"
   assert_contains "$(A "$D" --worker test-worker/db start --yes)" "| db start" "start"
   assert_contains "$(A "$D" --worker test-worker/db stop --yes)" "| db stop" "stop"
   assert_contains "$(A "$D" --fetch --remove test-worker)" "installed workers: test-worker/db; first: aios --worker test-worker/db remove" "remove blocked while installed"
   assert_contains "$(A "$D" --worker test-worker/db remove --yes)" "| db remove" "remove"
   A "$D" --fetch --remove test-worker --yes >/dev/null
   [ ! -e "$W" ] && ok || fail "package removed after the worker"
   assert_contains "$(A "$D" --worker test-worker/xx install)" "no fetched package test-worker" "unknown package"

#===============================================================================
# install fails: remove runs, not installed
#===============================================================================

   A "$D" --fetch test-worker --yes >/dev/null
   printf '#!/bin/bash\necho kaputt\nexit 3\n' > "$W/workers/db/install.sh"
   OUT="$(A "$D" --worker test-worker/db install --yes)"
   assert_contains "$OUT" "install of test-worker/db failed (exit 3); running remove" "failed install: remove runs"
   assert_contains "$OUT" "test-worker/db is not installed" "failed install: not installed"
   assert_contains "$(A "$D" --worker)" "test-worker/db  not installed" "failed install: state"

#===============================================================================
# aios --run: deployed commands of the chain, environment, not deployed
#===============================================================================

   A "$D" --fetch test-befehl --yes >/dev/null
   assert_eq "$(A "$G" --run hallo Welt)" "hallo Welt" "run a command of a package in the chain"
   assert_contains "$(A "$D" --deploy test-befehl --only nichts --yes)" "test-befehl has no element nichts" "only existing elements"
   printf 'aios: 0.4.0\npackages:\n  test-befehl: {range: "~=0.1.0", only: [anderes]}\n  test-worker: "~=0.1.0"\n' > "$D/.aios/config.yaml"
   assert_contains "$(A "$G" --run hallo)" "no deployed command hallo" "command not deployed (H3)"
   unset AIOS_HUBS
