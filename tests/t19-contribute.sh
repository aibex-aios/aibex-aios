# t19-contribute.sh: step 10 of the plan v0.4 (V0.4, memos 18, 55) - aios --contribute: branch and

   case "$SANDBOX" in */aios-test.*) ;; *) echo "*** run via tests/run, never directly (it would touch the real HOME)" >&2; exit 1;; esac
# pull request in the repo of a package, fork without write access (spec 06, Rückfluss; P5)

#===============================================================================
# setup: python3 with PyYAML, test hubs, a stand-in for gh, vault with the calculator
#===============================================================================

   PYDIR=""
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import yaml" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t19 needs a python3 with PyYAML (pip install pyyaml)"
   export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
   "$SRC/tests/hub/build" "$SANDBOX/hubs" >/dev/null
   export AIOS_HUBS="aibex-aios=file://$SANDBOX/hubs/aibex-aios"
   mkdir -p "$SANDBOX/ghbin"
   cat > "$SANDBOX/ghbin/gh" <<'GH'
#!/bin/bash
echo "gh $*" >> "$GH_LOG"
case "$1 $2" in
   "auth status") exit "${GH_AUTH:-0}" ;;
   "api user") echo tester ;;
   "api repos/"*) echo "${GH_PUSH:-true}" ;;
   "repo fork") exit 0 ;;
   "pr create") echo "https://github.com/aibex-aios/app-taschenrechner/pull/7" ;;
esac
GH
   chmod +x "$SANDBOX/ghbin/gh"
   export GH_LOG="$SANDBOX/gh.log" PATH="$SANDBOX/ghbin:$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
   D="$SANDBOX/work/§Demo"; mkdir -p "$D/@" "$D/.aios"; printf 'aios: 0.4.0\n' > "$D/.aios/config.yaml"
   at() { (cd "$1" && shift && "$@" 2>&1); }
   A() { local d="$1"; shift; at "$d" "$SRC/bin/aios" "$@"; }
   A "$D" --fetch app-taschenrechner --yes >/dev/null
   F="$D/@Data/app-taschenrechner/funktionstasten.yaml"
   mkdir -p "$(dirname "$F")"; printf 'A:\n  title: Quadrat\n  keys: ["ENTER", "×"]\n' > "$F"
   HUB="$SANDBOX/hubs/aibex-aios/app-taschenrechner"; MAIN="$(git -C "$HUB" rev-parse main)"
   DAY="$(date +%Y-%m-%d)"

#===============================================================================
# checks before anything is created
#===============================================================================

   assert_contains "$(A "$D" --contribute "$F")" "usage: aios --contribute" "--to required"
   assert_contains "$(A "$D" --contribute nicht-da.yaml --to app-taschenrechner)" "no such file" "missing file"
   assert_contains "$(A "$D" --contribute "$F" --to knowledge-orion)" "knowledge-orion is not fetched" "package not fetched"
   assert_contains "$(GH_AUTH=1 A "$D" --contribute "$F" --to app-taschenrechner)" "gh is not logged in" "gh not logged in"
   assert_contains "$(PATH="$PYDIR:/usr/bin:/bin" A "$D" --contribute "$F" --to app-taschenrechner)" "needs gh" "without gh"

#===============================================================================
# plan, branch, file, pull request; the default branch stays (P5)
#===============================================================================

   OUT="$(A "$D" --contribute "$F" --to app-taschenrechner --plan)"
   assert_contains "$OUT" "branch contrib/tester/$DAY-funktionstasten" "plan: branch"
   assert_contains "$OUT" "-> contrib/tester/funktionstasten.yaml" "plan: target in contrib/<user>/"
   assert_contains "$OUT" "pull request \"Beitrag: funktionstasten.yaml von tester\" against the default branch" "plan: title"
   [ "$(git -C "$HUB" branch --list 'contrib/*' | wc -l | tr -d ' ')" == "0" ] && ok || fail "--plan creates nothing"
   OUT="$(A "$D" --contribute "$F" --to app-taschenrechner --yes)"
   assert_contains "$OUT" "=> pull request: https://github.com/aibex-aios/app-taschenrechner/pull/7" "URL of the pull request"
   assert_eq "$(git -C "$HUB" show "contrib/tester/$DAY-funktionstasten:contrib/tester/funktionstasten.yaml" | sed -n 2p)" "  title: Quadrat" "file in the new branch"
   assert_eq "$(git -C "$HUB" rev-parse main)" "$MAIN" "default branch untouched (P5)"
   assert_contains "$(cat "$GH_LOG")" "gh pr create --repo aibex-aios/app-taschenrechner --base main --head contrib/tester/$DAY-funktionstasten --title Beitrag: funktionstasten.yaml von tester" "gh pr create"
   assert_contains "$(cat "$GH_LOG")" "geholte Version: 0.5.0" "body: version from lock.yaml"
   A "$D" --contribute "$F" --to app-taschenrechner --message "Quadrat neu" --yes >/dev/null
   assert_eq "$(git -C "$HUB" log -1 --format=%s "contrib/tester/$DAY-funktionstasten-2")" "Quadrat neu" "second contribution: own branch, --message"

#===============================================================================
# without write access: fork
#===============================================================================

   mkdir -p "$SANDBOX/forks/tester"; git clone -q "$HUB" "$SANDBOX/forks/tester/app-taschenrechner"
   : > "$GH_LOG"
   OUT="$(GH_PUSH=false AIOS_GITHUB="file://$SANDBOX/forks" A "$D" --contribute "$F" --to app-taschenrechner --yes)"
   assert_contains "$(cat "$GH_LOG")" "gh repo fork aibex-aios/app-taschenrechner --clone=false" "fork without write access"
   assert_contains "$(cat "$GH_LOG")" "--head tester:contrib/tester/$DAY-funktionstasten" "pull request from the fork"
   assert_eq "$(git -C "$SANDBOX/forks/tester/app-taschenrechner" branch --list "contrib/tester/$DAY-funktionstasten" | wc -l | tr -d ' ')" "1" "branch pushed to the fork"
   unset AIOS_HUBS GH_LOG
