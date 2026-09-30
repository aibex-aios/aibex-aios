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

   for D in "@/@Rule" bin lib/aios skills library templates python; do
      assert_dir "$SRC/$D"
   done
   assert_file "$SRC/VERSION"
   assert_file "$SRC/python/requirements.txt"
   assert_file "$SRC/templates/gitignore"
   assert_dir  "$REPO/spec"
   assert_exec "$SRC/bin/aios-context"

   assert_contains "$(cat "$SRC/python/requirements.txt")" "pyyaml" "requirements"
   assert_eq "$(cat "$SRC/templates/gitignore")" "$(printf '.DS_Store\n.claude/skills/\n.aios/manifest')" "gitignore template"

#===============================================================================
# bash scripts: syntax, help and version (bash convention)
#===============================================================================

   for S in "$SRC/bin/aios-context" "$REPO/tests/run"; do
      bash -n "$S" && ok || fail "syntax: $S"
   done
   assert_exit 1 "$SRC/bin/aios-context" -?
   assert_exit 1 "$SRC/bin/aios-context"
   assert_eq "$("$SRC/bin/aios-context" --version)" "$(cat "$SRC/VERSION")" "aios-context --version"
   assert_exit 2 "$SRC/bin/aios-context" --id

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
