---
name: aios-fetch
description: Holt ein Paket von AIbex AIOS aus einem Hub ins Projekt (nach @!Package/, packages: und lock.yaml), gleicht das Projekt mit lock.yaml ab, aktualisiert oder entfernt Pakete. Hilfs-Skill von /aios-package. Verwenden bei "/aios-fetch", "Paket holen", "Pakete abgleichen".
allowed-tools: Bash(aios --fetch *), Bash(aios --library *), Bash(aios --worker *)
---

# Paket holen

Ein AIOS-Skill von AIbex AIOS (Spec 06, *Holen*). Aufruf: `/aios-fetch [<hub>/]<paket>[<bereich>] [--hub <hub>] [--from <repo>] [--to <projekt>]`, `/aios-fetch` ohne Paket zum Abgleich, `/aios-fetch --upgrade [<paket>]`, `/aios-fetch --remove <paket>`. Für Anwender in Umgangssprache gibt es `/aios-package`.

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt das Projekt der Session aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben. Rufe `aios …` immer als einzelnen Befehl auf, ohne `;`, `&&`, `|`, Umleitung oder vorangestelltes `cd`; nur so gibt AIBOS den Aufruf ohne Rückfrage frei.

## Ablauf

1. **Ziel klären:** Beim Holen eines Pakets ohne `--to` frage, wohin es soll, und schlage das **Root-Projekt** (die Vault-Root) vor; das Projekt der Session ist die zweite Möglichkeit. Beim Abgleich, `--upgrade` und `--remove` gilt ohne `--to` das Projekt der Session.
2. **Plan:** den Befehl mit `--plan` ausführen, z. B. `aios --fetch app-taschenrechner --to "<ziel>" --plan`.
3. **Fehler:** Endet der Befehl mit Exit 3 (`is in several hubs: …`), frage mit dem Auswahlwerkzeug (`AskUserQuestion`), aus welchem Hub das Paket kommen soll, und beginne mit `<hub>/<paket>` bei Schritt 2. Andere Meldungen (`*** aios --fetch: …`, z. B. ein Konflikt der Versionen) dem User nennen und beenden.
4. **Rückfrage:** Zeige den Plan: je Paket `new`, `upgrade X -> Y`, `missing`, `changed directly, restored`, `remove`, dazu die Änderungen an `packages:` und `lock.yaml`. Weise ausdrücklich darauf hin, wenn eine direkt geänderte Kopie ersetzt wird, und nenne Abhängigkeiten, die mitkommen. Frage dann **immer**, ob geholt werden soll. Der Wunsch selbst („installiere …", „hole …") ist keine Bestätigung des Plans; ohne Rückfrage nur, wenn der User den gezeigten Plan bestätigt oder ausdrücklich „ohne Rückfrage" gesagt hat (V0.4, Memo 67, B2).
5. **Ausführen:** Nach Ja denselben Befehl mit `--yes` statt `--plan`.
6. **Arbeitspferde:** Arbeitspferde (Pakete `worker-<name>`, auch als Abhängigkeit) richtet derselbe Plan ein: Zeile `setup      <paket> <version> -> <ort>` mit den Paketen `paket==version` (bzw. dem vollständigen Inhalt des Skripts bei `kind: script`). Zeige diese Zeilen in der Rückfrage ausdrücklich; Versionen, die kein Projekt mehr nutzt, entfernt der Plan (`remove … (no project uses it)`). Meldet der Plan einen Konflikt (`both bring the program`), nenne ihn und beende. Eine beschädigte Installation repariert `aios --worker <paket> setup` (Plan, Rückfrage, `--yes`); `aios --worker` zeigt den Stand.
7. **Abschluss:** die Hinweise der Ausgabe weitergeben: neue Skills gelten ab dem nächsten Chat; ein Assistent wird mit `/aios-assistant <Titel>` zugeordnet; eine App öffnet ihr Oberflächen-Skill (z. B. `/taschenrechner-gui`) oder die Kachel *Apps* von `/aios-gui`.

Pakete holt nur der User; schlage das Holen nicht von dir aus vor. AIOS committet nichts davon; `@!Package/`, `config.yaml` und `lock.yaml` committet der User.
