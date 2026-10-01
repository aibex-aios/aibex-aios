---
name: aios-deploy
description: Rollt eine Version eines Skills oder Assistenten von AIbex AIOS in ein Projekt aus (Blueprint in @!Skill bzw. @!Assistant, Manifest skills: bzw. assistants:), aus der Bibliothek oder (Skills) einem Pflegeprojekt, oder gleicht die Blueprints mit dem Manifest ab. Verwenden bei "/aios-deploy", "Skill ausrollen", "Assistent ausrollen", "memo==6.0.0 ausrollen", "gaertner==0.1.0 ausrollen", "Skills abgleichen".
allowed-tools: Bash(aios --deploy *), Bash(aios --library *)
---

# Skill oder Assistent ausrollen

Ein AIOS-Skill von AIbex AIOS (Spec 03, *Ausrollen*). Aufruf: `/aios-deploy <name>==<version> [--to <projekt>] [--assistant <name>] [--from <pflegeprojekt>]` oder `/aios-deploy` ohne Namen zum Abgleich. `<name>` ist ein Skill oder ein Assistent der Bibliothek (`aios --library`, Spalte Art); `--assistant` und `--from` gelten nur für Skills.

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt das Projekt der Session aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben.

## Ablauf mit Name und Version

1. **Ohne Version:** Nennt der User nur einen Namen oder fragt, was es gibt, führe `aios --library` aus, zeige Skills und Assistenten der Bibliothek mit ihren Versionen und frage nach der Version.
2. **Ziel klären:** Hat der User kein Ziel (`--to`) genannt, frage, wohin der Skill oder Assistent soll, und schlage das **Root-Projekt** (die Vault-Root) vor; das Projekt der Session ist die zweite Möglichkeit. Ein Assistent als Ziel eines Skills wird mit `--assistant <name>` angegeben.
3. **Vorschau:** `aios --deploy <name>==<version> --to "<ziel>" [--assistant …] [--from …] --plan` ausführen. Fehlermeldungen (`*** aios --deploy: …`) dem User nennen und beenden.
4. **Rückfrage:** Zeige die Vorschau (Dateien `new`, `changed`, `remove` und die Änderung am Manifest, z. B. `skills: memo: (new) -> 6.0.0` oder `assistants: gaertner: (new) -> 0.1.0`). Steht darin `changed directly` oder `local skill` bzw. `local assistant`, weise ausdrücklich darauf hin, dass direkte Änderungen ersetzt werden. Hat der User das Ausrollen schon ausdrücklich bestätigt, ist keine weitere Rückfrage nötig.
5. **Ausrollen:** Nach Ja denselben Befehl mit `--yes` statt `--plan` ausführen.
6. **Abschluss:**
   - Skill: „Der Skill ist ab dem nächsten Chat verfügbar (oder nach `/reload-skills`)."
   - Assistent: „Der Assistent ist sofort verfügbar: `/aios-assistant <Titel>`" mit dem Titel aus der Ausgabe (`activate it … with /aios-assistant …`). Assistenten werden nicht registriert.

## Ablauf ohne Namen (Abgleich)

1. `aios --deploy --to "<ziel>" --plan` (ohne `--to`: das Projekt der Session).
2. `match the manifest`: „Die Blueprints entsprechen dem Manifest." und beenden.
3. Sonst die Vorschau zeigen; Zeilen `remove …` entfernen Blueprints, die nicht mehr in `skills:` oder `assistants:` stehen. Nach Ja mit `--yes` ausführen und wie oben abschließen.

Skills und Assistenten der Bibliothek rollt nur der User aus; schlage das Ausrollen nicht von dir aus vor.
