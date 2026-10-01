# t10-agent.sh: step 10 of the plan (memo 18) - aios-context --agent/--agents, resolution of prompt and skills

#===============================================================================
# setup: Obstgärtner and Astronom in AIOS layout (after PC-Custom-AI), shared and private skills
#===============================================================================

   export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
   D="$SANDBOX/work/§Demo"; G="$D/Garten"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
   skill() { mk "$1/SKILL.md" "$(printf -- '---\nname: %s\ndescription: %s\n---\n\n# %s\n' "$2" "$3" "$2")"; }
   mk "$D/.aios/config.yaml" $'aios: 0.1.0\n'
   mk "$D/@/@Rule/stil.md" $'# Stil\n'
   mk "$D/@/@!Prompt/obstgaertner.md" $'# Obstgärtner (Vault)\nvom Vault\n'
   skill "$D/@/@!Skill/memo" memo "Memo des Vaults"
   skill "$D/@/@!Skill/sonne-mond-zahlen" sonne-mond-zahlen "Zahlen des Vaults"
   O="$G/@/@!Agent/obstgaertner"
   mk "$G/@/garten.md" $'# Garten\n'
   mk "$O/AGENT.md" $'---\nname: obstgaertner\ntitle: Obstgärtner\ndescription: >\n  Bodenständiger Obstgärtner,\n  rechnet mit Äpfeln und Birnen\nprompt: obstgaertner\nskills: [apfel-birnen-algebra, memo]\nmodel:\n  claude: sonnet\ntools: [read, search]\n---\n\n## Handwerk\nNur Äpfel und Birnen.\n'
   mk "$O/@!Prompt/obstgaertner.md" $'# Obstgärtner\nbodenständig\n'
   skill "$O/@!Skill/apfel-birnen-algebra" apfel-birnen-algebra "Boolesche Algebra mit Apfel und Birne"
   mk "$O/@Wissen/@Grundlagen/grundlagen.md" $'# Grundlagen\nÄpfel und Birnen sind Kernobst.\n'
   mk "$O/@Wissen/@Content/inhalt.md" $'# Inhalt\n| Datei | Lesen, wenn |\n'
   mk "$O/@Wissen/@@Sortenkunde/sortenkunde.md" $'# Sortenkunde\nGravensteiner reifen im August.\n'
   mk "$O/@Wissen/@!Entwurf/geheim.md" $'# Entwurf\n'
   mk "$O/notiz.txt" 'kein md'
   A="$D/@/@!Agent/astronom"
   mk "$A/AGENT.md" $'---\nname: astronom\ntitle: Astronom\ndescription: Poetisch-präziser Astronom\nskills: [sonne-mond-zahlen]\nmodel: opus\n---\n\nSonne und Mond.\n'
   mk "$D/Wiese/@/wiese.md" $'# Wiese\n'
   AC() { (cd "$1" && shift && "$SRC/bin/aios-context" "$@" 2>&1); }

#===============================================================================
# --agents and resolution of the name
#===============================================================================

   OUT="$(AC "$G" --agents)"
   assert_contains "$OUT" "astronom             Astronom — Poetisch-präziser Astronom  (§Demo)" "--agents: agent of the vault"
   assert_contains "$OUT" "obstgaertner         Obstgärtner — Bodenständiger Obstgärtner, rechnet mit Äpfeln und Birnen  (Garten)" "--agents: agent of the project, block scalar"
   for Q in "Obstgärtner" "obstgaertner" "OBSTGÄRTNER" "Obstgartner"; do
      case "$Q" in
         Obstgartner) assert_contains "$(AC "$G" --agent "$Q")" "no agent named 'Obstgartner'" "unknown name: error with the list" ;;
         *) assert_contains "$(AC "$G" --agent "$Q")" '<aios-agent name="obstgaertner" title="Obstgärtner"' "name or title without case/umlauts: $Q" ;;
      esac
   done
   assert_contains "$(AC "$G" --agent Obstgartner)" "astronom             Astronom" "unknown name: available agents listed"
   assert_exit 1 "$SRC/bin/aios-context" --agent nobody
   assert_contains "$(AC "$D/Wiese" --agent obstgaertner)" "no agent named" "agent of a sibling project is not in the chain"
   assert_contains "$(AC "$D/Wiese" --agent astronom)" '<aios-agent name="astronom"' "vault agent from a sibling project"

#===============================================================================
# --agent: exact output (prompt, AGENT.md body, knowledge, available, skills)
#===============================================================================

   OUT="$(AC "$G" --agent Obstgärtner; echo x)"; OUT="${OUT%x}"
   assert_eq "$OUT" "<aios-agent name=\"obstgaertner\" title=\"Obstgärtner\" src=\"$O\">
<aios-agent-meta>
description: Bodenständiger Obstgärtner, rechnet mit Äpfeln und Birnen
model: claude: sonnet
tools: read, search
skills: apfel-birnen-algebra, memo
</aios-agent-meta>
<aios-file class=\"prompt\" src=\"$O/@!Prompt/obstgaertner.md\">
# Obstgärtner
bodenständig
</aios-file>
<aios-file class=\"agent\" src=\"$O/AGENT.md\">
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
---

# apfel-birnen-algebra
</aios-file>
<aios-file class=\"skill\" src=\"$D/@/@!Skill/memo/SKILL.md\">
---
name: memo
description: Memo des Vaults
---

# memo
</aios-file>
</aios-agent name=\"obstgaertner\">
" "--agent: exact output"
   case "$OUT" in *Entwurf*|*notiz.txt*|*Gravensteiner*) fail "hidden, non-md and available content must not appear" ;; *) ok ;; esac

#===============================================================================
# resolution of prompt and skills: agent folder first, then the chain from the project up
#===============================================================================

   assert_contains "$(AC "$D" --agent astronom)" "src=\"$D/@/@!Skill/sonne-mond-zahlen/SKILL.md\"" "skill from the chain"
   skill "$G/@/@!Skill/sonne-mond-zahlen" sonne-mond-zahlen "Zahlen des Gartens"
   assert_contains "$(AC "$G" --agent astronom)" "src=\"$G/@/@!Skill/sonne-mond-zahlen/SKILL.md\"" "nearest masterspace wins"
   assert_contains "$(AC "$D" --agent astronom)" "model: opus" "model as plain value"
   rm -rf "$O/@!Prompt"
   assert_contains "$(AC "$G" --agent obstgaertner)" "src=\"$D/@/@!Prompt/obstgaertner.md\"" "prompt from the chain when the agent has none"
   rm -rf "$O/@!Skill"
   assert_contains "$(AC "$G" --agent obstgaertner)" "skill apfel-birnen-algebra of the agent obstgaertner not found" "missing skill: error"

#===============================================================================
# errors and modes
#===============================================================================

   mk "$D/@/@!Agent/falsch/AGENT.md" $'---\nname: anders\n---\n'
   assert_contains "$(AC "$D" --agents)" "name 'anders' differs from the folder 'falsch'" "name differs from the folder"
   rm -rf "$D/@/@!Agent/falsch"
   mk "$SANDBOX/work/§Alt/@/@!Agent/x/AGENT.md" $'---\nname: x\n---\n'
   assert_contains "$(AC "$SANDBOX/work/§Alt" --agent x)" "need a vault activated with AIOS" "legacy: no agents"
   [ ! -e "$G/.claude" ] && [ ! -e "$G/.aios" ] && ok || fail "stateless: nothing written"
