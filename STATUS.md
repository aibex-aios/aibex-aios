# Stand der Umsetzung AIOS v0.6.1

Umsetzungsschritte nach dem Implementierungsplan v0.6.1 (Memo 87 in `AA-AIbex-AIOS/@Memo/V0.6/`, freigegeben in Memo 88; Spec freigegeben in Memo 86). Jeder Schritt wird im selben Commit `v0.6.1 Schritt N: …` abgehakt, der ihn abschließt. Vor einem Schritt kommt ein Fragepaket nach der Regel *Weiter*, wenn eine Entscheidung offen ist.

v0.6.0 ist abgeschlossen (Tag `v0.6.0`, Abnahme in Memo 74 von `AA-AIbex-AIOS/@Memo/V0.6/`); sein Stand steht in `STATUS.md` des Tags `v0.6.0`, der von v0.5 im Tag `v0.5.1`.

| # | Schritt | Ergebnis | Spec | Stand |
|---|---|---|---|---|
| 0 | **Repo auf 0.6.1:** `VERSION`, `manifest.yaml`, `STATUS.md`, `CLAUDE.md` | Ausgangsprüfung 1314 Prüfungen grün; `VERSION` und `manifest.yaml` `0.6.1-dev`; `STATUS.md` neu für v0.6.1 (v0.6.0 im Tag); `CLAUDE.md` mit Plan und Freigabe, Arbeitsrechner auf 0.6.0, Weiterleiter `~/.aios/bin/aios`; 1314 Prüfungen grün | 01 | ☑ abgeschlossen |
| 1 | **B12:** Nutzer einer Version gegen die bekannten Vaults | `worker.known_users`: Projekte der bekannten Vaults (`install.known_vaults`), deren `lock.yaml` die Version nennt; `worker.add_users` trägt sie in `workers.yaml` nach; `fetch.worker_users` behält eine solche Version mit der Zeile `<workers.yaml>: <paket> <version> stays, used by <projekte>`, sonst `remove … (removed: no known project uses it)` (Spec 07); Tests: t17 (+6: Vault mit Altbindung nur über den Merker der Session bekannt, Version und Weiterleiter bleiben, Projekt nachgetragen), Text in t17 und `tests/live/rothirsch.sh`; 1320 Prüfungen grün | 07 | ☑ abgeschlossen |
| 2 | **B13:** Paketwechsel mit Unterschritten | `fetch.Fetch.plan` geteilt in `build` (Plan aufbauen, `Built`) und `run` (bestätigen, alles oder nichts); `migrate.Change04.substeps` baut das Holen jedes Projekts mit den neuen `packages:` gegen den neuen Kernel, der Plan der Aktivierung zeigt dessen Schritte unter `packages for AIOS <version>: <projekt>` (bei Umbenennungen weiter `changeover from v0.4`), `apply` führt genau diesen Plan aus statt eines stillen `fetch.sync`; mehrere Projekte werden nacheinander geplant (`worker.assume`/`forget`: Versionen und `lock.yaml` der Projekte davor gelten als erledigt); Tests: t18 (+5: Überschrift, Unterschritte, keine Überschrift von v0.4 ohne Umbenennung); mehrere Projekte mit Arbeitspferden im Live-Test `changeover.sh` (Schritt 5); 1325 Prüfungen grün | 04, 06 | ☑ abgeschlossen |
| 3 | **H3:** offene Dateien je Paketordner | | 06 | ☐ |
| 4 | **Distributionen als Kandidaten:** Rothirsch `1.1.0-rc1`, Capricorn `0.3.0-rc1` | | 06 | ☐ |
| 5 | **Live-Tests und Tutorial 05:** `changeover.sh` neu, `rothirsch.sh` | | 01, 06, 07 | ☐ |
| 6 | **Release-Kandidat lokal:** `0.6.1-rc1`, Lauf in kleinster Umgebung | | 01 | ☐ |
| 7 | **Abnahme** nach Spec 01, danach Veröffentlichen | | 01 | ☐ |
