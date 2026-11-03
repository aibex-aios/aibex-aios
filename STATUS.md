# Stand der Umsetzung AIOS v0.6.2

Umsetzungsschritte nach dem Implementierungsplan v0.6.2 (Memo 126 in `AA-AIbex-AIOS/@Memo/V0.6/`, freigegeben in Memo 127; Spec freigegeben in Memo 125). Jeder Schritt wird im selben Commit `v0.6.2 Schritt N: …` abgehakt, der ihn abschließt. Diese Datei enthält alle Schritte des Plans von Anfang an (F102). Vor einem Schritt kommt ein Fragepaket nach der Regel *Weiter*, wenn eine Entscheidung offen ist.

v0.6.1 ist abgeschlossen (Tag `v0.6.1`, Abnahme in Memo 107 von `AA-AIbex-AIOS/@Memo/V0.6/`); sein Stand steht in `STATUS.md` des Tags `v0.6.1`, der von v0.6.0 im Tag `v0.6.0`.

v0.6.2 ist ein Release aus drei Paketen: Kernel 0.6.2, `skill-cleanup` 0.1.1 (Paket-Repo in `MSC-Cleanup/@Package/skill-cleanup`) und `distribution-capricorn` 0.4.0. Deren Schritte 6 und 7 stehen hier mit (F103).

| # | Schritt | Ergebnis | Spec | Stand |
|---|---|---|---|---|
| 0 | **Repo auf 0.6.2:** `VERSION`, `manifest.yaml`, `STATUS.md`, `CLAUDE.md` | Ausgangsprüfung 1344 Prüfungen grün; `VERSION` und `manifest.yaml` `0.6.2-dev`; `STATUS.md` neu für v0.6.2 mit allen Schritten (v0.6.1 im Tag); `CLAUDE.md` mit Plan und Freigabe, Arbeitsrechner auf 0.6.1, Zweig `v0.8`, `STATUS.md` in Paket-Repos, Push mit Liste der Commits; 1344 Prüfungen grün | 01 | ☑ abgeschlossen |
| 1 | **H8, H6:** Suche nach Vaults | `install.find_vaults()` mit den Quellen `session`, `repo`, `workers`, `beside`, `inside`, `above` (nur Standardbibliothek, F101); `aios --vaults`; Plan von `aios --remove-version` nennt die gebundenen Vaults; Tests t23 (neu), t03 | 04 | ☐ |
| 2 | **H7:** Registrierung endet an `§`-Ordnern | `activate.vault_projects` überspringt `§`-Ordner im Vault (nicht `/aios-integrity`, F100); Test t04 | 04 | ☐ |
| 3 | **H5:** Hinweis auf eine Distribution mit anderem Kernel | `note: distribution-<name> <version> wants kernel <bereich>; update it with aios --install distribution-<name>` im Plan von `aios --activate` (F99); Tests t04 bzw. t21 | 04, 06 | ☐ |
| 4 | **H9:** `Read` unter `doc/` der Bindung | `permit` gibt `<installation>/doc/` der Bindung frei (R2); Tests t22, `tests/live/permit.sh` | 02 | ☐ |
| 5 | **Spec und Hilfe** | Spec nachgeführt, falls nötig; `aios --help` mit `--vaults` | 01–06 | ☐ |
| 6 | **`skill-cleanup` 0.1.1** | Kandidat `0.1.1-rc1` mit `requires.aios: ">=0.6,<0.7"`, lokal getaggt; Paket-Spec und Memo in `MSC-Cleanup` | 06 | ☐ |
| 7 | **`distribution-capricorn` 0.4.0** | Kandidat `0.4.0-rc1` mit `kernel: "==0.6.2-rc1"`, Anja 0.3.0, `skill-cleanup` `0.1.1-rc1`, lokal getaggt; Memos in `DC-Capricorn/@Memo/V0.4/` | 06 | ☐ |
| 8 | **Live-Tests und Release-Kandidat** | `fresh.sh`, `permit.sh`, `rothirsch.sh`, `changeover.sh` mit Kernel aus einem Sandkasten-Klon; `VERSION` und `manifest.yaml` `0.6.2-rc1`, lokaler Tag `v0.6.2-rc1` | 01 | ☐ |
| 9 | **Abnahme** nach Spec 01, danach Veröffentlichen | Spec 01, *Abnahmetest*, Schritte 1–14 | 01 | ☐ |
