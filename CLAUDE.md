# AIbex AIOS — Arbeiten am Repo

Regeln für Sessions, die an AIbex AIOS arbeiten, ob sie im Repo laufen oder im Konzeptprojekt (dort mit absoluten Pfaden auf dieses Repo).

## Wo was liegt

| Was | Ort |
|---|---|
| Spec (Soll-Stand, verbindlich) | `spec/` |
| Memos (Begründungen, Verlauf) | Projekt `AA-AIbex-AIOS`, Versionsordner, siehe unten |
| Implementierungsplan | v0.6.3: verkürzte Form ohne eigenen Plan, Schritte 0–3 in Memo 156 in V0.6 (Skizze Memo 153; Spec freigegeben in Memo 156); v0.6.2: Memo 126 in V0.6, freigegeben in Memo 127 (Spec freigegeben in Memo 125); v0.6.1: Memo 87 in V0.6, freigegeben in Memo 88 (Spec freigegeben in Memo 86); v0.6: Memo 40 in V0.6, freigegeben in Memo 41 (Spec freigegeben in Memo 39); v0.5.1: Memo 74 in V0.5, freigegeben in Memo 75; v0.5: Memo 44 in V0.5, freigegeben in Memo 45; spätere Memos gehen ihm vor (v0.4: Memo 18 in V0.4, v0.3: Memo 32 in V0.3, v0.2: Memo 20 in V0.2, v0.1: Memo 18 in V0.1) |
| Stand der Umsetzung | `STATUS.md`: alle Schritte des freigegebenen Implementierungsplans mit ☐/☑; liegt in jedem Paket-Repo mit Implementierungsplan, auch hier (V0.6, Memos 123, 126: F102) |
| Code | `bin/` (Bash: `aios`; `aios --context` für Hooks und lesende Skills), `templates/forwarder` (Weiterleiter `~/.aios/bin/aios`), `lib/aios/` (Python) |
| Skills | `skills/aios/<name>/SKILL.md` (AIOS-Skills); Pakete (Skills, Assistenten, Wissen, Arbeitspferde, Distributionen) in eigenen Paket-Repos unter `~/git/AIbex/<paket>/` oder im Konzeptprojekt unter `@Package/<paket>/` |
| Ort dieses Repos | `~/Workspace/§AIBOS/A-AIOS/AA-AIbex-AIOS/@Package/aibex-aios/` im Konzeptprojekt; am alten Ort `~/git/AIbex/aibex-aios` steht ein Link (Konzept-Repo V0.6, Memo 178) |
| Paket-Manifest des Kernels | `manifest.yaml` (`name: aios`, `type: kernel`), Version wie `VERSION` |
| Tests | `tests/run` |
| Entwickler-Doku | `dev/` (wird nicht installiert) |

Das Repo enthält keinen Vault. Vaults legt der User an und bindet sie mit `aios --activate` an eine installierte Version; Tests legen ihre Vaults im Sandkasten an.

Memos und ToDos im Projekt `~/Workspace/§AIBOS/A-AIOS/AA-AIbex-AIOS/` (Regeln `@/@Rule/Weiter.md` und `@/@Rule/01 Implementierung im Repo aibex-aios (Rule).md`), je Version ein Unterordner. Bis 2026-10-19 waren das eigene Unterprojekte `AAA-AIbex-AIOS-V0.<n>`; die Zuordnung alt → neu steht in `@Memo/03` von `AA-AIbex-AIOS`. Das Projekt ist das Konzept-Repo `AA-AIbex-AIOS` (`aibex-aios/AIBOS-AA-AIbex-AIOS`):

| Ordner | Inhalt |
|---|---|
| `@Memo/V0.6/` | v0.6.3 (in Arbeit, verkürzte Form): Memos 152 (Einstieg), 153 (Bewertung und Skizze mit Abnahmetest), 154 (Zustimmung, F149–F152), 155, 156 (Spec und Freigabe, F153). v0.6.2 (abgeschlossen, Tag `v0.6.2`, Abnahme Memo 145, Veröffentlichung Memos 148, 149, Rückblick Memos 150, 151): Memos 114–117 (Wünsche H5–H11), 118 (Bewertung), 119–121 (Konsolidierung FG11–FG13), 122 (Soll-Bild und Skizze mit Abnahmetest), 123 (Zustimmung, `STATUS.md` im Paket-Repo), 124, 125 (Spec und Freigabe), 126, 127 (Implementierungsplan und Freigabe). v0.6.1 (abgeschlossen, Tag `v0.6.1`, Abnahme Memo 107, Veröffentlichung Memo 112, Rückblick Memos 113, 114; Wünsche für v0.6.2 in Memo 114): Memos 79 (Bewertung), 80–83 (Konsolidierung), 84 (Skizze mit Abnahmetest), 85, 86 (Spec und Freigabe), 87, 88 (Implementierungsplan und Freigabe); der Installer kommt danach in einem eigenen Durchlauf mit eigenem Repo (Memos 01, 04–08, 13, 80). v0.6.0 (abgeschlossen, Tag `v0.6.0`, Abnahme Memo 74, Rückblick Memos 76, 77): Memos 01–17 (Konzept), 18 (Bewertung), 19–33 (Konsolidierung mit Proben P1–P5), 34 (Soll-Bild), 35 (Skizze mit Abnahmetest), 36–38 (Spezifikation, Festlegungen F26–F41), 39 (Freigabe der Spec), 40, 41 (Implementierungsplan und Freigabe) |
| `@Memo/V0.5/` | v0.5.1 (abgeschlossen, Tag `v0.5.1`, Abnahme Memo 94, Veröffentlichung Memo 95, Rückblick Memos 96, 97): Memos 70–72 (Neuinstallation, Befunde B6–B8, Umfang), 73–75 (Entscheidungen, Plan, Freigabe), 76–93 (Umsetzung, Abnahme mit B9–B11); v0.5.0 (abgeschlossen, Tag `v0.5.0`, Abnahme Memo 68): Memos 01–12 (Wünsche), 13–40 (Konzept), 41–43 (Spec), 44–45 (Plan), 46–67 (Umsetzung und Abnahme) |
| `@Memo/V0.4/`, `@ToDo/V0.4/` | v0.4 (abgeschlossen, Tag `v0.4.0`, Abnahme Memo 75) |
| `@Memo/V0.3/` | v0.3 (abgeschlossen, Tag `v0.3.1`); in Memos 01–11 heißt der Assistent noch *Agent* (Memo 13) |
| `@Memo/V0.2/` | v0.2 (abgeschlossen, Tag `v0.2.0`) |
| `@Memo/V0.1/`, `@Spec/V0.1/` | Grundlage aus v0.1 (abgeschlossen, Tag `v0.1.0`) |
| `@Memo/V0.7/`, `@Memo/V0.8/`, `@Memo/V0.99/` | Ideen für spätere Versionen (Workflows v0.7, Wissen v0.8) bzw. ohne Version, nicht Teil der laufenden Arbeit; bis 2026-10-27 lagen sie in `V0.6/` und `V0.7/` (`@Memo/07`) |

## Stand ermitteln

1. Die Memos der laufenden Version lesen (`@Memo/V0.6/`, die neuesten zuerst) und daraus die Phase des Workflows bestimmen (Konzept, Bewertung, Konsolidierung, Spec, Freigabe, Implementierung, Abnahme). Für den Hintergrund die Abnahme und den Rückblick der Vorversion (V0.5, Memos 94, 96).
2. Gibt es einen freigegebenen Implementierungsplan: ihn lesen, dann `STATUS.md`; der nächste Schritt ist der erste mit ☐. Zur Kontrolle `git log --oneline`: Jeder abgeschlossene Schritt hat einen Commit `Schritt N: …`. Ohne Plan wird am Code noch nicht gearbeitet.
3. Vor Arbeit am Code `tests/run` als Ausgangsprüfung, alle Tests müssen grün sein.
4. Dem User die Phase und den nächsten Schritt nennen und dann beginnen.

## Memos schreiben

Vorher den Skill `memo` vollständig lesen und befolgen (Nummerierung, Header-Block, bestehende Memos werden nie geändert):

```
~/Workspace/§AIBOS/@/@!Package/skill-memo/skills/memo/SKILL.md
```

Das Memo wird im Versionsordner der laufenden Version angelegt (`AA-AIbex-AIOS/@Memo/V0.6/`, nächste Nummer dieses Ordners; der Skill kennt keine Unterordner, deshalb den Ordner ausdrücklich nennen) und im Konzept-Repo `AA-AIbex-AIOS` committet, die Spec-Änderung in diesem Repo.

## Regeln

- **Die Spec ist verbindlich.** Weicht die Umsetzung von der Spec ab, wird zuerst die Spec korrigiert und die Entscheidung als Memo festgehalten.
- **Bash für Weiterleiter und Bootstrap, Python für die Logik** (V0.1, Memo 18, E1). Bash-Skripte folgen der Bash-Konvention (unten).
- **Keine fest verdrahteten Pfade:** immer `AIOS_PREFIX`, `HOME`, `AIOS_CLAUDE_DIR` (Spec 04, *Umlenkung für Tests*).
- **Tests im Sandkasten:** `tests/run` vor jedem Commit; Tests verändern nie den echten Rechner. Einzelne Testdateien nur mit `tests/run <präfix>` (z. B. `tests/run t22`), nie direkt mit `bash tests/tNN-….sh`: ohne Sandkasten liefen sie gegen das echte `HOME` (V0.6, Memo 66); jede Datei bricht dann ab.
- **Ein Schritt, ein Commit:** jeder Schritt des Plans endet mit grünen Tests und einem Commit `Schritt N: …` (bei einem Patch `v<x.y.z> Schritt N: …`), danach Push. Im selben Commit wird der Schritt in `STATUS.md` abgehakt (☐ → ☑, Ergebnis nachgetragen).
- **Das Arbeitsverzeichnis nicht wechseln:** `git -C <repo>` und absolute Pfade verwenden, damit der Masterspace der Session gültig bleibt.
- **Der Arbeitsrechner wird erst im Abnahmeschritt umgestellt**; bis dahin bleiben er und die Vaults auf der letzten veröffentlichten Version (derzeit v0.6.2). Entwicklungsstände nur im Sandkasten und über `AIOS_HOME`.
- **Paket-Repos und Hubs:** Paket-Repos entstehen lokal unter `~/git/AIbex/<paket>/` und werden lokal getaggt; in die Hubs gepusht wird erst in der Abnahme (V0.5, Memos 30, 45). Tests holen Pakete nur aus Test-Hubs unter `file://` (`AIOS_HUBS`, `tests/hub/`) und Wheels nur aus `AIOS_PIP_FIND_LINKS`; kein Test erreicht das Netz außer `tests/live/`.
- **Zweige:** v0.6.3 entsteht auf `main`; Spec 08 und Änderungen an 01–07 für Wissen (v0.8) nur auf dem Zweig `v0.8`, den die Arbeit an Wissen auf `main` nachzieht (V0.6, Memos 119, 121: F88).
- **Push:** nach jedem Schritt nur mit Rückfrage (V0.5, Memo 45, Q5), vorher die Commits zeigen, die hinausgehen (`git log origin/main..main`), und fremde nennen (V0.6, Memo 114, R9). Ein gepushter Tag wird nie bewegt; eine neue Version entsteht auf `main` über dem letzten Tag (V0.5, Memo 75, U2).
- **Fragepakete nach der Regel *Weiter*** (`AA-AIbex-AIOS/@/@Rule/Weiter.md`): vor jedem Schritt des Plans ein kurzes Fragepaket, bei einem Patch nur, wenn eine Entscheidung offen ist (V0.5, Memo 74).
- **Kleinste Umgebung:** Eine Abnahme, die installiert oder Arbeitspferde einrichtet, enthält einen Lauf im Sandkasten mit frischem `HOME` und `AIOS_PREFIX`, einem `python3` an der Untergrenze der Grundausstattung und ohne PyYAML, gegen den echten Hub und PyPI (V0.5, Memos 90, 96–97: V1).
- **Tag nach der Abnahme:** Den lokalen Versions-Tag erst nach bestandener Abnahme setzen; bis dahin trägt `VERSION` die Version ohne Tag (V0.5, Memos 96–97: V3).
- **Spec zitieren:** Beruft sich eine Entscheidung oder ein Memo auf die Spec, mit Dokument, Abschnitt und Wortlaut; vorher nachlesen (V0.5, Memos 96–97: V4).

## Bash-Konvention

@dev/Bash-Skript-Struktur.md
