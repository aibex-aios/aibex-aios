# AIbex AIOS — Arbeiten am Repo

Regeln für Sessions, die an AIbex AIOS arbeiten, ob sie im Repo laufen oder im Konzeptprojekt (dort mit absoluten Pfaden auf dieses Repo).

## Wo was liegt

| Was | Ort |
|---|---|
| Spec (Soll-Stand, verbindlich) | `spec/` |
| Memos (Begründungen, Verlauf) | Projekt `AA-AIbex-AIOS`, Versionsordner, siehe unten |
| Implementierungsplan | v0.5: Memo 44 in V0.5, freigegeben in Memo 45; spätere Memos gehen ihm vor (v0.4: Memo 18 in V0.4, v0.3: Memo 32 in V0.3, v0.2: Memo 20 in V0.2, v0.1: Memo 18 in V0.1) |
| Stand der Umsetzung | `STATUS.md` |
| Code | `bin/` (Bash: `aios`, `aios-context`), `lib/aios/` (Python) |
| Skills | `skills/aios/<name>/SKILL.md` (AIOS-Skills); Pakete (Skills, Assistenten, Wissen, Arbeitspferde, Distributionen) in eigenen Paket-Repos unter `~/git/AIbex/<paket>/` |
| Paket-Manifest des Kernels | `manifest.yaml` (`name: aios`, `type: kernel`), Version wie `VERSION` |
| Tests | `tests/run` |
| Entwickler-Doku | `dev/` (wird nicht installiert) |

Das Repo enthält keinen Vault. Vaults legt der User an und bindet sie mit `aios --activate` an eine installierte Version; Tests legen ihre Vaults im Sandkasten an.

Memos und ToDos im Projekt `~/vault/§AIOS/A-AIOS/AA-AIbex-AIOS/` (Regeln `@/@Rule/Weiter.md` und `@/@Rule/01 Implementierung im Repo aibex-aios (Rule).md`), je Version ein Unterordner. Bis 2026-10-19 waren das eigene Unterprojekte `AAA-AIbex-AIOS-V0.<n>`; die Zuordnung alt → neu steht in `@Memo/03` von `AA-AIbex-AIOS`. Das Projekt ist das Konzept-Repo `AA-AIbex-AIOS` (`aibex-aios/AA-AIbex-AIOS`):

| Ordner | Inhalt |
|---|---|
| `@Memo/V0.5/` | **laufende Version v0.5**: Memos 01–12 (Wünsche, Übergabe), 13–40 (Konzept: Arbeitspferde, Distributionen, kleine Themen, Proben, Soll-Bild 36, Skizze 37), 41–43 (Spec, Freigabe), 44–45 (Implementierungsplan), danach die Umsetzung |
| `@Memo/V0.4/`, `@ToDo/V0.4/` | v0.4 (abgeschlossen, Tag `v0.4.0`, Abnahme Memo 75) |
| `@Memo/V0.3/` | v0.3 (abgeschlossen, Tag `v0.3.1`); in Memos 01–11 heißt der Assistent noch *Agent* (Memo 13) |
| `@Memo/V0.2/` | v0.2 (abgeschlossen, Tag `v0.2.0`) |
| `@Memo/V0.1/`, `@Spec/V0.1/` | Grundlage aus v0.1 (abgeschlossen, Tag `v0.1.0`) |
| `@Memo/V0.6/`, `@Memo/V0.7/`, `@Memo/V0.99/` | Ideen für spätere Versionen (Workflows, Wissen) bzw. ohne Version, nicht Teil der laufenden Arbeit |

## Stand ermitteln

1. Memo 44 in V0.5 lesen (Implementierungsplan v0.5, Schritte 0–16), dann alle Memos von V0.5 mit höherer Nummer. Für den Hintergrund Memo 36 (Soll-Bild) und Memo 37 (Skizze mit Abnahmetest).
2. `STATUS.md` lesen: Der nächste Schritt ist der erste mit ☐. Zur Kontrolle `git log --oneline`: Jeder abgeschlossene Schritt hat einen Commit `Schritt N: …`.
3. `tests/run` als Ausgangsprüfung, alle Tests müssen grün sein.
4. Dem User den ermittelten Schritt nennen und dann beginnen.

## Memos schreiben

Vorher den Skill `memo` vollständig lesen und befolgen (Nummerierung, Header-Block, bestehende Memos werden nie geändert):

```
~/vault/§AIOS/@/@!Skill/memo/SKILL.md
```

Das Memo wird im Versionsordner der laufenden Version angelegt (`AA-AIbex-AIOS/@Memo/V0.5/`, nächste Nummer dieses Ordners; der Skill kennt keine Unterordner, deshalb den Ordner ausdrücklich nennen) und im Konzept-Repo `AA-AIbex-AIOS` committet, die Spec-Änderung in diesem Repo.

## Regeln

- **Die Spec ist verbindlich.** Weicht die Umsetzung von der Spec ab, wird zuerst die Spec korrigiert und die Entscheidung als Memo festgehalten.
- **Bash für Weiterleiter und Bootstrap, Python für die Logik** (V0.1, Memo 18, E1). Bash-Skripte folgen der Bash-Konvention (unten).
- **Keine fest verdrahteten Pfade:** immer `AIOS_PREFIX`, `HOME`, `AIOS_CLAUDE_DIR` (Spec 04, *Umlenkung für Tests*).
- **Tests im Sandkasten:** `tests/run` vor jedem Commit; Tests verändern nie den echten Rechner.
- **Ein Schritt, ein Commit:** jeder Schritt des Plans endet mit grünen Tests und einem Commit `Schritt N: …`, danach Push. Im selben Commit wird der Schritt in `STATUS.md` abgehakt (☐ → ☑, Ergebnis nachgetragen).
- **Das Arbeitsverzeichnis nicht wechseln:** `git -C <repo>` und absolute Pfade verwenden, damit der Masterspace der Session gültig bleibt.
- **Der Arbeitsrechner wird erst im Abnahmeschritt umgestellt** (v0.5: Schritt 16, Memo 44); bis dahin bleiben er und `§AIOS` auf v0.4.0. Entwicklungsstände nur im Sandkasten und über `AIOS_HOME`.
- **Paket-Repos und Hubs:** Paket-Repos (auch die Begleitpakete von v0.5) entstehen lokal unter `~/git/AIbex/<paket>/` und werden lokal getaggt; in die Hubs gepusht wird erst in der Abnahme (Schritt 16; V0.5, Memos 30, 45). Tests holen Pakete nur aus Test-Hubs unter `file://` (`AIOS_HUBS`, `tests/hub/`) und Wheels nur aus `AIOS_PIP_FIND_LINKS`; kein Test erreicht das Netz außer `tests/live/`.
- **Begleitpakete:** Für sie gilt die Vorabregel `aios-v05-vorabversion` in `M-Module/@/@Rule/` (V0.5, Memo 39): Maßstab ist die freigegebene Spec v0.5 dieses Repos.
- **Push:** nach jedem Schritt nur mit Rückfrage (V0.5, Memo 45, Q5).
- **Fragepakete nach der Regel *Weiter*** (`AA-AIbex-AIOS/@/@Rule/Weiter.md`): vor jedem Schritt des Plans ein kurzes Fragepaket.

## Bash-Konvention

@dev/Bash-Skript-Struktur.md
