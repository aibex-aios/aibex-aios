---
title: "Arbeitspferde"
date: 2026-10-25
author: iHux
status: Spec
tags: [spec, aios, v0.5, arbeitspferde]
number: 07
related:
  - "Spec 01 AIbex AIOS v0.5 — Überblick"
  - "Spec 03 Skills und Assistenten"
  - "Spec 04 Installation und Konfiguration"
  - "Spec 06 Pakete und Workspaces"
  - "Memos 11–37 (AA-AIbex-AIOS, @Memo/V0.5)"
---

# Arbeitspferde

Diese Spec regelt Arbeitspferde: was ein Arbeitspferd ist, Pakete vom Typ `worker`, ihre Installation auf dem Rechner, die Aktivierung über `lock.yaml`, die Weiterleiter unter `~/.aios/bin/`, die Abläufe beim Laden, Aktualisieren, Abgleichen und Entfernen, den Befehl `aios --worker` und die Tests. Pakete allgemein, `manifest.yaml`, Resolver und `aios --fetch` stehen in Spec 06, Dateien, Formate und CLI in Spec 04, das Ausführungsmodell der Skills in Spec 03. Das Soll-Bild steht in V0.5, Memo 36.

## Definition

Ein **Arbeitspferd** ist ein Programm, das auf dem Rechner des Users eingerichtet wird, damit Elemente eines Pakets etwas können, was das Modell allein nicht kann, z. B. `yt-dlp` oder `deno` (V0.5, Memos 14, 16).

Ein Programm ist genau dann ein Arbeitspferd, wenn es alle drei Kernkriterien erfüllt:

| # | Kriterium | Bedeutung |
|---|---|---|
| K1 | **ausgeführt, nicht gelesen** | ein Programm, das der Rechner ausführt; Skills, Assistenten und Wissen sind Anleitungen, die das Modell liest |
| K2 | **wohnt auf dem Rechner, nicht im Projekt** | es liegt außerhalb jedes Repos und lässt sich nicht über Git verteilen (plattformgebunden, absolute Pfade) |
| K3 | **wird vor Ort gebaut** | `aios --fetch` kann es nicht spiegeln; AIOS richtet es ein (setup) und baut es ab (remove) |

Typische Merkmale, die nicht entscheiden, ob etwas ein Arbeitspferd ist:

| # | Merkmal | Bedeutung |
|---|---|---|
| K4 | eigene Version | die Version des Programms ist unabhängig vom Paket (`yt-dlp` 2026.10.21 im Paket 0.1.0) |
| K5 | meist Fremdsoftware | aus fremden Quellen wie PyPI; daher Bestätigung mit Inhalt (Spec 06, P3) |
| K6 | für Elemente gebaut | Skills rufen es über den Weiterleiter auf; es hat keine Oberfläche im Chat; der User darf es auch direkt aufrufen |
| K7 | Programm und Daten getrennt | das Programm liegt auf dem Rechner, Daten unter `@Data/` des Pakets, das sie erzeugt (Spec 06, *Daten*) |

**Spielarten:** Ein **Werkzeug** läuft nur während eines Aufrufs (`yt-dlp`, `deno`). Ein **Dienst** läuft dauerhaft (Datenbank, Server); Dienste sind in v0.5 nicht umgesetzt (*Grenzen*).

**Abgrenzung:** Ein Befehl (`commands/`, Spec 06) liegt im Paket und braucht kein setup (verletzt K2, K3). Eine Voraussetzung von AIOS (`python3`, `git`, Spec 04) gehört dem Kernel. Ein Skript eines Skills liegt im Paket und läuft sofort (Spec 03, *Ausführungsmodell*).

## Paket `worker-<name>`

Ein Arbeitspferd ist ein Paket vom Typ `worker` mit dem Namen `worker-<name>` (V0.5, Memos 15, 17). Andere Pakete nutzen es über `depends`. Pakete anderer Typen bringen keine Arbeitspferde mit; das Feld `workers:` aus v0.4 gibt es nicht mehr (Spec 06, *Umstellung von v0.4*).

```yaml
name: worker-yt-dlp
version: 0.1.0
type: worker
description: yt-dlp zum Laden von Videos und Untertiteln
requires:
  aios: ">=0.5,<0.6"
depends:
  worker-deno: "~=0.1.0"
worker:
  kind: python
  requirements: worker/requirements.lock
  programs: [yt-dlp]
  check: yt-dlp --version
```

| Feld unter `worker:` | Pflicht | Regel |
|---|---|---|
| `kind` | ja | `python` oder `script` |
| `programs` | ja | Namen der Programme, die das Arbeitspferd in `bin/` bereitstellt; für jedes entsteht ein Weiterleiter |
| `check` | nein | Befehl, der nach setup und bei `aios --worker` läuft; Exit 0 heißt in Ordnung |
| `requirements` | bei `python` | Pfad einer Datei im Paket mit allen Python-Paketen, Versionen und Hashes |
| `setup`, `remove` | bei `script` | Pfade der Skripte im Paket |

Ein Paket vom Typ `worker` ist ein **Modul ohne Elemente**: Nach dem Holen kann AIOS etwas Neues, aber `aios --deploy`, `only` und das Registrieren wirken nicht (V0.5, Memo 30, L8). Die Programmversion steht im Paket fest; ein neues Programm ist eine neue Version des Pakets (V0.5, Memo 17).

### `kind: python`

`requirements` nennt eine Datei, in der jede Zeile die Form `<paket>==<version> --hash=sha256:<hash>` hat, auch für alle Abhängigkeiten (V0.5, Memos 21, 22). Eine Datei ohne Hashes oder mit einer Angabe ohne `==` besteht die Prüfung beim Holen nicht (Spec 06). Die Datei erzeugt der Maintainer auf seinem Rechner, z. B. mit `pip-compile --generate-hashes --strip-extras`; das Werkzeug ist nicht Teil von AIOS (V0.5, Memo 30, F15). Sie enthält die Hashes aller Wheels einer Version und deckt damit alle Plattformen ab (V0.5, Memo 33).

### `kind: script`

`setup` und `remove` sind Bash-Skripte im Paket. Sie laufen mit `bash`, Arbeitsverzeichnis ist der Paketordner, Umgebung `AIOS_WORKER_DIR` (Installationsordner der Version) und `AIOS_PACKAGE` (Paketordner). `setup` legt die Programme aus `programs` in `$AIOS_WORKER_DIR/bin/` ab. `kind: script` ist der Ausweg für Sonderfälle; der Plan zeigt den vollen Inhalt der Skripte (V0.5, Memo 21).

## Installation

Jede Version eines Arbeitspferds wird **einmal je Rechner** installiert. Versionen liegen nebeneinander, wie die Installationen des Kernels (V0.5, Memo 20):

| Ort | Inhalt |
|---|---|
| `/opt/aios/workers/<paket>/v<version>/` | Installation einer Version; nach setup schreibgeschützt |
| `/opt/aios/workers.yaml` | Verzeichnis der Installationen (Format Spec 04) |
| `~/.aios/workers/<paket>/v<version>/`, `~/.aios/workers.yaml` | Ersatzorte, wenn `/opt/aios` nicht eingerichtet werden kann (wie `~/.aios/versions/`, Spec 04). Legt der Plan einer Distribution `/opt/aios` erst an, gilt schon im Plan `/opt/aios` (V0.5, Memo 71, B7) |
| `~/.aios/bin/<programm>` | Weiterleiter |

Der Ordner heißt nach dem Paket, nicht nach dem Programm (V0.5, Memo 18, F1).

### setup

setup einer Version läuft immer in einem Plan mit Bestätigung (*Abläufe*). Es baut in einem temporären Ordner `v<version>.new/` und benennt ihn erst nach Erfolg um.

| # | `kind: python` | `kind: script` |
|---|---|---|
| 1 | Grundausstattung prüfen (Spec 04, `aios --prepare`); fehlt sie, kein setup (V0.5, Memo 31, F29) | ebenso |
| 2 | `python3 -m venv v<version>.new` | `bash <setup>` mit `AIOS_WORKER_DIR=…/v<version>.new` |
| 3 | `pip install --require-hashes --no-deps -r <requirements>`; ist `AIOS_PIP_FIND_LINKS` gesetzt, zusätzlich `--no-index --find-links <ordner>` (Spec 04) | — |
| 4 | jedes Programm aus `programs` liegt ausführbar in `bin/` | ebenso |
| 5 | `python -m compileall -q lib/` (V0.5, Memo 33, P1) | — |
| 6 | `check`, mit `~/.aios/bin` vorn im `PATH` | ebenso |
| 7 | Ordner umbenennen nach `v<version>/`, Schreibschutz (`chmod -R a-w`) | ebenso |
| 8 | Eintrag in `workers.yaml`, Weiterleiter für jedes Programm anlegen, falls er fehlt | ebenso |

Scheitert ein Schritt, entfernt AIOS `v<version>.new/` (bei `kind: script` nach Aufruf von `remove`), meldet Schritt und Ausgabe, und das Arbeitspferd gilt als nicht installiert. Arbeitspferde, von denen ein Arbeitspferd abhängt (`depends`), werden zuerst eingerichtet.

Das venv wird mit dem `python3` gebaut, mit dem das venv der aktiven Kernel-Installation gebaut ist (Spec 04, `aios --install`); so bestimmt nicht der `PATH` des Aufrufers die Python-Version (V0.5, Memo 21, F11).

### remove

`remove` einer Version hebt den Schreibschutz auf, ruft bei `kind: script` das Skript `remove` und löscht `v<version>/`. Danach wird der Eintrag aus `workers.yaml` entfernt; ist es die letzte Version des Pakets, auch die Weiterleiter seiner Programme. Eine Version wird nur entfernt, wenn kein Projekt sie mehr nutzt (*Abläufe*).

## Aktivierung und Weiterleiter

**Aktiviert** ist die Version eines Arbeitspferds, die in `lock.yaml` eines Projekts steht. Es gibt keine eigene Aktivierung (V0.5, Memo 20).

Ein Skill ruft ein Programm über seinen Weiterleiter auf, z. B. `~/.aios/bin/yt-dlp`, nicht über den `PATH` des Users (Spec 03, *Ausführungsmodell*). Der Weiterleiter ist ein Bash-Skript (V0.1, Memo 18, E1):

1. Pakete, die das Programm bereitstellen, aus `workers.yaml` lesen (Abschnitt `programs`).
2. Ab dem Ordner des Aufrufs (`cwd`) aufwärts das nächste Projekt suchen, dessen `.aios/lock.yaml` eines dieser Pakete nennt.
3. Version daraus lesen; liegt `<workers>/<paket>/v<version>/bin/<programm>` ausführbar vor, es mit allen Argumenten aufrufen, mit `~/.aios/bin` vorn im `PATH` (so finden Arbeitspferde einander, V0.5, Memo 31, F28).
4. Sonst mit Exit 127 enden:

| Fall | Meldung (stderr) |
|---|---|
| kein Projekt der Kette nennt ein passendes Paket | `*** <programm>: no project of the chain from <cwd> has <paket> in lock.yaml` |
| Version nicht installiert | `*** <programm>: <paket> <version> is not fully loaded; aios --fetch` |

Der Weiterleiter löst **nie** ein setup aus (Spec 01, I10). Er liest `lock.yaml` und `workers.yaml` ohne PyYAML; dafür schreibt AIOS beide in der Untermenge aus Spec 04 (V0.5, Memo 37, K-a).

Nennen zwei Pakete in derselben Kette dasselbe Programm, meldet der Plan beim Laden einen Konflikt und lädt nicht (V0.5, Memo 20, F9).

## Abläufe

| Vorgang | Wirkung |
|---|---|
| **Laden** (`aios --fetch <paket>`, Spec 06) | ein Plan: Pakete holen, setup jedes Arbeitspferds, dessen Version auf dem Rechner fehlt, Projekte in `workers.yaml` eintragen, Skills registrieren; ein Ja; alles oder nichts (Spec 01, I11) |
| **Plan bei `python`** | Ziel, Python-Version, Anzahl der Pakete, je Zeile `paket==version` ohne Hashes, `check` (V0.5, Memo 29) |
| **Aktualisieren** (`--upgrade`) | ändert sich die Version eines `worker`-Pakets, läuft setup der neuen Version im selben Plan; die alte wird entfernt, wenn kein Projekt sie mehr nutzt |
| **Abgleich** (`aios --fetch` ohne Argument) | nimmt Arbeitspferde aus `lock.yaml`, die auf dem Rechner fehlen, in den Plan (zweiter Rechner, V0.5, Memo 29) |
| **Entfernen** (`--fetch --remove`) | entfernt das Projekt aus `workers.yaml`; eine Version, die kein Projekt mehr nutzt, wird im selben Plan entfernt |
| **Hinweis beim Chat-Start** | `aios --context --advise` meldet fehlende Arbeitspferde des Projekts mit dem Befehl `aios --fetch` (Spec 02) |

**Nutzende Projekte:** `workers.yaml` führt je Version die Projekte, deren `lock.yaml` sie nennt. Ein Projekt, dessen Ordner nicht mehr existiert, zählt nicht und wird von `aios --worker` als verwaist gemeldet (V0.5, Memo 21, F5).

## `aios --worker`

| CLI | Wirkung |
|---|---|
| `aios --worker` | je installiertem Arbeitspferd: Paket, Version, Ort, Programme, nutzende Projekte (verwaiste markiert), Ergebnis von `check` |
| `aios --worker <paket> setup [--to <projekt>]` | **Reparatur:** die in `lock.yaml` des Ziels gesperrte Version entfernen und neu einrichten; Plan und Bestätigung |

Weitere Unterbefehle gibt es nicht; setup und remove laufen sonst nur beim Laden und Entfernen (V0.5, Memo 18).

## Voraussetzungen und Plattformen

- **Grundausstattung** (Spec 04, `aios --prepare`): `python3` ≥ 3.9 mit den Modulen `venv` und `pip`, `git`.
- **Plattformen:** macOS und Linux (Spec 04). Für Wheels gelten die Grenzen ihrer Plattform, z. B. glibc ≥ 2.27 bei `deno` unter Linux (V0.5, Memo 33, P5).
- `deno` ist keine Voraussetzung des Kernels, sondern das Arbeitspferd `worker-deno` (V0.5, Memo 31).

## Tests

| Punkt | Regel |
|---|---|
| ohne Netz | `tests/run` setzt `AIOS_PIP_FIND_LINKS`; der Kernel ruft `pip` dann nie ohne `--no-index` (V0.5, Memo 32, F31) |
| Test-Wheel | `tests/hub/build` erzeugt ein Wheel `aios-test-tool` mit der Standardbibliothek (`zipfile`) und die Datei mit Hashes dazu |
| Testpakete | `worker-test` (`kind: python`, `programs: [aios-test-tool]`, `check`), `worker-test-script` (`kind: script`, auch mit scheiterndem setup), `skill-test-nutzer` (Skill mit `depends: worker-test`), `test-worker` aus v0.4 (wird abgelehnt) |
| live | `tests/live/workers.sh` holt `worker-deno` und `worker-yt-dlp` mit `--from` aus den lokalen Repos in einen Sandkasten, mit Netz, und prüft `check` und einen Aufruf; nicht Teil von `tests/run` |

## Grenzen

- **Dienste** (`start`, `stop`, Ports) sind nicht umgesetzt (V0.5, Memo 15).
- **`kind: binary`** (z. B. `ffmpeg`) ist nicht umgesetzt (V0.5, Memo 21).
- `/opt/aios` gehört einem Benutzer (Spec 04); mehrere User auf einem Rechner sind nicht geregelt.

## Invarianten der Arbeitspferde

Zusätzlich zu Spec 01 und Spec 06:

| # | Regel |
|---|---|
| A1 | setup und remove laufen nur in einem Plan mit Bestätigung, der bei `kind: python` die Pakete und bei `kind: script` den Inhalt der Skripte zeigt (P3). |
| A2 | Eine installierte Version wird nie verändert, nur ganz entfernt und neu eingerichtet. |
| A3 | Eine Version wird nur entfernt, wenn kein Projekt sie mehr nutzt. |
| A4 | Ein Weiterleiter ruft nur die Version, die `lock.yaml` des nächsten passenden Projekts nennt. |

## Entschiedene Festlegungen

V0.5, Memos 15–22, 28–33 und 37 (F1–F37, K-a, S1–S5).
