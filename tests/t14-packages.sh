# t14-packages.sh: step 2 of the plan v0.4 (V0.4, memo 18) - versions and ranges, manifest.yaml,

   case "$SANDBOX" in */aios-test.*) ;; *) echo "*** run via tests/run, never directly (it would touch the real HOME)" >&2; exit 1;; esac
# resolver (spec 06)

#===============================================================================
# setup: a python3 with PyYAML, helpers
#===============================================================================

   PYDIR=""
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import yaml" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t14 needs a python3 with PyYAML (pip install pyyaml)"
   export PATH="$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
   PY() { PYTHONPATH="$SRC/lib" python3 -c "from aios import semver, package, resolver
$1" 2>&1; }
   IN() { PY "print(semver.Range.parse('$1').contains('$2'))"; }

#===============================================================================
# versions: SemVer 2.0, missing parts, v, pre-release, build metadata
#===============================================================================

   assert_eq "$(PY "print(semver.Version.parse('v0.4'))")" "0.4.0" "leading v, missing parts count as 0"
   assert_eq "$(PY "print(semver.Version.parse('1.2.3+build.7'))")" "1.2.3" "build metadata ignored"
   assert_eq "$(PY "V=semver.Version.parse; print(V('0.4.0-dev') < V('0.4.0-rc1') < V('0.4.0'))")" "True" "pre-releases before the release"
   assert_eq "$(PY "V=semver.Version.parse; print(V('1.0.0-rc.2') < V('1.0.0-rc.10'), V('1.0.0-1') < V('1.0.0-a'))")" "True True" "numeric identifiers, numeric before alphanumeric"
   assert_eq "$(PY "V=semver.Version.parse; print(V('0.10.0') > V('0.9.9'))")" "True" "numeric order"
   assert_contains "$(PY "semver.Version.parse('x.1')")" "is not a version" "invalid version"

#===============================================================================
# ranges like pip
#===============================================================================

   assert_eq "$(IN '==6.0.0' 6.0.0)$(IN '==6.0.0' 6.0.1)" "TrueFalse" "=="
   assert_eq "$(IN '!=0.2.1' 0.2.1)$(IN '!=0.2.1' 0.2.2)" "FalseTrue" "!="
   assert_eq "$(IN '>=0.4,<0.5' 0.4.7)$(IN '>=0.4,<0.5' 0.5.0)" "TrueFalse" "comma: both conditions"
   assert_eq "$(IN '~=6.0' 6.9.0)$(IN '~=6.0' 7.0.0)" "TrueFalse" "~=X.Y up to the next major"
   assert_eq "$(IN '~=0.1.2' 0.1.9)$(IN '~=0.1.2' 0.2.0)$(IN '~=0.1.2' 0.1.1)" "TrueFalseFalse" "~=X.Y.Z up to the next minor"
   assert_eq "$(IN '*' 3.0.0)$(IN '' 0.0.1)" "TrueTrue" "* and empty: any version"
   assert_eq "$(IN '6.0.0' 6.0.0)" "True" "bare version means =="
   assert_eq "$(IN '>=0.4' 0.5.0-rc1)$(IN '>=0.4.0-rc1' 0.5.0-rc1)" "FalseTrue" "pre-release only if the range names one"
   assert_contains "$(PY "semver.Range.parse('~=6')")" "needs at least two parts" "~= with one part"
   assert_eq "$(PY "print(semver.default_range('6.0.0'), semver.default_range('0.1.0'), semver.default_range('1.4.2'))")" "~=6.0 ~=0.1.0 ~=1.4" "default range: ~=X.Y from 1.0, ~=0.Y.Z below (L5)"
   assert_eq "$(PY "print(semver.kernel_fits('>=0.4,<0.5', '0.4.0-dev'), semver.kernel_fits('>=0.4,<0.5', '0.4.0-rc1'), semver.kernel_fits('>=0.4,<0.5', '0.3.1'))")" "True True False" "kernel without pre-release (L1)"

#===============================================================================
# manifest.yaml: fields, module, elements, checks
#===============================================================================

   P="$SANDBOX/pkg/taschenrechner"
   mkdir -p "$P/skills/taschenrechner" "$P/skills/taschenrechner-gui" "$P/knowledge/@!Kacheln"
   printf -- '---\nname: taschenrechner\nversion: 0.1.0\ndescription: x\n---\n' > "$P/skills/taschenrechner/SKILL.md"
   printf -- '---\nname: taschenrechner-gui\ndescription: x\n---\n' > "$P/skills/taschenrechner-gui/SKILL.md"
   cat > "$P/manifest.yaml" <<'EOF'
name: taschenrechner
version: 0.1.0
type: app
description: Programmierbarer Taschenrechner
requires:
  aios: ">=0.4,<0.5"
depends:
  memo: "~=6.0"
contents:
  skills: [taschenrechner, taschenrechner-gui]
  knowledge: true
  gui: taschenrechner-gui
license: MIT
EOF
   OUT="$(PY "m = package.load('$P'); print(m.name, m.version, m.type, m.requires, m.depends['memo'], m.is_module, m.elements())")"
   assert_eq "$OUT" "taschenrechner 0.1.0 app >=0.4,<0.5 ~=6.0 True ['taschenrechner', 'taschenrechner-gui', 'knowledge']" "manifest read, module, elements"
   assert_eq "$(PY "print(package.check_tree('$P', package.load('$P')))")" "['skill taschenrechner-gui: no valid version']" "check: skill without version"
   printf -- '---\nname: taschenrechner-gui\nversion: 0.1.0\ndescription: x\n---\n' > "$P/skills/taschenrechner-gui/SKILL.md"
   assert_eq "$(PY "print(package.check_tree('$P', package.load('$P')))")" "[]" "check: complete package"
   rm -r "$P/knowledge"
   assert_contains "$(PY "print(package.check_tree('$P', package.load('$P')))")" "knowledge/ is missing" "check: missing knowledge"

   MF() { PY "import yaml
d = yaml.safe_load('''name: k
version: 0.1.0
type: knowledge
description: x
requires: {aios: '*'}
$1''')
d.update($2)
try:
    m = package.parse(d); print('ok', m.is_module, m.warnings)
except package.ManifestError as e:
    print(e)"; }
   assert_eq "$(MF '' '{}')" "ok False []" "knowledge package is no module"
   assert_eq "$(MF 'contents: {skills: [a]}' '{}')" "ok True []" "knowledge package with a skill is a module"
   assert_contains "$(MF '' "{'type': 'buch'}")" "unknown type 'buch', treated as knowledge" "unknown type: warning"
   assert_contains "$(MF '' "{'name': 'aios-x'}")" "aios-x is a reserved name" "reserved prefix aios-"
   assert_contains "$(MF '' "{'name': 'aios'}")" "aios is a reserved name" "aios reserved for the kernel (Q1)"
   assert_contains "$(MF '' "{'name': 'Gross'}")" "is not a package name" "upper case name"
   assert_contains "$(MF '' "{'version': '0.1'}")" "not MAJOR.MINOR.PATCH" "version needs three parts"
   assert_contains "$(MF '' "{'requires': None}")" "requires is missing" "requires required"
   assert_contains "$(MF 'depends: {aios: ">=0.4"}' '{}')" "depends must not name aios" "no depends on the kernel"
   assert_contains "$(MF 'contents: {skills: [a], gui: b}' '{}')" "contents.gui b is not in contents.skills" "gui must be a skill"
   assert_contains "$(MF 'contents: {skills: [a], commands: [a]}' '{}')" "element names are not unique: a" "unique element names"
   assert_contains "$(MF 'workers: {db: {install: i.sh}}' '{}')" "workers: is gone since AIOS 0.5" "workers: of v0.4 rejected (L9)"

#===============================================================================
# v0.5 step 2: type worker (spec 07), type distribution with kernel: (spec 06)
#===============================================================================

   W="'type': 'worker', 'worker': {'kind': 'python', 'requirements': 'worker/requirements.lock', 'programs': ['yt-dlp'], 'check': 'yt-dlp --version'}"
   WM() { PY "m = package.parse({'name': 'worker-x', 'version': '0.1.0', 'description': 'x', 'requires': {'aios': '*'}, $W})
$1"; }
   assert_eq "$(MF '' "{$W}")" "ok True []" "worker: a module"
   assert_eq "$(WM "print(m.elements(), m.worker['programs'])")" "[] ['yt-dlp']" "worker: no elements, programs"
   assert_contains "$(MF '' "{'type': 'worker'}")" "type worker needs worker:" "worker: needs worker:"
   X1="{'type': 'worker', 'worker': {'kind': 'binary', 'programs': ['x']}}"; assert_contains "$(MF '' "$X1")" "worker.kind must be python or script" "worker: kind"
   X2="{'type': 'worker', 'worker': {'kind': 'python', 'requirements': 'r'}}"; assert_contains "$(MF '' "$X2")" "worker.programs names no program" "worker: programs"
   X3="{'type': 'worker', 'worker': {'kind': 'python', 'programs': ['x']}}"; assert_contains "$(MF '' "$X3")" "needs requirements:" "worker python: requirements"
   X4="{'type': 'worker', 'worker': {'kind': 'script', 'programs': ['x'], 'setup': 's.sh'}}"; assert_contains "$(MF '' "$X4")" "needs remove:" "worker script: setup and remove"
   assert_contains "$(MF 'contents: {skills: [a]}' "{$W}")" "a worker has no elements" "worker: no contents"
   assert_contains "$(MF '' "{'worker': {'kind': 'python'}}")" "worker: is only allowed for type: worker" "worker: only with type worker"
   D="'type': 'distribution', 'kernel': '==0.5.0', 'depends': {'skill-a': '==0.2.0'}"
   assert_eq "$(MF '' "{$D}")" "ok False []" "distribution with kernel: and exact versions"
   X5="{'type': 'distribution', 'depends': {'skill-a': '~=0.2.0'}}"; assert_contains "$(MF '' "$X5")" "a distribution names exact versions" "distribution: exact depends"
   X6="{'type': 'distribution', 'kernel': '>=0.5'}"; assert_contains "$(MF '' "$X6")" "kernel: '>=0.5' is not ==X.Y.Z" "distribution: exact kernel"
   assert_contains "$(MF '' "{'kernel': '==0.5.0'}")" "kernel: is only allowed for type: distribution" "kernel: only for distributions"

   H64="$(printf 'a%.0s' $(seq 64))"
   mkdir -p "$SANDBOX/wk/worker"
   printf '# hashes\nyt-dlp==2026.10.21 \\\n    --hash=sha256:%s\ncertifi==2026.10.23 --hash=sha256:%s\n' "$H64" "$H64" > "$SANDBOX/wk/req-ok"
   assert_eq "$(PY "print(package.requirements_problems(open('$SANDBOX/wk/req-ok').read()))")" "[]" "requirements: entries with hashes, continuation, comment"
   printf 'yt-dlp>=1\nidna==3.1\n' > "$SANDBOX/wk/req-bad"
   assert_eq "$(PY "print(package.requirements_problems(open('$SANDBOX/wk/req-bad').read()))")" "['yt-dlp>=1: not <package>==<version>', 'idna==3.1: needs --hash=sha256:<hash> and nothing else']" "requirements: without == or hash rejected (F14)"
   printf 'x==1.0\n' > "$SANDBOX/wk/worker/requirements.lock"
   assert_eq "$(WM "print(package.check_tree('$SANDBOX/wk', m))")" "['worker: worker/requirements.lock: x==1.0: needs --hash=sha256:<hash> and nothing else']" "check_tree: hash file checked when fetching"

#===============================================================================
# v0.5 step 2: lock.yaml in the subset of spec 04, readable without a YAML parser (S3)
#===============================================================================

   L="$(PYTHONPATH="$SRC/lib" python3 -c "
from aios import yamlsub
print(yamlsub.dump({'schema': 1, 'packages': {'worker-yt-dlp': {'version': '0.1.0', 'hub': 'aibex-aios',
  'repo': 'https://github.com/aibex-aios/worker-yt-dlp', 'tag': 'v0.1.0', 'commit': '1234567',
  'requested': '~=0.1.0', 'required_by': ['skill-a', 'skill-b']}},
  'workspace': {'AA': 'abc123'}}, 'written by AIOS (fetch, workspace), do not edit'), end='')")"
   assert_eq "$L" '# written by AIOS (fetch, workspace), do not edit
schema: 1
packages:
  worker-yt-dlp:
    version: 0.1.0
    hub: aibex-aios
    repo: "https://github.com/aibex-aios/worker-yt-dlp"
    tag: v0.1.0
    commit: "1234567"
    requested: "~=0.1.0"
    required_by: [skill-a, skill-b]
workspace:
  AA: abc123' "lock.yaml: fixed subset (two spaces, flat lists, quotes where needed)"
   assert_eq "$(python3 -c "import yaml,sys; p=yaml.safe_load(sys.argv[1])['packages']['worker-yt-dlp']; print(p['commit'], p['version'], p['required_by'])" "$L")" "1234567 0.1.0 ['skill-a', 'skill-b']" "lock.yaml: valid YAML with the same values"
   bash_version() { awk -v p="  $2:" '$0=="packages:"{s=1;next} /^[^ ]/{s=0} s&&$0==p{f=1;next} f&&/^    version:/{print $2;exit} f&&/^  [^ ]/{exit}' <<< "$1"; }
   assert_eq "$(bash_version "$L" worker-yt-dlp)" "0.1.0" "lock.yaml: version readable without PyYAML"
   assert_eq "$(PY "print(package.load('$SRC', kernel=True).type)")" "kernel" "manifest.yaml of the kernel"

#===============================================================================
# resolver: highest version, depends, hubs, lock, conflicts
#===============================================================================

   RES() { PY "import yaml
def M(name, ver, dep=None, req='>=0.4,<0.5'):
    return package.parse({'name': name, 'version': ver, 'type': 'skill', 'description': 'x',
                          'requires': {'aios': req}, 'depends': dep or {}})
H = {('aibex-aios', 'memo'): {'6.0.0': M('memo', '6.0.0'), '6.1.0': M('memo', '6.1.0'), '7.0.0': M('memo', '7.0.0')},
     ('aibex-aios', 'taschenrechner'): {'0.1.0': M('taschenrechner', '0.1.0', {'memo': '~=6.0'}),
                                        '0.1.1': M('taschenrechner', '0.1.1', {'memo': '~=6.0'}),
                                        '0.2.0': M('taschenrechner', '0.2.0', {'memo': '~=6.0'}, '>=0.5')},
     ('aibex-hub', 'knowledge-scorpio'): {'0.1.0': M('knowledge-scorpio', '0.1.0', {'sternkarte': '*'})},
     ('aibex-hub', 'sternkarte'): {'1.0.0': M('sternkarte', '1.0.0')},
     ('aibex-aios', 'sternkarte'): {'2.0.0': M('sternkarte', '2.0.0')},
     ('aibex-hub', 'memo'): {'6.0.0': M('memo', '6.0.0')},
     ('aibex-aios', 'a'): {'1.0.0': M('a', '1.0.0', {'b': '>=1.0'})},
     ('aibex-aios', 'b'): {'1.0.0': M('b', '1.0.0', {'a': '*'}), '2.0.0': M('b', '2.0.0', {'a': '<1.0'})}}
src = resolver.MemorySource(H)
R = resolver.Request; S = semver.Range.parse
def run(req, hubs=('aibex-aios',), locked=None, upgrade=(), kernel='0.4.0-dev'):
    try:
        out = resolver.Resolver(src, hubs, kernel, locked, upgrade).resolve(req)
        print(' '.join(f'{p.name}={p.version}@{p.hub}' + (f'<{\",\".join(p.required_by)}' if p.required_by else '') for p in out.values()))
    except resolver.ResolveError as e:
        print(type(e).__name__, e)
$1"; }
   assert_eq "$(RES "run({'taschenrechner': R()})")" "memo=6.1.0@aibex-aios<taschenrechner taschenrechner=0.1.1@aibex-aios" "highest fitting versions, requires.aios, depends"
   assert_eq "$(RES "run(dict(taschenrechner=R(S('==0.1.0')), memo=R(S('<6.1'))))")" "memo=6.0.0@aibex-aios<taschenrechner taschenrechner=0.1.0@aibex-aios" "ranges from packages: and depends together"
   assert_eq "$(RES "run({'memo': R()}, locked=dict(memo=('6.0.0', 'aibex-aios')))")" "memo=6.0.0@aibex-aios" "locked version stays (no silent update)"
   assert_eq "$(RES "run({'memo': R()}, locked=dict(memo=('6.0.0', 'aibex-aios')), upgrade=['memo'])")" "memo=7.0.0@aibex-aios" "--upgrade chooses anew"
   assert_contains "$(RES "run({'taschenrechner': R(S('>=0.2'))})")" "requires.aios" "conflict: no version runs with this AIOS"
   assert_contains "$(RES "run(dict(taschenrechner=R(), memo=R(S('>=7'))))")" "- memo: no version fulfils the ranges; >=7 (packages:); ~=6.0 (taschenrechner 0.1.1)" "conflict list with origins"
   assert_contains "$(RES "run({'memo': R()}, hubs=('aibex-aios', 'aibex-hub'))")" "Ambiguous package memo is in several hubs: aibex-aios, aibex-hub" "name in two hubs: ambiguous"
   assert_eq "$(RES "run({'memo': R(hub='aibex-hub')}, hubs=('aibex-aios', 'aibex-hub'))")" "memo=6.0.0@aibex-hub" "named hub"
   assert_eq "$(RES "run({'knowledge-scorpio': R(hub='aibex-hub')})")" "knowledge-scorpio=0.1.0@aibex-hub sternkarte=1.0.0@aibex-hub<knowledge-scorpio" "dependency first in the hub of the package, also outside the hub list (H5)"
   assert_contains "$(RES "run({'gibtsnicht': R()})")" "NotFound package gibtsnicht not found in the hubs aibex-aios" "unknown package"
   assert_eq "$(RES "run(dict(a=R(), b=R(S('==1.0.0'))))")" "a=1.0.0@aibex-aios<b b=1.0.0@aibex-aios<a" "cycle in depends allowed when fulfillable"
   assert_contains "$(RES "run({'a': R()})")" "- a: no version fulfils the ranges; * (packages:); <1.0 (b 2.0.0)" "no backtracking over older versions of other packages (F5)"
   assert_eq "$(RES "run({'memo': R()}, kernel='0.3.1')")" "Conflict no versions fulfil all ranges:
- memo: no fitting version runs with AIOS 0.3.1 (requires.aios); * (packages:)" "kernel too old"
