---
name: aios-status
description: Rekonstruiert den Projektstatus eines AIbex-AIOS-Projekts aus den Memos und dem Git-Log, was erledigt ist und was offen ist. Der Status wird nicht gespeichert. Verwenden bei "/aios-status", "Projektstatus", "Wo stehen wir?".
allowed-tools: Read, Glob, Bash(git log *), Bash(aios --context --id *)
---

# Projektstatus

Ein AIOS-Skill von AIbex AIOS (Spec 03, *Projektstatus*). Er läuft nur auf Anforderung und schreibt nichts.

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt das Projekt der Session aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben. Rufe `aios …` immer als einzelnen Befehl auf, ohne `;`, `&&`, `|`, Umleitung oder vorangestelltes `cd`; nur so gibt AIBOS den Aufruf ohne Rückfrage frei.

## Ablauf

1. **Projekt bestimmen:** Führe `aios --context --id` aus; das Projekt ist das `cwd` daraus. Hat es kein `@Memo/`, stütze dich nur auf das Git-Log und sag das.
2. **Memos lesen:** alle Dateien in `<Projekt>/@Memo/` in Nummernfolge. Header (`Datum`, `Status`, `Ersetzt`) und die Abschnitte *Offen* und *Caveats* genau lesen, den Rest überfliegen.
3. **Abgleichen:** Was ein späteres Memo entscheidet oder mit `Ersetzt` ablöst, gilt nicht mehr als offen. Bei Widerspruch gilt das spätere Memo.
4. **Git-Log:** `git log --oneline -n 30` im Projekt ergänzt Schritte, die in keinem Memo stehen, und liefert den jüngsten Commit (`git log -1 --format='%h %s (%as)'`).
5. **Ausgabe im Chat**, kurz:

```
Projektstatus <Projekt> — Stand <Datum>

Erledigt
- …
Offen
- …
Zuletzt: <hash> <Commit-Nachricht> (<Datum>)
```

Gespeichert wird der Status nur auf ausdrücklichen Wunsch des Users, dann als gewöhnliches Memo nach dem Skill `memo`.
