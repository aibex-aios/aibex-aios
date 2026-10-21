# t13-gui.sh: step 8 of the plan (V0.3, memo 32) - surfaces: gui.yaml, aios --gui, alias /gui, aios-gui (spec 03, 04)

#===============================================================================
# setup: a python with PyYAML (gui.yaml is read with PyYAML), vault with the demo Gärtner 0.2.0
#===============================================================================

   PYDIR=""
   for P in $(type -ap python3) /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
      [ -x "$P" ] && "$P" -c "import yaml" 2>/dev/null && { PYDIR="$(dirname "$P")"; break; }
   done
   [ -n "$PYDIR" ] && ok || fail "t13 needs a python3 with PyYAML (pip install pyyaml)"
   export PATH="$PYDIR:/usr/bin:/bin:/usr/sbin:/sbin"
   D="$SANDBOX/work/§Demo"; G="$D/Garten"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   mk "$D/.aios/config.yaml" $'aios: 0.3.0\n'
   mkdir -p "$D/@/@!Assistant" "$G/@/@!Assistant" "$D/Wiese/@"
   cp -R "$SRC/tests/hub/aibex-aios/assistent-gaertner/0.2.0/assistants/gaertner" "$G/@/@!Assistant/gaertner"
   cp -R "$SRC/tests/hub/aibex-aios/assistent-astronom/0.2.0/assistants/astronom" "$D/@/@!Assistant/astronom"
   at() { (cd "$1" && shift && "$@" 2>&1); }
   GUI() { local d="$1"; shift; at "$d" "$SRC/bin/aios" --gui "$@"; }
   GG="$G/@/@!Assistant/gaertner/@!Skill/gaertner-gui"

#===============================================================================
# /gui: no assistant, assistant without surface, Gärtner with surface
#===============================================================================

   assert_eq "$(GUI "$G")" $'No assistant active.\nAIOS surface: `/aios-gui`' "no assignment: no assistant"
   mk "$D/.aios/config.yaml" $'aios: 0.3.0\nassistant: astronom\n'
   assert_eq "$(GUI "$D/Wiese")" $'The assistant Astronom has no surface.\nAIOS surface: `/aios-gui`' "assistant without gui"
   mk "$G/.aios/config.yaml" $'assistant: gaertner\n'
   OUT="$(GUI "$G")"
   assert_contains "$OUT" "# Oberfläche des Gärtners" "body of the surface skill"
   case "$OUT" in *"version: 0.1.0"*|*"name: gaertner-gui"*) fail "body without frontmatter" ;; *) ok ;; esac
   assert_contains "$OUT" "## Show the surface" "instruction appended"
   assert_contains "$OUT" "run \`aios --gui --html\` and show" "instruction: HTML in the desktop app"
   assert_contains "$OUT" "at most 4 entries per level" "instruction: menu otherwise"
   assert_contains "$OUT" "- Apfel-Birnen-Rechner — Rechnet mit Äpfeln und Birnen, ohne Claude (HTML part rechner.html)" "tile with HTML part"
   assert_contains "$OUT" "- Aufgabe rechnen — Eine Apfel-Birnen-Aufgabe mit Rechenweg (sends: Run the skill /apfel-birnen-algebra.)" "skill tile sends /<skill>"
   assert_contains "$OUT" "(sends: Hilf mir, eine Apfelsorte zu bestimmen. Frag mich nach den Merkmalen.)" "prompt tile"

#===============================================================================
# --html: fragment with buttons (sendPrompt) and embedded HTML parts
#===============================================================================

   OUT="$(GUI "$G" --html)"
   case "$OUT" in "<div class=\"aios-gui\">"*) ok ;; *) fail "--html: fragment" ;; esac
   case "$OUT" in *"<html"*|*"<head"*|*"<body"*) fail "--html: no html, head, body" ;; *) ok ;; esac
   assert_contains "$OUT" "<h2>Gärtner</h2>" "--html: title"
   assert_contains "$OUT" "<p>Was möchtest du heute im Garten wissen?</p>" "--html: intro"
   assert_contains "$OUT" 'data-prompt="Run the skill /apfel-birnen-algebra."' "--html: skill tile sends a sentence (the app drops messages starting with /)"
   case "$OUT" in *'data-prompt="/'*) fail "--html: no data-prompt starting with /" ;; *) ok ;; esac
   assert_contains "$OUT" 'data-prompt="Hilf mir, eine Apfelsorte zu bestimmen. Frag mich nach den Merkmalen."' "--html: prompt tile"
   assert_contains "$OUT" 'data-part="aios-part-1"' "--html: HTML tile jumps to its part"
   assert_contains "$OUT" 'sendPrompt(b.dataset.prompt)' "--html: one script connects the tiles (sendPrompt)"
   case "$OUT" in *onclick*) fail "--html: no inline handlers (hosts drop them)" ;; *) ok ;; esac
   assert_eq "$(printf '%s\n' "$OUT" | python3 -c '
import sys, re
t = sys.stdin.read()
inner = t[:t.rindex("</div>")]                      # everything up to the end of the container
print(len(re.findall("<script", inner)), len(re.findall("<script", t)))')" "0 2" "--html: no script inside the container, part script and tile script at top level"
   assert_contains "$OUT" '<section class="part" id="aios-part-1"><h3>Apfel-Birnen-Rechner</h3>' "--html: HTML part embedded"
   assert_contains "$OUT" 'id="abr-out"' "--html: content of rechner.html"

#===============================================================================
# assistant of the session from the marker, switching without registration
#===============================================================================

   mkdir -p "$HOME/.aios/sessions"
   printf '# written by AIOS (session), do not edit\ncwd: "%s"\nassistant: astronom\nused: 2026-10-03T10:00:00\n' "$G" > "$HOME/.aios/sessions/s1.yaml"
   assert_contains "$(GUI "$G" --session s1)" "The assistant Astronom has no surface." "--session: assistant of the session"
   assert_contains "$(GUI "$G" --session s2)" "# Oberfläche des Gärtners" "--session without marker: assignment"
   assert_contains "$(GUI "$G" --session ../x)" "is not a session id" "--session: bad id"
   assert_contains "$(GUI "$G" --session s2)" "\`aios --gui --session s2 --html\`" "instruction keeps --session"

#===============================================================================
# /aios-gui: the surface of AIOS with its 7 tiles
#===============================================================================

   OUT="$(GUI "$G" --aios)"
   assert_contains "$OUT" "# AIbex AIOS" "--aios: title"
   for T in "Projekt initialisieren" "Kontext und Konfiguration" "Assistent zuordnen" "Pakete" "Apps" "Pakete abgleichen und Skills registrieren" "Integrität prüfen" "Projektstatus" "Memo schreiben"; do
      assert_contains "$OUT" "- $T — " "--aios: tile $T"
   done
   assert_eq "$(printf '%s\n' "$OUT" | grep -c '^- .*(sends: ')" "9" "--aios: 9 tiles"
   assert_contains "$OUT" "(sends: Run the skill /aios-init.)" "--aios: /aios-init"
   assert_contains "$OUT" "(sends: Run the skill /aios-integrity.)" "--aios: /aios-integrity"
   assert_contains "$OUT" "\`aios --gui --aios --html\`" "--aios: instruction for HTML"
   case "$(GUI "$SANDBOX" --aios --html)" in "<div class=\"aios-gui\">"*"<h2>AIbex AIOS</h2>"*) ok ;; *) fail "--aios --html outside a vault" ;; esac
   assert_contains "$(at "$G" "$SRC/bin/aios" --skill aios-gui)" "Führe \`aios --gui --aios\` über das Bash-Werkzeug aus." "skill aios-gui calls aios --gui --aios"

#===============================================================================
# checks of gui.yaml and of the assistant
#===============================================================================

   CHK() { PYTHONPATH="$SRC/lib" python3 -c "
import sys, yaml
from pathlib import Path
from aios import gui
print('|'.join(gui.check(yaml.safe_load(sys.argv[1]), Path('$GG'))))" "$1"; }
   assert_eq "$(CHK $'title: T\ntiles:\n  - title: A\n    prompt: p\n')" "" "valid description"
   assert_contains "$(CHK $'tiles:\n  - title: A\n    prompt: p\n')" "title is missing" "title required"
   assert_contains "$(CHK $'title: T\ntiles: []\n')" "tiles must be a list of 1 to 12 tiles" "at least one tile"
   assert_contains "$(CHK "$(printf 'title: T\ntiles:\n'; for i in $(seq 13); do printf '  - title: A%s\n    prompt: p\n' "$i"; done)")" "1 to 12" "at most 12 tiles"
   assert_contains "$(CHK $'title: T\ntiles:\n  - title: A\n    prompt: p\n    skill: s\n')" "tile 1: exactly one of prompt, skill, html" "exactly one action"
   assert_contains "$(CHK $'title: T\ntiles:\n  - title: A\n    html: fehlt.html\n')" "tile 1: HTML part fehlt.html not found" "HTML part must exist"
   assert_contains "$(CHK $'title: T\ncolor: red\ntiles:\n  - title: A\n    prompt: p\n')" "unknown key color" "unknown key"
   printf 'title: [kaputt\n' > "$GG/gui.yaml"
   assert_contains "$(GUI "$G")" "*** aios --gui: $GG/gui.yaml" "broken gui.yaml: error"
   assert_exit 1 bash -c "cd '$G' && '$SRC/bin/aios' --gui"
   cp "$SRC/tests/hub/aibex-aios/assistent-gaertner/0.2.0/assistants/gaertner/@!Skill/gaertner-gui/gui.yaml" "$GG/gui.yaml"
   sed -i.bak 's/^skills: .*/skills: [apfel-birnen-algebra]/' "$G/@/@!Assistant/gaertner/ASSISTANT.md"
   assert_contains "$(GUI "$G")" "gui gaertner-gui of the assistant gaertner is not in its skills" "gui must be in skills"
   assert_contains "$(at "$G" "$SRC/bin/aios-context" --assistant gaertner)" "gui gaertner-gui of the assistant gaertner is not in its skills" "aios-context --assistant reports it"
   mv "$G/@/@!Assistant/gaertner/ASSISTANT.md.bak" "$G/@/@!Assistant/gaertner/ASSISTANT.md"
   assert_contains "$(at "$G" "$SRC/bin/aios-context" --assistant gaertner)" "gui: gaertner-gui" "meta block names the gui"

#===============================================================================
# reserved name gui, alias /gui in --install and --uninstall
#===============================================================================

   mk "$D/@/@!Skill/gui/SKILL.md" $'---\nname: gui\nversion: 0.1.0\ndescription: d\n---\n'
   assert_contains "$(at "$G" "$SRC/bin/aios-context" --sync --plan)" "the name gui is reserved for the alias /gui, not registered" "blueprint gui: not registered"
   rm -rf "$D/@/@!Skill/gui"
   AL() { PYTHONPATH="$SRC/lib" python3 -c "
from aios import install, ui
plan = ui.Plan(); install.plan_alias(plan); plan.run(); print(len(plan.steps))" 2>&1; }
   AL >/dev/null
   A="$AIOS_CLAUDE_DIR/skills/gui/SKILL.md"
   assert_contains "$(cat "$A")" '!`aios --gui --session ${CLAUDE_SESSION_ID}`' "alias written"
   assert_contains "$(cat "$A")" "allowed-tools: Bash(aios --gui *), Bash(aios-context *)" "alias: allowed-tools"
   assert_eq "$(AL)" "0" "alias unchanged: nothing to do"
   printf -- '---\nname: gui\n---\neigener Skill\n' > "$A"
   assert_contains "$(AL)" "was not written by AIOS, left untouched" "foreign gui folder: warning"
   assert_eq "$(cat "$A")" $'---\nname: gui\n---\neigener Skill' "foreign gui folder: not overwritten"
   rm -rf "$AIOS_CLAUDE_DIR/skills/gui"; AL >/dev/null
   mkdir -p "$HOME/.aios/sessions"; touch "$HOME/.aios/sessions/x.yaml"
   PYTHONPATH="$SRC/lib" python3 -c "from aios import install, ui; ui.MODE = 'yes'; install.uninstall()" >/dev/null 2>&1
   [ ! -e "$AIOS_CLAUDE_DIR/skills/gui" ] && ok || fail "uninstall: alias removed"
   [ ! -e "$HOME/.aios/sessions" ] && ok || fail "uninstall: markers of the sessions removed"

#===============================================================================
# v0.4 step 1: A10 - hint under the HTML surface, menu as fallback
#===============================================================================

   OUT="$(GUI "$SANDBOX" --aios --html)"
   assert_contains "$OUT" "If a tile only fills the input field, press Enter." "html: hint under the tiles (A10)"
   OUT="$(GUI "$SANDBOX" --aios)"
   assert_contains "$OUT" "offer the same tiles as the menu below" "instruction: menu as fallback (A10)"

#===============================================================================
# v0.4 step 9: surface of an app, placeholders with the data of the app, --apps
#===============================================================================

   "$SRC/tests/hub/build" "$SANDBOX/hubs" >/dev/null
   export AIOS_HUBS="aibex-aios=file://$SANDBOX/hubs/aibex-aios"
   W="$SANDBOX/work/§Apps"; mkdir -p "$W/@" "$W/.aios"; printf 'aios: 0.4.0\n' > "$W/.aios/config.yaml"
   assert_contains "$(at "$W" "$SRC/bin/aios" --gui --apps)" "No apps in this project." "--apps: none yet"
   at "$W" "$SRC/bin/aios" --fetch app-taschenrechner --yes >/dev/null
   assert_contains "$(at "$W" "$SRC/bin/aios" --gui --apps)" "- /taschenrechner-gui — app-taschenrechner 0.3.1" "--apps: the app with its surface"
   assert_contains "$(at "$W" "$SRC/bin/aios" --gui --skill taschenrechner-gui)" "run \`aios --gui --skill taschenrechner-gui --html\`" "--skill: instruction"
   assert_contains "$(at "$W" "$SRC/bin/aios" --gui --skill taschenrechner-gui --html)" "var saved = null;" "placeholder without data: null"
   mkdir -p "$W/@Data/app-taschenrechner"; printf 'A:\n  title: Quadrat\n  keys: ["ENTER", "×"]\n' > "$W/@Data/app-taschenrechner/kacheln.yaml"
   assert_contains "$(at "$W" "$SRC/bin/aios" --gui --skill taschenrechner-gui --html)" 'var saved = {"A": {"title": "Quadrat", "keys": ["ENTER", "×"]}};' "placeholder: kacheln.yaml as JSON"
   assert_contains "$(at "$W" "$SRC/bin/aios" --gui --skill gibtsnicht)" "no deployed app with the surface gibtsnicht" "--skill: unknown surface"
   unset AIOS_HUBS
