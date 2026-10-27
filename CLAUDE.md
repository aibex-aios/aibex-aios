# AIbex AIOS — Arbeiten am Repo

Regeln für Sessions, die an AIbex AIOS arbeiten, ob sie im Repo laufen oder im Konzeptprojekt (dort mit absoluten Pfaden auf dieses Repo).

## Wo was liegt

| Was | Ort |
|---|---|
| Spec (Soll-Stand, verbindlich) | `spec/` |
| Memos (Begründungen, Verlauf) | Projekt `AA-AIbex-AIOS`, Versionsordner, siehe unten |
| Implementierungsplan | v0.5.1: Memo 74 in V0.5, freigegeben in Memo 75; v0.5: Memo 44 in V0.5, freigegeben in Memo 45; spätere Memos gehen ihm vor (v0.4: Memo 18 in V0.4, v0.3: Memo 32 in V0.3, v0.2: Memo 20 in V0.2, v0.1: Memo 18 in V0.1) |
| Stand der Umsetzung | `STATUS.md` |
| Code | `bin/` (Bash: `aios`; `aios --context` für Hooks und lesende Skills), `templates/forwarder` (Weiterleiter `~/bin/aios`), `lib/aios/` (Python) |
| Skills | `skills/aios/<name>/SKILL.md` (AIOS-Skills); Pakete (Skills, Assistenten, Wissen, Arbeitspferde, Distributionen) in eigenen Paket-Repos unter `~/git/AIbex/<paket>/` |
| Paket-Manifest des Kernels | `manifest.yaml` (`name: aios`, `type: kernel`), Version wie `VERSION` |
| Tests | `tests/run` |
| Entwickler-Doku | `dev/` (wird nicht installiert) |

Das Repo enthält keinen Vault. Vaults legt der User an und bindet sie mit `aios --activate` an eine installierte Version; Tests legen ihre Vaults im Sandkasten an.

Memos und ToDos im Projekt `~/vault/§AIOS/A-AIOS/AA-AIbex-AIOS/` (Regeln `@/@Rule/Weiter.md` und `@/@Rule/01 Implementierung im Repo aibex-aios (Rule).md`), je Version ein Unterordner. Bis 2026-10-19 waren das eigene Unterprojekte `AAA-AIbex-AIOS-V0.<n>`; die Zuordnung alt → neu steht in `@Memo/03` von `AA-AIbex-AIOS`. Das Projekt ist das Konzept-Repo `AA-AIbex-AIOS` (`aibex-aios/AA-AIbex-AIOS`):

| Ordner | Inhalt |
|---|---|
| `@Memo/V0.5/` | **laufende Version v0.5.1**: Memos 70–72 (Neuinstallation, Befunde B6–B8, Umfang), 73–75 (Entscheidungen, Plan, Freigabe), danach die Umsetzung; v0.5.0 (abgeschlossen, Tag `v0.5.0`, Abnahme Memo 68): Memos 01–12 (Wünsche), 13–40 (Konzept), 41–43 (Spec), 44–45 (Plan), 46–67 (Umsetzung und Abnahme) |
| `@Memo/V0.4/`, `@ToDo/V0.4/` | v0.4 (abgeschlossen, Tag `v0.4.0`, Abnahme Memo 75) |
| `@Memo/V0.3/` | v0.3 (abgeschlossen, Tag `v0.3.1`); in Memos 01–11 heißt der Assistent noch *Agent* (Memo 13) |
| `@Memo/V0.2/` | v0.2 (abgeschlossen, Tag `v0.2.0`) |
| `@Memo/V0.1/`, `@Spec/V0.1/` | Grundlage aus v0.1 (abgeschlossen, Tag `v0.1.0`) |
| `@Memo/V0.7/`, `@Memo/V0.8/`, `@Memo/V0.99/` | Ideen für spätere Versionen (Workflows v0.7, Wissen v0.8) bzw. ohne Version, nicht Teil der laufenden Arbeit; bis 2026-10-27 lagen sie in `V0.6/` und `V0.7/` (`@Memo/07`) |

## Stand ermitteln

1. Memo 74 in V0.5 lesen (Implementierungsplan v0.5.1, Schritte 0–4), dann alle Memos von V0.5 mit höherer Nummer. Für den Hintergrund Memo 71 (Befunde B6–B8) und Memo 68 (Abnahme v0.5.0).
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
- **Ein Schritt, ein Commit:** jeder Schritt des Plans endet mit grünen Tests und einem Commit `Schritt N: …` (v0.5.1: `v0.5.1 Schritt N: …`), danach Push. Im selben Commit wird der Schritt in `STATUS.md` abgehakt (☐ → ☑, Ergebnis nachgetragen).
- **Das Arbeitsverzeichnis nicht wechseln:** `git -C <repo>` und absolute Pfade verwenden, damit der Masterspace der Session gültig bleibt.
- **Der Arbeitsrechner wird erst im Abnahmeschritt umgestellt** (v0.5.1: Schritt 4, Memo 74); bis dahin bleiben er und die Vaults auf v0.5.0. Entwicklungsstände nur im Sandkasten und über `AIOS_HOME`.
- **Paket-Repos und Hubs:** Paket-Repos entstehen lokal unter `~/git/AIbex/<paket>/` und werden lokal getaggt; in die Hubs gepusht wird erst in der Abnahme (V0.5, Memos 30, 45). v0.5.1 bringt keine neuen Paketversionen, außer ein Befund verlangt es (Memo 75, U3). Tests holen Pakete nur aus Test-Hubs unter `file://` (`AIOS_HUBS`, `tests/hub/`) und Wheels nur aus `AIOS_PIP_FIND_LINKS`; kein Test erreicht das Netz außer `tests/live/`.
- **Push:** nach jedem Schritt nur mit Rückfrage (V0.5, Memo 45, Q5). Ein gepushter Tag wird nie bewegt; v0.5.1 entsteht über `v0.5.0` (Memo 75, U2).
- **Fragepakete nach der Regel *Weiter*** (`AA-AIbex-AIOS/@/@Rule/Weiter.md`): vor jedem Schritt des Plans ein kurzes Fragepaket; in v0.5.1 nur, wenn eine Entscheidung offen ist (Memo 74).
- **Kleinste Umgebung:** Eine Abnahme, die installiert oder Arbeitspferde einrichtet, enthält einen Lauf im Sandkasten mit frischem `HOME` und `AIOS_PREFIX`, einem `python3` an der Untergrenze der Grundausstattung und ohne PyYAML, gegen den echten Hub und PyPI (V0.5, Memos 90, 96–97: V1).
- **Tag nach der Abnahme:** Den lokalen Versions-Tag erst nach bestandener Abnahme setzen; bis dahin trägt `VERSION` die Version ohne Tag (V0.5, Memos 96–97: V3).
- **Spec zitieren:** Beruft sich eine Entscheidung oder ein Memo auf die Spec, mit Dokument, Abschnitt und Wortlaut; vorher nachlesen (V0.5, Memos 96–97: V4).

## Bash-Konvention

@dev/Bash-Skript-Struktur.md
