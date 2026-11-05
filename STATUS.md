# Stand der Umsetzung AIOS v0.6.4

v0.6.4 macht Workspaces zuverlässig auf mehreren Rechnern: `attach`, `sync`, `detach` (mit Teilauslagerung), Namensschema am Remote, `@Secret/`, Schlüssel `sync:`, drei Kernel-Skills. Verkürzte Form ohne eigenen Implementierungsplan: die Schritte stehen in Memo 176 in `AIBOS-AA-AIbex-AIOS/@Memo/V0.6/` (Skizze Memo 171; Spec freigegeben in Memo 176, ergänzt in Memo 177). Jeder Schritt wird im selben Commit `v0.6.4 Schritt N: …` abgehakt, der ihn abschließt. Diese Datei enthält alle Schritte von Anfang an (F102).

v0.6.3 ist abgeschlossen (Tag `v0.6.3`, Abnahme in Memo 160, Veröffentlichung in Memo 162); sein Stand steht in `STATUS.md` des Tags `v0.6.3`, frühere in den Tags `v0.6.2`, `v0.6.1` und `v0.6.0`.

Das Repo liegt seit 2026-11-05 im Konzeptprojekt unter `~/Workspace/§AIBOS/A-AIOS/AA-AIbex-AIOS/@Package/aibex-aios` (Memos 178, 179, 183); am alten Ort `~/git/AIbex/aibex-aios` steht ein Link.

| # | Schritt | Ergebnis | Spec | Stand |
|---|---|---|---|---|
| 0 | **Repo auf 0.6.4:** `VERSION`, `manifest.yaml`, `STATUS.md`, `CLAUDE.md` | Ausgangsprüfung 1410 Prüfungen grün; `VERSION` und `manifest.yaml` `0.6.4-dev`; `STATUS.md` neu für v0.6.4 (v0.6.3 im Tag); `CLAUDE.md` mit den Memos von v0.6.4, Arbeitsrechner auf 0.6.3, Zweig-Regel | 01 | ☑ abgeschlossen |
| 1 | **Spec 01–06** nach Memo 171 | Entwurf `b2a2568`, freigegeben `add92cb` (Memo 176), Paket-Repos klein `b1f95e9` (Memo 177), Abnahmetest mit `~/Workspace` `b6196d8` | 01–06 | ☑ abgeschlossen |
| 2 | **`workspace.py`:** Manifest, Merker `workspace.local.yaml`, Eltern vor Kindern, `attach <repo>`, `sync` ohne Push, `status` | — | 06 | ☐ |
| 3 | **sync:** Manifest nachführen, Push, Prüfung auf Geheimnisse | — | 06 | ☐ |
| 4 | **detach und attach mit Pfad:** Prüfung, Platzhalter `DETACHED.md` und `DETACHED.command`, Papierkorb; Probe zu `DETACHED.command` | — | 06 | ☐ |
| 5 | **Hook, Integrität, Vorlage, Kernel-Skills:** `AIOS-SYNC`, `AIOS-DETACHED`, `<aios-workspace>`, Zustand `detached`, `.gitignore`-Vorlage, `aios-attach`, `aios-sync`, `aios-detach` | — | 01–05 | ☐ |
| 6 | **README, Tutorial 04; Release-Kandidat** `0.6.4-rc1`, Live-Tests | — | 01 | ☐ |
| 7 | **Abnahme** nach Spec 01 (Vorabnahme im zweiten Benutzer, Abnahme auf dem Notebook), danach Veröffentlichen | — | 01 | ☐ |
