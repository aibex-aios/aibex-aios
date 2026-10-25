# t17-worker.sh: workhorses (spec 07) and commands (aios --run, spec 06). v0.5 step 2: workers: of
# v0.4 is rejected, aios --worker is rebuilt in step 6 (this file is rewritten then, V0.5 memo 45, Q3)

#===============================================================================
# setup: python3 with PyYAML, test hubs, vault §Demo
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

#===============================================================================
# workers: of v0.4 is rejected (spec 06, Prüfung beim Holen; V0.5, memo 30, L9)
#===============================================================================

   OUT="$(A "$D" --fetch test-worker --yes)"
   assert_contains "$OUT" "workers: is gone since AIOS 0.5; a workhorse is a package of type: worker (spec 07)" "fetch: workers: rejected"
   [ ! -e "$D/@/@!Package/test-worker" ] && ok || fail "fetch: nothing fetched"
   assert_contains "$(A "$D" --worker)" "aios --worker is rebuilt for AIOS 0.5" "aios --worker: rebuilt in step 6"

#===============================================================================
# aios --run: deployed commands of the chain, environment, not deployed
#===============================================================================

   A "$D" --fetch test-befehl --yes >/dev/null
   assert_eq "$(A "$G" --run hallo Welt)" "hallo Welt" "run a command of a package in the chain"
   assert_contains "$(A "$D" --deploy test-befehl --only nichts --yes)" "test-befehl has no element nichts" "only existing elements"
   printf 'aios: 0.4.0\npackages:\n  test-befehl: {range: "~=0.1.0", only: [anderes]}\n' > "$D/.aios/config.yaml"
   assert_contains "$(A "$G" --run hallo)" "no deployed command hallo" "command not deployed (H3)"
   unset AIOS_HUBS
