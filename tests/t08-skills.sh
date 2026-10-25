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
   for S in aios-context aios-init aios-register aios-status aios-deploy aios-assistant aios-integrity aios-memo aios-gui aios-fetch aios-package aios-distribution; do
      assert_contains "$(at "$D" aios --skill "$S")" "Ein AIOS-Skill von AIbex AIOS" "--skill $S"
   done
   assert_exit 1 "$SRC/bin/aios" --skill aios-nope
   assert_exit 1 "$SRC/bin/aios" --skill aios-agent
   assert_eq "$(ls "$SRC/skills/aios" | tr '\n' ' ')" "aios-assistant aios-context aios-deploy aios-distribution aios-fetch aios-gui aios-init aios-integrity aios-memo aios-package aios-register aios-status " "AIOS skills of v0.5 (with aios-distribution)"
   FM() { sed -n '/^allowed-tools:/p' "$SRC/skills/aios/$1/SKILL.md"; }
   assert_eq "$(FM aios-distribution)" "allowed-tools: Bash(aios --library *), Bash(aios --install * --plan), Bash(aios --context *), Bash(git -C *), Bash(mkdir -p *), Write" "aios-distribution: allowed-tools (N16)"
   assert_contains "$(FM aios-package)" "Bash(aios --install distribution-*)" "aios-package: may install distributions"
   B="$(at "$D" aios --skill aios-distribution)"
   assert_contains "$B" 'aios --install distribution-<name> "<scratchpad>/§Probe-<name>" --from "<entwurf>" --plan' "aios-distribution: check with the resolver"
   assert_contains "$B" "tag v<version>\` (lokal, nicht gepusht)" "aios-distribution: local tag"
   assert_contains "$(at "$D" aios --skill aios-package)" "## Distribution installieren" "aios-package: recognizes distributions"
   assert_not_contains "$(at "$D" aios --skill aios-fetch)" "<paket>/<name> install" "aios-fetch: no workers of v0.4 any more"

#===============================================================================
# wrapper: name, description and allowed-tools from the version, body from aios --skill
#===============================================================================

   W="$(PYTHONPATH="$SRC/lib" python3 -c "
from aios import install
from pathlib import Path
m = install.frontmatter(Path('$SRC/skills/aios/aios-context/SKILL.md'))
print(install.wrapper('aios-context', m['description'], m.get('allowed-tools', '')), end='')")"
   assert_contains "$W" $'---\nname: aios-context\ndescription: "Prüft, ob der Master-Kontext' "wrapper: name and description"
   assert_contains "$W" "allowed-tools: Bash(aios --skill *), Bash(aios --context *), Read" "wrapper: allowed-tools"
   assert_contains "$W" $'---\n\n!`aios --skill aios-context`' "wrapper: body"

#===============================================================================
# aios --context --list: listing for /aios-context
#===============================================================================

   at "$D" "$SRC/bin/aios" --context --sync --yes >/dev/null
   rm -rf "$D/.claude/skills/notiz"
   OUT="$("$SRC/bin/aios" --context --list "$D")"
   ID="$("$SRC/bin/aios" --context --id "$D" | sed 's/^id=\([^ ]*\).*/\1/')"
   CH="$("$SRC/bin/aios" --context "$D" | python3 -c 'import sys; print(f"{len(sys.stdin.read()):,}".replace(",", "."))')"
   assert_eq "$OUT" "Master context id $ID, AIOS $(cat "$SRC/VERSION") — §Demo

Chain                      §Demo
Assistant                  none (no assignment)

Master context (loaded)    1 file, $CH characters
  §Demo/@/@Rule/stil.md
Available knowledge        1 file (not loaded, table of contents in the master context)
  §Demo/@/@@Buch/kapitel.md
Hidden                     Blueprints: 3 skills, 1 assistant, 1 prompt
  Skills       memo 6.0.0 (§Demo) — registered
               notiz 0.1.0 (§Demo) — not registered
               apfel 0.1.0 (assistant obstgaertner, private)
  Assistants   obstgaertner 0.1.0 (§Demo)
  Prompts      obstgaertner (§Demo)
Note: blueprints and registered skills differ — /aios-register" "--list: exact listing"
   assert_contains "$("$SRC/bin/aios" --context --list "$D/Garten")" "Chain                      §Demo → Garten" "--list: chain"
   assert_contains "$("$SRC/bin/aios" --context --list "$D/Wiese")" "Wiese (not initialized, chain up to §Demo)" "--list: not initialized"
   assert_eq "$("$SRC/bin/aios" --context --list "$SANDBOX/work/§Alt")" "Legacy mode (ai-brain, no aios: in the chain) — see /masterspace." "--list: legacy"
   assert_eq "$("$SRC/bin/aios" --context --list "$SANDBOX/outside")" "No vault — no master context." "--list: outside a vault"
   printf 'aios: 0.1.0\nassistant: obstgaertner\n' > "$D/.aios/config.yaml"
   assert_contains "$("$SRC/bin/aios" --context --list "$D")" "Assistant                  obstgaertner 0.1.0 (assigned in §Demo)" "--list: own assignment"
   assert_contains "$("$SRC/bin/aios" --context --list "$D/Garten")" "Assistant                  obstgaertner 0.1.0 (inherit, assigned in §Demo)" "--list: inherited assignment"
   printf 'aios: 0.1.0\nassistant: astronom\n' > "$D/.aios/config.yaml"
   assert_contains "$("$SRC/bin/aios" --context --list "$D")" "Assistant                  astronom (not found) (assigned in §Demo)" "--list: assistant not found"
   printf 'aios: 0.1.0\n' > "$D/.aios/config.yaml"

#===============================================================================
# aios --skill --session: the id replaces <session-id>; wrapper: id as a line of text (version-neutral)
#===============================================================================

   assert_contains "$(at "$D" aios --skill aios-assistant --session abc-123)" "--yes --session abc-123" "--skill --session: id in the body"
   case "$(at "$D" aios --skill aios-assistant --session abc-123)" in *'<session-id>'*) fail "--skill --session: no placeholder left" ;; *) ok ;; esac
   assert_contains "$(at "$D" aios --skill aios-assistant)" '<session-id>' "--skill without --session: placeholder stays"
   assert_contains "$(at "$D" aios --skill aios-assistant)" 'Zeile *Session-ID dieses Chats* am Ende dieser Anweisung' "body points to the line of the wrapper"
   assert_contains "$(at "$D" aios --skill aios-assistant --session ../x)" "is not a session id" "--skill --session: bad id"
   W="$(AIOS_CLAUDE_DIR="$SANDBOX/claude" PYTHONPATH="$SRC/lib" python3 -c "
from pathlib import Path
from aios import install
from aios.ui import Plan
d = Path('$SANDBOX/claude')
plan = Plan(); install.plan_skills(plan, Path('$SRC')); plan.run()
for n in ('aios-assistant', 'aios-context', 'aios-init'):
    print('==', n); print((d / 'skills' / n / 'SKILL.md').read_text())")"
   WA="$(printf '%s\n' "$W" | sed -n '/^== aios-assistant/,/^== aios-context/p')"
   WI="$(printf '%s\n' "$W" | sed -n '/^== aios-init/,$p')"
   assert_contains "$WA" '!`aios --skill aios-assistant`' "wrapper calls only aios --skill <name> (every version understands it)"
   assert_contains "$WA" 'Session-ID dieses Chats: `${CLAUDE_SESSION_ID}`' "wrapper: session id as a line of text"
   case "$W" in *"--skill aios-assistant --session"*|*"--skill aios --context --session"*) fail "wrapper: no --session flag (v0.2 does not know it)" ;; *) ok ;; esac
   assert_contains "$(printf '%s\n' "$W" | sed -n '/^== aios-context/,/^== aios-init/p')" 'Session-ID dieses Chats' "wrapper of aios-context with the session line"
   case "$WI" in *"Session-ID"*) fail "wrapper without session id stays plain" ;; *) ok ;; esac

#===============================================================================
# --plan and --yes on writing commands (for skills)
#===============================================================================

   OUT="$("$SRC/bin/aios" --activate v0.1.0 "$D/Garten/Beet" --plan 2>&1)"; RC=$?
   assert_contains "$OUT" "/aios-init" "--plan: checks still apply"
   OUT="$("$SRC/bin/aios" --register "$D" --plan 2>&1)"; RC=$?
   assert_eq "$RC" "0" "--plan: exit 0"
   assert_contains "$OUT" "(plan only, nothing written)" "--plan: plan only"
   [ ! -e "$D/.claude/skills/notiz" ] && ok || fail "--plan: nothing written"
   assert_contains "$(at "$D" "$SRC/bin/aios" --context --sync --plan)" "changed  notiz" "aios --context --sync --plan (copy deleted: changed)"
   [ ! -e "$D/.claude/skills/notiz" ] && ok || fail "--sync --plan: nothing written"
   "$SRC/bin/aios" --register "$D" --yes </dev/null >/dev/null 2>&1
   assert_file "$D/.claude/skills/notiz/SKILL.md"

#===============================================================================
# aios --init: checks, plan, name rule, project with git and first commit (spec 05)
#===============================================================================

   assert_contains "$("$SRC/bin/aios" --init "$SANDBOX/outside" 2>&1)" "is not in a vault" "init: outside a vault"
   assert_contains "$("$SRC/bin/aios" --init "$SANDBOX/work/§Alt/Feld" 2>&1)" "is not activated" "init: legacy vault"
   OUT="$("$SRC/bin/aios" --init "$D" --plan 2>&1)"
   assert_contains "$OUT" "the project $D" "init: vault root allowed"
   case "$OUT" in *"name "*) fail "init: vault root exempt from the name rule" ;; *) ok ;; esac
   assert_contains "$("$SRC/bin/aios" --init "$D/Garten" --plan 2>&1)" "git init (branch main)" "init: existing project is completed"

   OUT="$(at "$D/Wiese" "$SRC/bin/aios" --init --plan)"; RC=$?
   assert_eq "$RC" "0" "init --plan: exit 0"
   assert_contains "$OUT" "name Wiese: the name has no prefix" "init plan: name rule"
   assert_contains "$OUT" "proposal: W-Wiese" "init plan: proposal"
   assert_contains "$OUT" "create @/ (with .gitkeep)" "init plan: masterspace"
   assert_contains "$OUT" ".gitignore: .DS_Store, .claude/skills/, .agents/, .aios/registry, .aios/backup/" "init plan: gitignore"
   assert_contains "$OUT" "git init (branch main)" "init plan: git init"
   [ ! -e "$D/Wiese/@" ] && [ ! -e "$D/Wiese/.git" ] && ok || fail "init --plan: nothing written"
   OUT="$(at "$D/Wiese" "$SRC/bin/aios" --init --yes)"; RC=$?
   assert_eq "$RC" "2" "init --yes with a name violation: exit 2"
   assert_contains "$OUT" "run again with --name <name> (proposal) or --accept-name" "violation: hint"
   [ ! -e "$D/Wiese/@" ] && ok || fail "violation: nothing written"

   printf 'eigen.txt\n.DS_Store\n' > "$D/Wiese/.gitignore"
   OUT="$(at "$D/Wiese" "$SRC/bin/aios" --init --accept-name --yes)"; RC=$?
   assert_eq "$RC" "0" "init --accept-name --yes: exit 0"
   assert_eq "$OUT" "=> $D/Wiese is a project" "init --yes: only the result"
   assert_file "$D/Wiese/@/.gitkeep"
   [ ! -e "$D/Wiese/@Memo" ] && ok || fail "init: no @Memo/ (spec 05)"
   assert_eq "$(cat "$D/Wiese/.gitignore")" "$(printf 'eigen.txt\n.DS_Store\n.claude/skills/\n.agents/\n.aios/registry\n.aios/backup/')" "init: .gitignore completed, own lines kept"
   assert_eq "$(git -C "$D/Wiese" symbolic-ref --short HEAD)" "main" "init: branch main"
   assert_eq "$(git -C "$D/Wiese" log --format=%s)" "AIOS: Projekt initialisiert" "init: first commit"
   assert_eq "$(git -C "$D/Wiese" show --name-only --format= | sort | tr '\n' ' ')" ".gitignore @/.gitkeep " "init: committed files"
   assert_file "$D/Wiese/.claude/skills/memo/SKILL.md"
   assert_eq "$(git -C "$D/Wiese" status --porcelain)" "" "init: working tree clean (build output ignored)"
   assert_eq "$(at "$D/Wiese" "$SRC/bin/aios" --init --accept-name </dev/null)" "=> $D/Wiese is a complete project, nothing to do" "init again: nothing to do"

   OUT="$(at "$D" sh -c "echo y | '$SRC/bin/aios' --init '$D/W2-Weide' --accept-name")"
   assert_contains "$OUT" "create the folder $D/W2-Weide" "init: folder created"
   assert_contains "$OUT" "from the next chat" "init: hint next chat without --yes"
   assert_dir "$D/W2-Weide/@"

   OUT="$("$SRC/bin/aios" --init "$D/wiese drei" --name W-Wiese-Drei --plan 2>&1)"
   assert_contains "$OUT" "create the folder $D/W-Wiese-Drei" "--name: folder under the new name"
   case "$OUT" in *"name W-"*) fail "--name: conforming name, no violation" ;; *) ok ;; esac
   mkdir -p "$D/feld vier"
   "$SRC/bin/aios" --init "$D/feld vier" --name F-Feld-Vier --yes >/dev/null 2>&1
   [ -d "$D/F-Feld-Vier/@" ] && [ ! -e "$D/feld vier" ] && ok || fail "--name: existing folder renamed"
   assert_contains "$("$SRC/bin/aios" --init "$D/A-Acker" --assistant Bad_Name --plan 2>&1)" "is not an assistant name" "--assistant: name checked"
   "$SRC/bin/aios" --init "$D/A-Acker" --assistant gaertner --yes >/dev/null 2>&1
   assert_eq "$(cat "$D/A-Acker/.aios/config.yaml")" "assistant: gaertner" "--assistant written"
   assert_eq "$(git -C "$D/A-Acker" show --name-only --format= | sort | tr '\n' ' ')" ".aios/config.yaml .gitignore @/.gitkeep " "--assistant: config committed"

#===============================================================================
# aios --init and the repo above (S4): exclusion, git rm --cached, commit there
#===============================================================================

   git -C "$D" init -q
   printf '.DS_Store\n' > "$D/.gitignore"
   mkdir -p "$D/G-Garten/B-Beet/@"; printf '# Beet\n' > "$D/G-Garten/B-Beet/@/beet.md"
   git -C "$D" add .gitignore G-Garten && git -C "$D" commit -qm vorher
   OUT="$("$SRC/bin/aios" --init "$D/G-Garten/B-Beet" --accept-name --plan 2>&1)"
   assert_contains "$OUT" "repo above $D: /G-Garten/B-Beet/ in $D/.gitignore; git rm -r --cached G-Garten/B-Beet (1 files" "init plan: exclusion in the repo above"
   "$SRC/bin/aios" --init "$D/G-Garten/B-Beet" --accept-name --yes >/dev/null 2>&1
   assert_eq "$(git -C "$D" log -1 --format=%s)" "AIOS: G-Garten/B-Beet als eigenes Projekt ausgeschlossen" "commit in the repo above"
   assert_eq "$(git -C "$D" ls-files G-Garten)" "" "repo above: files no longer tracked"
   assert_file "$D/G-Garten/B-Beet/@/beet.md"
   assert_eq "$(git -C "$D" status --porcelain -- G-Garten .gitignore)" "" "repo above: exclusion committed, subproject not shown"
   assert_eq "$(git -C "$D/G-Garten/B-Beet" log --format=%s)" "AIOS: Projekt initialisiert" "own repo of the subproject"
   assert_eq "$(git -C "$D/G-Garten/B-Beet" ls-files @/beet.md)" "@/beet.md" "files taken over from the repo above are committed (A14)"
   assert_eq "$(git -C "$D/G-Garten/B-Beet" status --porcelain)" "" "subproject: nothing left uncommitted (A14)"
   rm "$D/G-Garten/B-Beet/.gitignore"
   OUT="$("$SRC/bin/aios" --init "$D/G-Garten/B-Beet" --accept-name --yes 2>&1)"
   assert_not_contains "$OUT" "commit failed" "restored .gitignore with the same content: no false warning (A16)"
   assert_eq "$(git -C "$D/G-Garten/B-Beet" log --format=%s | wc -l | tr -d ' ')" "1" "restored .gitignore: no new commit (A16)"
   mkdir -p "$D/F-Fall"
   "$SRC/bin/aios" --init "$D/F-Fall" --name F-FALL --yes >/dev/null 2>&1
   assert_eq "$(ls "$D" | grep -x 'F-F[Aa][Ll][Ll]')" "F-FALL" "rename only in the case of the name (A13)"
   assert_dir "$D/F-FALL/@"
   mkdir -p "$D/H-Hof"; printf 'x\n' > "$D/notiz.txt"; git -C "$D" add notiz.txt
   "$SRC/bin/aios" --init "$D/H-Hof" --yes >"$SANDBOX/hof.out" 2>&1
   assert_contains "$(cat "$SANDBOX/hof.out")" "has staged changes; commit the exclusion there by hand" "staged changes above: no commit there"
   assert_contains "$(cat "$D/.gitignore")" "/H-Hof/" "exclusion written anyway"

#===============================================================================
# v0.3 step 7: /aios-memo - body of memo==6.0.0, precedence of a registered memo
#===============================================================================

   MEMO_BODY="$(python3 -c "
import sys; t=open(sys.argv[1],encoding='utf-8').read(); e=t.find('\n---',3); print(t[t.find('\n',e+4)+1:].lstrip('\n'),end='')" "$SRC/tests/hub/aibex-aios/skill-memo/6.0.0/skills/memo/SKILL.md")"
   assert_contains "$(head -5 "$SRC/tests/hub/aibex-aios/skill-memo/6.0.0/skills/memo/SKILL.md")" "version: 6.0.0" "package skill-memo 6.0.0 (aios-memo carries its body)"
   mkdir -p "$D/Notiz/@"
   OUT="$(at "$D/Notiz" aios --skill aios-memo)"
   case "$OUT" in *"$MEMO_BODY"*) ok ;; *) fail "aios-memo: body of memo==6.0.0" ;; esac
   assert_contains "$OUT" "Fehlt \`@Memo/\` im Projekt, lege ihn beim ersten Memo an." "aios-memo: creates @Memo/"
   assert_contains "$(sed -n 1,10p "$SRC/skills/aios/aios-memo/SKILL.md")" 'Nur verwenden, wenn kein Skill `memo` verfügbar ist.' "aios-memo: description defers to memo"
   mk "$D/Notiz/.aios/registry" $'# written by AIOS (registration), do not edit\nschema: 1\nregistered:\n  memo:\n    source: "x"\n    version: 6.0.0\n    digest: sha256:0\n'
   assert_eq "$(at "$D/Notiz" aios --skill aios-memo)" "Use \`/memo\` — the skill \`memo\` is registered in this project." "memo registered: precedence"
   assert_eq "$(at "$D/Notiz/@" aios --skill aios-memo)" "Use \`/memo\` — the skill \`memo\` is registered in this project." "precedence from a folder inside the project"
   mk "$D/Notiz/.aios/registry" $'# written by AIOS (registration), do not edit\nschema: 1\nregistered:\n  notiz:\n    source: "x"\n    version: 0.1.0\n    digest: sha256:0\n'
   case "$(at "$D/Notiz" aios --skill aios-memo)" in *"$MEMO_BODY"*) ok ;; *) fail "other skills registered: body" ;; esac
   case "$(at "$SANDBOX/outside" "$SRC/bin/aios" --skill aios-memo)" in *"$MEMO_BODY"*) ok ;; *) fail "outside a vault: body" ;; esac
