---
name: aios-detach
description: Lagert einen Teilbaum eines AIbex-AIOS-Workspace auf diesem Rechner aus (Papierkorb, Platzhalter mit DETACHED.md und DETACHED.command) oder löst den ganzen Workspace vom Rechner - erst nach der Prüfung, dass nichts verloren geht. Verwenden bei "/aios-detach", "auslagern", "Teilbaum auslagern", "Platz sparen", "Workspace lösen", "detach".
allowed-tools: Bash(aios --workspace *)
---

# Teilbaum auslagern, Workspace lösen

Ein AIOS-Skill von AIbex AIOS (Spec 06, *detach*; Spec 03, *Workspaces*).

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt den Workspace aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben. Rufe `aios …` immer als einzelnen Befehl auf, ohne `;`, `&&`, `|`, Umleitung oder vorangestelltes `cd`; nur so gibt AIBOS den Aufruf ohne Rückfrage frei.

## Ablauf

1. **Argument:** ein Pfad (ein Projekt aus `workspace.yaml`) oder keiner. **Ohne Pfad wird der ganze Workspace gelöst**: Sag das ausdrücklich, bevor du weitermachst.
2. **Plan:** `aios --workspace detach "<pfad>" --plan` (ohne Pfad: `aios --workspace detach --plan`). Meldet der Befehl `nothing detached, something would be lost`, zeige jedes Hindernis (offene Dateien, ungepushte Commits, Repos ohne Remote, ignorierte Dateien wie unter `@Secret/`) und beende; lösen kann der User die Hindernisse selbst oder mit `/aios-sync`.
3. **Zeigen und fragen:** Plan zeigen (Ziel im Papierkorb, Platzhalter), einmal fragen. Ohne Ja nichts ausführen.
4. **Ausführen:** dasselbe mit `--yes`, Ergebnis kurz melden, mit dem Weg zurück: `/aios-attach <pfad>` im Chat, `DETACHED.command` im Finder.

## Grenzen

- Die Auslagerung gilt nur für diesen Rechner; andere Rechner merken nichts.
- Leere den Papierkorb nie; das bleibt beim User.
