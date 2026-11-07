---
name: aios-restore
description: Holt in einem AIbex-AIOS-Workspace frühere Fassungen zurück - gelöschte Dateien, ältere Fassungen einer Datei, ein Projekt auf den Stand eines Tages - aus der gesicherten Geschichte, ohne Git-Wissen. Verwenden bei "/aios-restore", "hol die gelöschte Datei zurück", "zeig frühere Fassungen von", "setz das Projekt auf den Stand von gestern zurück", "wiederherstellen", "restore".
allowed-tools: Bash(aios --workspace *)
---

# Frühere Fassungen zurückholen

Ein AIOS-Skill von AIbex AIOS (Spec 06, *Zurückholen*; Spec 03, *Workspaces*; V0.6, Memo 204: F229).

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; Pfade gibst du absolut oder relativ zum Arbeitsverzeichnis an. Rufe `aios …` immer als einzelnen Befehl auf, ohne `;`, `&&`, `|`, Umleitung oder vorangestelltes `cd`; nur so gibt AIBOS den Aufruf ohne Rückfrage frei.

## Ablauf

1. **Was ist gemeint?**
   - **Gelöschte Datei** („hol die gelöschte Notiz … zurück"): `aios --workspace history "<projekt>" --deleted` zeigt die gelöschten Dateien mit Datum. Findest du den Namen nicht eindeutig, nenne die Kandidaten und frag.
   - **Frühere Fassung einer Datei** („zeig frühere Fassungen von …"): `aios --workspace history "<datei>"`; nenne die Fassungen mit Datum und Rechner in Alltagssprache.
   - **Projekt auf einen Stand** („setz das Projekt auf gestern zurück"): Zeitpunkt klären (Datum, Uhrzeit); `aios --workspace history "<projekt>"` zur Orientierung.
2. **Plan:** `aios --workspace restore "<pfad>" [--at <zeit>] --plan`; `<zeit>` ist ein Datum (`2026-11-06`), Datum mit Uhrzeit oder ein Kurz-SHA aus `history`. Ein Ordner geht nur mit `--at`.
3. **Zeigen und fragen:** Nenne, welche Fassung zurückkommt, und ob nicht gesicherte Dateien vorher in den Papierkorb kommen. Einmal fragen; ohne Ja nichts ausführen.
4. **Ausführen:** dasselbe mit `--yes`. Melde das Ergebnis und biete `/aios-sync` an, damit die zurückgeholte Fassung gesichert wird.

## Grenzen

- `restore` ändert nie die Geschichte; jede Fassung bleibt erhalten, auch die, die du ersetzt.
- Leere den Papierkorb nie; das bleibt beim User.
