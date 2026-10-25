# t15-hub.sh: step 3 of the plan v0.4 (V0.4, memos 18, 35) - test hubs, hub list, aios --hubs,
# aios --library, the git source of the resolver (spec 04, 06)

#===============================================================================
# setup: a python3 with PyYAML, test hubs built from tests/hub/, vault §Demo
#===============================================================================

   PYDIR=""
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import yaml" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t15 needs a python3 with PyYAML (pip install pyyaml)"
   export PATH="$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
   HUBS="$("$SRC/tests/hub/build" "$SANDBOX/hubs")"
   assert_eq "$HUBS" "aibex-aios=file://$SANDBOX/hubs/aibex-aios aibex-hub=file://$SANDBOX/hubs/aibex-hub" "build prints AIOS_HUBS"
   assert_eq "$(git ls-remote --tags "$SANDBOX/hubs/aibex-aios/app-taschenrechner" | sed 's/.*refs.tags.//' | tr '\n' ' ')" "v0.3.0 v0.3.1 v0.3.2 v0.4.0 v0.4.1 v0.4.2 v0.4.3 " "one tag per version"
   assert_eq "$(git -C "$SANDBOX/hubs/aibex-aios/app-taschenrechner" show v0.4.0:manifest.yaml | sed -n 2p)" "version: 0.4.0" "tag holds its version"
   assert_eq "$(git -C "$SANDBOX/hubs/aibex-aios/app-taschenrechner" ls-tree -r --name-only v0.4.0 | grep -c doppelt)" "0" "files of later versions not in earlier tags"
   D="$SANDBOX/work/§Demo"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   mk "$D/.aios/config.yaml" $'aios: 0.4.0\n'
   mkdir -p "$D/@" "$D/P-Projekt/@"
   at() { (cd "$1" && shift && "$@" 2>&1); }
   A() { local d="$1"; shift; at "$d" "$SRC/bin/aios" "$@"; }
   HL() { at "$1" env PYTHONPATH="$SRC/lib" python3 -c "from aios import hub; print(' '.join(f'{h.name}={h.url}({h.origin})' for h in hub.hub_list()))"; }

#===============================================================================
# config.yaml: one-line mappings and - name: url
#===============================================================================

   CP() { PYTHONPATH="$SRC/lib" python3 -c "from aios import config; print(config.parse('''$1'''))" 2>&1; }
   assert_eq "$(CP $'packages:\n  memo: "~=6.0"\n  k: {range: "~=0.1.0", hub: aibex-hub, only: [a, b]}')" "{'packages': {'memo': '~=6.0', 'k': {'range': '~=0.1.0', 'hub': 'aibex-hub', 'only': ['a', 'b']}}}" "packages: range or one-line mapping"
   assert_eq "$(CP $'hubs:\n  - aibex-aios\n  - firma: https://git.example.com/aios')" "{'hubs': ['aibex-aios', {'firma': 'https://git.example.com/aios'}]}" "hubs: names and name: url"

#===============================================================================
# hub list: default, home, vault root first, same name, AIOS_HUBS
#===============================================================================

   assert_eq "$(HL "$D")" "aibex-aios=https://github.com/aibex-aios(default)" "default hub list"
   mk "$HOME/.aios/config.yaml" $'hubs:\n  - aibex-hub\n  - firma: https://git.example.com/home\n'
   assert_eq "$(HL "$D")" "aibex-hub=https://github.com/aibex-hub(home) firma=https://git.example.com/home(home)" "home list replaces the default"
   mk "$D/.aios/config.yaml" $'aios: 0.4.0\nhubs:\n  - aibex-aios\n  - firma: https://git.example.com/vault\n'
   assert_eq "$(HL "$D/P-Projekt")" "aibex-aios=https://github.com/aibex-aios(vault) firma=https://git.example.com/vault(vault) aibex-hub=https://github.com/aibex-hub(home)" "vault root first, its entry wins"
   mk "$D/P-Projekt/.aios/config.yaml" $'hubs:\n  - nur-projekt\n'
   assert_contains "$(A "$D/P-Projekt" --config)" "hubs is not allowed here, ignored" "hubs: not in a project"
   rm "$D/P-Projekt/.aios/config.yaml"
   assert_eq "$(A "$D" --hubs)" "aibex-aios          https://github.com/aibex-aios  (vault)
firma               https://git.example.com/vault  (vault)
aibex-hub           https://github.com/aibex-hub  (home)
(home: firma covered by the vault root)" "aios --hubs: list with origin and covered names"
   assert_eq "$(AIOS_HUBS="x=file:///x y" HL "$D")" "x=file:///x(AIOS_HUBS) y=https://github.com/y(AIOS_HUBS)" "AIOS_HUBS replaces both lists"

#===============================================================================
# aios --hubs add / remove: plan, home or vault root, idempotent
#===============================================================================

   rm "$HOME/.aios/config.yaml"; mk "$D/.aios/config.yaml" $'aios: 0.4.0\n'
   OUT="$(A "$D" --hubs add aibex-hub --plan)"
   assert_contains "$OUT" "$HOME/.aios/config.yaml: hubs: aibex-hub https://github.com/aibex-hub" "add: plan names home"
   [ ! -e "$HOME/.aios/config.yaml" ] && ok || fail "--plan writes nothing"
   A "$D" --hubs add aibex-hub --yes >/dev/null
   assert_contains "$OUT" "hubs: aibex-aios https://github.com/aibex-aios (the default, kept in the new list)" "add: the first list keeps the default"
   assert_eq "$(cat "$HOME/.aios/config.yaml")" $'hubs:\n  - aibex-aios\n  - aibex-hub' "add: written to home"
   A "$D" --hubs add aibex-aios --yes >/dev/null
   A "$D" --hubs add firma https://git.example.com/aios --vault --yes >/dev/null
   assert_eq "$(cat "$D/.aios/config.yaml")" $'aios: 0.4.0\nhubs:\n  - firma: https://git.example.com/aios' "add --vault: written to the vault root"
   assert_contains "$(A "$D" --hubs add aibex-hub)" "nothing to do" "add again: nothing to do"
   A "$D" --hubs remove aibex-hub --yes >/dev/null
   assert_eq "$(cat "$HOME/.aios/config.yaml")" $'hubs:\n  - aibex-aios' "remove from home"
   A "$D" --hubs remove firma --vault --yes >/dev/null
   assert_eq "$(cat "$D/.aios/config.yaml")" "aios: 0.4.0" "remove the last vault hub: block gone"
   assert_contains "$(A "$SANDBOX" --hubs add x --vault --yes)" "is not in a vault" "--vault outside a vault"
   assert_contains "$(A "$D" --hubs add 'bad name')" "bad name is not a hub name" "invalid hub name"
   assert_contains "$(A "$D" --hubs drop x)" "usage: aios --hubs" "usage"
   rm "$HOME/.aios/config.yaml"

#===============================================================================
# aios --library: index, search, versions, hub without index
#===============================================================================

   export AIOS_HUBS="$HUBS"
   OUT="$(A "$D" --library)"
   assert_contains "$(printf '%s\n' "$OUT" | grep app-taschenrechner | tr -s ' ')" "aibex-aios/app-taschenrechner app Programmierbarer RPN-Taschenrechner" "library: index of aibex-aios"
   assert_contains "$OUT" "(hub aibex-hub cannot be searched: no aios-index, no topic aios-package; fetch by name)" "library: hub without index"
   assert_eq "$(A "$D" --library orion | head -1 | tr -s ' ')" "aibex-aios/knowledge-orion knowledge Die hellsten Sterne des Orion" "library: search in name and description"
   assert_eq "$(A "$D" --library skill-memo)" $'aibex-aios/skill-memo  6.0.0 6.0.1 6.1.0\naibex-hub/skill-memo  6.0.0' "library <package>: versions per hub"
   assert_eq "$(A "$D" --library aibex-hub/skill-memo)" "aibex-hub/skill-memo  6.0.0" "library <hub>/<package>: only this hub"
   assert_contains "$(A "$D" --library gibtsnicht)" "no package matches gibtsnicht" "library: no match"
   assert_dir "$HOME/.aios/hub/aibex-aios/.git"
   mkdir -p "$SANDBOX/bin"; printf '#!/bin/bash\necho "$*" >> "%s/gh.log"\necho '"'"'[{"name":"memo","description":"Memo vom Topic"}]'"'"'\n' "$SANDBOX" > "$SANDBOX/bin/gh"; chmod +x "$SANDBOX/bin/gh"
   OUT="$(AIOS_HUBS="gh-hub=https://github.com/nicht-vorhanden-aios-test" PATH="$SANDBOX/bin:$PATH" A "$D" --library)"
   assert_contains "$OUT" "gh-hub/memo" "library: GitHub hub without index searched by topic"
   assert_contains "$(cat "$SANDBOX/gh.log")" "repo list nicht-vorhanden-aios-test --topic aios-package" "topic search with gh"

#===============================================================================
# git source of the resolver: versions, cache, manifest, end to end
#===============================================================================

   SRCPY() { at "$D" env PYTHONPATH="$SRC/lib" python3 -c "from aios import hub, resolver, ui
s = hub.GitSource(hub.hub_list())
R = resolver.Request
def run(req, hubs=('aibex-aios', 'aibex-hub')):
    try:
        out = resolver.Resolver(s, hubs, '0.4.0-dev').resolve(req)
        print(' '.join(f'{p.name}={p.version}@{p.hub}' for p in out.values()))
    except (resolver.ResolveError, ui.Abort) as e:
        print(type(e).__name__, e)
$1"; }
   assert_eq "$(SRCPY "print(sorted(s.versions('skill-memo', 'aibex-aios')), s.versions('gibtsnicht', 'aibex-aios'))")" "['6.0.0', '6.0.1', '6.1.0'] []" "versions from the tags, none for a missing repo"
   assert_eq "$(SRCPY "m = s.manifest('app-taschenrechner', 'aibex-aios', '0.4.3'); print(m.name, m.version, m.elements())")" "app-taschenrechner 0.4.3 ['taschenrechner', 'taschenrechner-gui', 'knowledge']" "manifest from the cache"
   assert_dir "$HOME/.aios/packages/aibex-aios/app-taschenrechner/0.4.3/.git"
   assert_eq "$(SRCPY "print(len(s.commit('app-taschenrechner', 'aibex-aios', '0.4.3')))")" "40" "commit of the cached version"
   assert_eq "$(SRCPY "run({'app-taschenrechner': R()}, hubs=('aibex-aios',))")" "app-taschenrechner=0.4.3@aibex-aios skill-memo=6.1.0@aibex-aios" "end to end: taschenrechner with memo"
   assert_contains "$(SRCPY "run({'skill-memo': R()})")" "Ambiguous package skill-memo is in several hubs: aibex-aios, aibex-hub" "end to end: memo in both hubs"
   assert_eq "$(SRCPY "run({'knowledge-scorpio': R(hub='aibex-hub')}, hubs=('aibex-aios',))")" "knowledge-scorpio=0.1.0@aibex-hub" "end to end: hub outside the hub list"
   assert_eq "$(SRCPY "run({'test-befehl': R(repo='$SANDBOX/hubs/aibex-aios/test-befehl')}, hubs=())")" "test-befehl=0.1.0@from:$SANDBOX/hubs/aibex-aios/test-befehl" "end to end: --from a repo"
   assert_contains "$(SRCPY "run({'test-konflikt': R()}, hubs=('aibex-aios',))")" "- skill-memo: no version fulfils the ranges; >=7 (test-konflikt 1.0.0)" "end to end: conflict"
   git -C "$SANDBOX/hubs/aibex-aios/skill-memo" tag v9.9.9 v6.0.0
   assert_contains "$(SRCPY "s.manifest('skill-memo', 'aibex-aios', '9.9.9')")" "tag v9.9.9 has version 6.0.0 in manifest.yaml" "tag and manifest must agree"
   unset AIOS_HUBS

#===============================================================================
# every template of the test hubs is a valid package
#===============================================================================

   OUT="$(PYTHONPATH="$SRC/lib" python3 -c "
import pathlib
from aios import package
for d in sorted(pathlib.Path('$SRC/tests/hub').glob('*/*/*/manifest.yaml')):
    if d.parent.parent.name == 'test-worker':           # workers: of v0.4 is rejected since v0.5
        try:
            package.load(d.parent); print(d.parent, 'not rejected')
        except package.ManifestError as e:
            'workers: is gone' in str(e) or print(d.parent, e)
        continue
    m = package.load(d.parent)
    problems = package.check_tree(d.parent, m)
    if problems or m.name != d.parent.parent.name or str(m.version) != d.parent.name:
        print(d.parent, problems)
" 2>&1)"
   assert_eq "$OUT" "" "templates: manifest, tree, name and version fit"
