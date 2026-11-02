#!/bin/bash
# changeover.sh: live test of the change of packages at the activation (v0.6.1, step 5; V0.6, memos 81, 84, 90):
# vault A with two projects on worker-yt-dlp 0.1.0 (fits 0.5 only), vault B on 0.1.0 without an entry in
# workers.yaml, known by the marker of a session; aios --activate of A on the candidate 0.6.1-rc1 shows the
# fetch of each project (B13), sets up 0.1.1 once and keeps 0.1.0 for B (B12); real PyPI

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/changeover.sh [<repos>]  # activate a vault of 0.5.1 on the candidate with packages'
      echo '                                            # from the tagged repos in <repos> (default ~/git/AIbex)'
      echo '          tests/live/changeover.sh --version  # print version'
      echo '   not part of tests/run: needs network access to PyPI, takes about two minutes'
      echo '   see also: tests/live/rothirsch.sh, aios --activate'
      exit 1
   fi

#===============================================================================
# print version: tests/live/changeover.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.1.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/changeover.sh [<repos>]
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
      hasnt() { ! has "$@"; }
      VER() { python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]+'/.aios/lock.yaml'))['packages'][sys.argv[2]]['version'])" "$1" "$2"; }
      count() { printf '%s\n' "$1" | grep -c -F "$2"; }
      G() { git -c user.name=live -c user.email=live@test "$@"; }

      K="0.6.1-rc1"; S="$SB/kernel"                 # sandbox clone with the working tree and the local tag (F59)
      G clone -q "$REPO" "$S" || exit 1
      (cd "$REPO" && git -c core.quotePath=false ls-files -co --exclude-standard) | while IFS= read -r F; do
         mkdir -p "$S/$(dirname "$F")"; cp -p "$REPO/$F" "$S/$F"
      done
      printf '%s\n' "$K" > "$S/VERSION"; sed -i.bak "s/^version: .*$/version: $K/" "$S/manifest.yaml" && rm "$S/manifest.yaml.bak"
      G -C "$S" add -A && G -C "$S" commit -q -m "v$K" && G -C "$S" tag "v$K" || exit 1

      H="$SB/aibex-local"; mkdir -p "$H/aios-index"   # local hub of the tagged package repos (S4)
      printf 'schema: 1\npackages:\n' > "$H/aios-index/index.yaml"
      for P in skill-video-analyse skill-5-8-zusammenfassung skill-memo worker-yt-dlp worker-deno; do
         G clone -q "$REPOS/$P" "$H/$P" || exit 1
         printf '  - name: %s\n    type: %s\n    description: %s\n' "$P" "${P%%-*}" "$P" >> "$H/aios-index/index.yaml"
      done
      G -C "$H/aios-index" init -q && G -C "$H/aios-index" add -A && G -C "$H/aios-index" commit -q -m index
      mkdir -p "$SB/home/bin" "$SB/opt" "$SB/fake"
      export HOME="$SB/home" AIOS_PREFIX="$SB/opt" AIOS_CLAUDE_DIR="$SB/home/.claude"
      export AIOS_SUDO="$SB/fake/no-sudo" AIOS_PIP=true
      export AIOS_HUBS="aibex-local=file://$H"
      PYDIR=""                                      # never the real ~/bin in PATH
      for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
         [ -x "$P" ] && "$P" -c "import yaml, venv, ensurepip" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
      done
      [ -n "$PYDIR" ] || { echo "*** needs a python3 with PyYAML, venv and ensurepip" >&2; exit 1; }
      export PATH="$HOME/bin:$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
      A_="$S/bin/aios"; WK="$HOME/.aios/workers"; BIN="$HOME/.aios/bin"; WY="$HOME/.aios/workers.yaml"

      OUT="$(cd "$SB" && "$A_" --install "v$K" --yes 2>&1)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      check "kernel $K installed" [ "$RC" == "0" ] && [ -x "$HOME/.aios/versions/v$K/bin/aios" ]

      VA="$SB/§Alpha"; VB="$SB/§Beta"               # two vaults of 0.5.1, each project on worker-yt-dlp 0.1.0
      for P in "$VA/PA-Eins" "$VA/PA-Zwei" "$VB/PB-Alt"; do
         V="$(dirname "$P")"; mkdir -p "$V/@" "$V/.aios" "$P/@"
         [ -f "$V/.aios/config.yaml" ] || printf 'aios: 0.5.1\n' > "$V/.aios/config.yaml"
         OUT="$("$A_" --fetch 'worker-yt-dlp==0.1.0' --to "$P" --yes 2>&1)" && \
         OUT="$("$A_" --fetch 'skill-video-analyse==0.2.0' --to "$P" --yes 2>&1)"; RC=$?
         [ "$RC" == "0" ] || printf '%s\n' "$OUT"
         check "$(basename "$P"): skill-video-analyse 0.2.0, worker-yt-dlp 0.1.0" \
            [ "$(VER "$P" skill-video-analyse) $(VER "$P" worker-yt-dlp)" == "0.2.0 0.1.0" ] && [ -d "$WK/worker-yt-dlp/v0.1.0" ]
      done
      python3 - "$WY" "$VB" <<'EOF'                 # B: written before workers.yaml knew it (B12)
import sys, yaml
f, vb = sys.argv[1], sys.argv[2]
d = yaml.safe_load(open(f))
for pkg in d.get("workers", {}).values():
    for v in pkg.values():
        v["projects"] = [p for p in v.get("projects", []) if not p.startswith(vb)]
open(f, "w").write(yaml.safe_dump(d, sort_keys=False))
EOF
      check "B not in workers.yaml" hasnt "$(cat "$WY")" "$VB"
      mkdir -p "$HOME/.aios/sessions"
      printf 'cwd: "%s"\nassistant: none\nused: 2026-11-01T10:00:00\n' "$VB/PB-Alt" > "$HOME/.aios/sessions/beta.yaml"

      OUT="$("$A_" --activate "v$K" "$VA" --plan 2>&1)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      printf '%s\n' "$OUT" | sed 's/^/      | /'
      check "plan: exit 0" [ "$RC" == "0" ]
      for P in PA-Eins PA-Zwei; do
         check "plan: packages for AIOS $K: $P (B13)" has "$OUT" "packages for AIOS $K: $VA/$P"
         check "plan: lock.yaml of $P among the substeps" has "$OUT" "$VA/$P/.aios/lock.yaml"
      done
      check "plan: packages: skill-video-analyse 0.2.0 -> 0.2.1" has "$OUT" "$VA/PA-Eins: packages: skill-video-analyse 0.2.0 -> skill-video-analyse 0.2.1"
      check "plan: upgrade skill-video-analyse among the substeps" has "$OUT" "upgrade 0.2.0 -> 0.2.1 skill-video-analyse 0.2.1"
      check "plan: setup worker-yt-dlp 0.1.1 once" [ "$(count "$OUT" "setup      worker-yt-dlp 0.1.1")" == "1" ]
      check "plan: 0.1.0 stays for B (B12)" has "$OUT" "worker-yt-dlp 0.1.0 stays, used by $VB/PB-Alt"
      check "plan: 0.1.0 not removed" hasnt "$OUT" "remove     worker-yt-dlp 0.1.0"
      check "plan: no changeover from v0.4" hasnt "$OUT" "changeover from v0.4"

      OUT="$("$A_" --activate "v$K" "$VA" --yes 2>&1)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      check "activate: exit 0" [ "$RC" == "0" ]
      check "activate: A bound to $K" has "$(cat "$VA/.aios/config.yaml")" "aios: $K"
      for P in PA-Eins PA-Zwei; do
         check "activate: $P on skill-video-analyse 0.2.1, worker-yt-dlp 0.1.1" \
            [ "$(VER "$VA/$P" skill-video-analyse) $(VER "$VA/$P" worker-yt-dlp)" == "0.2.1 0.1.1" ]
      done
      check "activate: 0.1.1 set up" [ -d "$WK/worker-yt-dlp/v0.1.1" ]
      check "activate: 0.1.0 still there for B" [ -d "$WK/worker-yt-dlp/v0.1.0" ]
      check "activate: B noted in workers.yaml" has "$(cat "$WY")" "$VB/PB-Alt"
      check "forwarder in A takes 0.1.1" has "$(cd "$VA/PA-Eins" && "$BIN/yt-dlp" ---which 2>&1)" "version=0.1.1"
      check "forwarder in B takes 0.1.0" has "$(cd "$VB/PB-Alt" && "$BIN/yt-dlp" ---which 2>&1)" "version=0.1.0"
      check "B untouched: bound to 0.5.1" has "$(cat "$VB/.aios/config.yaml")" "aios: 0.5.1"

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
