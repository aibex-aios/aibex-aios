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

   for D in bin lib/aios skills/aios templates python spec dev tests; do
      assert_dir "$SRC/$D"
   done
   assert_file "$REPO/CLAUDE.md"
   assert_file "$REPO/dev/Bash-Skript-Struktur.md"
   [ ! -e "$REPO/§AIOS" ] && ok || fail "no vault in the repo: §AIOS exists"
   [ ! -e "$REPO/library" ] && ok || fail "library/ replaced by skills/<group>/"
   assert_file "$SRC/VERSION"
   assert_file "$SRC/python/requirements.txt"
   assert_file "$SRC/templates/gitignore"
   [ ! -e "$SRC/bin/aios-context" ] && ok || fail "bin/aios-context is gone (aios --context, V0.5, memo 04)"

   assert_contains "$(cat "$SRC/python/requirements.txt")" "pyyaml" "requirements"
   assert_eq "$(cat "$SRC/templates/gitignore")" "$(printf '.DS_Store\n.claude/skills/\n.aios/registry')" "gitignore template"

#===============================================================================
# bash scripts: syntax, help and version (bash convention)
#===============================================================================

   for S in "$SRC/bin/aios" "$SRC/templates/forwarder" "$REPO/tests/run"; do
      bash -n "$S" && ok || fail "syntax: $S"
   done
   assert_exit 1 "$SRC/bin/aios" --context -?
   assert_exit 1 "$SRC/bin/aios" --context --nope
   assert_eq "$("$SRC/bin/aios" --version)" "$(cat "$SRC/VERSION")" "aios --version"
   assert_exit 1 "$SRC/bin/aios" --context --assistant obstgaertner
   assert_contains "$("$SRC/bin/aios" -? 2>&1)" "aios --context --session|--advise" "help names the group --context"

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
# development state: bin/ holds aios (spec 04)
#===============================================================================

   assert_exec "$SRC/bin/aios"
   assert_exit 1 "$SRC/bin/aios" -?
   assert_eq "$("$SRC/bin/aios" --version)" "$(cat "$SRC/VERSION")" "aios --version"
   assert_exit 1 "$SRC/bin/aios" --deploy memo-6.0.0

#===============================================================================
# v0.4: no library in the kernel; manifest.yaml of the kernel (spec 04, 06)
#===============================================================================

   [ ! -e "$SRC/skills/basic" ] && [ ! -e "$SRC/assistants" ] && ok || fail "no library (skills/basic, assistants) in the kernel"
   assert_eq "$(ls "$SRC/skills")" "aios" "only AIOS skills"
   assert_eq "$(sed -n 's/^version: //p' "$SRC/manifest.yaml")" "$(cat "$SRC/VERSION")" "manifest.yaml: version as VERSION"
   assert_contains "$(cat "$SRC/manifest.yaml")" "type: kernel" "manifest.yaml: type kernel"
