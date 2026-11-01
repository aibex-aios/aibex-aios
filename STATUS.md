# Stand der Umsetzung AIOS v0.6.1

Umsetzungsschritte nach dem Implementierungsplan v0.6.1 (Memo 87 in `AA-AIbex-AIOS/@Memo/V0.6/`, freigegeben in Memo 88; Spec freigegeben in Memo 86). Jeder Schritt wird im selben Commit `v0.6.1 Schritt N: …` abgehakt, der ihn abschließt. Vor einem Schritt kommt ein Fragepaket nach der Regel *Weiter*, wenn eine Entscheidung offen ist.

v0.6.0 ist abgeschlossen (Tag `v0.6.0`, Abnahme in Memo 74 von `AA-AIbex-AIOS/@Memo/V0.6/`); sein Stand steht in `STATUS.md` des Tags `v0.6.0`, der von v0.5 im Tag `v0.5.1`.

| # | Schritt | Ergebnis | Spec | Stand |
|---|---|---|---|---|
| 0 | **Repo auf 0.6.1:** `VERSION`, `manifest.yaml`, `STATUS.md`, `CLAUDE.md` | Ausgangsprüfung 1314 Prüfungen grün; `VERSION` und `manifest.yaml` `0.6.1-dev`; `STATUS.md` neu für v0.6.1 (v0.6.0 im Tag); `CLAUDE.md` mit Plan und Freigabe, Arbeitsrechner auf 0.6.0, Weiterleiter `~/.aios/bin/aios`; 1314 Prüfungen grün | 01 | ☑ abgeschlossen |
| 1 | **B12:** Nutzer einer Version gegen die bekannten Vaults | | 07 | ☐ |
| 2 | **B13:** Paketwechsel mit Unterschritten | | 04, 06 | ☐ |
| 3 | **H3:** offene Dateien je Paketordner | | 06 | ☐ |
| 4 | **Distributionen als Kandidaten:** Rothirsch `1.1.0-rc1`, Capricorn `0.3.0-rc1` | | 06 | ☐ |
| 5 | **Live-Tests und Tutorial 05:** `changeover.sh` neu, `rothirsch.sh` | | 01, 06, 07 | ☐ |
| 6 | **Release-Kandidat lokal:** `0.6.1-rc1`, Lauf in kleinster Umgebung | | 01 | ☐ |
| 7 | **Abnahme** nach Spec 01, danach Veröffentlichen | | 01 | ☐ |
