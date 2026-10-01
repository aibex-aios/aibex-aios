# Stand der Umsetzung AIOS v0.2.0

Umsetzungsschritte nach dem Implementierungsplan v0.2 (Memo 20 im Konzeptprojekt `PAA-AIbex-AIOS-V0.2`, ergänzt durch spätere Memos). Jeder Schritt wird im selben Commit `Schritt N: …` abgehakt, der ihn abschließt.

v0.1.0 ist abgeschlossen (Tag `v0.1.0`, Abnahme in Memo 32 von `PAA-AIbex-AIOS-V0.1`); sein Stand steht in `STATUS.md` dieses Tags.

| # | Schritt | Ergebnis | Spec | Stand |
|---|---|---|---|---|
| 0 | **Repo auf v0.2 umstellen:** `CLAUDE.md`, `STATUS.md`, `VERSION` `0.2.0-dev` | Regeln zeigen auf V0.2 und Memo 20, Stand v0.2, 423 Prüfungen grün | — | ☑ abgeschlossen |
| 1 | **Umbenennung:** Agent → Assistent (`@!Assistant`, `ASSISTANT.md`, `--assistant(s)`, `<aios-assistant …>`, `/aios-assistant`, `deploy --assistant`) | `lib/aios/assistant.py`, Skill `aios-assistant`, t10 → `t10-assistant.sh` (`@!Agent/` wird ignoriert), t08 prüft die AIOS-Skills von v0.2; 430 Prüfungen grün, Live-Test `tests/live/assistants.sh` 7/7 | 01–04 | ☑ abgeschlossen |
| 2 | **Versionen Pflicht:** Skills und Assistenten ohne gültige `version` werden nicht registriert bzw. aufgelöst und gemeldet; Manifest immer mit Version | `registry.version_problem` (Semver `MAJOR.MINOR.PATCH`); Assistenten mit falschem Namen oder ohne Version werden übersprungen statt abzubrechen; `--assistants` und `<aios-assistant …>` mit Version (t07, t08, t10); 444 Prüfungen grün, Live-Test 7/7 | 03, 04 | ☑ abgeschlossen |
| 3 | **Demo-Assistenten in der Bibliothek:** `assistants/demo/gaertner`, `astronom` 0.1.0, Abbildung in der Installation, `aios --library` | aus `PC-Custom-AI` kopiert und neutral gemacht (Satz „Demo-Assistent“, private Skills 0.1.0); `install.assistants_of` mit eindeutigen Namen und Version, Abbildung `assistants/<gruppe>/<name>/<version>/`; `aios --library` mit Spalte Art (t01, t03, t09); 453 Prüfungen grün; Live-Test nutzt jetzt die Bibliothek, 7/7 | 03, 04 | ☑ abgeschlossen |
| 4 | **Ausrollen von Assistenten:** `aios --deploy gaertner==0.1.0`, Marke, `assistants:`, Abgleich | Art aus der Bibliothek, `--assistant`/`--from` nur für Skills; Unterordner mit eigener Marke zählen nicht zur Prüfsumme und bleiben beim Spiegeln erhalten (F3); `config` mit Abschnitt `assistants:`; Abgleich zuerst Assistenten, dann Skills; Skill `aios-deploy` (t03, t09); 490 Prüfungen grün | 03, 04 | ☑ abgeschlossen |
| 5 | **Doku:** `--list` mit Assistenten, README, Tutorial | | 02 | ☐ offen |
| 6 | **Abnahme:** v0.1.0 entfernen, v0.2.0 installieren, `§Demo` neu, Abnahmetest (Spec 01) | Tags **`v0.2.0`**, `gaertner-v0.1.0`, `astronom-v0.1.0` | 01 *Abnahmetest* | ☐ offen |
