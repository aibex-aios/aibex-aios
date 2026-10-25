#!/bin/bash
# rothirsch.sh: live test of the distribution Rothirsch 1.0 in a sandbox (V0.5, step 13): kernel 0.5.0
# from a sandbox clone, local hub aibex-local of the package repos, real PyPI; no call of YouTube

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/rothirsch.sh [<repos>]  # install distribution-rothirsch from a local hub of the'
      echo '                                           # tagged package repos in <repos> (default ~/git/AIbex)'
      echo '          tests/live/rothirsch.sh --version  # print version'
      echo '   not part of tests/run: needs network access to PyPI, takes about two minutes;'
      echo '   the test versions distribution-rothirsch 1.0.1 and worker-yt-dlp 0.1.1 exist only in the'
      echo '   clones of the sandbox hub, never in the package repos (S5)'
      echo '   see also: tests/live/workers.sh, aios --install distribution-<name>'
      exit 1
   fi

#===============================================================================
# print version: tests/live/rothirsch.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.1.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/rothirsch.sh [<repos>]
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
      line() { printf '%s\n' "$1" | grep -n -m1 -F "$2" | cut -d: -f1; }
      G() { git -c user.name=live -c user.email=live@test "$@"; }

      S="$SB/kernel"                                # sandbox clone of the kernel with the tag v0.5.0
      (cd "$REPO" && git -c core.quotePath=false ls-files -co --exclude-standard) | while IFS= read -r F; do
         mkdir -p "$S/$(dirname "$F")"; cp -p "$REPO/$F" "$S/$F"
      done
      G -C "$S" init -q && G -C "$S" add -A && G -C "$S" commit -q -m v0.5.0 && G -C "$S" tag v0.5.0 || exit 1

      H="$SB/aibex-local"; mkdir -p "$H/aios-index"   # local hub of the tagged package repos (S4)
      printf 'schema: 1\npackages:\n' > "$H/aios-index/index.yaml"
      for P in distribution-rothirsch skill-video-analyse assistant-anja skill-5-8-zusammenfassung skill-memo \
               worker-yt-dlp worker-deno; do
         G clone -q "$REPOS/$P" "$H/$P" || exit 1
         printf '  - name: %s\n    type: %s\n    description: %s\n' "$P" "${P%%-*}" "$P" >> "$H/aios-index/index.yaml"
      done
      G -C "$H/aios-index" init -q && G -C "$H/aios-index" add -A && G -C "$H/aios-index" commit -q -m index
      mkdir -p "$SB/home/bin" "$SB/opt" "$SB/fake" "$SB/stup"
      printf '#!/bin/bash\n[ "$*" == "--version" ] && { echo "9.9"; exit 0; }\n[ "$*" == "--profile" ] && { echo "# profile" > "$BIN/profile.sh"; exit 0; }\nexit 1\n' > "$SB/stup/stup"
      export HOME="$SB/home" AIOS_PREFIX="$SB/opt" AIOS_CLAUDE_DIR="$SB/home/.claude"
      export AIOS_SUDO="$SB/fake/no-sudo" AIOS_PIP=true AIOS_STUP_URL="file://$SB/stup/stup"
      export AIOS_HUBS="aibex-local=file://$H"
      PYDIR=""                                      # never the real ~/bin in PATH: aios --install would
      for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
         [ -x "$P" ] && "$P" -c "import yaml, venv, ensurepip" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
      done                                          # update the user's stup there (V0.5, memo 61)
      [ -n "$PYDIR" ] || { echo "*** needs a python3 with PyYAML, venv and ensurepip" >&2; exit 1; }
      export PATH="$HOME/bin:$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
      V="$SB/§Probe-Rothirsch"; mkdir -p "$V"
      I() { (cd "$V" && "$S/bin/aios" --install "$@" 2>&1); }
      WK="$AIOS_PREFIX/workers"; BIN="$HOME/.aios/bin"

      OUT="$(I distribution-rothirsch==1.0.0 --plan)"
      check "plan: install distribution-rothirsch 1.0.0 (kernel 0.5.0)" has "$OUT" "=> install distribution-rothirsch 1.0.0 into $V (kernel 0.5.0)"
      check "plan: kernel from the clone" has "$OUT" "install AIOS v0.5.0 from $S"
      check "plan: setup worker-deno" has "$OUT" "setup      worker-deno 0.1.0 -> $WK/worker-deno/v0.1.0"
      check "plan: setup worker-yt-dlp" has "$OUT" "setup      worker-yt-dlp 0.1.0 -> $WK/worker-yt-dlp/v0.1.0"
      check "plan: worker-deno before worker-yt-dlp" [ "$(line "$OUT" "setup      worker-deno")" -lt "$(line "$OUT" "setup      worker-yt-dlp")" ]
      check "plan: machine part before the vault part" [ "$(line "$OUT" "machine part")" -lt "$(line "$OUT" "vault part")" ]
      check "plan: binding of the vault root" has "$OUT" "create $V/.aios/config.yaml with aios: 0.5.0"
      for P in "skill-video-analyse 0.2.0" "assistant-anja 0.2.0" "skill-5-8-zusammenfassung 1.2.1" "skill-memo 6.0.1"; do
         check "plan: new $P" has "$OUT" "new        $P"
      done

      OUT="$(I distribution-rothirsch==1.0.0 --yes)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      check "install: exit 0" [ "$RC" == "0" ]
      check "vault bound to 0.5.0" has "$(cat "$V/.aios/config.yaml")" "aios: 0.5.0"
      check "packages: the distribution" has "$(cat "$V/.aios/config.yaml")" 'distribution-rothirsch: "==1.0.0"'
      check "skill video-analyse registered" [ -f "$V/.claude/skills/video-analyse/SKILL.md" ]
      check "yt-dlp over its forwarder in the vault" [ "$(cd "$V" && "$BIN/yt-dlp" --version 2>&1)" == "2026.10.21" ]
      check "yt-dlp finds deno" has "$(cd "$V" && "$BIN/yt-dlp" -v 2>&1)" "JS runtimes: deno-2.9.8"

      W1="$H/worker-yt-dlp"                         # test versions only in the clones (S5), released after 1.0.0
      sed -i.bak 's/^version: 0.1.0$/version: 0.1.1/' "$W1/manifest.yaml" && rm "$W1/manifest.yaml.bak"
      G -C "$W1" commit -q -am "worker-yt-dlp 0.1.1 (test version)" && G -C "$W1" tag v0.1.1
      D1="$H/distribution-rothirsch"
      sed -i.bak -e 's/^version: 1.0.0$/version: 1.0.1/' "$D1/manifest.yaml" && rm "$D1/manifest.yaml.bak"
      printf '  worker-yt-dlp: "==0.1.1"\n' >> "$D1/manifest.yaml"
      G -C "$D1" commit -q -am "distribution-rothirsch 1.0.1 (test version)" && G -C "$D1" tag v1.0.1

      OUT="$(echo y | I distribution-rothirsch)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      check "upgrade: 1.0.0 -> 1.0.1" has "$OUT" "=> upgrade distribution-rothirsch 1.0.0 -> 1.0.1 into $V"
      check "upgrade: setup worker-yt-dlp 0.1.1" has "$OUT" "setup      worker-yt-dlp 0.1.1 -> $WK/worker-yt-dlp/v0.1.1"
      check "upgrade: old version removed" has "$OUT" "remove     worker-yt-dlp 0.1.0 -> $WK/worker-yt-dlp/v0.1.0 (no project uses it)"
      check "upgrade: forwarder takes 0.1.1" has "$(cd "$V" && "$BIN/yt-dlp" ---which)" "package=worker-yt-dlp version=0.1.1"
      check "upgrade: 0.1.0 gone" [ ! -e "$WK/worker-yt-dlp/v0.1.0" ]

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
