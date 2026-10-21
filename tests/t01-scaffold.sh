# t01-scaffold.sh: step 1 of the plan (memo 18) - repo scaffold and sandbox

#===============================================================================
# sandbox isolates HOME, AIOS_PREFIX and AIOS_CLAUDE_DIR
#===============================================================================

   assert_contains "$HOME" "aios-test." "HOME in sandbox"
   assert_eq "$AIOS_PREFIX" "$SANDBOX/opt/aios" "AIOS_PREFIX"
   assert_eq "$AIOS_CLAUDE_DIR" "$HOME/.claude" "AIOS_CLAUDE_DIR"

#===============================================================================
# repo layout (spec 04, Repo aibex-aios)
#===============================================================================

   for D in bin lib/aios skills/aios skills/basic templates python spec dev tests; do
      assert_dir "$SRC/$D"
   done
   assert_file "$REPO/CLAUDE.md"
   assert_file "$REPO/dev/Bash-Skript-Struktur.md"
   [ ! -e "$REPO/§AIOS" ] && ok || fail "no vault in the repo: §AIOS exists"
   [ ! -e "$REPO/library" ] && ok || fail "library/ replaced by skills/<group>/"
   assert_file "$SRC/VERSION"
   assert_file "$SRC/python/requirements.txt"
   assert_file "$SRC/templates/gitignore"
   assert_exec "$SRC/bin/aios-context"

   assert_contains "$(cat "$SRC/python/requirements.txt")" "pyyaml" "requirements"
   assert_eq "$(cat "$SRC/templates/gitignore")" "$(printf '.DS_Store\n.claude/skills/\n.aios/registry')" "gitignore template"

#===============================================================================
# bash scripts: syntax, help and version (bash convention)
#===============================================================================

   for S in "$SRC/bin/aios-context" "$REPO/tests/run"; do
      bash -n "$S" && ok || fail "syntax: $S"
   done
   assert_exit 1 "$SRC/bin/aios-context" -?
   assert_exit 1 "$SRC/bin/aios-context"
   assert_eq "$("$SRC/bin/aios-context" --version)" "$(cat "$SRC/VERSION")" "aios-context --version"
   assert_exit 1 "$SRC/bin/aios-context" --assistant obstgaertner

#===============================================================================
# python part: paths follow the redirection variables
#===============================================================================

   PYOUT="$(PYTHONPATH="$SRC/lib" python3 -c '
import aios, aios.paths as p
print(aios.version()); print(p.prefix()); print(p.user_dir()); print(p.claude_dir()); print(p.bin_dir())')"
   assert_eq "$(sed -n 1p <<< "$PYOUT")" "$(cat "$SRC/VERSION")" "aios.version()"
   assert_eq "$(sed -n 2p <<< "$PYOUT")" "$AIOS_PREFIX" "paths.prefix()"
   assert_eq "$(sed -n 3p <<< "$PYOUT")" "$HOME/.aios" "paths.user_dir()"
   assert_eq "$(sed -n 4p <<< "$PYOUT")" "$AIOS_CLAUDE_DIR" "paths.claude_dir()"
   assert_eq "$(sed -n 5p <<< "$PYOUT")" "$HOME/bin" "paths.bin_dir()"

#===============================================================================
# development state: bin/ holds aios and aios-context (spec 04)
#===============================================================================

   assert_exec "$SRC/bin/aios"
   assert_exit 1 "$SRC/bin/aios" -?
   assert_eq "$("$SRC/bin/aios" --version)" "$(cat "$SRC/VERSION")" "aios --version"
   assert_exit 1 "$SRC/bin/aios" --deploy memo-6.0.0

#===============================================================================
# library of the repo: demo assistants gaertner and astronom (spec 03, memo 17 of V0.2)
#===============================================================================

   assert_eq "$(PYTHONPATH="$SRC/lib" python3 -c '
import sys
from pathlib import Path
from aios import install
print(" ".join(f"{g}/{n}=={v}" for g, n, _, v in install.assistants_of(Path(sys.argv[1]))))' "$SRC")" \
      "demo/astronom==0.1.0 demo/gaertner==0.2.0" "library: demo assistants with versions (Gärtner 0.2.0 with surface)"
   case "$(grep -rl -e 'P-Projekte' -e 'PC-Custom-AI' -e '§AIbex' "$SRC/assistants")" in
      "") ok ;; *) fail "demo assistants contain no paths of a particular vault" ;;
   esac
   for F in "gaertner/@!Skill/apfel-birnen-algebra" "gaertner/@!Skill/gaertner-gui" "astronom/@!Skill/sonne-mond-zahlen"; do
      assert_contains "$(sed -n 1,4p "$SRC/assistants/demo/$F/SKILL.md")" "version: 0.1.0" "private skill with version: $F"
   done
