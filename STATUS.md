# Stand der Umsetzung AIOS v0.2.0

Umsetzungsschritte nach dem Implementierungsplan v0.2 (Memo 20 im Konzeptprojekt `PAA-AIbex-AIOS-V0.2`, ergänzt durch spätere Memos). Jeder Schritt wird im selben Commit `Schritt N: …` abgehakt, der ihn abschließt.

v0.1.0 ist abgeschlossen (Tag `v0.1.0`, Abnahme in Memo 32 von `PAA-AIbex-AIOS-V0.1`); sein Stand steht in `STATUS.md` dieses Tags.

| # | Schritt | Ergebnis | Spec | Stand |
|---|---|---|---|---|
| 0 | **Repo auf v0.2 umstellen:** `CLAUDE.md`, `STATUS.md`, `VERSION` `0.2.0-dev` | Regeln zeigen auf V0.2 und Memo 20, Stand v0.2, 423 Prüfungen grün | — | ☑ abgeschlossen |
| 1 | **Umbenennung:** Agent → Assistent (`@!Assistant`, `ASSISTANT.md`, `--assistant(s)`, `<aios-assistant …>`, `/aios-assistant`, `deploy --assistant`) | | 01–04 | ☐ offen |
| 2 | **Versionen Pflicht:** Skills und Assistenten ohne gültige `version` werden nicht registriert bzw. aufgelöst und gemeldet; Manifest immer mit Version | | 03, 04 | ☐ offen |
| 3 | **Demo-Assistenten in der Bibliothek:** `assistants/demo/gaertner`, `astronom` 0.1.0, Abbildung in der Installation, `aios --library` | | 03, 04 | ☐ offen |
| 4 | **Ausrollen von Assistenten:** `aios --deploy gaertner==0.1.0`, Marke, `assistants:`, Abgleich | | 03, 04 | ☐ offen |
| 5 | **Doku:** `--list` mit Assistenten, README, Tutorial | | 02 | ☐ offen |
| 6 | **Abnahme:** v0.1.0 entfernen, v0.2.0 installieren, `§Demo` neu, Abnahmetest (Spec 01) | Tags **`v0.2.0`**, `gaertner-v0.1.0`, `astronom-v0.1.0` | 01 *Abnahmetest* | ☐ offen |
