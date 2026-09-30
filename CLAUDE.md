# AIbex AIOS — Arbeiten am Repo

Regeln für Sessions, die an AIbex AIOS arbeiten, ob sie im Repo laufen oder im Konzeptprojekt (dort mit absoluten Pfaden auf dieses Repo).

## Wo was liegt

| Was | Ort |
|---|---|
| Spec (Soll-Stand, verbindlich) | `spec/` |
| Memos (Begründungen, Verlauf) | Konzeptprojekt, siehe unten |
| Implementierungsplan | Memo 18 im Konzeptprojekt, spätere Memos gehen ihm vor |
| Stand der Umsetzung | `STATUS.md` |
| Code | `bin/` (Bash: `aios`, `aios-context`), `lib/aios/` (Python) |
| Skills | `skills/<gruppe>/<name>/SKILL.md`: `aios` (AIOS-Skills), `basic` (Grundausstattung) |
| Tests | `tests/run` |
| Entwickler-Doku | `dev/` (wird nicht installiert) |

Das Repo enthält keinen Vault. Vaults legt der User an und bindet sie mit `aios --activate` an eine installierte Version; Tests legen ihre Vaults im Sandkasten an.

Konzeptprojekt mit den Memos:

```
/Users/hux/Library/CloudStorage/GoogleDrive-hugo.pristauz@aibex.at/Geteilte Ablagen/§AIbex/P-Projekte/AI/PA-AIbex-AIOS/PAA-AIbex-AIOS-V0.1/@Memo/
```

## Stand ermitteln

1. Memo 18 lesen (Implementierungsplan, Schritte 1–12), dann alle Memos mit höherer Nummer.
2. `STATUS.md` lesen: Der nächste Schritt ist der erste mit ☐. Zur Kontrolle `git log --oneline`: Jeder abgeschlossene Schritt hat einen Commit `Schritt N: …`.
3. `tests/run` als Ausgangsprüfung, alle Tests müssen grün sein.
4. Dem User den ermittelten Schritt nennen und dann beginnen.

## Memos schreiben

Vorher den Skill `memo` vollständig lesen und befolgen (Nummerierung, Header-Block, bestehende Memos werden nie geändert):

```
/Users/hux/Library/CloudStorage/GoogleDrive-hugo.pristauz@aibex.at/Geteilte Ablagen/§AIbex/@/@Skill/memo/SKILL.md
```

Das Memo wird im Konzeptprojekt angelegt und dort committet, die Spec-Änderung im Repo.

## Regeln

- **Die Spec ist verbindlich.** Weicht die Umsetzung von der Spec ab, wird zuerst die Spec korrigiert und die Entscheidung als Memo festgehalten.
- **Bash für Weiterleiter und Bootstrap, Python für die Logik** (Memo 18, E1). Bash-Skripte folgen der Bash-Konvention (unten).
- **Keine fest verdrahteten Pfade:** immer `AIOS_PREFIX`, `HOME`, `AIOS_CLAUDE_DIR` (Spec 04, *Umlenkung für Tests*).
- **Tests im Sandkasten:** `tests/run` vor jedem Commit; Tests verändern nie den echten Rechner.
- **Ein Schritt, ein Commit:** jeder Schritt des Plans endet mit grünen Tests und einem Commit `Schritt N: …`, danach Push. Im selben Commit wird der Schritt in `STATUS.md` abgehakt (☐ → ☑, Ergebnis nachgetragen).
- **Das Arbeitsverzeichnis nicht wechseln:** `git -C <repo>` und absolute Pfade verwenden, damit der Masterspace der Session gültig bleibt.
- **Der Arbeitsrechner wird erst in Schritt 12 umgestellt** (Memo 18, E4).

## Bash-Konvention

@dev/Bash-Skript-Struktur.md
