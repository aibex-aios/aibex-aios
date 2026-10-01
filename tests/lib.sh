#!/bin/bash
# lib.sh: helpers for AIOS tests (sandbox, assertions); sourced by tests/run

   REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
   SRC="$REPO"                         # repo root = source of an installation

#===============================================================================
# sandbox: fresh HOME, AIOS_PREFIX and AIOS_CLAUDE_DIR per test file
#===============================================================================

   sandbox_new() {
      SANDBOX="$(T="${TMPDIR:-/tmp}"; cd "$(mktemp -d "${T%/}/aios-test.XXXXXX")" && pwd -P)" || exit 1   # physical, like AIOS
      export HOME="$SANDBOX/home"
      export AIOS_PREFIX="$SANDBOX/opt/aios"
      export AIOS_CLAUDE_DIR="$HOME/.claude"
      unset AIOS_HOME
      mkdir -p "$HOME"
   }

   sandbox_drop() {
      case "$SANDBOX" in
         */aios-test.*) chmod -R u+w "$SANDBOX" 2>/dev/null; rm -rf "$SANDBOX" ;;   # installations are read-only
      esac
   }

#===============================================================================
# assertions: count passes and failures, print one line per failure
#===============================================================================

   PASS=0; FAIL=0

   ok()   { PASS=$((PASS+1)); }
   fail() { FAIL=$((FAIL+1)); printf '   \033[31mFAIL\033[0m %s\n' "$*"; }

   assert_file()   { [ -f "$1" ] && ok || fail "missing file: $1"; }
   assert_dir()    { [ -d "$1" ] && ok || fail "missing dir: $1"; }
   assert_exec()   { [ -x "$1" ] && ok || fail "not executable: $1"; }
   assert_eq()     { [ "$1" == "$2" ] && ok || fail "$3: expected [$2], got [$1]"; }
   assert_contains() { case "$1" in *"$2"*) ok ;; *) fail "$3: [$2] not in output" ;; esac; }
   assert_exit()   { "${@:2}" >/dev/null 2>&1; local rc=$?; [ "$rc" == "$1" ] && ok || fail "exit $rc (expected $1): ${*:2}"; }
