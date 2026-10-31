---
name: aios-deploy
description: Rollt Elemente geholter Pakete von AIbex AIOS in einem Projekt aus oder zeigt sie - nur bestimmte Skills, Assistenten oder Wissen eines Pakets freischalten (--only) oder wieder alle (--all). Hilfs-Skill von /aios-package. Verwenden bei "/aios-deploy", "ausrollen", "freischalten", "nur den Skill … nutzen", "welche Elemente sind ausgerollt?".
allowed-tools: Bash(aios --deploy *)
---

# Elemente ausrollen

Ein AIOS-Skill von AIbex AIOS (Spec 06, *Ausrollen*). Aufruf: `/aios-deploy` (zeigen), `/aios-deploy <paket> --only <element>…`, `/aios-deploy <paket> --all`, jeweils optional `--to <projekt>`. Ein Paket holt `/aios-fetch` bzw. `/aios-package`; nach dem Holen sind alle Elemente ausgerollt.

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt das Projekt der Session aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben. Rufe `aios …` immer als einzelnen Befehl auf, ohne `;`, `&&`, `|`, Umleitung oder vorangestelltes `cd`; nur so gibt AIBOS den Aufruf ohne Rückfrage frei.

## Ablauf

1. **Zeigen:** `aios --deploy [--to "<projekt>"]` ausführen und die Pakete mit ihren Elementen zeigen (`deployed`, `not deployed`). Fragt der User nur, was ausgerollt ist, hier beenden.
2. **Auswahl klären:** Will der User nur einen Teil eines Pakets nutzen, nenne die Elemente aus Schritt 1 und frage mit dem Auswahlwerkzeug (`AskUserQuestion`, Mehrfachauswahl), welche wirken sollen. Elemente heißen wie ihr Skill, Assistent oder Befehl; das Wissen heißt `knowledge`.
3. **Plan:** `aios --deploy <paket> --only <element>… --plan` bzw. `aios --deploy <paket> --all --plan`.
4. **Rückfrage und Ausführen:** Plan zeigen (Änderung an `packages:`, Registrierung); nach Ja denselben Befehl mit `--yes`.
5. **Abschluss:** „Die Auswahl gilt; Skills ab dem nächsten Chat (oder nach `/reload-skills`)." Nicht ausgerollte Elemente wirken nicht: Sie werden nicht registriert, nicht als Assistent aufgelöst und ihr Wissen kommt nicht in den Master-Kontext.

Abhängigkeiten werden immer ganz ausgerollt; `--only` gilt nur für Pakete, die in `packages:` des Projekts stehen. Meldet `aios --deploy` „to fetch … use: aios --fetch …", wollte der User ein Paket holen: weiter mit `/aios-fetch`.
