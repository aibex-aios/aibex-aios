# Arbeiten an AIOS

**Datum:** 2026-09-30
**Status:** Konvention

## Zweck

Regeln für Sessions, die in `§AIOS` an AIbex AIOS arbeiten. `§AIOS` ist der Vault von AIOS selbst im Repo `aibex-aios` (Memo 04, 15, 18 im Konzeptprojekt).

## Wo was liegt

| Was | Ort |
|---|---|
| Spec (Soll-Stand, verbindlich) | `../spec/` im Repo |
| Memos (Begründungen, Verlauf) | Konzeptprojekt, siehe *Einstieg in eine Session* |
| Implementierungsplan | Memo 18 im Konzeptprojekt |
| Code | `§AIOS/bin/` (Bash), `§AIOS/lib/aios/` (Python), `../bin/aios` (Einstieg) |
| Tests | `../tests/` |

## Einstieg in eine Session

`§AIOS` ist ein eigener Vault. Der Masterspace von `§AIbex` (und damit der Skill `memo`) wird hier nicht geladen, die Memos liegen außerhalb des Repos:

```
/Users/hux/Library/CloudStorage/GoogleDrive-hugo.pristauz@aibex.at/Geteilte Ablagen/§AIbex/P-Projekte/AI/PA-AIbex-AIOS/PAA-AIbex-AIOS-V0.1/@Memo/
```

**Stand ermitteln**, bevor gearbeitet wird:

1. Memo 18 lesen (Implementierungsplan, Schritte 1–12).
2. Alle Memos mit höherer Nummer lesen: Sie halten Entscheidungen seit dem Plan fest und gehen ihm vor.
3. `git -C ~/git/AIbex/aibex-aios log --oneline` prüfen: Jeder abgeschlossene Schritt hat einen Commit `Schritt N: …`. Der nächste Schritt ist der erste ohne solchen Commit.
4. `../tests/run` als Ausgangsprüfung ausführen, alle Tests müssen grün sein.
5. Dem User den ermittelten Schritt nennen und dann beginnen.

**Memos schreiben:** vorher den Skill `memo` vollständig lesen und befolgen (Nummerierung, Header-Block, Memos werden nie geändert):

```
/Users/hux/Library/CloudStorage/GoogleDrive-hugo.pristauz@aibex.at/Geteilte Ablagen/§AIbex/@/@Skill/memo/SKILL.md
```

Das Memo wird im `@Memo/`-Ordner des Konzeptprojekts angelegt und dort committet (`git -C "<Konzeptprojekt>" …`), die Spec-Änderung im Repo.

## Regeln

- **Die Spec ist verbindlich.** Weicht die Umsetzung von der Spec ab, wird zuerst die Spec korrigiert (im Repo) und die Entscheidung als Memo im Konzeptprojekt festgehalten.
- **Bash für Weiterleiter und Bootstrap, Python für die Logik** (Memo 18, E1). Bash-Skripte folgen `02 Bash-Skript-Struktur (Rule).md`.
- **Keine fest verdrahteten Pfade:** immer `AIOS_PREFIX`, `HOME`, `AIOS_CLAUDE_DIR` (Spec 04, *Umlenkung für Tests*).
- **Tests im Sandkasten:** `../tests/run` vor jedem Commit; Tests verändern nie den echten Rechner.
- **Ein Schritt, ein Commit:** jeder Schritt des Implementierungsplans endet mit grünen Tests und einem Commit.
- **Der Arbeitsrechner wird erst in Schritt 12 umgestellt** (Memo 18, E4).
