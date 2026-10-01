# t08-skills.sh: step 8 of the plan (memo 18) - aios --skill, wrappers, --list, aios --init, --plan/--yes

#===============================================================================
# setup: two installations (copies of the clone) with different skill bodies, forwarder
#===============================================================================

   mkdir -p "$HOME/bin"
   export PATH="$HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin"
   export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
   cp "$SRC/templates/forwarder" "$HOME/bin/aios"; chmod +x "$HOME/bin/aios"
   for V in 0.1.0 0.2.0; do
      I="$AIOS_PREFIX/v$V"; mkdir -p "$I"
      cp -R "$SRC/bin" "$SRC/lib" "$SRC/skills" "$SRC/templates" "$I/"
      echo "$V" > "$I/VERSION"
      echo "v$V: $I" >> "$AIOS_PREFIX/installations.yaml"
   done
   printf '\nNur in Version 0.2.0.\n' >> "$AIOS_PREFIX/v0.2.0/skills/aios/aios-init/SKILL.md"

   D="$SANDBOX/work/§Demo"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   skill() { mk "$1/SKILL.md" "$(printf -- '---\nname: %s\ndescription: d\n%s---\n\n# %s\n' "$2" "${3:+version: $3
}" "$2")"; }
   mk "$D/.aios/config.yaml" $'aios: 0.1.0\n'
   mk "$D/@/@Rule/stil.md" $'# Stil\nklar\n'
   mk "$D/@/@@Buch/kapitel.md" $'# Kapitel\n'
   skill "$D/@/@!Skill/memo" memo 6.0.0
   skill "$D/@/@!Skill/notiz" notiz 0.1.0
   mk "$D/@/@!Prompt/obstgaertner.md" $'# Prompt\n'
   mk "$D/@/@!Assistant/obstgaertner/ASSISTANT.md" $'---\nname: obstgaertner\nversion: 0.1.0\n---\n'
   skill "$D/@/@!Assistant/obstgaertner/@!Skill/apfel" apfel 0.1.0
   mk "$D/Garten/@/garten.md" $'# Garten\n'
   mk "$D/Garten/.aios/config.yaml" $'aios: 0.2.0\n'
   mkdir -p "$D/Wiese" "$D/Garten/Beet" "$SANDBOX/work/§Alt/Feld" "$SANDBOX/outside"
   at() { (cd "$1" && shift && "$@" 2>&1); }

#===============================================================================
# aios --skill: body without frontmatter, from the version valid for cwd
#===============================================================================

   assert_eq "$(at "$D" aios --skill aios-init)" "$(python3 -c "
import sys; t=open(sys.argv[1],encoding='utf-8').read(); e=t.find('\n---',3); print(t[t.find('\n',e+4)+1:].lstrip('\n'),end='')" "$SRC/skills/aios/aios-init/SKILL.md")" "--skill: body without frontmatter"
   case "$(at "$D" aios --skill aios-init)" in *"name: aios-init"*|*"allowed-tools"*) fail "--skill: no frontmatter" ;; *) ok ;; esac
   case "$(at "$D" aios --skill aios-init)" in *"Nur in Version 0.2.0"*) fail "--skill in §Demo: version 0.1.0" ;; *) ok ;; esac
   assert_contains "$(at "$D/Garten" aios --skill aios-init)" "Nur in Version 0.2.0" "--skill in Garten: version 0.2.0"
   for S in aios-context aios-init aios-register aios-status aios-deploy aios-assistant; do
      assert_contains "$(at "$D" aios --skill "$S")" "Ein AIOS-Skill von AIbex AIOS" "--skill $S"
   done
   assert_exit 1 "$SRC/bin/aios" --skill aios-nope
   assert_exit 1 "$SRC/bin/aios" --skill aios-agent
   assert_eq "$(ls "$SRC/skills/aios" | tr '\n' ' ')" "aios-assistant aios-context aios-deploy aios-init aios-register aios-status " "AIOS skills of v0.2 (aios-assistant, no aios-agent)"

#===============================================================================
# wrapper: name, description and allowed-tools from the version, body from aios --skill
#===============================================================================

   W="$(PYTHONPATH="$SRC/lib" python3 -c "
from aios import install
from pathlib import Path
m = install.frontmatter(Path('$SRC/skills/aios/aios-context/SKILL.md'))
print(install.wrapper('aios-context', m['description'], m.get('allowed-tools', '')), end='')")"
   assert_contains "$W" $'---\nname: aios-context\ndescription: "Prüft, ob der Master-Kontext' "wrapper: name and description"
   assert_contains "$W" "allowed-tools: Bash(aios --skill *), Bash(aios-context *), Read" "wrapper: allowed-tools"
   assert_contains "$W" $'---\n\n!`aios --skill aios-context`' "wrapper: body"

#===============================================================================
# aios-context --list: listing for /aios-context
#===============================================================================

   at "$D" "$SRC/bin/aios-context" --sync --yes >/dev/null
   rm -rf "$D/.claude/skills/notiz"
   OUT="$("$SRC/bin/aios-context" --list "$D")"
   ID="$("$SRC/bin/aios-context" --id "$D" | sed 's/^id=\([^ ]*\).*/\1/')"
   CH="$("$SRC/bin/aios-context" --context "$D" | python3 -c 'import sys; print(f"{len(sys.stdin.read()):,}".replace(",", "."))')"
   assert_eq "$OUT" "Master-Kontext id $ID, AIOS $(cat "$SRC/VERSION") — §Demo

Kette                      §Demo

Master-Kontext (geladen)   1 Datei, $CH Zeichen
  §Demo/@/@Rule/stil.md
verfügbares Wissen         1 Datei (nicht geladen, Inhaltsverzeichnis im Master-Kontext)
  §Demo/@/@@Buch/kapitel.md
Verborgen                  Blueprints: 3 Skills, 1 Assistent, 1 Prompt
  Skills       memo 6.0.0 (§Demo) — registriert
               notiz 0.1.0 (§Demo) — nicht registriert
               apfel 0.1.0 (Assistent obstgaertner, privat)
  Assistenten  obstgaertner 0.1.0 (§Demo)
  Prompts      obstgaertner (§Demo)
Hinweis: Blueprints und registrierte Skills stimmen nicht überein — /aios-register" "--list: exact listing"
   assert_contains "$("$SRC/bin/aios-context" --list "$D/Garten")" "Kette                      §Demo → Garten" "--list: chain"
   assert_contains "$("$SRC/bin/aios-context" --list "$D/Wiese")" "Wiese (nicht initialisiert, Kette bis §Demo)" "--list: not initialized"
   assert_eq "$("$SRC/bin/aios-context" --list "$SANDBOX/work/§Alt")" "Legacy-Modus (ai-brain, kein aios: in der Kette) — siehe /masterspace." "--list: legacy"
   assert_eq "$("$SRC/bin/aios-context" --list "$SANDBOX/outside")" "Kein Vault — kein Master-Kontext." "--list: outside a vault"

#===============================================================================
# --plan and --yes on writing commands (for skills)
#===============================================================================

   OUT="$("$SRC/bin/aios" --activate v0.1.0 "$D/Garten/Beet" --plan 2>&1)"; RC=$?
   assert_contains "$OUT" "/aios-init" "--plan: checks still apply"
   OUT="$("$SRC/bin/aios" --register "$D" --plan 2>&1)"; RC=$?
   assert_eq "$RC" "0" "--plan: exit 0"
   assert_contains "$OUT" "(plan only, nothing written)" "--plan: plan only"
   [ ! -e "$D/.claude/skills/notiz" ] && ok || fail "--plan: nothing written"
   assert_contains "$(at "$D" "$SRC/bin/aios-context" --sync --plan)" "changed  notiz" "aios-context --sync --plan (copy deleted: changed)"
   [ ! -e "$D/.claude/skills/notiz" ] && ok || fail "--sync --plan: nothing written"
   "$SRC/bin/aios" --register "$D" --yes </dev/null >/dev/null 2>&1
   assert_file "$D/.claude/skills/notiz/SKILL.md"

#===============================================================================
# aios --init: checks, plan, project with git and first commit
#===============================================================================

   assert_contains "$("$SRC/bin/aios" --init "$SANDBOX/outside" 2>&1)" "is not in a vault" "init: outside a vault"
   assert_contains "$("$SRC/bin/aios" --init "$SANDBOX/work/§Alt/Feld" 2>&1)" "is not activated" "init: legacy vault"
   assert_contains "$("$SRC/bin/aios" --init "$D" 2>&1)" "the vault root is the root project" "init: vault root"
   assert_contains "$("$SRC/bin/aios" --init "$D/Garten" 2>&1)" "is already a project" "init: already a project"

   OUT="$(at "$D/Wiese" "$SRC/bin/aios" --init --plan)"; RC=$?
   assert_eq "$RC" "0" "init --plan: exit 0"
   assert_contains "$OUT" "create @/ and @Memo/ (with .gitkeep), .gitignore: .DS_Store, .claude/skills/, .aios/manifest" "init plan: files"
   assert_contains "$OUT" "git init (branch main)" "init plan: git init"
   [ ! -e "$D/Wiese/@" ] && [ ! -e "$D/Wiese/.git" ] && ok || fail "init --plan: nothing written"

   printf 'eigen.txt\n.DS_Store\n' > "$D/Wiese/.gitignore"
   OUT="$(at "$D/Wiese" "$SRC/bin/aios" --init --yes)"; RC=$?
   assert_eq "$RC" "0" "init --yes: exit 0"
   assert_file "$D/Wiese/@/.gitkeep"
   assert_file "$D/Wiese/@Memo/.gitkeep"
   assert_eq "$(cat "$D/Wiese/.gitignore")" "$(printf 'eigen.txt\n.DS_Store\n.claude/skills/\n.aios/manifest')" "init: .gitignore completed, own lines kept"
   assert_eq "$(git -C "$D/Wiese" symbolic-ref --short HEAD)" "main" "init: branch main"
   assert_eq "$(git -C "$D/Wiese" log --format=%s)" "AIOS: Projekt initialisiert" "init: first commit"
   assert_eq "$(git -C "$D/Wiese" show --name-only --format= | sort | tr '\n' ' ')" ".gitignore @/.gitkeep @Memo/.gitkeep " "init: committed files"
   assert_file "$D/Wiese/.claude/skills/memo/SKILL.md"
   assert_contains "$OUT" "from the next chat" "init: hint next chat"
   assert_eq "$(git -C "$D/Wiese" status --porcelain)" "" "init: working tree clean (build output ignored)"

   git -C "$D" init -q
   OUT="$(at "$D/Garten/Beet" "$SRC/bin/aios" --init --plan)"
   assert_contains "$OUT" "lies inside the git repository $(cd "$D" && pwd -P)" "init plan: nested repository noted"
