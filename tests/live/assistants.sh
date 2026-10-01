#!/bin/bash
# assistants.sh: live test of /aios-assistant with Obstgärtner and Astronom (step 10, costs tokens)

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: tests/live/assistants.sh [<model>]   # headless sessions A1-A4, default model haiku'
      echo '          tests/live/assistants.sh --version   # print version'
      echo '   not part of tests/run: needs a logged-in claude CLI, uses tokens and reads the'
      echo '   example assistants of PC-Custom-AI (AIOS_ASSISTANT_SAMPLES, read only)'
      echo '   see also: tests/live/skills.sh, aios-context --assistant'
      exit 1
   fi

#===============================================================================
# print version: tests/live/assistants.sh --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "0.1.0"; exit 0
   fi

#===============================================================================
# run the live test: tests/live/assistants.sh [<model>]
#===============================================================================

   if [ "$2" == "" ]; then
      MODEL="${1:-haiku}"
      REPO="$(cd "$(dirname "$0")/../.." && pwd)"
      SRC="${AIOS_ASSISTANT_SAMPLES:-$HOME/Library/CloudStorage/GoogleDrive-hugo.pristauz@aibex.at/Geteilte Ablagen/§AIbex/P-Projekte/AI/PC-Custom-AI/@Agent}"
      [ -d "$SRC/Obstgarten" ] || { echo "*** example assistants not found: $SRC (set AIOS_ASSISTANT_SAMPLES)"; exit 1; }
      T="${TMPDIR:-/tmp}"; SB="$(cd "$(mktemp -d "${T%/}/aios-live.XXXXXX")" && pwd -P)" || exit 1
      V="$SB/§Live"; G="$V/Obstgarten"; O="$G/@/@!Assistant/obstgaertner"; A="$V/@/@!Assistant/astronom"
      mkdir -p "$SB/bin" "$SB/home" "$V/.aios" "$V/@/@Rule" "$O/@!Skill" "$O/@Wissen/@Grundlagen" \
               "$O/@Wissen/@@Sortenkunde" "$O/@Wissen/@@Veredelung" "$A" "$V/@/@!Skill"
      printf 'aios: 0.1.0\n' > "$V/.aios/config.yaml"
      printf '# Stil\nAntworte auf Deutsch.\n' > "$V/@/@Rule/stil.md"
      body() { awk 'BEGIN{n=0} /^---$/{n++; next} n>=2' "$1"; }    # text after the frontmatter
      { printf -- '---\nname: obstgaertner\ntitle: Obstgärtner\nversion: 0.1.0\ndescription: Bodenständiger Obstgärtner, rechnet ausschließlich mit Äpfeln und Birnen\nskills: [apfel-birnen-algebra]\nmodel:\n  claude: sonnet\ntools: [read, search]\n---\n'
        body "$SRC/Obstgarten/.claude/agents/obstgaertner.md" | sed 's/Dein Wissen dazu ist in `CLAUDE.md` beschrieben./Dein Wissen dazu steht im Wissen dieses Assistenten (geladen oder verfügbar)./'
      } > "$O/ASSISTANT.md"
      addver() { awk 'NR==2{print; print "version: 0.1.0"; next} 1' "$1/SKILL.md" > "$1/SKILL.md.tmp" && mv "$1/SKILL.md.tmp" "$1/SKILL.md"; }   # skills need a version (spec 03)
      cp -R "$SRC/Obstgarten/.claude/skills/apfel-birnen-algebra" "$O/@!Skill/"; addver "$O/@!Skill/apfel-birnen-algebra"
      cp "$SRC/Obstgarten/Wissen/grundlagen.md" "$O/@Wissen/@Grundlagen/"
      cp "$SRC/Obstgarten/Wissen/sortenkunde.md" "$O/@Wissen/@@Sortenkunde/"
      cp "$SRC/Obstgarten/Wissen/veredelung.md" "$O/@Wissen/@@Veredelung/"
      SORTE="Sternreinette $RANDOM"
      printf '\n## Sandkasten\n\n| Sorte | Genussreife |\n|---|---|\n| %s | nur am 29. Februar eines Schaltjahres |\n' "$SORTE" >> "$O/@Wissen/@@Sortenkunde/sortenkunde.md"
      { printf -- '---\nname: astronom\ntitle: Astronom\nversion: 0.1.0\ndescription: Poetisch-präziser Astronom, rechnet ausschließlich mit Sonne und Mond\nskills: [sonne-mond-zahlen]\nmodel:\n  claude: opus\n---\n'
        body "$SRC/Sternwarte/.claude/agents/astronom.md"
      } > "$A/ASSISTANT.md"
      cp -R "$SRC/Sternwarte/.claude/skills/sonne-mond-zahlen" "$V/@/@!Skill/"; addver "$V/@/@!Skill/sonne-mond-zahlen"
      mkdir -p "$G/@"; printf '# Obstgarten\n' > "$G/@/obstgarten.md"
      for TOOL in aios aios-context; do
         printf '#!/bin/bash\nHOME="%s/home" exec "%s/bin/%s" "$@"\n' "$SB" "$REPO" "$TOOL" > "$SB/bin/$TOOL"; chmod +x "$SB/bin/$TOOL"
      done
      PYTHONPATH="$REPO/lib" python3 -c '
import sys
from pathlib import Path
from aios import install
f = Path(sys.argv[1]) / "skills/aios/aios-assistant/SKILL.md"
m = install.frontmatter(f)
d = Path(sys.argv[2]) / ".claude/skills/aios-assistant"; d.mkdir(parents=True)
(d / "SKILL.md").write_text(install.wrapper("aios-assistant", m["description"], m.get("allowed-tools", "")))' "$REPO" "$G"
      ask() {                                       # ask <prompt>
         (cd "$G" && PATH="$SB/bin:$PATH" claude -p "$1" --model "$MODEL" --settings '{"hooks":{}}' \
            --setting-sources project --add-dir "$SB" \
            --allowedTools "Skill" "Read" "Bash(aios --skill *)" "Bash(aios-context --assistant *)" "Bash(aios-context --assistants *)" 2>&1)
      }
      PASS=0; FAIL=0
      check() {                                     # check <name> <answer> <expected> [<expected> …]
         local N="$1" ANS="$2" E; shift 2
         for E in "$@"; do
            case "$ANS" in *"$E"*) ;; *) FAIL=$((FAIL+1)); printf '\033[31mFAIL\033[0m %s: [%s] missing\n%s\n' "$N" "$E" "$ANS"; return;; esac
         done
         PASS=$((PASS+1)); printf '\033[32mok\033[0m   %s\n' "$N"
      }
      refuse() {                                    # refuse <name> <answer> <forbidden>
         case "$2" in *"$3"*) FAIL=$((FAIL+1)); printf '\033[31mFAIL\033[0m %s: [%s] must not appear\n%s\n' "$1" "$3" "$2";;
                      *) PASS=$((PASS+1)); printf '\033[32mok\033[0m   %s\n' "$1";; esac
      }
      echo "=> live assistant test with model $MODEL in $SB"

      ANS="$(ask "/aios-assistant Obstgärtner: Rechentest — und dann in der Rolle: Was ist ¬Apfel * Birne? Nenne nur das Ergebnis.")"
      check "A1 Obstgärtner: private skill apfel-birnen-algebra" "$ANS" "Birne"
      refuse "A1 Obstgärtner: no 0/1 result" "$ANS" "= 1"

      ANS="$(ask "/aios-assistant Obstgärtner — und dann in der Rolle: Was ist Mond * Mond?")"
      refuse "A2 Obstgärtner: boundary, no result −Sonne" "$ANS" "−Sonne"
      refuse "A2 Obstgärtner: boundary, no result -Sonne" "$ANS" "-Sonne"
      check "A2 Obstgärtner: boundary, refuses kindly" "$ANS" "nicht"

      ANS="$(ask "/aios-assistant Astronom — und dann in der Rolle: Was ist Mond · Mond? Nur das Ergebnis.")"
      case "$ANS" in *"−Sonne"*|*"-Sonne"*|*"− Sonne"*) R3="−Sonne";; *) R3="$ANS";; esac
      check "A3 Astronom (vault assistant from the project): shared skill sonne-mond-zahlen" "$R3" "−Sonne"

      ANS="$(ask "/aios-assistant Obstgärtner — und dann in der Rolle: Wann ist die Sorte $SORTE genussreif?")"
      check "A4 Obstgärtner: available knowledge read on demand" "$ANS" "29. Februar"

      echo "=> $PASS passed, $FAIL failed"
      rm -rf "$SB"
      [ "$FAIL" == "0" ] || exit 1
      exit 0
   fi

#===============================================================================
# cannot deal with anything else ...
#===============================================================================

   "$0" -?
   exit 1
