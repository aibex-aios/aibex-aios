# AIbex AIOS — Arbeiten am Repo

Regeln für Sessions, die an AIbex AIOS arbeiten, ob sie im Repo laufen oder im Konzeptprojekt (dort mit absoluten Pfaden auf dieses Repo).

## Wo was liegt

| Was | Ort |
|---|---|
| Spec (Soll-Stand, verbindlich) | `spec/` |
| Memos (Begründungen, Verlauf) | Konzeptprojekte, siehe unten |
| Implementierungsplan | v0.3: Memo 32 im Konzeptprojekt V0.3, freigegeben in Memo 33; spätere Memos gehen ihm vor (v0.2: Memo 20 in V0.2, v0.1: Memo 18 in V0.1) |
| Stand der Umsetzung | `STATUS.md` |
| Code | `bin/` (Bash: `aios`, `aios-context`), `lib/aios/` (Python) |
| Skills | `skills/<gruppe>/<name>/SKILL.md`: `aios` (AIOS-Skills), `basic` (Grundausstattung) |
| Tests | `tests/run` |
| Entwickler-Doku | `dev/` (wird nicht installiert) |

Das Repo enthält keinen Vault. Vaults legt der User an und bindet sie mit `aios --activate` an eine installierte Version; Tests legen ihre Vaults im Sandkasten an.

Konzeptprojekte mit den Memos, unter `~/vault/§AIOS/A-AIOS/AA-AIbex-AIOS/` (Projekt `AA-AIbex-AIOS` mit der Regel `@/@Rule/Weiter.md`):

| Projekt | Inhalt |
|---|---|
| `AAA-AIbex-AIOS-V0.3/@Memo/` | **laufende Version v0.3**: Memos 01–33 (Wünsche, Entscheidungen, Spec, Plan); in Memos 01–11 heißt der Assistent noch *Agent* (Memo 13) |
| `AAA-AIbex-AIOS-V0.2/@Memo/` | v0.2 (abgeschlossen, Tag `v0.2.0`) |
| `AAA-AIbex-AIOS-V0.1/@Memo/` | Grundlage aus v0.1 (abgeschlossen, Tag `v0.1.0`) |
| `AAA-AIbex-AIOS-V0.4/@ToDo/` | Wünsche für v0.4, nicht Teil der laufenden Arbeit |
| `AAA-AIbex-AIOS-V0.99/@Memo/` | Ideen ohne Version, nicht Teil der laufenden Arbeit |

## Stand ermitteln

1. Memo 32 in V0.3 lesen (Implementierungsplan v0.3, Schritte 0–10), dann alle Memos von V0.3 mit höherer Nummer.
2. `STATUS.md` lesen: Der nächste Schritt ist der erste mit ☐. Zur Kontrolle `git log --oneline`: Jeder abgeschlossene Schritt hat einen Commit `Schritt N: …`.
3. `tests/run` als Ausgangsprüfung, alle Tests müssen grün sein.
4. Dem User den ermittelten Schritt nennen und dann beginnen.

## Memos schreiben

Vorher den Skill `memo` vollständig lesen und befolgen (Nummerierung, Header-Block, bestehende Memos werden nie geändert):

```
~/vault/§AIOS/@/@!Skill/memo/SKILL.md
```

Das Memo wird im Konzeptprojekt der laufenden Version (V0.3) angelegt und dort committet, die Spec-Änderung im Repo.

## Regeln

- **Die Spec ist verbindlich.** Weicht die Umsetzung von der Spec ab, wird zuerst die Spec korrigiert und die Entscheidung als Memo festgehalten.
- **Bash für Weiterleiter und Bootstrap, Python für die Logik** (V0.1, Memo 18, E1). Bash-Skripte folgen der Bash-Konvention (unten).
- **Keine fest verdrahteten Pfade:** immer `AIOS_PREFIX`, `HOME`, `AIOS_CLAUDE_DIR` (Spec 04, *Umlenkung für Tests*).
- **Tests im Sandkasten:** `tests/run` vor jedem Commit; Tests verändern nie den echten Rechner.
- **Ein Schritt, ein Commit:** jeder Schritt des Plans endet mit grünen Tests und einem Commit `Schritt N: …`, danach Push. Im selben Commit wird der Schritt in `STATUS.md` abgehakt (☐ → ☑, Ergebnis nachgetragen).
- **Das Arbeitsverzeichnis nicht wechseln:** `git -C <repo>` und absolute Pfade verwenden, damit der Masterspace der Session gültig bleibt.
- **Der Arbeitsrechner wird erst im Abnahmeschritt umgestellt** (v0.3: Schritt 10, Memo 32).
- **Fragepakete nach der Regel *Weiter*** (`AA-AIbex-AIOS/@/@Rule/Weiter.md`): vor jedem Schritt des Plans ein kurzes Fragepaket (Memo 33).

## Bash-Konvention

@dev/Bash-Skript-Struktur.md
