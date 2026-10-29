# t05-context.sh: step 5 of the plan (memo 18) - aios --context/--load/--id, classes K1-K5 (spec 02)

#===============================================================================
# setup: activated vault with every class rule, a sibling, a container, fake ai-brain
#===============================================================================

   mkdir -p "$SANDBOX/fake" "$SANDBOX/outside"
   export PATH="$SANDBOX/fake:/usr/bin:/bin:/usr/sbin:/sbin"
   VER="$(cat "$SRC/VERSION")"
   D="$SANDBOX/work/§Demo"; M="$D/@"
   mk() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }

   mk "$D/.aios/config.yaml"                   $'aios: 0.6.0\n'
   mk "$M/README.md"                           $'# Root\nroot text\n'                  # K3
   mk "$M/@Rule/stil.md"                       $'# Stil\nschreib klar\n'
   mk "$M/@Rule/sub/tief.md"                   'no newline at the end'                  # K1, no trailing newline
   mk "$M/@Rule/bild.png"                      'PNG'                                    # K4
   mk "$M/@Rule/notiz.txt"                     'text'                                   # K4
   mk "$M/Notizen/n.md"                        $'# Notiz\n'                             # K1 in @/
   mk "$M/@Wissen/@Content/inhalt.md"          $'# Inhalt\n| Datei | Lesen, wenn |\n'
   mk "$M/@Wissen/@@Kapitel1/kapitel.md"       $'---\ntitle: x\n---\n\n# Kapitel 1: Grundlagen\nlang\n'
   mk "$M/@Wissen/@@Kapitel1/@Teil/teil.md"    $'Kein Titel\n'                          # K2: @ in @@ stays available
   mk "$M/@!Skill/memo/SKILL.md"               $'# Memo\n'                              # hidden
   mk "$M/@!Skill/memo/@Rule/r.md"             $'# r\n'                                 # K2: @ in @! stays hidden
   mk "$M/@@Buch/@!Geheim/g.md"                $'# Geheim\n'                            # K2: @! in @@ is hidden
   mk "$M/.obsidian/x.md"                      $'# dot\n'                               # dot entries skipped
   mk "$D/Garten/@/garten.md"                  $'# Garten\nApfel\n'
   mk "$D/Wiese/@/wiese.md"                    $'# Wiese\n'                             # sibling, not in the chain
   mkdir -p "$D/Garten/Beet"                                                            # not initialized

   at() { (cd "$1" && shift && "$@" 2>&1); }
   CTX() { at "$1" "$SRC/bin/aios" --context "${@:2}"; }
   IDOF() { CTX "$1" --id | sed 's/^id=\([^ ]*\).*/\1/'; }

#===============================================================================
# --context: exact output from the project Garten
#===============================================================================

   OUT="$(CTX "$D/Garten" --context; echo x)"; OUT="${OUT%x}"
   ID="$(IDOF "$D/Garten")"
   EXP="<aios-context id=\"$ID\" files=\"6\" cwd=\"$D/Garten\" version=\"$VER\">
<aios-file class=\"load\" src=\"$M/@Rule/stil.md\">
# Stil
schreib klar
</aios-file>
<aios-file class=\"load\" src=\"$M/@Rule/sub/tief.md\">
no newline at the end
</aios-file>
<aios-file class=\"load\" src=\"$M/@Wissen/@Content/inhalt.md\">
# Inhalt
| Datei | Lesen, wenn |
</aios-file>
<aios-file class=\"load\" src=\"$M/Notizen/n.md\">
# Notiz
</aios-file>
<aios-file class=\"load\" src=\"$M/README.md\">
# Root
root text
</aios-file>
<aios-file class=\"load\" src=\"$D/Garten/@/garten.md\">
# Garten
Apfel
</aios-file>
<aios-available>
- $M/@Wissen/@@Kapitel1/@Teil/teil.md — teil
- $M/@Wissen/@@Kapitel1/kapitel.md — Kapitel 1: Grundlagen
</aios-available>
</aios-context id=\"$ID\">
"
   assert_eq "$OUT" "$EXP" "--context: exact output"
   [[ "$ID" =~ ^[0-9a-f]{8}$ ]] && ok || fail "id: 8 hex characters ($ID)"
   assert_eq "$(CTX "$D/Garten" --id)" "id=$ID files=6 cwd=$D/Garten mode=aios-$VER" "--id"

   for X in "@!Skill" "@@Buch" ".obsidian" "bild.png" "notiz.txt" "wiese.md" "Geheim"; do
      case "$OUT" in *"$X"*) fail "must not appear in the master context: $X" ;; *) ok ;; esac
   done

#===============================================================================
# chain: root project, not initialized project, outside a vault
#===============================================================================

   assert_contains "$(CTX "$D" --id)" "files=5 cwd=$D " "root project: only the root masterspace"
   B="$(CTX "$D/Garten/Beet" --context)"
   assert_contains "$B" "src=\"$D/Garten/@/garten.md\"" "not initialized: chain up to the project above"
   [ "$(IDOF "$D/Garten/Beet")" != "$ID" ] && ok || fail "id depends on cwd"
   assert_eq "$(CTX "$SANDBOX/outside" --id)" "id=- files=0 cwd=$SANDBOX/outside mode=none" "outside a vault: mode=none"
   assert_eq "$(cd "$SANDBOX/outside" && "$SRC/bin/aios" --context 2>/dev/null)" "" "outside a vault: no master context on stdout"

#===============================================================================
# id (K5): what changes it and what does not
#===============================================================================

   I0="$(IDOF "$D/Garten")"
   assert_eq "$(IDOF "$D/Garten")" "$I0" "id is stable"
   printf 'lang und neu\n' >> "$M/@Wissen/@@Kapitel1/kapitel.md"
   assert_eq "$(IDOF "$D/Garten")" "$I0" "content of available knowledge: id unchanged"
   printf 'x\n' >> "$M/@!Skill/memo/SKILL.md"
   assert_eq "$(IDOF "$D/Garten")" "$I0" "hidden file changed: id unchanged"
   printf 'x\n' > "$M/@Rule/bild2.png"
   assert_eq "$(IDOF "$D/Garten")" "$I0" "non-md file added: id unchanged"
   mk "$M/@Wissen/@@Kapitel2/k2.md" $'# K2\n'
   I1="$(IDOF "$D/Garten")"
   [ "$I1" != "$I0" ] && ok || fail "available file added: id changes"
   printf 'Birne\n' >> "$D/Garten/@/garten.md"
   I2="$(IDOF "$D/Garten")"
   [ "$I2" != "$I1" ] && ok || fail "loaded content changed: id changes"
   mv "$M/@Rule/stil.md" "$M/@Rule/stil2.md"
   [ "$(IDOF "$D/Garten")" != "$I2" ] && ok || fail "loaded file renamed: id changes"

#===============================================================================
# --load: part files of at most 40000 characters, cache per id
#===============================================================================

   python3 -c "import sys; sys.stdout.write(''.join(f'Zeile {i:05d} ' + 'x'*80 + '\n' for i in range(1200)))" > "$D/Garten/@/gross.md"
   OUT="$(CTX "$D/Garten" --load)"
   ID="$(IDOF "$D/Garten")"
   CD="$HOME/.aios/cache/$ID"
   assert_contains "$OUT" "AIOS-CONTEXT-LOAD id=$ID files=7 parts=" "--load: header"
   assert_contains "$OUT" "</aios-context id=\"$ID\">" "--load: names the end marker"
   NP="$(ls "$CD"/part-*.md | wc -l | tr -d ' ')"
   [ "$NP" -ge 3 ] && ok || fail "--load: at least 3 parts ($NP)"
   MAXC="$(python3 -c "import glob; print(max(len(open(f,encoding='utf-8').read()) for f in glob.glob('$CD/part-*.md')))")"
   [ "$MAXC" -le 40000 ] && ok || fail "--load: parts <= 40000 characters ($MAXC)"
   ALL="$(for i in $(seq 1 "$NP"); do cat "$CD/part-$i.md"; done; echo x)"
   FULL="$(CTX "$D/Garten" --context; echo x)"
   assert_eq "$ALL" "$FULL" "--load: parts joined = --context"
   assert_eq "$(printf '%s\n' "$OUT" | grep -c '^   /')" "$NP" "--load: every part listed"

   mkdir -p "$HOME/.aios/cache/alt0000"; touch -t 202001010000 "$HOME/.aios/cache/alt0000"
   touch -t 202001010000 "$CD"
   CTX "$D/Garten" --load >/dev/null
   [ ! -e "$HOME/.aios/cache/alt0000" ] && ok || fail "--load: cache older than 7 days removed"
   assert_dir "$CD"

#===============================================================================
# legacy mode (legacy: ai-brain at the vault root): aios --context behaves like ai-brain
#===============================================================================

   L="$SANDBOX/work/§Alt"; mk "$L/@/a.md" $'# A\n'; mk "$L/.aios/config.yaml" $'legacy: ai-brain\n'
   assert_eq "$(CTX "$L" --id)" "id=- files=0 cwd=$L mode=legacy" "legacy --id without ai-brain"
   assert_eq "$(CTX "$L" --context)" "" "legacy --context without ai-brain: nothing"
   printf '#!/bin/bash\n[ "$*" == "--id" ] && echo "id=feed0001 files=1 cwd=$PWD" || echo "ai-brain $*"\n' > "$SANDBOX/fake/ai-brain"
   chmod +x "$SANDBOX/fake/ai-brain"
   assert_eq "$(CTX "$L" --id)" "id=feed0001 files=1 cwd=$L mode=legacy" "legacy --id: ai-brain plus mode=legacy"
   assert_eq "$(CTX "$L" --load)" "ai-brain --load" "legacy --load: ai-brain"

#===============================================================================
# kinds of vaults (spec 02, Arten von Vaults; V0.6, memos 14, 17, 42)
#===============================================================================

   N="$SANDBOX/work/§Leer"; mk "$N/@/a.md" $'# A\n'
   assert_eq "$(CTX "$N" --id)" "id=- files=0 cwd=$N mode=none" "vault without binding: mode=none"
   assert_contains "$(CTX "$N" --context)" "not in an AIBOS workspace, no master context" "vault without binding: no master context"
   O="$SANDBOX/work/§Old"; mk "$O/@/a.md" $'# A\n'; mk "$O/.aios/config.yaml" $'aios: 0.5.1\n'
   assert_eq "$(CTX "$O" --id)" "id=- files=0 cwd=$O mode=alt-0.5.1" "binding below 0.6: mode=alt"
   assert_contains "$(CTX "$O" --context)" "not in an AIBOS workspace, no master context" "binding below 0.6: no master context"
   V="$SANDBOX/work/§Dev"; mk "$V/@/a.md" $'# A\n'; mk "$V/.aios/config.yaml" $'aios: 0.6.0-dev\n'
   assert_contains "$(CTX "$V" --id)" "mode=aios-" "0.6.0-dev counts as AIBOS (MAJOR.MINOR)"
   mk "$N/.aios/config.yaml" $'legacy: something\n'
   assert_eq "$(CTX "$N" --id)" "id=- files=0 cwd=$N mode=none" "legacy: other value ignored"
   assert_contains "$(PYTHONPATH="$SRC/lib" python3 -c "from aios import config; print(config.load('$N').warnings)")" "legacy: something is not ai-brain, ignored" "legacy: warning for another value"
   mk "$O/.aios/config.yaml" $'aios: 0.6.0\nlegacy: ai-brain\n'
   assert_contains "$(CTX "$O" --id)" "mode=aios-" "aios: and legacy: together: aios: applies"
   assert_contains "$(PYTHONPATH="$SRC/lib" python3 -c "from aios import config; print(config.load('$O').warnings)")" "aios: and legacy: together, aios: applies" "aios: and legacy: together: warning"
   mk "$O/P/@/a.md" $'# A\n'; mk "$O/P/.aios/config.yaml" $'aios: 0.5.1\nlegacy: ai-brain\n'
   assert_contains "$(CTX "$O/P" --id)" "mode=aios-" "project: aios: and legacy: do not count"
   assert_exit 1 "$SRC/bin/aios" --context --assistant obstgaertner

#===============================================================================
# physical paths: a symlink without § reaches the same vault and the same id
#===============================================================================

   ln -s "$D" "$SANDBOX/Vault"
   assert_eq "$(CTX "$SANDBOX/Vault/Garten" --id)" "$(CTX "$D/Garten" --id)" "symlink: same id, same cwd"
   assert_contains "$("$SRC/bin/aios" --context --id "$SANDBOX/Vault/Garten")" "mode=aios-" "symlink: vault recognized"
   mkdir -p "$HOME/bin"; cp "$SRC/templates/forwarder" "$HOME/bin/aios"; chmod +x "$HOME/bin/aios"
   mkdir -p "$AIOS_PREFIX/v0.6.0/bin"; printf '#!/bin/bash\necho "fwd $*"\n' > "$AIOS_PREFIX/v0.6.0/bin/aios"
   chmod +x "$AIOS_PREFIX/v0.6.0/bin/aios"; echo "v0.6.0: $AIOS_PREFIX/v0.6.0" > "$AIOS_PREFIX/installations.yaml"
   assert_eq "$(at "$SANDBOX/Vault/Garten" "$HOME/bin/aios" --context --id)" "fwd --context --id" "forwarder: vault recognized through the symlink"
