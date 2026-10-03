# Stand der Umsetzung AIOS v0.3.0

Umsetzungsschritte nach dem Implementierungsplan v0.3 (Memo 32 im Konzeptprojekt `AAA-AIbex-AIOS-V0.3`, freigegeben in Memo 33, ergänzt durch spätere Memos). Jeder Schritt wird im selben Commit `Schritt N: …` abgehakt, der ihn abschließt. Vor jedem Schritt kommt ein Fragepaket nach der Regel *Weiter*.

v0.2.0 ist abgeschlossen (Tag `v0.2.0`, Abnahme in Memo 21 von `AAA-AIbex-AIOS-V0.2`); sein Stand steht in `STATUS.md` dieses Tags.

| # | Schritt | Ergebnis | Spec | Stand |
|---|---|---|---|---|
| 0 | **Repo auf v0.3 umstellen:** `CLAUDE.md`, `STATUS.md`, `VERSION` `0.3.0-dev` | Regeln zeigen auf V0.3 (`~/vault/§AIOS/A-AIOS/AA-AIbex-AIOS/`) und Memo 32, Stand v0.3, 492 Prüfungen grün | — | ☑ abgeschlossen |
| 1 | **Struktur und Namensregel:** `lib/aios/project.py` (S1–S4, Namensregel, Vorschlag) | `project.check` (S1–S4; S4 mit `git check-ignore --no-index` und `git ls-files`, Repo darüber bis zur Vault-Root), `project.check_name` mit Vorschlag (Prefix aus dem Anfangsbuchstaben, ein gültiger Prefix bleibt); neuer Test t11 (30 Prüfungen); 522 Prüfungen grün | 05 | ☑ abgeschlossen |
| 2 | **`aios --init` und `aios --activate`:** Ergänzen, `--name`, `--accept-name`, Repo darüber, Vault-Root, kein `@Memo/` | `aiosinit.Steps` (nur fehlende Teile S1–S4, Commit „initialisiert"/„ergänzt" nur mit den Dateien von AIOS), Ausschluss und `git rm --cached` im Repo darüber mit eigenem Commit (bei gestagten Änderungen dort nur Warnung), `--name` (anlegen/umbenennen), `--accept-name`, Exit 2 bei Verstoß, `--assistant` (Schlüssel `assistant` vorerst nur zugelassen), `--yes` gibt nur das Ergebnis aus; `aios --activate` an der Vault-Root mit Struktur und erstem Commit samt `.aios/config.yaml`; Skill `aios-init` mit Dialog und Namensdialog; Vorschlag erkennt kleingeschriebenen Prefix (`pb2-…` → `PB2-…`); t04, t08, t11; 550 Prüfungen grün | 04, 05 | ☑ abgeschlossen |
| 3 | **Konsistenzprüfung und Dialog:** `PROJECT-INCOMPLETE`, Dialog *Projekt initialisieren* | | 02 | ☐ |
| 4 | **Integrität:** `aios --integrity`, Skill `aios-integrity` | | 05 | ☐ |
| 5 | **Zuordnung des Assistenten:** `assistant:`, `aios --assistant`, `aios-context --assignment`, Merker | | 03, 04 | ☐ |
| 6 | **Assistent der Session in den Hooks:** Kontext, `AIOS-ASSISTANT-CHECK`, Skill `aios-assistant` | | 02, 03 | ☐ |
| 7 | **`/aios-memo`:** Rumpf von `memo==6.0.0`, Vorrang von `memo` | | 03 | ☐ |
| 8 | **Oberflächen:** `gui.yaml`, `aios --gui`, Alias `/gui`, `aios-gui`, Gärtner 0.2.0 | | 03, 04 | ☐ |
| 9 | **Doku:** `--list` mit Assistent, README, Tutorials | | 02, 04 | ☐ |
| 10 | **Abnahme:** v0.3.0 installieren, `§Demo` neu, Abnahmetest (Spec 01) | | 01 *Abnahmetest* | ☐ |
