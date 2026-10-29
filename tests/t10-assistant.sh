# t10-assistant.sh: step 10 of the plan (memo 18) - aios --context --assistant/--assistants, resolution of prompt and skills; v0.3 step 5: assignment, aios --assistant, marker

#===============================================================================
# setup: Obstgärtner and Astronom in AIOS layout (after PC-Custom-AI), shared and private skills
#===============================================================================

   export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
   D="$SANDBOX/work/§Demo"; G="$D/Garten"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   skill() { mk "$1/SKILL.md" "$(printf -- '---\nname: %s\ndescription: %s\n%s---\n\n# %s\n' "$2" "$3" "${4-version: 0.1.0
}" "$2")"; }
   mk "$D/.aios/config.yaml" $'aios: 0.6.0\n'
   mk "$D/@/@Rule/stil.md" $'# Stil\n'
   mk "$D/@/@!Prompt/obstgaertner.md" $'# Obstgärtner (Vault)\nvom Vault\n'
   skill "$D/@/@!Skill/memo" memo "Memo des Vaults"
   skill "$D/@/@!Skill/sonne-mond-zahlen" sonne-mond-zahlen "Zahlen des Vaults"
   O="$G/@/@!Assistant/obstgaertner"
   mk "$G/@/garten.md" $'# Garten\n'
   mk "$O/ASSISTANT.md" $'---\nname: obstgaertner\ntitle: Obstgärtner\nversion: 0.2.0\ndescription: >\n  Bodenständiger Obstgärtner,\n  rechnet mit Äpfeln und Birnen\nprompt: obstgaertner\nskills: [apfel-birnen-algebra, memo]\nmodel:\n  claude: sonnet\ntools: [read, search]\n---\n\n## Handwerk\nNur Äpfel und Birnen.\n'
   mk "$O/@!Prompt/obstgaertner.md" $'# Obstgärtner\nbodenständig\n'
   skill "$O/@!Skill/apfel-birnen-algebra" apfel-birnen-algebra "Boolesche Algebra mit Apfel und Birne"
   mk "$O/@Wissen/@Grundlagen/grundlagen.md" $'# Grundlagen\nÄpfel und Birnen sind Kernobst.\n'
   mk "$O/@Wissen/@Content/inhalt.md" $'# Inhalt\n| Datei | Lesen, wenn |\n'
   mk "$O/@Wissen/@@Sortenkunde/sortenkunde.md" $'# Sortenkunde\nGravensteiner reifen im August.\n'
   mk "$O/@Wissen/@!Entwurf/geheim.md" $'# Entwurf\n'
   mk "$O/notiz.txt" 'kein md'
   A="$D/@/@!Assistant/astronom"
   mk "$A/ASSISTANT.md" $'---\nname: astronom\ntitle: Astronom\nversion: 0.1.0\ndescription: Poetisch-präziser Astronom\nskills: [sonne-mond-zahlen]\nmodel: opus\n---\n\nSonne und Mond.\n'
   mk "$D/Wiese/@/wiese.md" $'# Wiese\n'
   AC() { (cd "$1" && shift && "$SRC/bin/aios" --context "$@" 2>&1); }

#===============================================================================
# --assistants and resolution of the name
#===============================================================================

   OUT="$(AC "$G" --assistants)"
   assert_contains "$OUT" "astronom             Astronom 0.1.0 — Poetisch-präziser Astronom  (§Demo)" "--assistants: assistant of the vault"
   assert_contains "$OUT" "obstgaertner         Obstgärtner 0.2.0 — Bodenständiger Obstgärtner, rechnet mit Äpfeln und Birnen  (Garten)" "--assistants: assistant of the project, block scalar"
   for Q in "Obstgärtner" "obstgaertner" "OBSTGÄRTNER" "Obstgartner"; do
      case "$Q" in
         Obstgartner) assert_contains "$(AC "$G" --assistant "$Q")" "no assistant named 'Obstgartner'" "unknown name: error with the list" ;;
         *) assert_contains "$(AC "$G" --assistant "$Q")" '<aios-assistant name="obstgaertner" title="Obstgärtner" version="0.2.0"' "name or title without case/umlauts: $Q" ;;
      esac
   done
   assert_contains "$(AC "$G" --assistant Obstgartner)" "astronom             Astronom 0.1.0" "unknown name: available assistants listed"
   assert_exit 1 "$SRC/bin/aios" --context --assistant nobody
   assert_contains "$(AC "$D/Wiese" --assistant obstgaertner)" "no assistant named" "assistant of a sibling project is not in the chain"
   assert_contains "$(AC "$D/Wiese" --assistant astronom)" '<aios-assistant name="astronom"' "vault assistant from a sibling project"

#===============================================================================
# --assistant: exact output (prompt, ASSISTANT.md body, knowledge, available, skills)
#===============================================================================

   OUT="$(AC "$G" --assistant Obstgärtner; echo x)"; OUT="${OUT%x}"
   assert_eq "$OUT" "<aios-assistant name=\"obstgaertner\" title=\"Obstgärtner\" version=\"0.2.0\" src=\"$O\">
<aios-assistant-meta>
description: Bodenständiger Obstgärtner, rechnet mit Äpfeln und Birnen
model: claude: sonnet
tools: read, search
skills: apfel-birnen-algebra, memo
gui: -
</aios-assistant-meta>
<aios-file class=\"prompt\" src=\"$O/@!Prompt/obstgaertner.md\">
# Obstgärtner
bodenständig
</aios-file>
<aios-file class=\"assistant\" src=\"$O/ASSISTANT.md\">
## Handwerk
Nur Äpfel und Birnen.
</aios-file>
<aios-file class=\"load\" src=\"$O/@Wissen/@Content/inhalt.md\">
# Inhalt
| Datei | Lesen, wenn |
</aios-file>
<aios-file class=\"load\" src=\"$O/@Wissen/@Grundlagen/grundlagen.md\">
# Grundlagen
Äpfel und Birnen sind Kernobst.
</aios-file>
<aios-available>
- $O/@Wissen/@@Sortenkunde/sortenkunde.md — Sortenkunde
</aios-available>
<aios-file class=\"skill\" src=\"$O/@!Skill/apfel-birnen-algebra/SKILL.md\">
---
name: apfel-birnen-algebra
description: Boolesche Algebra mit Apfel und Birne
version: 0.1.0
---

# apfel-birnen-algebra
</aios-file>
<aios-file class=\"skill\" src=\"$D/@/@!Skill/memo/SKILL.md\">
---
name: memo
description: Memo des Vaults
version: 0.1.0
---

# memo
</aios-file>
</aios-assistant name=\"obstgaertner\">
" "--assistant: exact output"
   case "$OUT" in *Entwurf*|*notiz.txt*|*Gravensteiner*) fail "hidden, non-md and available content must not appear" ;; *) ok ;; esac

#===============================================================================
# resolution of prompt and skills: assistant folder first, then the chain from the project up
#===============================================================================

   assert_contains "$(AC "$D" --assistant astronom)" "src=\"$D/@/@!Skill/sonne-mond-zahlen/SKILL.md\"" "skill from the chain"
   skill "$G/@/@!Skill/sonne-mond-zahlen" sonne-mond-zahlen "Zahlen des Gartens"
   assert_contains "$(AC "$G" --assistant astronom)" "src=\"$G/@/@!Skill/sonne-mond-zahlen/SKILL.md\"" "nearest masterspace wins"
   assert_contains "$(AC "$D" --assistant astronom)" "model: opus" "model as plain value"
   rm -rf "$O/@!Prompt"
   assert_contains "$(AC "$G" --assistant obstgaertner)" "src=\"$D/@/@!Prompt/obstgaertner.md\"" "prompt from the chain when the assistant has none"
   rm -rf "$O/@!Skill"
   assert_contains "$(AC "$G" --assistant obstgaertner)" "skill apfel-birnen-algebra of the assistant obstgaertner not found" "missing skill: error"

#===============================================================================
# errors and modes
#===============================================================================

   mk "$D/@/@!Assistant/falsch/ASSISTANT.md" $'---\nname: anders\nversion: 0.1.0\n---\n'
   OUT="$(AC "$D" --assistants)"
   assert_contains "$OUT" "skipped: $D/@/@!Assistant/falsch/ASSISTANT.md: name 'anders' differs from the folder 'falsch', not resolved" "name differs from the folder: skipped"
   assert_contains "$OUT" "astronom             Astronom 0.1.0" "name differs: the other assistants still listed"
   rm -rf "$D/@/@!Assistant/falsch"
   mk "$D/@/@!Assistant/ohne/ASSISTANT.md" $'---\nname: ohne\ntitle: Ohne\ndescription: d\n---\n'
   mk "$D/@/@!Assistant/kurz/ASSISTANT.md" $'---\nname: kurz\ntitle: Kurz\nversion: 1\ndescription: d\n---\n'
   OUT="$(AC "$D" --assistants)"
   assert_contains "$OUT" "skipped: assistant ohne has no version, not resolved ($D/@/@!Assistant/ohne)" "assistant without version: skipped and reported"
   assert_contains "$OUT" "skipped: assistant kurz has an invalid version '1' (MAJOR.MINOR.PATCH), not resolved" "assistant with invalid version: reported"
   assert_contains "$(AC "$D" --assistant Ohne)" "no assistant named 'Ohne'" "assistant without version: not resolved"
   assert_contains "$(AC "$D" --assistant Ohne)" "skipped: assistant ohne has no version" "assistant without version: reported with the list"
   rm -rf "$D/@/@!Assistant/ohne" "$D/@/@!Assistant/kurz"
   skill "$D/@/@!Skill/sonne-mond-zahlen" sonne-mond-zahlen "Zahlen ohne Version" ""
   rm -rf "$G/@/@!Skill/sonne-mond-zahlen"
   assert_contains "$(AC "$D" --assistant astronom)" "skill sonne-mond-zahlen has no version" "skill of an assistant without version: error"
   mk "$SANDBOX/work/§Alt/@/@!Assistant/x/ASSISTANT.md" $'---\nname: x\n---\n'
   assert_contains "$(AC "$SANDBOX/work/§Alt" --assistant x)" "need a vault activated with AIOS" "legacy: no assistants"
   [ ! -e "$G/.claude" ] && [ ! -e "$G/.aios" ] && ok || fail "stateless: nothing written"

#===============================================================================
# v0.2 knows no @!Agent/ (spec 01, Vorabversionen): an ordinary hidden folder
#===============================================================================

   mk "$D/@/@!Agent/alt/AGENT.md" $'---\nname: alt\ntitle: Alt\ndescription: alter Agent\n---\n'
   case "$(AC "$G" --assistants)" in *alt*) fail "@!Agent/ is not read" ;; *) ok ;; esac
   assert_contains "$(AC "$G" --assistant Alt)" "no assistant named 'Alt'" "@!Agent/: no assistant"
   case "$(AC "$G" --context)" in *AGENT.md*) fail "@!Agent/ stays hidden" ;; *) ok ;; esac

#===============================================================================
# step 5 (V0.3, memo 32): assignment assistant: in the chain, aios --context --assignment
#===============================================================================

   AS() { (cd "$1" && shift && "$SRC/bin/aios" --context --assignment "$@" 2>&1); }
   AI() { (cd "$1" && shift && "$SRC/bin/aios" --assistant "$@" 2>&1); }
   CFGF="$D/.aios/config.yaml"
   assert_eq "$(AS "$G")" "assistant=none from=-" "no entry up to the vault root: no assistant"
   printf '# Vault\naios: 0.6.0\nassistant: astronom\n' > "$CFGF"
   assert_eq "$(AS "$G")" "assistant=astronom from=$CFGF" "inherit without entry: vault assistant"
   mk "$G/.aios/config.yaml" $'assistant: inherit\n'
   assert_eq "$(AS "$G")" "assistant=astronom from=$CFGF" "inherit counts as no entry"
   assert_eq "$(AS "$D/Wiese")" "assistant=astronom from=$CFGF" "sibling inherits the vault"
   assert_eq "$(AS "$SANDBOX" "$G")" "assistant=astronom from=$CFGF" "--assignment <path>"
   mk "$G/.aios/config.yaml" $'assistant: none\n'
   assert_eq "$(AS "$G")" "assistant=none from=$G/.aios/config.yaml" "none stops the search"
   mk "$G/.aios/config.yaml" $'assistant: Bad_Name\n'
   assert_eq "$(AS "$G")" "assistant=astronom from=$CFGF" "invalid value ignored"
   assert_contains "$(cd "$G" && "$SRC/bin/aios" --config)" "assistant: Bad_Name is not an assistant name (or none, inherit), ignored" "invalid value: warning"
   mkdir -p "$HOME/.aios"; printf 'assistant: obstgaertner\n' > "$HOME/.aios/config.yaml"
   assert_contains "$(cd "$G" && "$SRC/bin/aios" --config)" "assistant is not allowed here, ignored" "assistant at home: ignored"
   assert_contains "$(cd "$G" && "$SRC/bin/aios" --config)" "assign    astronom ($CFGF)" "--config shows the assignment"
   rm -f "$HOME/.aios/config.yaml" "$G/.aios/config.yaml"
   assert_eq "$(AS "$SANDBOX/work/§Alt")" "assistant=none from=-" "legacy vault: none"
   assert_eq "$(AS "$SANDBOX")" "assistant=none from=-" "outside a vault: none"

#===============================================================================
# aios --assistant: plan, write only the line assistant:, name or title
#===============================================================================

   skill "$D/@/@!Skill/sonne-mond-zahlen" sonne-mond-zahlen "Zahlen des Vaults"
   OUT="$(AI "$G" obstgaertner --plan)"
   assert_contains "$OUT" "project Garten: Astronom → Obstgärtner" "plan: old and new assistant by title"
   assert_contains "$OUT" "applies to all new chats in Garten and in its subprojects with inherit" "plan: scope"
   assert_contains "$OUT" "(plan only, nothing written)" "--plan writes nothing"
   [ ! -e "$G/.aios/config.yaml" ] && ok || fail "--plan: no config.yaml"
   OUT="$(cd "$G" && echo n | "$SRC/bin/aios" --assistant obstgaertner 2>&1)"
   [ ! -e "$G/.aios/config.yaml" ] && ok || fail "no: nothing written"
   mk "$G/.aios/config.yaml" $'# Garten\nskills:\n  memo: 6.0.0\n'
   assert_eq "$(AI "$G" Obstgärtner --yes)" "=> Garten: assistant obstgaertner" "--yes by title: one result line"
   assert_eq "$(cat "$G/.aios/config.yaml")" $'# Garten\nskills:\n  memo: 6.0.0\nassistant: obstgaertner' "only the line assistant: added, other lines stay"
   assert_eq "$(AS "$G")" "assistant=obstgaertner from=$G/.aios/config.yaml" "assignment written"
   assert_contains "$(AI "$G" obstgaertner --yes)" "already, nothing to do" "same value: nothing to do"
   assert_contains "$(AI "$G" nobody --yes)" "no assistant named 'nobody'" "unknown name: error with the list"
   assert_exit 1 bash -c "cd '$G' && '$SRC/bin/aios' --assistant nobody --yes"
   assert_contains "$(AI "$D/Wiese" obstgaertner --plan)" "no assistant named 'obstgaertner'" "assistant must be in the chain of the project"
   assert_exit 1 bash -c "cd '$G' && '$SRC/bin/aios' --assistant"
   assert_contains "$(AI "$SANDBOX/work/§Alt" none --yes)" "need a vault activated with AIOS" "legacy vault: refused"

#===============================================================================
# inherit, none, --to, --session and the marker
#===============================================================================

   OUT="$(AI "$G" inherit --plan)"
   assert_contains "$OUT" "project Garten: Obstgärtner → Astronom" "inherit: plan shows the assistant of the parent"
   assert_eq "$(AI "$G" inherit --yes --session S-1)" $'=> Garten: assistant inherit, applies: Astronom\n   session S-1: astronom' "inherit with session"
   assert_contains "$(cat "$G/.aios/config.yaml")" "assistant: inherit" "inherit is written by aios --assistant"
   M="$HOME/.aios/sessions/S-1.yaml"
   assert_file "$M"
   assert_eq "$(sed -n 1,3p "$M")" "# written by AIOS (session), do not edit
cwd: \"$G\"
assistant: astronom" "marker: header, cwd, assistant"
   assert_contains "$(sed -n 4p "$M")" "used: $(date +%Y-%m-%d)T" "marker: used"
   assert_eq "$(AS "$G" --session S-1)" "assistant=astronom from=session" "--assignment --session: from the marker"
   assert_eq "$(AS "$G" --session S-none)" "assistant=astronom from=$CFGF" "no marker: assignment of the project"
   assert_contains "$(AI "$G" none --to "$D" --plan)" "project §Demo: Astronom → no assistant" "--to the vault root"
   assert_eq "$(AI "$G" none --to "$D" --yes --session S-1)" $'=> §Demo: assistant none\n   session S-1: none' "--to: the session follows when its assistant changes"
   assert_contains "$(cat "$CFGF")" $'aios: 0.6.0\nassistant: none' "vault: line replaced, aios kept"
   assert_eq "$(AI "$G" obstgaertner --yes --session S-1)" $'=> Garten: assistant obstgaertner\n   session S-1: obstgaertner' "switch with session"
   assert_eq "$(AI "$G" astronom --to "$D" --yes --session S-1)" "=> §Demo: assistant astronom" "--to: session unchanged when its assistant stays"
   assert_eq "$(AS "$G" --session S-1)" "assistant=obstgaertner from=session" "marker kept"
   assert_contains "$(AI "$G" none --to "$D/Wiese" --plan)" "is not a project of the chain" "--to outside the chain"
   assert_contains "$(AI "$G" none --yes --session ../x)" "is not a session id" "bad session id"
   assert_eq "$(AS "$G")" "assistant=obstgaertner from=$G/.aios/config.yaml" "bad session id: nothing written"
   mkdir -p "$D/Wiese/.aios"; printf 'assistant: none\n  bad indent\n' > "$D/Wiese/.aios/config.yaml"
   assert_contains "$(AI "$D/Wiese" astronom --yes)" "fix the file first, nothing changed" "file outside the subset: refused"
   assert_eq "$(cat "$D/Wiese/.aios/config.yaml")" $'assistant: none\n  bad indent' "file outside the subset: unchanged"
   rm -rf "$D/Wiese/.aios"

#===============================================================================
# reserved names, cleaning of old markers
#===============================================================================

   mk "$D/@/@!Assistant/none/ASSISTANT.md" $'---\nname: none\ntitle: Keiner\nversion: 0.1.0\ndescription: d\n---\n'
   assert_contains "$(AC "$D" --assistants)" "none is a reserved name (none, inherit), not resolved" "reserved name: skipped"
   rm -rf "$D/@/@!Assistant/none"
   printf '# written by AIOS (session), do not edit\ncwd: "/x"\nassistant: none\nused: 2020-01-01T00:00:00\n' > "$HOME/.aios/sessions/alt.yaml"
   PYTHONPATH="$SRC/lib" python3 -c "from aios import session; session.clean()"
   [ ! -e "$HOME/.aios/sessions/alt.yaml" ] && [ -e "$M" ] && ok || fail "clean: old marker removed, recent kept"

#===============================================================================
# step 6: aios --context --assistant <name> --load (part files like --load)
#===============================================================================

   OUT="$(AC "$G" --assistant Astronom --load)"
   assert_contains "$OUT" "AIOS-ASSISTANT-LOAD name=astronom version=0.1.0 parts=1" "--load: header with name and version"
   P1="$(printf '%s\n' "$OUT" | grep -o "$HOME/.aios/cache/a-astronom-[0-9a-f]*/part-1.md")"
   assert_file "$P1"
   assert_eq "$(cat "$P1")" "$(AC "$G" --assistant astronom)" "--load: part = --assistant output"
   assert_contains "$OUT" 'The assistant is loaded once </aios-assistant name="astronom"> (end of the last part) has been read.' "--load: end marker"
   assert_contains "$(AC "$G" --assistant nobody --load)" "no assistant named 'nobody'" "--load: unknown name"
   assert_exit 1 "$SRC/bin/aios" --context --assistant astronom --nope
