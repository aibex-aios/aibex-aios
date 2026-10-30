#!/bin/bash
# fresh.sh: AIBOS v0.6.0 in the smallest environment (V0.6, plan step 12): fresh HOME, python3 3.11 without
# PyYAML, PATH without the user's folders, kernel from a sandbox clone with the local tag v0.6.0; packages from
# a local hub of the package repos, the real hub only read; no Claude session, no tokens

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/fresh.sh [<repos>]   # install, activate, init, fetch in a fresh sandbox; packages'
      echo '                                         # from the tagged repos in <repos> (default ~/git/AIbex)'
      echo '          tests/live/fresh.sh --version   # print version'
      echo '   not part of tests/run: needs python3.11 and network access (PyPI for PyYAML, GitHub for stup and'
      echo '   the real hub, read only)'
      echo '   see also: tests/live/rothirsch.sh, aios --install'
      exit 1
   fi

#===============================================================================
# print version: tests/live/fresh.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.1.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/fresh.sh [<repos>]
#===============================================================================

   if [ "$2" == "" ]; then
      REPOS="${1:-$HOME/git/AIbex}"
      REPO="$(cd "$(dirname "$0")/../.." && pwd)"
      VERSION="$(cat "$REPO/VERSION")"
      PY311="$(command -v python3.11 || ls /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11 2>/dev/null | head -1)"
      [ -x "$PY311" ] || { echo "*** needs python3.11" >&2; exit 1; }
      T="${TMPDIR:-/tmp}"; SB="$(cd "$(mktemp -d "${T%/}/aios-live.XXXXXX")" && pwd -P)" || exit 1
      PASS=0; FAIL=0
      check() {                                     # check <name> <condition...>
         local N="$1"; shift
         if "$@"; then PASS=$((PASS+1)); printf '\033[32mok\033[0m   %s\n' "$N"
         else FAIL=$((FAIL+1)); printf '\033[31mFAIL\033[0m %s\n' "$N"; fi
      }
      has() { case "$1" in *"$2"*) return 0;; esac; return 1; }
      hasnt() { ! has "$@"; }
      G() { git -c user.name=live -c user.email=live@test "$@"; }

      S="$SB/kernel"                                # sandbox clone with the local tag (the tag of the repo comes after acceptance)
      (cd "$REPO" && git -c core.quotePath=false ls-files -co --exclude-standard) | while IFS= read -r F; do
         mkdir -p "$S/$(dirname "$F")"; cp -p "$REPO/$F" "$S/$F"
      done
      G -C "$S" init -q && G -C "$S" add -A && G -C "$S" commit -q -m "v$VERSION" && G -C "$S" tag "v$VERSION" || exit 1

      H="$SB/aibex-local"; mkdir -p "$H/aios-index"   # local hub of the tagged package repos (not yet published)
      printf 'schema: 1\npackages:\n' > "$H/aios-index/index.yaml"
      for P in assistant-gaertner assistant-astronom skill-memo knowledge-orion app-taschenrechner; do
         G clone -q "$REPOS/$P" "$H/$P" || exit 1
         printf '  - name: %s\n    type: %s\n    description: %s\n' "$P" "${P%%-*}" "$P" >> "$H/aios-index/index.yaml"
      done
      G -C "$H/aios-index" init -q && G -C "$H/aios-index" add -A && G -C "$H/aios-index" commit -q -m index

      "$PY311" -m venv "$SB/py" || exit 1           # python3 3.11 without PyYAML
      mkdir -p "$SB/home" "$SB/opt" "$SB/fake"
      export HOME="$SB/home" AIOS_PREFIX="$SB/opt" AIOS_CLAUDE_DIR="$SB/home/.claude" AIOS_SUDO="$SB/fake/no-sudo"
      unset AIOS_HOME AIOS_HUBS AIOS_PIP AIOS_STUP_URL AIOS_GITHUB PYTHONPATH
      export PATH="$HOME/.aios/bin:$HOME/bin:$SB/py/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      LOCAL="aibex-local=file://$H"
      V="$HOME/tmp/§Demo"; P="$V/G-Garten"; FWD="$HOME/.aios/bin/aios"

      check "python3 3.11 without PyYAML" [ "$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')" == "3.11" ] \
         && ! python3 -c "import yaml" 2>/dev/null

      OUT="$(cd "$SB" && "$S/bin/aios" --install "v$VERSION" --plan 2>&1)"
      check "plan: into ~/.aios/versions" has "$OUT" "$HOME/.aios/versions/v$VERSION"
      check "plan: nothing under /opt" hasnt "$OUT" "/opt/aios"
      OUT="$(cd "$SB" && "$S/bin/aios" --install "v$VERSION" --yes 2>&1)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      check "install: exit 0" [ "$RC" == "0" ]
      check "install: version read-only" [ -x "$HOME/.aios/versions/v$VERSION/bin/aios" ] && [ ! -w "$HOME/.aios/versions/v$VERSION" ]
      check "install: forwarder ~/.aios/bin/aios" [ -x "$FWD" ]
      check "install: three hooks with the absolute forwarder" [ "$(grep -c "$FWD --context --" "$HOME/.claude/settings.json")" == "3" ]
      check "install: PreToolUse for Bash" has "$(cat "$HOME/.claude/settings.json")" '"PreToolUse"'
      check "install: no global wrappers" [ ! -e "$HOME/.claude/skills/aios-status" ]
      check "install: no aios in ~/bin" [ ! -e "$HOME/bin/aios" ]
      check "--version over the forwarder" [ "$(cd "$SB" && aios --version 2>&1)" == "$VERSION" ]

      mkdir -p "$P"
      OUT="$(aios --activate "v$VERSION" "$V" --yes 2>&1)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      check "activate: exit 0" [ "$RC" == "0" ]
      check "activate: aios: $VERSION at the vault root" has "$(cat "$V/.aios/config.yaml")" "aios: $VERSION"
      check "activate: wrappers at the vault root" [ -f "$V/.claude/skills/aios-status/SKILL.md" ]
      check "activate: wrapper calls the absolute forwarder" has "$(cat "$V/.claude/skills/aios-status/SKILL.md")" "Bash($FWD --skill aios-status)"
      OUT="$(cd "$P" && aios --init --yes 2>&1)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      check "init: G-Garten is a project with wrappers" [ -d "$P/@" ] && [ -d "$P/.git" ] && [ -f "$P/.claude/skills/aios-init/SKILL.md" ]
      check "context: id in the A/W" has "$(cd "$P" && aios --context --id)" "mode=aios-$VERSION"
      J="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$FWD --skill aios-status\"},\"cwd\":\"$P\"}"
      check "permit: release in the A/W" has "$(cd "$P" && printf '%s' "$J" | aios --context --permit)" '"allow"'

      OUT="$(cd "$HOME/tmp" && aios --skill aios-status 2>&1)"; RC=$?
      check "outside: aios --skill says no A/W" [ "$RC" == "1" ] && has "$OUT" "Kein AIBOS-Workspace: $HOME/tmp"
      check "outside: the session hook prints nothing" [ -z "$(cd "$HOME/tmp" && echo '{}' | aios --context --session 2>&1)" ]

      OUT="$(cd "$P" && AIOS_HUBS="$LOCAL" aios --fetch assistant-gaertner --yes 2>&1)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      check "local hub: fetch assistant-gaertner 0.3.1" [ "$RC" == "0" ] && has "$(cat "$P/.aios/lock.yaml")" "0.3.1"
      check "local hub: package in @!Package" [ -f "$P/@/@!Package/assistant-gaertner/manifest.yaml" ]

      OUT="$(cd "$P" && aios --library 2>&1)"; RC=$?
      [ "$RC" == "0" ] || printf '%s\n' "$OUT"
      check "real hub: library readable" [ "$RC" == "0" ] && has "$OUT" "assistant-astronom"
      OUT="$(cd "$P" && aios --fetch assistant-astronom --plan 2>&1)"; RC=$?
      printf '%s\n' "$OUT" | sed 's/^/      | /'
      check "real hub: nothing published fits 0.6 yet" [ "$RC" != "0" ]

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
