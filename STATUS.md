# Stand der Umsetzung AIOS v0.5

Umsetzungsschritte nach dem Implementierungsplan v0.5 (Memo 44 in `AA-AIbex-AIOS/@Memo/V0.5/`, freigegeben in Memo 45, ergänzt durch spätere Memos). Jeder Schritt wird im selben Commit `Schritt N: …` abgehakt, der ihn abschließt. Vor jedem Schritt kommt ein Fragepaket nach der Regel *Weiter*.

v0.4.0 ist abgeschlossen (Tag `v0.4.0`, Abnahme in den Memos 63–75 von `AA-AIbex-AIOS/@Memo/V0.4/`); sein Stand steht in `STATUS.md` dieses Tags. Die offenen Punkte B5, B8 und der Kandidat aus V0.4, Memo 77 laufen in v0.5 mit, wo sie dieselben Stellen berühren (V0.5, Memo 44).

| # | Schritt | Ergebnis | Spec | Stand |
|---|---|---|---|---|
| 0 | **Repo auf v0.5 umstellen:** `spec-v0.5` nach `main`, `CLAUDE.md`, `STATUS.md`, `VERSION` `0.5.0-dev`, `manifest.yaml` des Kernels | `main` per fast-forward auf die freigegebene Spec (`7d922eb`), Zweig `spec-v0.5` gelöscht; Specs 01–07 mit Status *Spec*; `CLAUDE.md` mit Plan, Ordnern und Regeln von v0.5; `VERSION` und `manifest.yaml` `0.5.0-dev`; t03 prüft jetzt alle Dateien in `spec/` (fand vorher den umbenannten Überblick nicht und verglich zwei leere Ausgaben), README-Tabelle der Specs; 961 Prüfungen grün | 01–07 | ☑ abgeschlossen |
| 1 | **`aios --context`** statt `aios-context`: Gruppe in `aios`, Weiterleiter, Hooks, Hüllen, Umstieg der Einrichtung | `bin/aios` gibt `--context` direkt an `aios.context` weiter (ohne das CLI zu laden), ohne Option = Master-Kontext (N6); `bin/aios-context` entfernt; Weiterleiter 0.2.0 nur noch für `aios`, Rückfall auf `ai-brain` nur bei `--context` (mit Pfadargument wie bisher); `install.py`: Hooks `aios --context --session`/`--advise`, alte `aios-context`-Hooks entfernt (nicht als ai-brain gesichert), `~/bin/aios-context` mit Marke entfernt, Alias und Hüllen mit `Bash(aios --context *)`, Hinweis auf Vaults unter 0.5 aus den Merkern der Sessions (N7); Meldungen der Python-Module und Rümpfe der AIOS-Skills auf `aios --context`; Tests t01–t10, t13, t18 umgestellt, t02 mit Rückfall nur für `--context`, t03 mit Umstieg einer v0.4-Einrichtung; Live-Tests umgestellt (Lauf in Schritt 15); 975 Prüfungen grün | 02, 04 | ☑ abgeschlossen |
| 2 | **Formate und Prüfungen:** Typen `worker` und `distribution`, `worker:`, `kernel:`, Ablehnung von `workers:`, Hash-Datei, `lock.yaml` in der Untermenge, `PREFIX` `assistant-` | | 06, 07 | ☐ |
| 3 | **`aios --prepare`, Vorlage, Integrität:** zwei Stufen, `.gitignore` mit `.agents/` und `.aios/backup/`, `.agents/` in `/aios-integrity` | | 04, 05 | ☐ |
| 4 | **Begleitpaket `assistant-anja` 0.2.0** | | Memo 39 | ☐ |
| 5 | **Sicherung, alles oder nichts** in `aios --fetch` | | 06 | ☐ |
| 6 | **Arbeitspferde — Kern:** `worker.py`, `workers.yaml`, setup und remove, Weiterleiter, `aios --worker`, Test-Wheel, Testpakete | | 07, 04 | ☐ |
| 7 | **Paket laden:** setup im Plan, Upgrade, Abgleich, Entfernen, Konflikt, Hinweis `AIOS-WORKERS` | | 06, 07, 02 | ☐ |
| 8 | **Begleitpakete `worker-deno`, `worker-yt-dlp`**, Live-Test `tests/live/workers.sh` | | 07 | ☐ |
| 9 | **Distributionen — Installieren:** `aios --install distribution-<name>`, `kernel:`, Rechner- und Vaultteil, Testpaket `distribution-demo` | | 04, 06 | ☐ |
| 10 | **`/aios-distribution`** | | 03 | ☐ |
| 11 | **Umstellung von v0.4:** Umbenennung `assistent-*`, Pakete mit `requires.aios` unter 0.5 | | 04, 06 | ☐ |
| 12 | **Grundausstattung** in neuen Versionen (N8) | | 03 | ☐ |
| 13 | **`skill-video-analyse` 0.2.0, `distribution-rothirsch` 1.0.0** | | 01 | ☐ |
| 14 | **Doku:** README, Tutorials, Hilfe | | 04 | ☐ |
| 15 | **Version 0.5.0:** Live-Tests, Index, Tag lokal | | 01, 04 | ☐ |
| 16 | **Abnahme** v0.5.0 mit „Rothirsch 1.0", danach Veröffentlichen | | 01 | ☐ |
