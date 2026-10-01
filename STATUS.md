# Stand der Umsetzung AIOS v0.1.0

Umsetzungsschritte nach dem Implementierungsplan (Memo 18 im Konzeptprojekt, ergänzt durch spätere Memos). Jeder Schritt wird im selben Commit `Schritt N: …` abgehakt, der ihn abschließt.

| # | Schritt | Ergebnis | Spec | Stand |
|---|---|---|---|---|
| 1 | **Gerüst:** Repo-Struktur (`bin/`, `lib/aios/`, `skills/aios/`, `skills/basic/`, `templates/`, `python/`, `CLAUDE.md`, `dev/`), Testrahmen `tests/` mit Sandkasten | Grundgerüst, 36 Prüfungen grün | 04 *Repo* | ☑ abgeschlossen |
| 2 | **Weiterleiter und Versionen:** `~/bin/aios`, `~/bin/aios-context`; Auflösung über `AIOS_HOME`, Kette, `installations.yaml`; Legacy-Aufruf von `ai-brain` | `templates/forwarder`, alle Ränge getestet (t02, 24 Prüfungen), Memo 22 | 04 *Weiterleiter* | ☑ abgeschlossen |
| 3 | **Installieren:** `--prepare`, `--install [v<version>]`, `--versions`, `--remove-version`, `--uninstall`; ersetzt den Prototyp `bin/aios` | `bin/aios` → `lib/aios/install.py`, ganzer Lebenslauf im Sandkasten getestet (t03, 77 Prüfungen), Prototyp ersetzt, Memo 23 | 04 *CLI* | ☑ abgeschlossen |
| 4 | **Aktivieren:** `--activate`, `--deactivate`, Konfigurationskette mit Übertrumpfung je Schlüssel | `lib/aios/config.py` (Kette), `activate.py`, neu `aios --config`; geprüft gegen die Weiterleiter (t04, 46 Prüfungen), Memo 24 | 04 *Formate*, 02 | ☑ abgeschlossen |
| 5 | **Master-Kontext:** `aios-context` mit Vault, Projekt, Kette, Klassen K1–K5, Inhaltsverzeichnis, Ausgabe, id, `--load` | `lib/aios/context.py`: `--context`, `--load`, `--id`, Legacy-Modus; Ausgabe exakt und id-Vertrag geprüft (t05, 35 Prüfungen), Memo 25 | 02 | ☑ abgeschlossen |
| 6 | **Hooks:** `--session`, `--advise`, `PROJECT-UNINITIALIZED`, Inline-Grenze und Part-Dateien | `--session`, `--advise` (t06, 25 Prüfungen); vier echte Headless-Sessions bestanden (`tests/live/hooks.sh`), Memo 26 | 02 *Hooks* | ☑ abgeschlossen |
| 7 | **Registrieren:** `--sync`, Manifest, reservierte Namen, `aios --register` | `lib/aios/registry.py`, `--sync`, `aios --register`, Registrierung beim Session-Start (t07, 42 Prüfungen); Abgleich über eine Git-Grenze mit echten Sessions bestanden (L5), Memo 27 | 03 *Registrieren* | ☑ abgeschlossen |
| 8 | **AIOS-Skills:** versionsneutrale Hüllen (`aios --skill`), dann `/aios-context`, `/aios-init`, `/aios-status`, `/aios-register` | `aios --skill`, Hüllen, `--list`, `aios --init`, `--plan`/`--yes`; vier Skills (t08, 43 Prüfungen), alle vier in echten Sessions aufgerufen (`tests/live/skills.sh`), Memo 28 | 03, 04 | ☑ abgeschlossen |
| 9 | **Ausrollen und Versionen:** `aios --deploy`, Tags `<skill>-v<version>`, Manifest `skills:`; `memo` neutralisieren und in `skills/basic/` aufnehmen (O3) | `/aios-deploy memo==6.0.0` funktioniert | 03 *Ausrollen* | ☐ offen |
| 10 | **Agenten:** `aios-context --agent`, `/aios-agent`, Auflösung von Prompt und Skills | Obstgärtner und Astronom als Testfälle | 03 *Agenten* | ☐ offen |
| 11 | **Doku:** `spec/` → `doc/spec/` in der Installation, README aktualisieren | Installation enthält die Spec | 04 | ☐ offen |
| 12 | **Abnahme:** auf dem Arbeitsrechner installieren, `§Demo` anlegen, Abnahmetest (Spec 01) durchspielen | Tag **`v0.1.0`** | 01 *Abnahmetest* | ☐ offen |
