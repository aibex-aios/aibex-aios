# Stand der Umsetzung AIOS v0.6.3

v0.6.3 ist ein Patch auf v0.6.2 in verkürzter Form, ohne eigenen Implementierungsplan: die Schritte stehen in Memo 156 in `AA-AIbex-AIOS/@Memo/V0.6/` (Vorschau in Memo 153; Spec freigegeben in Memo 156). Jeder Schritt wird im selben Commit `v0.6.3 Schritt N: …` abgehakt, der ihn abschließt. Diese Datei enthält alle Schritte von Anfang an (F102).

v0.6.2 ist abgeschlossen (Tag `v0.6.2`, Abnahme in Memo 145 von `AA-AIbex-AIOS/@Memo/V0.6/`); sein Stand steht in `STATUS.md` des Tags `v0.6.2`, frühere in den Tags `v0.6.1` und `v0.6.0`.

v0.6.3 betrifft nur den Kernel; `distribution-capricorn` bleibt 0.4.1 (F149).

| # | Schritt | Ergebnis | Spec | Stand |
|---|---|---|---|---|
| 0 | **Repo auf 0.6.3:** `VERSION`, `manifest.yaml`, `STATUS.md`, `CLAUDE.md` | Ausgangsprüfung 1402 Prüfungen grün; `VERSION` und `manifest.yaml` `0.6.3-dev`; `STATUS.md` neu für v0.6.3 (v0.6.2 im Tag); `CLAUDE.md` mit den Memos von v0.6.3, Arbeitsrechner auf 0.6.2, Zweig-Regel; 1402 Prüfungen grün | 01 | ☑ abgeschlossen |
| 1 | **B26:** nur eigene Projekte aus `/opt/aios/workers.yaml` | `install.workers_projects()` liefert die Projekte beider `workers.yaml`; aus `<prefix>/workers.yaml` nur existierende Ordner mit der eigenen uid als Eigentümer (F150), uid über `install.own_uid()` mit `AIOS_TEST_UID` (F151); `known_vaults()` und `source_vaults()` nutzen sie, damit auch der Plan von `--install`, `--activate`, `--remove-version` und die Suche in Spec 07; Tests: t23 (+6), t03 (+2); Gegenprobe ohne Korrektur: t23 2, t03 1 Fehler; auf dem Arbeitsrechner nur lesend `aios --vaults` gleich wie mit 0.6.2 (16 Vaults); 1410 Prüfungen grün | 04 | ☑ abgeschlossen |
| 2 | **H13:** `README.md` und Tutorials auf `v0.6.3` (F152) | | 01 | ☐ |
| 3 | **Release-Kandidat** `0.6.3-rc1`, Live-Tests | | 01 | ☐ |
| 4 | **Abnahme** nach Spec 01, danach Veröffentlichen | | 01 | ☐ |
