---
name: taschenrechner-gui
version: 0.3.1
description: >
  Oberfläche des programmierbaren RPN-Taschenrechners von AIbex AIOS (nach dem Vorbild
  des HP-15C): Ziffern, Grundrechenarten, CHS, ENTER, vier belegbare Kacheln A bis D und LEARN. Verwenden bei
  "/taschenrechner-gui", "Taschenrechner öffnen", "zeig den Rechner".
allowed-tools: Bash(aios --gui *)
---

# Oberfläche des Taschenrechners

Ein Skill der Demo-App `app-taschenrechner` von AIbex AIOS.

**Arbeitsverzeichnis:** Führe alle Befehle im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`.

1. Führe `aios --gui --skill taschenrechner-gui` über das Bash-Werkzeug aus.
2. Folge der Anweisung *Show the surface* in der Ausgabe: in der Desktop-App mit HTML-Oberflächen das Fragment von `aios --gui --skill taschenrechner-gui --html` unverändert zeigen, sonst das Menü mit dem Auswahlwerkzeug. Der Rechner selbst läuft nur in der HTML-Oberfläche.
3. Kommt aus dem Rechner eine Nachricht zum Speichern einer Kachel, folge dem Skill `/taschenrechner`.
