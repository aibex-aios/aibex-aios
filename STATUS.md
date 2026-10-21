# Stand der Umsetzung AIOS v0.4

Umsetzungsschritte nach dem Implementierungsplan v0.4 (Memo 18 in `AA-AIbex-AIOS/@Memo/V0.4/` mit den Änderungen aus Memo 19, freigegeben in Memo 20, ergänzt durch spätere Memos, besonders 21–29). Jeder Schritt wird im selben Commit `Schritt N: …` abgehakt, der ihn abschließt. Vor jedem Schritt kommt ein Fragepaket nach der Regel *Weiter*.

v0.3.1 ist abgeschlossen (Tag `v0.3.1`, Abnahme in den Memos 56–62 von `AA-AIbex-AIOS/@Memo/V0.3/`); sein Stand steht in `STATUS.md` dieses Tags. Die Befunde A4, A5, A10, A11, A13–A16 der Abnahme gehen in v0.4 (V0.4, Memo 05), eine Version v0.3.2 gibt es nicht.

| # | Schritt | Ergebnis | Spec | Stand |
|---|---|---|---|---|
| 0 | **Repo auf v0.4 umstellen:** `spec-v0.4` nach `main`, Spec-Korrekturen aus den Memos 18–29, `CLAUDE.md`, `STATUS.md`, `VERSION` `0.4.0-dev`, `manifest.yaml` des Kernels | `main` per fast-forward auf den Entwurf, Zweig `spec-v0.4` gelöscht; Specs 01–06: L1–L6, Q1–Q5, Hubs und Hub-Liste (`hubs:`, `AIOS_HUBS`, `aios --hubs`), holen (`aios --fetch`) und ausrollen (`aios --deploy --only`), Skills `/aios-package`, `/aios-fetch`, `/aios-deploy`, Kachel *Apps*, Wissenspakete, Astronom 0.2.0, Abnahmetest (Spec 01); `manifest.yaml` (`name: aios`, `type: kernel`); 768 Prüfungen grün | 01–06 | ☑ abgeschlossen |
| 1 | **Befunde aus v0.3.1:** A11 (L6), A13, A14, A15, A16; A4 und A10 als Hinweise in den Skills | | 03, 05 | ☐ |
| 2 | **Kern der Pakete:** SemVer und Bereiche, `manifest.yaml`, Resolver | | 06 | ☐ |
| 3 | **Test-Hubs und Hubs:** `tests/hub/` mit zwei Hubs, `tests/hub/build`, `lib/aios/hub.py`, `aios --library`, `aios --hubs` | | 04, 06 | ☐ |
| 4 | **Holen:** `aios --fetch` (holen, abgleichen, `--upgrade`, `--remove`, `--from`, `--hub`), Skills `aios-package` und `aios-fetch`; A5 | | 03, 06 | ☐ |
| 5 | **Ausrollen und Wirkung:** `aios --deploy --only/--all`, `.aios/registry`, Elemente aus `@!Package/` in der Kette, K6, Vorrang, Skill `aios-deploy` | | 02, 03, 04, 06 | ☐ |
| 6 | **Arbeitspferde, Befehle, Hooks:** `workers:`, `aios --worker`, `aios --run`, Meldung von Hooks | | 06 | ☐ |
| 7 | **Paket-Repos herauslösen:** `memo`, `gaertner`, `astronom` 0.2.0, `knowledge-orion`, `knowledge-scorpio` lokal, Bibliothek aus dem Kernel entfernt | | 03, 04, 06 | ☐ |
| 8 | **Umstellung von v0.3:** `aios --activate v0.4.<n>` | | 04, 06 | ☐ |
| 9 | **Taschenrechner:** Paket-Repo, Oberfläche, Kacheln, `knowledge/@!Kacheln/`, Kachel *Apps* in `/aios-gui` | | 03, 06 | ☐ |
| 10 | **Rückfluss:** `aios --contribute` mit Attrappe für `gh` | | 06 | ☐ |
| 11 | **Workspaces:** `aios --workspace`, Fremd-Repos, `aios --integrity` mit `workspace.yaml` | | 05, 06 | ☐ |
| 12 | **Doku:** README, Tutorials | | 01, 04 | ☐ |
| 13 | **Version 0.4.0 und Hubs:** Live-Tests, Paket-Repos in `aibex-aios` und `aibex-hub` | | 01, 04 | ☐ |
| 14 | **Abnahme** v0.4.0 | | 01 | ☐ |
