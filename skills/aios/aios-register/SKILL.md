---
name: aios-register
description: Registriert die Projekt-Skills (Blueprints @!Skill der Masterspace-Kette) von AIbex AIOS für Claude Code, mit Vorschau. Verwenden bei "/aios-register", "Skills registrieren", nach /aios-deploy oder wenn /aios-context auf /aios-register hinweist.
allowed-tools: Bash(aios --register *)
---

# Skills registrieren

Ein AIOS-Skill von AIbex AIOS (Spec 03, *Registrieren*).

## Ablauf

1. **Vorschau:** Führe `aios --register --plan` über das Bash-Werkzeug aus.
   - `are up to date`: Antworte „Die Projekt-Skills sind aktuell." und beende.
   - `nothing registered: …`: Nenne den Grund (kein Vault, Legacy-Modus oder kein Projekt) und beende.
2. **Rückfrage:** Zeige die Vorschau (`new`, `changed`, `remove`) und gemeldete Warnungen (übersprungene Blueprints) und frage, ob registriert werden soll. Hat der User das schon ausdrücklich verlangt, ist keine weitere Rückfrage nötig.
3. **Registrieren:** Nach Ja `aios --register --yes` ausführen.
4. **Abschluss:** „Der Skill ist ab dem nächsten Chat verfügbar (oder nach `/reload-skills`)."
