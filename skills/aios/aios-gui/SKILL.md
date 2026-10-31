---
name: aios-gui
description: Zeigt die Oberfläche von AIbex AIOS mit den Aufgaben von AIOS (Projekt initialisieren, Kontext und Konfiguration, Assistent zuordnen, Pakete, Apps, Pakete abgleichen und Skills registrieren, Integrität, Projektstatus, Memo). Verwenden bei "/aios-gui", "AIOS-Oberfläche", "AIOS-Menü".
allowed-tools: Bash(aios --gui *)
---

# AIOS-Oberfläche

Ein AIOS-Skill von AIbex AIOS (Spec 03, *Oberflächen*). Die Oberfläche ist eine Abkürzung zu den AIOS-Skills; alles läuft weiter über deren Regeln, z. B. die Rückfrage vor dem Schreiben.

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt das Projekt der Session aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben. Rufe `aios …` immer als einzelnen Befehl auf, ohne `;`, `&&`, `|`, Umleitung oder vorangestelltes `cd`; nur so gibt AIBOS den Aufruf ohne Rückfrage frei.

## Ablauf

1. Führe `aios --gui --aios` über das Bash-Werkzeug aus.
2. Folge der Anweisung *Show the surface* in der Ausgabe: in der Desktop-App mit HTML-Oberflächen das Fragment von `aios --gui --aios --html` zeigen, sonst das Menü mit dem Auswahlwerkzeug.
3. Nach der Wahl einer Kachel: Ihr Text gilt, als hätte der User ihn getippt; `/<skill>` ist ein Aufruf dieses Skills.
