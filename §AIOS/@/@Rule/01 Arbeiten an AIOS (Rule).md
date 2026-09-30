# Arbeiten an AIOS

**Datum:** 2026-09-30
**Status:** Konvention

## Zweck

Regeln für Sessions, die in `§AIOS` an AIbex AIOS arbeiten. `§AIOS` ist der Vault von AIOS selbst im Repo `aibex-aios` (Memo 04, 15, 18 im Konzeptprojekt).

## Wo was liegt

| Was | Ort |
|---|---|
| Spec (Soll-Stand, verbindlich) | `../spec/` im Repo |
| Memos (Begründungen, Verlauf) | Konzeptprojekt `§AIbex/P-Projekte/AI/PA-AIbex-AIOS/PAA-AIbex-AIOS-V0.1/@Memo/` |
| Implementierungsplan | Memo 18 im Konzeptprojekt |
| Code | `§AIOS/bin/` (Bash), `§AIOS/lib/aios/` (Python), `../bin/aios` (Einstieg) |
| Tests | `../tests/` |

## Regeln

- **Die Spec ist verbindlich.** Weicht die Umsetzung von der Spec ab, wird zuerst die Spec korrigiert (im Repo) und die Entscheidung als Memo im Konzeptprojekt festgehalten.
- **Bash für Weiterleiter und Bootstrap, Python für die Logik** (Memo 18, E1). Bash-Skripte folgen `02 Bash-Skript-Struktur (Rule).md`.
- **Keine fest verdrahteten Pfade:** immer `AIOS_PREFIX`, `HOME`, `AIOS_CLAUDE_DIR` (Spec 04, *Umlenkung für Tests*).
- **Tests im Sandkasten:** `../tests/run` vor jedem Commit; Tests verändern nie den echten Rechner.
- **Ein Schritt, ein Commit:** jeder Schritt des Implementierungsplans endet mit grünen Tests und einem Commit.
- **Der Arbeitsrechner wird erst in Schritt 12 umgestellt** (Memo 18, E4).
