#!/bin/bash
# rothirsch.sh: live test of the distribution Rothirsch 1.1 in a sandbox (V0.5, step 13; V0.6, step 11; v0.6.1,
# step 5): the candidate of distribution-rothirsch with the kernel of VERSION from a sandbox clone of this
# repo with the local tag (F59); local hub aibex-local of the package repos, real PyPI

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/rothirsch.sh [<repos>]  # install distribution-rothirsch from a local hub of the'
      echo '                                           # tagged package repos in <repos> (default ~/git/AIbex)'
      echo '          tests/live/rothirsch.sh --version  # print version'
      echo '   not part of tests/run: needs network access to PyPI, takes about two minutes;'
      echo '   the test versions distribution-rothirsch <candidate>-rc9 and worker-yt-dlp 0.1.9 exist only in the'
      echo '   clones of the sandbox hub, never in the package repos (S5)'
      echo '   see also: tests/live/workers.sh, aios --install distribution-<name>'
      exit 1
   fi

#===============================================================================
# print version: tests/live/rothirsch.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.3.1"; exit 0
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

      K="$(cat "$REPO/VERSION")"; S="$SB/kernel"    # sandbox clone with the working tree and the local tag (F59)
      DV="$(sed -n 's/^version: //p' "$REPOS/distribution-rothirsch/manifest.yaml")"   # the candidate of the distribution
      DT="${DV%-rc*}-rc9"                           # its test version for the upgrade, only in the sandbox hub
      G clone -q "$REPO" "$S" || exit 1
      (cd "$REPO" && git -c core.quotePath=false ls-files -co --exclude-standard) | while IFS= read -r F; do
         mkdir -p "$S/$(dirname "$F")"; cp -p "$REPO/$F" "$S/$F"
      done
      printf '%s\n' "$K" > "$S/VERSION"; sed -i.bak "s/^version: .*$/version: $K/" "$S/manifest.yaml" && rm "$S/manifest.yaml.bak"
      G -C "$S" tag -d "v$K" >/dev/null 2>&1        # a tag of the repo moves onto the working tree, in the clone only
      G -C "$S" add -A && { G -C "$S" diff --cached --quiet || G -C "$S" commit -q -m "v$K"; } && G -C "$S" tag "v$K" || exit 1

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
      I() { (cd "$V" && "$S/bin/aios" --install "$@" 2>&1); }      # the candidate installs itself from its clone
      WK="$HOME/.aios/workers"; BIN="$HOME/.aios/bin"   # no /opt/aios/workers.yaml: workers per user (V0.6, F27)

      OUT="$(I distribution-rothirsch==$DV --plan)"
      check "plan: install distribution-rothirsch $DV (kernel $K)" has "$OUT" "=> install distribution-rothirsch $DV into $V (kernel $K)"
      check "plan: kernel from the sandbox clone" has "$OUT" "install AIOS v$K from $S"
      check "plan: setup worker-deno" has "$OUT" "setup      worker-deno 0.1.1 -> $WK/worker-deno/v0.1.1"
      check "plan: setup worker-yt-dlp" has "$OUT" "setup      worker-yt-dlp 0.1.1 -> $WK/worker-yt-dlp/v0.1.1"
      check "plan: worker-deno before worker-yt-dlp" [ "$(line "$OUT" "setup      worker-deno")" -lt "$(line "$OUT" "setup      worker-yt-dlp")" ]
      check "plan: machine part before the vault part" [ "$(line "$OUT" "machine part")" -lt "$(line "$OUT" "vault part")" ]
      check "plan: binding of the vault root" has "$OUT" "create $V/.aios/config.yaml with aios: $K"
      for P in "skill-video-analyse 0.2.1" "assistant-anja 0.2.1" "skill-5-8-zusammenfassung 1.2.2" "skill-memo 6.0.2"; do
         check "plan: new $P" has "$OUT" "new        $P"
      done

      OUT="$(I distribution-rothirsch==$DV --yes)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      check "install: exit 0" [ "$RC" == "0" ]
      check "vault bound to $K" has "$(cat "$V/.aios/config.yaml")" "aios: $K"
      check "packages: the distribution" has "$(cat "$V/.aios/config.yaml")" "distribution-rothirsch: \"==$DV\""
      check "kernel $K under ~/.aios/versions" [ -x "$HOME/.aios/versions/v$K/bin/aios" ]
      check "skill video-analyse registered by the installation (K2)" [ -f "$V/.claude/skills/video-analyse/SKILL.md" ]
      check "the forwarder runs $K in the vault" [ "$(cd "$V" && "$BIN/aios" --version 2>&1)" == "$K" ]
      check "yt-dlp over its forwarder in the vault" [ "$(cd "$V" && "$BIN/yt-dlp" --version 2>&1)" == "2026.10.21" ]
      check "yt-dlp finds deno" has "$(cd "$V" && "$BIN/yt-dlp" -v 2>&1)" "JS runtimes: deno-2.9.8"

      W1="$H/worker-yt-dlp"                         # test versions only in the clones (S5), released after 1.0.0
      sed -i.bak 's/^version: .*$/version: 0.1.9/' "$W1/manifest.yaml" && rm "$W1/manifest.yaml.bak"
      G -C "$W1" commit -q -am "worker-yt-dlp 0.1.9 (test version)" && G -C "$W1" tag v0.1.9
      D1="$H/distribution-rothirsch"
      sed -i.bak -e "s/^version: $DV\$/version: $DT/" "$D1/manifest.yaml" && rm "$D1/manifest.yaml.bak"
      printf '  worker-yt-dlp: "==0.1.9"\n' >> "$D1/manifest.yaml"
      G -C "$D1" commit -q -am "distribution-rothirsch $DT (test version)" && G -C "$D1" tag v$DT

      OUT="$(echo y | I distribution-rothirsch==$DT)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      check "upgrade: $DV -> $DT" has "$OUT" "=> upgrade distribution-rothirsch $DV -> $DT into $V"
      check "upgrade: setup worker-yt-dlp 0.1.9" has "$OUT" "setup      worker-yt-dlp 0.1.9 -> $WK/worker-yt-dlp/v0.1.9"
      check "upgrade: old version removed" has "$OUT" "remove     worker-yt-dlp 0.1.1 -> $WK/worker-yt-dlp/v0.1.1 (removed: no known project uses it)"
      check "upgrade: forwarder takes 0.1.9" has "$(cd "$V" && "$BIN/yt-dlp" ---which)" "package=worker-yt-dlp version=0.1.9"
      check "upgrade: 0.1.1 gone" [ ! -e "$WK/worker-yt-dlp/v0.1.1" ]

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
