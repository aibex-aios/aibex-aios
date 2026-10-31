---
name: aios-register
description: Registriert die Projekt-Skills (Blueprints @!Skill der Masterspace-Kette) von AIbex AIOS für Claude Code, mit Vorschau. Verwenden bei "/aios-register", "Skills registrieren", nach /aios-deploy oder wenn /aios-context auf /aios-register hinweist.
allowed-tools: Bash(aios --register *)
---

# Skills registrieren

Ein AIOS-Skill von AIbex AIOS (Spec 03, *Registrieren*).

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt das Projekt der Session aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben. Rufe `aios …` immer als einzelnen Befehl auf, ohne `;`, `&&`, `|`, Umleitung oder vorangestelltes `cd`; nur so gibt AIBOS den Aufruf ohne Rückfrage frei.

## Ablauf

1. **Vorschau:** Führe `aios --register --plan` über das Bash-Werkzeug aus.
   - `are up to date`: Antworte „Die Projekt-Skills sind aktuell." und beende.
   - `nothing registered: …`: Nenne den Grund (kein Vault, Legacy-Modus oder kein Projekt) und beende.
2. **Rückfrage:** Zeige die Vorschau (`new`, `changed`, `remove`) und gemeldete Warnungen (übersprungene Blueprints) und frage, ob registriert werden soll. Hat der User das schon ausdrücklich verlangt, ist keine weitere Rückfrage nötig.
3. **Registrieren:** Nach Ja `aios --register --yes` ausführen.
4. **Abschluss:** „Der Skill ist ab dem nächsten Chat verfügbar (oder nach `/reload-skills`)."
