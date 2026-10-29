# Stand der Umsetzung AIOS v0.6.0

Umsetzungsschritte nach dem Implementierungsplan v0.6.0 (Memo 40 in `AA-AIbex-AIOS/@Memo/V0.6/`, freigegeben in Memo 41; Spec freigegeben in Memo 39). Jeder Schritt wird im selben Commit `Schritt N: …` abgehakt, der ihn abschließt. Vor jedem Schritt kommt ein Fragepaket nach der Regel *Weiter*.

v0.5.0 und v0.5.1 sind abgeschlossen (Tags `v0.5.0`, `v0.5.1`, Abnahme in den Memos 68 und 94 von `AA-AIbex-AIOS/@Memo/V0.5/`); ihr Stand steht in `STATUS.md` des Tags `v0.5.1`.

| # | Schritt | Ergebnis | Spec | Stand |
|---|---|---|---|---|
| 0 | **Repo auf v0.6 umstellen:** `VERSION`, `manifest.yaml`, `STATUS.md`, `CLAUDE.md` | `VERSION` und `manifest.yaml` `0.6.0-dev`; `STATUS.md` neu für v0.6.0 (v0.5 im Tag `v0.5.1`); `CLAUDE.md` mit Plan und Freigabe; t03 vergleicht alle Dateien in `spec/` mit `doc/spec/` (auch den umbenannten Überblick); Ausgangsprüfung und Abschluss mit 1175 Prüfungen grün | 01 | ☑ abgeschlossen |
| 1 | **Arten von Vaults:** `aios:` und `legacy:` nur an der Vault-Root, Modi, Warnungen | `config.py`: `aios:` und `legacy:` nur auf Ebene `vault` (Warnung „is only allowed at the vault root“), `legacy:` nur mit `ai-brain`, Warnung bei beiden zusammen, `kind` (aios, alt, legacy, none), `is_aibos` nach MAJOR.MINOR ≥ 0.6 (auch `-dev`), `--config` mit `kind`; `context.py`: Modus aus `kind`, `--id` mit `mode=alt-<version>`, Hooks und Ausgaben außerhalb eines A/W leer; `integrity.py`: Hinweise zu `aios:`/`legacy:` im Projekt und zu beiden an der Vault-Root; Tests: Testvaults an 0.6.0 gebunden (t05–t10, t13, t17), Legacy-Vaults mit `legacy: ai-brain` (t05–t08), t05 (+13 Arten von Vaults), t12 (+2), t04 (Kette nur aus der Vault-Root); Test-Hub: Obergrenze `<0.6` → `<0.7` (17 Manifeste), `test-assistent`, `test-hook`, `test-konflikt` bis `<0.7`, neues `test-alt` (nur `<0.5`) für t18, Testdistributionen mit Kernel 0.6.0 (t21); 1190 Prüfungen grün | 02, 04, 05 | ☑ abgeschlossen |
| 2 | **Orte und Weiterleiter 0.4.0:** `~/.aios/bin/aios`, `~/.aios/versions/`, `--system`, Arbeitspferde | | 04, 07 | ☐ |
| 3 | **Hooks still außerhalb eines A/W:** Log, absolute Pfade in Texten, Merker nur am gespeicherten `cwd` | | 02 | ☐ |
| 4 | **Block der Kernel-Skills** mit id-Zeile `kernel-skills <version>` | | 02 | ☐ |
| 5 | **Hook `PreToolUse`:** `aios --context --permit`, t22 | | 02 | ☐ |
| 6 | **Hüllen im Vault und Ortsprüfung** von `aios --skill`, absoluter Pfad in den Rümpfen | | 03, 04, 05 | ☐ |
| 7 | **`aios --install` und `--activate` für v0.6:** Umstieg | | 04 | ☐ |
| 8 | **Memos 02 und 03:** offene Dateien im Plan, Cache von `--from`, Registrierung im Ziel-Vault | | 04, 06 | ☐ |
| 9 | **Begleitpakete:** 13 Patch-Versionen mit Obergrenze `<0.7` | | 03 | ☐ |
| 10 | **Doku:** README, Tutorials, Hilfe | | 01, 04 | ☐ |
| 11 | **Live-Tests** auf v0.6, neu `permit.sh`, `outside.sh` | | 01, 02 | ☐ |
| 12 | **Version 0.6.0 lokal**, Lauf in kleinster Umgebung | | 01 | ☐ |
| 13 | **Abnahme** nach Spec 01, danach Veröffentlichen | | 01 | ☐ |
