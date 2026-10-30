#!/bin/bash
# workers.sh: live test of the companion workhorses worker-deno and worker-yt-dlp against the real
# PyPI (spec 07, Tests; V0.5, step 8; V0.6, step 11: vault bound to 0.6, versions 0.1.1); no call of YouTube

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/workers.sh [<repos>]  # load worker-yt-dlp (with worker-deno) from the local'
      echo '                                         # package repos in <repos> (default ~/git/AIbex)'
      echo '          tests/live/workers.sh --version  # print version'
      echo '   not part of tests/run: needs network access to PyPI, takes about a minute'
      echo '   see also: tests/run, aios --worker, aios --fetch'
      exit 1
   fi

#===============================================================================
# print version: tests/live/workers.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.2.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/workers.sh [<repos>]
#===============================================================================

   if [ "$2" == "" ]; then
      REPOS="${1:-$HOME/git/AIbex}"
      REPO="$(cd "$(dirname "$0")/../.." && pwd)"
      T="${TMPDIR:-/tmp}"; SB="$(cd "$(mktemp -d "${T%/}/aios-live.XXXXXX")" && pwd -P)" || exit 1
      PASS=0; FAIL=0
      check() {                                     # check <name> <condition...>
         local N="$1"; shift
         if "$@"; then PASS=$((PASS+1)); printf '\033[32mok\033[0m   %s\n' "$N"
         else FAIL=$((FAIL+1)); printf '\033[31mFAIL\033[0m %s\n' "$N"; fi
      }
      has() { case "$1" in *"$2"*) return 0;; esac; return 1; }
      H="$SB/hub"; mkdir -p "$H/aios-index" "$SB/home" "$SB/opt"
      printf 'schema: 1\npackages:\n' > "$H/aios-index/index.yaml"
      for P in worker-deno worker-yt-dlp; do        # local hub of the tagged package repos
         git clone -q "$REPOS/$P" "$H/$P" || exit 1
         printf '  - name: %s\n    type: worker\n    description: %s\n' "$P" "$P" >> "$H/aios-index/index.yaml"
      done
      git -C "$H/aios-index" init -q && git -C "$H/aios-index" add -A &&
         git -C "$H/aios-index" -c user.name=live -c user.email=live@test commit -q -m index || exit 1
      export HOME="$SB/home" AIOS_PREFIX="$SB/opt-none" AIOS_HUBS="live=file://$H"
      V="$SB/§Live"; P="$V/P-Projekt"; mkdir -p "$V/.aios" "$V/@" "$P/@"
      printf 'aios: 0.6.0\n' > "$V/.aios/config.yaml"
      A() { (cd "$P" && "$REPO/bin/aios" "$@" 2>&1); }
      W="$HOME/.aios/workers"; BIN="$HOME/.aios/bin"

      OUT="$(A --fetch worker-yt-dlp --plan)"
      check "plan: setup of worker-deno" has "$OUT" "setup      worker-deno 0.1.1 -> $W/worker-deno/v0.1.1"
      check "plan: setup of worker-yt-dlp" has "$OUT" "setup      worker-yt-dlp 0.1.1 -> $W/worker-yt-dlp/v0.1.1"
      check "plan: worker-deno first (depends)" [ "$(printf '%s\n' "$OUT" | grep -n 'setup      worker-deno' | cut -d: -f1)" \
         -lt "$(printf '%s\n' "$OUT" | grep -n 'setup      worker-yt-dlp' | cut -d: -f1)" ]
      check "plan: 11 packages of yt-dlp[default]" has "$OUT" "11 packages from worker/requirements.lock:"
      check "plan: yt-dlp==2026.10.21" has "$OUT" "| yt-dlp==2026.10.21"
      check "plan: deno==2.9.8" has "$OUT" "| deno==2.9.8"
      OUT="$(A --fetch worker-yt-dlp --yes)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      check "fetch with setup from PyPI" [ "$RC" == "0" ]
      check "deno over its forwarder" has "$(cd "$P" && "$BIN/deno" --version 2>&1)" "deno 2.9.8"
      check "yt-dlp over its forwarder" [ "$(cd "$P" && "$BIN/yt-dlp" --version 2>&1)" == "2026.10.21" ]
      check "yt-dlp finds deno as JS runtime (F28)" has "$(cd "$P" && "$BIN/yt-dlp" -v 2>&1)" "JS runtimes: deno-2.9.8"
      check "installations read-only" [ ! -w "$W/worker-deno/v0.1.1" ] && [ ! -w "$W/worker-yt-dlp/v0.1.1" ]
      OUT="$(A --worker)"
      check "--worker: both checked" has "$OUT" "worker-yt-dlp 0.1.1  $W/worker-yt-dlp/v0.1.1  programs yt-dlp  check ok"
      OUT="$(cd "$SB" && "$BIN/yt-dlp" --version 2>&1)"; RC=$?
      check "outside the chain: exit 127" [ "$RC" == "127" ]
      OUT="$(A --fetch --remove worker-yt-dlp --yes)"
      check "remove: both versions and forwarders gone" [ ! -e "$W/worker-yt-dlp/v0.1.1" ] && [ ! -e "$W/worker-deno/v0.1.1" ] \
         && [ ! -e "$BIN/yt-dlp" ] && [ ! -e "$BIN/deno" ]

      echo "=> $PASS passed, $FAIL failed (sandbox $SB)"
      [ "$FAIL" == "0" ] || exit 1
      chmod -R u+w "$SB"; rm -rf "$SB"
      exit 0
   fi

#===============================================================================
# cannot deal with anything else ...
#===============================================================================

   "$0" -?
   exit 1
