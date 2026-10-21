---
name: taschenrechner-gui
version: 0.1.0
description: >
  Oberfläche des programmierbaren Taschenrechners von AIbex AIOS: Rechner mit Ziffern,
  Grundrechenarten, vier belegbaren Kacheln und der Taste Lernen. Verwenden bei
  "/taschenrechner-gui", "Taschenrechner öffnen", "zeig den Rechner".
allowed-tools: Bash(aios --gui *)
---

# Oberfläche des Taschenrechners

Ein Skill der Demo-App `app-taschenrechner` von AIbex AIOS.

**Arbeitsverzeichnis:** Führe alle Befehle im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`.

1. Führe `aios --gui --skill taschenrechner-gui` über das Bash-Werkzeug aus.
2. Folge der Anweisung *Show the surface* in der Ausgabe: in der Desktop-App mit HTML-Oberflächen das Fragment von `aios --gui --skill taschenrechner-gui --html` unverändert zeigen, sonst das Menü mit dem Auswahlwerkzeug. Der Rechner selbst läuft nur in der HTML-Oberfläche.
3. Kommt aus dem Rechner eine Nachricht zum Speichern einer Kachel, folge dem Skill `/taschenrechner`.
