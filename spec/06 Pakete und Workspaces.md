---
title: "Pakete und Workspaces"
date: 2026-10-21
author: iHux
status: Entwurf
tags: [spec, aios, v0.4, pakete, workspaces]
number: 06
related:
  - "Spec 01 AIbex AIOS v0.4 — Überblick"
  - "Spec 02 Master-Kontext"
  - "Spec 03 Skills und Assistenten"
  - "Spec 04 Installation und Konfiguration"
  - "Spec 05 Projekte"
  - "Memos 01–15 (AA-AIbex-AIOS, @Memo/V0.4)"
---

# Pakete und Workspaces

Diese Spec regelt Pakete und Module: das Paket-Manifest `manifest.yaml`, Versionen und Bereiche, den Hub mit seinem Index, den Resolver, die Installation als Kopie mit `aios --deploy`, den aufgelösten Stand in `.aios/lock.yaml`, Arbeitspferde, Workspaces mit `.aios/workspace.yaml` und `aios --workspace`, den Rückfluss mit `aios --contribute`, die Daten von Apps in `@Data/` und die Demo-App Taschenrechner. Die Begriffe stehen in Spec 01, die Auflösung entlang der Kette in Spec 02 und 03, Dateistrukturen und CLI in Spec 04, Struktur und Integrität von Projekten in Spec 05. Die Gegenüberstellung mit Zephyr steht in V0.4, Memo 14.

## Pakete

Ein **Paket** ist eine versionierte Einheit aus einem oder mehreren Elementen, die eine Datei `manifest.yaml` beschreibt. Ein **Modul** ist ein Paket, nach dessen Installation AIOS etwas Neues kann. Eine **App** ist ein Modul, das der Anwender direkt benutzt. Eine **Distribution** ist ein Paket, das nur andere Pakete mit Versionen auflistet (V0.4, Memos 04, 07).

Jedes Paket liegt in einem eigenen Git-Repo. Eine Version ist ein Tag `v<version>` in diesem Repo, und `version` in `manifest.yaml` des getaggten Stands muss übereinstimmen. Der Kernel von AIOS ist ebenfalls ein Paket (`type: kernel`, Repo `aibex-aios`), wird aber mit `aios --install` installiert, nicht mit `aios --deploy` (Spec 04).

### Aufbau eines Paket-Repos

```
<paket>/
├── manifest.yaml                   Pflicht
├── skills/<name>/SKILL.md          Skills (Format Spec 03)
├── assistants/<name>/ASSISTANT.md  Assistenten (Aufbau Spec 03)
├── knowledge/                      Wissen, mit Klassen wie ein Masterspace (Spec 02)
├── commands/<name>                 Befehle (ausführbar)
├── workers/<name>/                 Skripte der Arbeitspferde
├── contrib/<user>/…                Rückflüsse (aios --contribute)
└── README.md                       optional
```

Nur `manifest.yaml` ist Pflicht. Welche Ordner ein Paket hat, nennt `contents`.

### `manifest.yaml`

```yaml
name: taschenrechner
version: 0.1.0
type: app
description: Programmierbarer Taschenrechner mit lernenden Kacheln (Demo-App von AIOS)
requires:
  aios: ">=0.4,<0.5"
depends:
  memo: "~=6.0"
contents:
  skills: [taschenrechner, taschenrechner-gui]
  gui: taschenrechner-gui
license: MIT
```

| Feld | Pflicht | Regel |
|---|---|---|
| `name` | ja | Kleinbuchstaben, Ziffern, Bindestriche, höchstens 64 Zeichen; gleich dem Namen des Repos im Hub; über alle Pakete des Hubs eindeutig; nicht `aios-…`, `gui`, `none`, `inherit` |
| `version` | ja | SemVer `MAJOR.MINOR.PATCH`, optional mit Vorabkennung (`0.4.0-rc1`) |
| `type` | ja | `kernel`, `app`, `assistant`, `skill`, `knowledge`, `tutorial`, `distribution`; unbekannte Werte werden mit Warnung als `knowledge` behandelt |
| `description` | ja | ein Satz |
| `requires` | ja | `aios: "<bereich>"`, Bereich der AIOS-Version, in der das Paket läuft |
| `depends` | nein | Name → Bereich anderer Pakete |
| `contents` | nein | `skills`, `assistants`, `commands`, `hooks` (Listen von Namen), `knowledge` (`true`), `gui` (Name eines Skills aus `skills`) |
| `workers` | nein | Arbeitspferde, siehe *Arbeitspferde* |
| `license` | nein | SPDX-Kennung oder Freitext |
| `userdata` | nein | beliebige Daten; AIOS wertet sie nicht aus |

`manifest.yaml` wird mit PyYAML gelesen. Ein Paket ist ein **Modul**, wenn `type` `kernel`, `app`, `assistant` oder `skill` ist oder `contents` mindestens einen Skill, Assistenten, Befehl oder Hook nennt. Pakete vom Typ `knowledge`, `tutorial` und `distribution` ohne solche Inhalte sind keine Module (V0.4, Memo 04).

**Prüfung beim Installieren:** Jeder in `contents` genannte Name muss als Ordner bzw. Datei vorhanden sein, jeder Skill braucht eine gültige `version` (Spec 03), `gui` muss in `skills` stehen. Ein Paket, das die Prüfung nicht besteht, wird nicht installiert.

**Hooks** (`contents.hooks`) sind im Format vorgesehen, in v0.4 aber ohne Wirkung: `aios --deploy` meldet sie und installiert das Paket ohne sie.

## Versionen und Bereiche

Versionen folgen SemVer. Bereiche folgen den Versionsangaben von pip:

| Angabe | Bedeutung | Beispiel |
|---|---|---|
| `==X.Y.Z` | genau diese Version | `==6.0.0` |
| `!=X.Y.Z` | nicht diese Version | `!=0.2.1` |
| `>=`, `<=`, `>`, `<` | Vergleich | `>=0.4` |
| `~=X.Y` | kompatibel: `>=X.Y,<(X+1).0` | `~=6.0` → `>=6.0,<7.0` |
| `~=X.Y.Z` | kompatibel: `>=X.Y.Z,<X.(Y+1).0` | `~=0.1.2` → `>=0.1.2,<0.2.0` |
| `A,B` | beide Bedingungen | `>=0.4,<0.5` |
| `*` oder leer | jede Version | |

Fehlende Teile einer Version zählen als `0` (`0.4` = `0.4.0`). Vorabversionen erfüllen einen Bereich nur, wenn der Bereich selbst eine Vorabversion nennt (`>=0.4.0-rc1`).

## Hub

Der **Hub** ist die GitHub-Organisation `aibex-aios` (V0.4, Memo 07): ein Repo je Paket, Versionen als Tags `v<version>`, dazu das Index-Repo `aios-index`.

**Index** `aios-index/index.yaml`:

```yaml
schema: 1
packages:
  - name: memo
    repo: https://github.com/aibex-aios/memo
    type: skill
    description: Memo-Stil der AIbex-Workspaces
  - name: taschenrechner
    repo: https://github.com/aibex-aios/taschenrechner
    type: app
    description: Programmierbarer Taschenrechner mit lernenden Kacheln
```

Der Index nennt je Paket nur `name`, `repo`, `type` und `description`. Die verfügbaren Versionen liest AIOS aus den Tags des Paket-Repos (`git ls-remote --tags <repo>`), Tags, die nicht der Form `v<SemVer>` folgen, werden übergangen. Eine neue Version braucht deshalb keinen Commit im Index, ein neues Paket schon (V0.4, Memo 11).

**Ort des Index:** Standard `https://github.com/aibex-aios/aios-index`, überschreibbar mit dem Schlüssel `hub` in `~/.aios/config.yaml` (Spec 04) und für Tests mit `AIOS_HUB` (auch `file://`). Den Index holt AIOS mit `git clone --depth 1` bzw. `git pull` nach `~/.aios/hub/index/`.

**Zugriff aufs Netz:** Nur `aios --deploy`, `aios --library`, `aios --workspace` und `aios --contribute` greifen auf das Netz zu, und nur über `git` bzw. `gh` mit den Zugangsdaten des Users. Ohne Netz arbeitet `aios --deploy` ohne Argument mit dem Cache (unten), wenn alle Versionen aus `lock.yaml` dort liegen.

## Resolver

Der Resolver bestimmt aus den gewünschten Paketen (`packages:` der Konfigurationskette, Spec 04) die zu installierenden Versionen (V0.4, Memo 15, F5):

1. Für jedes gewünschte Paket die Versionen aus dem Hub holen.
2. Je Paket die **höchste Version** wählen, die alle Bereiche erfüllt, die bis jetzt dafür gelten (aus `packages:` und aus `depends` bereits gewählter Pakete).
3. Ihr `manifest.yaml` lesen (aus dem Cache bzw. nach Download): `requires.aios` gegen die für das Zielprojekt gültige AIOS-Version prüfen, `depends` als neue Bereiche aufnehmen.
4. Ändert ein neuer Bereich die Wahl eines bereits gewählten Pakets, wird dieses neu gewählt und Schritt 3 wiederholt, bis sich nichts mehr ändert.
5. Erfüllt keine Version alle Bereiche eines Pakets oder passt `requires.aios` bei keiner passenden Version: Abbruch mit einer Liste der Konflikte (Paket, Bereiche, Herkunft je Bereich). Es gibt kein Backtracking über ältere Versionen anderer Pakete.

Zyklen in `depends` sind erlaubt, solange die Bereiche erfüllbar sind. Ein Paket, das in `lock.yaml` steht und dessen Version alle Bereiche weiter erfüllt, bleibt bei dieser Version (kein stilles Update). Ein Update gibt es nur mit `aios --deploy --upgrade [<name>]`.

## Installation als Kopie — `aios --deploy`

`aios --deploy` installiert Pakete in ein Projekt (Anwender-Site, V0.4, Memo 09) und ersetzt das Ausrollen einzelner Blueprints aus v0.3.

| Skill | CLI | Wirkung |
|---|---|---|
| `/aios-deploy taschenrechner~=0.1` | `aios --deploy <name>[<bereich>] [--to <projekt>]` | Paket in `packages:` aufnehmen bzw. dort ändern, auflösen, installieren |
| `/aios-deploy` | `aios --deploy [--to <projekt>]` | Projekt mit `lock.yaml` abgleichen (z. B. nach `git pull`, auf einem anderen Rechner) |
| — | `aios --deploy --upgrade [<name>] [--to <projekt>]` | höchste passende Versionen neu wählen |
| — | `aios --deploy --remove <name> [--to <projekt>]` | Paket entfernen |
| — | `aios --library [<name>]` | Index des Hubs, mit `<name>` die Versionen eines Pakets |
| `/aios-deploy <name> --from <repo>` | `aios --deploy <name>[<bereich>] --from <repo> [--to <projekt>]` | Paket aus einem anderen Git-Repo statt aus dem Hub installieren (Pflegeprojekt, V0.4, Memo 09) |

Ohne Bereich gilt `~=<höchste Version>` mit den ersten beiden Stellen (`taschenrechner` → `~=0.1`).

**Pflegeprojekte:** Mit `--from <repo>` (lokaler Pfad oder URL eines Git-Repos mit `manifest.yaml` und Tags `v<version>`) kommt ein Paket nicht aus dem Hub, sondern aus diesem Repo, z. B. aus einem Projekt, in dem der Skill gepflegt wird. `lock.yaml` hält das Repo fest; der Abgleich ohne Argument holt das Paket wieder von dort. Installiert wird auch hier nur eine getaggte Version.

**Ziel** ist das Projekt der Session oder `--to <projekt>` (F4). Ein Paket in einem Projekt gilt für dieses Projekt und alle Projekte der Kette darunter. Der Skill fragt nach dem Ziel und schlägt das Root-Projekt vor.

**Ablauf:**

1. `packages:` in `<ziel>/.aios/config.yaml` mit dem neuen Eintrag lesen, zusammen mit den `packages:` der Kette darüber (je Name gewinnt der nächstgelegene Eintrag, Spec 04).
2. Auflösen (*Resolver*).
3. Pakete in den Cache holen: `git clone --depth 1 --branch v<version> <repo>` nach `~/.aios/packages/<name>/<version>/`, Commit-SHA merken. Ein vorhandener Cache-Eintrag wird wiederverwendet, wenn sein Commit zu `lock.yaml` passt.
4. Vorschau: je Paket `new`, `upgrade X → Y`, `remove`, `unchanged`; Dateien, die sich in `@!Package/<name>/` ändern; direkt geänderte Kopien; Arbeitspferde mit ihren Skripten; Änderungen an `config.yaml` und `lock.yaml`.
5. Nach Ja: je Paket den Inhalt ohne `.git` nach `<ziel>/@/@!Package/<name>/` spiegeln (nur dieser Ordner), die Marke schreiben, `install` der Arbeitspferde nach eigener Bestätigung ausführen (*Arbeitspferde*), `packages:` und `lock.yaml` schreiben.
6. Projekt-Skills im Projekt der Session registrieren (Spec 03).

Abhängigkeiten werden in dasselbe Ziel installiert wie das Paket, das sie verlangt, außer sie liegen dort schon oder in einem Projekt der Kette darüber in einer passenden Version.

**Marke `.aios-deploy`** (F3): `@!Package/<name>/.aios-deploy` mit `name`, `version`, `repo`, `commit` und `digest` (Verfahren wie Spec 04, *`.aios/registry`*, über alle Dateien des Pakets ohne die Marke). Weicht der Inhalt vom `digest` ab, meldet `aios --deploy` die Kopie als „direkt geändert" und ersetzt sie nach Rückfrage.

**Abgleich ohne Argument:** Für jedes Paket aus `lock.yaml` des Ziels prüfen, ob `@!Package/<name>/` mit Version und `digest` übereinstimmt. Fehlende, abweichende und direkt geänderte Kopien werden aus dem Cache bzw. dem Hub neu gespiegelt. Ein Paketordner mit Marke, der in `lock.yaml` nicht mehr steht, wird nach Rückfrage entfernt.

**Entfernen:** `--remove <name>` entfernt den Eintrag aus `packages:`, löst neu auf, ruft `remove` der Arbeitspferde des Pakets nach Bestätigung auf und entfernt `@!Package/<name>/` sowie Pakete, die nur noch als Abhängigkeit dieses Pakets im Ziel lagen. Verlangt ein anderes Paket es noch, bricht `--remove` mit dieser Angabe ab.

### Wirkung installierter Pakete

Ein installiertes Paket wirkt über die Masterspace-Kette (Spec 02, 03):

| Inhalt | Wirkung |
|---|---|
| `skills/<name>/` | Projekt-Skill wie ein Blueprint `@!Skill/<name>/` desselben Masterspace; wird registriert (Spec 03) |
| `assistants/<name>/` | Assistent wie `@!Assistant/<name>/` desselben Masterspace; zuordnen mit `/aios-assistant` |
| `knowledge/` | Teil des Masterspace: Dateien darin werden nach den Klassen von Spec 02 eingeteilt, als lägen sie direkt in `@/`; Pfadangaben im Master-Kontext nennen den Ort in `@!Package/<name>/knowledge/` |
| `commands/<name>` | aufrufbar mit `aios --run <name> [argumente]` in Projekten, für die das Paket gilt |
| `gui` | Oberfläche einer App; der Skill dieses Namens zeigt sie (Spec 03, *Oberflächen*) |

**Vorrang** (V0.4, Memo 12): Zuerst gilt der nächstgelegene Masterspace (Spec 01, Grundregel 3). Innerhalb eines Masterspace gewinnt ein lokaler Blueprint in `@!Skill/` bzw. `@!Assistant/` vor einem Element gleichen Namens aus `@!Package/`. `/aios-context` meldet jede solche Verdeckung. Zwei Pakete mit Elementen gleichen Namens im selben Masterspace sind ein Fehler, den `aios --deploy` vor dem Schreiben meldet.

### Konfiguration und Lock

`<ziel>/.aios/config.yaml` nennt unter `packages:` die gewünschten Pakete (Spec 04):

```yaml
aios: 0.4.0
packages:
  taschenrechner: "~=0.1"
  memo: "~=6.0"
assistant: none
```

`<ziel>/.aios/lock.yaml` schreibt nur AIOS. Es ist versioniert:

```yaml
# written by AIOS (deploy, workspace), do not edit
schema: 1
packages:
  taschenrechner:
    version: 0.1.0
    repo: https://github.com/aibex-aios/taschenrechner
    tag: v0.1.0
    commit: 3f2a…
    requested: "~=0.1"
  memo:
    version: 6.0.0
    repo: https://github.com/aibex-aios/memo
    tag: v6.0.0
    commit: 9c1d…
    required_by: [taschenrechner]
workspace:
  AA-AIbex-AIOS: 8f31…
```

`requested` steht bei Paketen aus `packages:`, `required_by` bei Abhängigkeiten. `workspace` hält den eingefrorenen Stand eines Workspace (unten). `lock.yaml` wird mit PyYAML gelesen.

### Arbeitspferde

Ein Arbeitspferd ist ein Programm mit Lebenszyklus, das ein Paket mitbringt, z. B. eine SQL-Datenbank (V0.4, Memo 09).

```yaml
workers:
  db:
    description: SQLite-Datenbank der Kacheln
    install: workers/db/install.sh
    remove: workers/db/remove.sh
    start: workers/db/start.sh
    stop: workers/db/stop.sh
```

| Regel | |
|---|---|
| Pflicht | `install` und `remove`; `start` und `stop` optional |
| Ausführung | mit `bash`, Arbeitsverzeichnis `@!Package/<name>/`, Umgebung `AIOS_PACKAGE`, `AIOS_PROJECT`, `AIOS_DATA` (= `<projekt>/@Data/<name>/`) |
| Bestätigung | jedes Skript nur nach eigener Bestätigung: Plan mit Pfad und Inhalt des Skripts, dann `--yes` (Spec 01, I7) |
| Aufruf | `install` beim Installieren, `remove` beim Entfernen, `start` und `stop` mit `aios --worker <paket>/<name> start\|stop` |
| Fehler | Exit ≠ 0 bei `install` bricht die Installation dieses Pakets ab; AIOS ruft dann `remove` auf und meldet beides |

### Umstellung von v0.3

`skills:` und `assistants:` aus v0.3 gehen in `packages:` auf (V0.4, Memo 09). v0.4 liest beide Schlüssel weiter: `skills: {memo: 6.0.0}` gilt als `packages: {memo: "==6.0.0"}`, `assistants:` ebenso; Einträge der Form `<assistant>/<skill>` werden mit Warnung übergangen. `aios --activate v0.4.<n>` bietet an, die Schlüssel umzuschreiben und die Blueprints mit Marke aus `@!Skill/` und `@!Assistant/` durch Pakete in `@!Package/` zu ersetzen. Lokale Blueprints ohne Marke bleiben. Weil die `.gitignore`-Vorlage jetzt `.aios/registry` statt `.aios/manifest` enthält (Spec 04), melden Konsistenzprüfung und `/aios-integrity` in Projekten aus v0.3 die fehlende Zeile; `aios --init` ergänzt sie.

## Daten von Apps — `@Data/`

Daten, die eine App im Projekt erzeugt, liegen in `<projekt>/@Data/<paket>/` (F6). `@Data/` ist ein Schlüsselordner wie `@Memo/`: Er gehört nicht zum Masterspace, wird nicht in den Kontext geladen und ist versioniert. AIOS legt `@Data/<paket>/` an, wenn eine App zum ersten Mal schreibt. `aios --deploy --remove` lässt `@Data/` unberührt.

## Workspaces

Ein **Workspace** ist ein AIOS-Projekt, das in `.aios/workspace.yaml` Projekte mit Repo, Revision und Pfad nennt (V0.4, Memo 10). Das Projekt mit dieser Datei ist das **Wurzelprojekt** des Workspace. Es hat ein eigenes Repo; die Projekte des Workspace liegen darunter, verschachtelt, und sind im jeweils darüberliegenden Repo ausgeschlossen (Spec 05, S4). Projekte im Workspace müssen keine Pakete sein. Ein Paket im Workspace liegt als Checkout an seinem Pfad (Entwickler-Site), in einem Vault als Kopie in `@!Package/` (Anwender-Site).

### `.aios/workspace.yaml`

```yaml
schema: 1
remotes:
  aibex: https://github.com/aibex-aios
projects:
  - name: AA-AIbex-AIOS
    remote: aibex
    revision: main
    path: AA-AIbex-AIOS
  - name: taschenrechner
    remote: aibex
    revision: v0.1.0
    path: AT-Taschenrechner/taschenrechner
    groups: [apps]
```

| Feld | Pflicht | Regel |
|---|---|---|
| `remotes` | nein | Name → Basis-URL; die URL eines Projekts ist `<basis>/<name>` |
| `projects[].name` | ja | eindeutig im Workspace |
| `projects[].remote` oder `repo` | genau eines | Remote aus `remotes` oder volle URL |
| `projects[].revision` | ja | Zweig, Tag oder Commit-SHA |
| `projects[].path` | ja | relativ zum Wurzelprojekt, darunter, ohne `..` |
| `projects[].groups` | nein | Liste von Gruppennamen |
| `projects[].import` | nein | im Format vorgesehen, in v0.4 ohne Wirkung; `aios --workspace` meldet ihn und übergeht ihn |

Die Datei wird mit PyYAML gelesen und vom User gepflegt.

### `aios --workspace`

| Befehl | Wirkung |
|---|---|
| `aios --workspace init <repo> [<ordner>] [--group <g>…]` | Wurzelprojekt nach `<ordner>` klonen (Standard: Name des Repos), dann alle Projekte aus seiner `workspace.yaml` |
| `aios --workspace update [<pfad>] [--group <g>…]` | fehlende Projekte klonen, vorhandene auf die Revision bringen |
| `aios --workspace freeze [<pfad>]` | Commit-SHA jedes Projekts in `lock.yaml` des Wurzelprojekts schreiben (Abschnitt `workspace`) |
| `aios --workspace status [<pfad>]` | je Projekt: vorhanden, Zweig, Revision enthalten, voraus/hinter dem Remote, offene Änderungen |

`<pfad>` ist das Wurzelprojekt oder ein Ordner darunter; AIOS sucht die nächste `workspace.yaml` aufwärts. Ohne `--group` gelten alle Projekte; mit `--group` nur Projekte dieser Gruppen und Projekte ohne Gruppe.

**Klonen:** `git clone <url> <path>`. Ist `revision` ein Zweig, wird er ausgecheckt. Ist sie ein Tag oder Commit, legt AIOS einen lokalen Zweig `ws/<revision>` an diesem Commit an und checkt ihn aus. Es gibt kein *detached HEAD* (V0.4, Memo 10). Danach trägt AIOS `/<path>/` in die `.gitignore` des Repos darüber ein, wenn sie fehlt, und committet nur diese Zeile („AIOS: <path> als Projekt des Workspace ausgeschlossen", I9).

**Update** (nur fast-forward): Ist `revision` ein Zweig, `git fetch` und `git merge --ff-only origin/<zweig>`. Ist sie ein Tag oder Commit und enthält der ausgecheckte Zweig ihn nicht, wird der Zweig per fast-forward auf diesen Commit gesetzt, wenn das möglich ist. Ist ein fast-forward nicht möglich (eigene Commits, nicht committete Änderungen, anderer Zweig ausgecheckt), lässt AIOS das Projekt unverändert und meldet es mit dem Grund. `update` schreibt nichts in die Projekte außer durch Klonen und fast-forward.

**Status** zeigt eine Tabelle wie `aios --integrity` (Spec 05):

```
Workspace A-AIOS — 2026-10-21

Project          Path                     Branch   Revision   Remote        Changes
AA-AIbex-AIOS    AA-AIbex-AIOS            main     ok         ok            ok
taschenrechner   AT-Taschenrechner/…      ws/v0.1.0 ok        —             2 changed
aibex-aios       AB-Code/aibex-aios       —        missing    —             —
```

Alle Befehle außer `status` sind schreibend und folgen I7 (Plan, `--plan`, `--yes`).

## Rückfluss — `aios --contribute`

Ein Rückfluss bringt Dateien von der Anwender-Site zurück in ein Paket-Repo des Hubs (V0.4, Memo 11). Er ist kein Modul.

`aios --contribute <datei>… --to <paket> [--message <text>]`:

1. Paket aus `lock.yaml` der Kette bestimmen, `gh` und Anmeldung prüfen; ohne Zugang: Meldung, nichts anlegen.
2. Plan: Repo, Zweig `contrib/<gh-user>/<datum>-<kurzname>`, Ziel `contrib/<gh-user>/<dateiname>`, Titel des Pull Requests.
3. Nach Ja: Repo in ein temporäres Verzeichnis klonen (bei fehlenden Schreibrechten einen Fork), Zweig anlegen, Dateien kopieren, committen, pushen und mit `gh pr create` den Pull Request gegen den Standardzweig anlegen. Ausgabe: URL des Pull Requests.

Der Maintainer prüft und übernimmt. Mit dem nächsten Tag kommt der Beitrag als Inhalt der neuen Version zu anderen Usern. Wird ein Beitrag als eigenes Paket veröffentlicht (z. B. `type: knowledge`), ist er ein Paket, aber kein Modul (V0.4, Memo 11).

## Demo-App Taschenrechner

Paket `taschenrechner` (`type: app`) im Repo `aibex-aios/taschenrechner`, Version `0.1.0`. Es zeigt Installation, Version, Abgleich und Rückfluss (V0.4, Memos 01, 05).

| Element | Inhalt |
|---|---|
| Skill `taschenrechner-gui` | Oberfläche (`gui.yaml`) mit einem HTML-Teil `rechner.html` |
| Skill `taschenrechner` | speichert, liest und listet Kachel-Funktionen in `@Data/taschenrechner/kacheln.yaml` |
| Tasten | `0`–`9`, `+`, `−`, `×`, `÷`, `=`, vier Kacheln `K1`–`K4`, **Lernen** |
| Lernen | erster Druck startet die Aufnahme der folgenden Tasten, zweiter Druck beendet sie; die nächste gedrückte Kachel übernimmt die Folge |
| Kachel | spielt ihre Tastenfolge ab, als würde sie getippt |
| Speichern | Der HTML-Teil kann keine Dateien schreiben. Nach dem Belegen einer Kachel sendet er mit `sendPrompt` eine Nachricht an Claude, die den Skill `taschenrechner` aufruft und die Belegung speichert (Spec 01, I7: Claude zeigt, was gespeichert wird). Beim Öffnen liest der Skill die Datei und übergibt sie dem HTML-Teil |
| Rückfluss | `aios --contribute @Data/taschenrechner/kacheln.yaml --to taschenrechner` |

`kacheln.yaml`:

```yaml
K1:
  title: Quadrat
  keys: ["×", "="]
K2:
  title: plus 19 %
  keys: ["×", "1", ".", "1", "9", "="]
```

## Invarianten der Pakete

Zusätzlich zu Spec 01 (I1–I9):

| # | Regel |
|---|---|
| P1 | AIOS schreibt in `@!Package/` nur mit `aios --deploy` und nur ganze Paketordner mit Marke. |
| P2 | `lock.yaml` schreiben nur `aios --deploy` und `aios --workspace freeze`. |
| P3 | Skripte eines Pakets (Arbeitspferde, Befehle) laufen nie ohne Bestätigung, außer `aios --run` mit einem Befehl, den der User selbst aufruft. |
| P4 | `aios --workspace` verschiebt keinen Zweig außer per fast-forward und verwirft nie Änderungen. |
| P5 | `aios --contribute` schreibt nur in einen neuen Zweig; es pusht nie auf den Standardzweig. |
| P6 | `@Data/` wird von keinem Befehl außer der App selbst geändert; `--remove` lässt ihn stehen. |

## Festlegungen dieses Entwurfs (zu bestätigen)

Beim Schreiben getroffen, nicht in den Memos entschieden (Regel *Weiter*, *Offenlegen*):

| # | Festlegung |
|---|---|
| S1 | Aufbau eines Paket-Repos mit `skills/`, `assistants/`, `knowledge/`, `commands/`, `workers/`, `contrib/` |
| S2 | Hooks (`contents.hooks`) in v0.4 ohne Wirkung, nur gemeldet |
| S3 | Befehle eines Pakets über `aios --run <name>`, Arbeitspferde über `aios --worker <paket>/<name> start\|stop` |
| S4 | Cache `~/.aios/packages/<name>/<version>/`, Index in `~/.aios/hub/index/`, Schlüssel `hub` und Variable `AIOS_HUB` |
| S5 | kein stilles Update: Versionen aus `lock.yaml` bleiben, bis `--upgrade` aufgerufen wird; ohne Bereich `~=` der höchsten Version mit zwei Stellen |
| S6 | Vorrang: zuerst der nächstgelegene Masterspace, darin der lokale Blueprint vor dem Paket |
| S7 | Tag oder Commit als Revision im Workspace: lokaler Zweig `ws/<revision>` statt *detached HEAD* |
| S8 | Wissen eines Pakets (`knowledge/`) wird nach den Klassen eingeteilt, als läge es direkt in `@/` |
| S9 | Abhängigkeiten werden ins selbe Ziel installiert, außer sie liegen in der Kette darüber schon in passender Version |
