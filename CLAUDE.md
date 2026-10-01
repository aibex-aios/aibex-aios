# AIbex AIOS — Arbeiten am Repo

Regeln für Sessions, die an AIbex AIOS arbeiten, ob sie im Repo laufen oder im Konzeptprojekt (dort mit absoluten Pfaden auf dieses Repo).

## Wo was liegt

| Was | Ort |
|---|---|
| Spec (Soll-Stand, verbindlich) | `spec/` |
| Memos (Begründungen, Verlauf) | Konzeptprojekte, siehe unten |
| Implementierungsplan | v0.2: Memo 20 im Konzeptprojekt V0.2, spätere Memos gehen ihm vor (v0.1: Memo 18 in V0.1) |
| Stand der Umsetzung | `STATUS.md` |
| Code | `bin/` (Bash: `aios`, `aios-context`), `lib/aios/` (Python) |
| Skills | `skills/<gruppe>/<name>/SKILL.md`: `aios` (AIOS-Skills), `basic` (Grundausstattung) |
| Tests | `tests/run` |
| Entwickler-Doku | `dev/` (wird nicht installiert) |

Das Repo enthält keinen Vault. Vaults legt der User an und bindet sie mit `aios --activate` an eine installierte Version; Tests legen ihre Vaults im Sandkasten an.

Konzeptprojekte mit den Memos, unter `/Users/hux/Library/CloudStorage/GoogleDrive-hugo.pristauz@aibex.at/Geteilte Ablagen/§AIbex/P-Projekte/AI/PA-AIbex-AIOS/`:

| Projekt | Inhalt |
|---|---|
| `PAA-AIbex-AIOS-V0.2/@Memo/` | **laufende Version v0.2**: Memos 13–20 (Umfang, Begriffe, Plan) |
| `PAA-AIbex-AIOS-V0.1/@Memo/` | Grundlage aus v0.1 (abgeschlossen, Tag `v0.1.0`) |
| `PAA-AIbex-AIOS-V0.3/@Memo/` | Wünsche für v0.3, nicht Teil der laufenden Arbeit |
| `PAA-AIbex-AIOS-V0.99/@Memo/` | Ideen ohne Version, nicht Teil der laufenden Arbeit |

## Stand ermitteln

1. Memo 20 in V0.2 lesen (Implementierungsplan v0.2, Schritte 0–6), dann alle Memos von V0.2 mit höherer Nummer.
2. `STATUS.md` lesen: Der nächste Schritt ist der erste mit ☐. Zur Kontrolle `git log --oneline`: Jeder abgeschlossene Schritt hat einen Commit `Schritt N: …`.
3. `tests/run` als Ausgangsprüfung, alle Tests müssen grün sein.
4. Dem User den ermittelten Schritt nennen und dann beginnen.

## Memos schreiben

Vorher den Skill `memo` vollständig lesen und befolgen (Nummerierung, Header-Block, bestehende Memos werden nie geändert):

```
/Users/hux/Library/CloudStorage/GoogleDrive-hugo.pristauz@aibex.at/Geteilte Ablagen/§AIbex/@/@Skill/memo/SKILL.md
```

Das Memo wird im Konzeptprojekt der laufenden Version (V0.2) angelegt und dort committet, die Spec-Änderung im Repo.

## Regeln

- **Die Spec ist verbindlich.** Weicht die Umsetzung von der Spec ab, wird zuerst die Spec korrigiert und die Entscheidung als Memo festgehalten.
- **Bash für Weiterleiter und Bootstrap, Python für die Logik** (V0.1, Memo 18, E1). Bash-Skripte folgen der Bash-Konvention (unten).
- **Keine fest verdrahteten Pfade:** immer `AIOS_PREFIX`, `HOME`, `AIOS_CLAUDE_DIR` (Spec 04, *Umlenkung für Tests*).
- **Tests im Sandkasten:** `tests/run` vor jedem Commit; Tests verändern nie den echten Rechner.
- **Ein Schritt, ein Commit:** jeder Schritt des Plans endet mit grünen Tests und einem Commit `Schritt N: …`, danach Push. Im selben Commit wird der Schritt in `STATUS.md` abgehakt (☐ → ☑, Ergebnis nachgetragen).
- **Das Arbeitsverzeichnis nicht wechseln:** `git -C <repo>` und absolute Pfade verwenden, damit der Masterspace der Session gültig bleibt.
- **Der Arbeitsrechner wird erst im Abnahmeschritt umgestellt** (v0.2: Schritt 6, Memo 20).

## Bash-Konvention

@dev/Bash-Skript-Struktur.md
