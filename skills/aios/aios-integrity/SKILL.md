---
name: aios-integrity
description: Prüft die Integrität eines AIbex-AIOS-Projekts und aller seiner Unterprojekte (Struktur S1–S4 und Commit-Stand, Hinweise zu Push-Stand und Namensregel) und bietet für fehlende Teile der Struktur aios --init an. Verwenden bei "/aios-integrity", "Integrität", "Integrität prüfen".
allowed-tools: Bash(aios --integrity *), Bash(aios --init *)
---

# Integrität prüfen

Ein AIOS-Skill von AIbex AIOS (Spec 05, *Integrität*). Die Prüfung schreibt nichts.

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt das Projekt der Session aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben.

## Ablauf

1. **Prüfen:** Führe `aios --integrity "<pfad>"` über das Bash-Werkzeug aus, mit dem absoluten Pfad (Standard: das Arbeitsverzeichnis der Session). Zeige den Bericht unverändert im Chat. Exit 1 heißt nur, dass nicht alle Projekte integer sind; endet der Befehl mit einer Fehlermeldung (`*** aios --integrity: …`), nenne sie und beende.
2. **Init ergänzen:** Gibt es Projekte mit `missing: …` in der Spalte *Init*, führe für jedes davon `aios --init "<projekt>" --plan` aus und zeige die Pläne zusammen. Frag einmal, ob du die fehlenden Teile ergänzen sollst. Nach Ja je Projekt `aios --init "<projekt>" --yes`; meldet ein Plan einen Verstoß gegen die Namensregel, gilt der Namensdialog von `/aios-init` (Vorschlag, eigener Name mit `--accept-name`, abbrechen). Danach `aios --integrity "<pfad>"` wiederholen und das Ergebnis zeigen.
3. **Commit-Stand:** Nicht committete Änderungen (`<n> changed, <m> new`) nur nennen und nichts anbieten: Die Commit-Nachricht gehört dem User. Hinweise (Abschnitt `Notes`: Push-Stand, Namensregel) ebenfalls nur nennen. Der Bericht ist englisch; fasse ihn bei Bedarf in der Sprache des Users zusammen.

Registrierte Skills, Manifest und Blueprints gehören nicht zur Integrität; den Abgleich macht `/aios-deploy`.
