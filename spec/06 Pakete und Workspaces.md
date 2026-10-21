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
  - "Memos 01–29 (AA-AIbex-AIOS, @Memo/V0.4)"
---

# Pakete und Workspaces

Diese Spec regelt Pakete und Module: das Paket-Manifest `manifest.yaml`, Versionen und Bereiche, Hubs und die Hub-Liste, den Resolver, das Holen eines Pakets mit `aios --fetch`, das Ausrollen seiner Elemente mit `aios --deploy`, den aufgelösten Stand in `.aios/lock.yaml`, Arbeitspferde, Workspaces mit `.aios/workspace.yaml` und `aios --workspace`, den Rückfluss mit `aios --contribute`, die Daten von Apps in `@Data/` und die Demo-App Taschenrechner. Die Begriffe stehen in Spec 01, die Auflösung entlang der Kette in Spec 02 und 03, die Skills `/aios-package`, `/aios-fetch` und `/aios-deploy` in Spec 03, Dateistrukturen und CLI in Spec 04, Struktur und Integrität von Projekten in Spec 05. Die Gegenüberstellung mit Zephyr steht in V0.4, Memo 14.

## Pakete

Ein **Paket** ist eine versionierte Einheit aus einem oder mehreren Elementen, die eine Datei `manifest.yaml` beschreibt. **Elemente** sind die Teile, die in einem Projekt wirken: Skills, Assistenten, Wissen und Befehle. Ein **Modul** ist ein Paket, nach dessen Holen AIOS etwas Neues kann. Eine **App** ist ein Modul, das der Anwender direkt benutzt. Eine **Distribution** ist ein Paket, das nur andere Pakete mit Versionen auflistet (V0.4, Memos 04, 07).

Jedes Paket liegt in einem eigenen Git-Repo in einem Hub. Eine Version ist ein Tag `v<version>` in diesem Repo, und `version` in `manifest.yaml` des getaggten Stands muss übereinstimmen. Der Kernel von AIOS ist ebenfalls ein Paket (`type: kernel`, Name `aios`, Repo `aibex-aios/aibex-aios`), wird aber mit `aios --install` installiert, nicht geholt (Spec 04).

Für Pakete gelten drei Verben (V0.4, Memos 23, 24):

| Verb | Gegenstand | Bedeutung | CLI |
|---|---|---|---|
| **holen** (fetch) | Paket | eine Version eines Pakets ganz vom Hub ins Projekt holen | `aios --fetch` |
| **ausrollen** (deploy) | Element | festlegen, welche Elemente eines geholten Pakets im Projekt wirken; ohne Kopie | `aios --deploy` |
| **registrieren** (register) | Skill | ausgerollte Skills dem Host bekannt machen (Spec 03) | `aios --register` |

*Installieren* ist dem Kernel vorbehalten. Für Pakete ist es nur ein Wort der Anwender, das `/aios-package` versteht.

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
name: app-taschenrechner
version: 0.1.0
type: app
description: Programmierbarer Taschenrechner mit lernenden Kacheln (Demo-App von AIOS)
requires:
  aios: ">=0.4,<0.5"
depends:
  skill-memo: "~=6.0"
contents:
  skills: [taschenrechner, taschenrechner-gui]
  knowledge: true
  gui: taschenrechner-gui
license: MIT
```

| Feld | Pflicht | Regel |
|---|---|---|
| `name` | ja | Kleinbuchstaben, Ziffern, Bindestriche, höchstens 64 Zeichen; gleich dem Namen des Repos in seinem Hub; nicht `aios` (Kernel), `aios-…`, `gui`, `none`, `inherit` |
| `version` | ja | SemVer `MAJOR.MINOR.PATCH`, optional mit Vorabkennung (`0.4.0-rc1`) |
| `type` | ja | `kernel`, `app`, `assistant`, `skill`, `knowledge`, `tutorial`, `distribution`; unbekannte Werte werden mit Warnung als `knowledge` behandelt |
| `description` | ja | ein Satz |
| `requires` | ja | `aios: "<bereich>"`, Bereich der AIOS-Version, in der das Paket läuft |
| `depends` | nein | Name → Bereich anderer Pakete; `aios` ist hier nicht erlaubt, dafür gibt es `requires` |
| `contents` | nein | `skills`, `assistants`, `commands`, `hooks` (Listen von Namen), `knowledge` (`true`), `gui` (Name eines Skills aus `skills`) |
| `workers` | nein | Arbeitspferde, siehe *Arbeitspferde* |
| `license` | nein | SPDX-Kennung oder Freitext |
| `userdata` | nein | beliebige Daten; AIOS wertet sie nicht aus |

`manifest.yaml` wird mit PyYAML gelesen. Ein Paket ist ein **Modul**, wenn `type` `kernel`, `app`, `assistant` oder `skill` ist oder `contents` mindestens einen Skill, Assistenten, Befehl oder Hook nennt. Pakete vom Typ `knowledge`, `tutorial` und `distribution` ohne solche Inhalte sind keine Module (V0.4, Memo 04).

**Elemente** eines Pakets und ihre Namen beim Ausrollen: jeder Skill und jeder Assistent unter seinem Namen, jeder Befehl unter seinem Namen und das Wissen als `knowledge`. Die Namen sind innerhalb eines Pakets eindeutig.

**Prüfung beim Holen:** Jeder in `contents` genannte Name muss als Ordner bzw. Datei vorhanden sein, jeder Skill braucht eine gültige `version` (Spec 03), `gui` muss in `skills` stehen, Elementnamen dürfen sich nicht wiederholen. Ein Paket, das die Prüfung nicht besteht, wird nicht geholt.

**Hooks** (`contents.hooks`) sind im Format vorgesehen, in v0.4 aber ohne Wirkung: `aios --fetch` meldet sie und holt das Paket ohne sie.

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

Fehlende Teile einer Version zählen als `0` (`0.4` = `0.4.0`). Vorabversionen eines Pakets erfüllen einen Bereich nur, wenn der Bereich selbst eine Vorabversion nennt (`>=0.4.0-rc1`).

**Version des Kernels:** Für `requires.aios` zählt die AIOS-Version **ohne Vorabkennung**: `0.4.0-dev` und `0.4.0-rc1` gelten als `0.4.0` (V0.4, Memo 18, L1). So lassen sich Pakete auch mit Entwicklungsständen und Release-Kandidaten holen.

**Standardbereich:** Wird ein Paket ohne Bereich geholt, gilt ab Version 1.0 `~=X.Y` der höchsten Version (`memo` 6.0.0 → `~=6.0`), darunter `~=0.Y.Z` (`app-taschenrechner` 0.1.0 → `~=0.1.0`, also `>=0.1.0,<0.2.0`). Vor 1.0 bleibt ein Paket damit in seiner Minor-Version, weil dort jede Minor-Version brechen darf (V0.4, Memo 19, L5).

## Hubs

Ein **Hub** ist ein Ort mit Paket-Repos: ein Name und eine Basis-URL. Ein Paket `<paket>` liegt dort als Repo `<basis>/<paket>`. Bei GitHub ist der Name des Hubs gleich dem **Owner** (Organisation oder User), die Basis-URL ist `https://github.com/<name>`. Der **volle Paketname** ist `<hub>/<paket>`, z. B. `aibex-aios/knowledge-orion` (V0.4, Memos 21, 22).

Der Standard-Hub ist `aibex-aios` (`https://github.com/aibex-aios`). Für die Tests von v0.4 gibt es einen zweiten Hub `aibex-hub` (V0.4, Memos 27, 28).

### Hub-Liste

Die **Hub-Liste** nennt die Hubs, in denen AIOS einen Paketnamen ohne Hub sucht, in Suchreihenfolge. Sie steht unter `hubs:` in `~/.aios/config.yaml` (Home) und in `.aios/config.yaml` der Vault-Root (V0.4, Memos 21, 26):

```yaml
hubs:
  - aibex-aios
  - aibex-hub
  - firma-gitlab: https://gitlab.example.com/aios
```

| Regel | |
|---|---|
| Eintrag | ein Name (GitHub-Hub, Basis-URL `https://github.com/<name>`) oder `name: url` (jeder Git-Server, auch `file://`) |
| Reihenfolge | erst die Liste der Vault-Root, dann die aus Home |
| gleicher Name in beiden | der Eintrag der Vault-Root gilt; `aios --hubs` zeigt die Überdeckung |
| ohne Eintrag | `[aibex-aios]`. Sobald es einen Eintrag `hubs:` gibt, zählt `aibex-aios` nur, wenn er darin steht |
| Tests | `AIOS_HUBS` ersetzt beide Listen: Einträge `name=url`, durch Leerzeichen getrennt (Spec 04) |

Die Hub-Liste ist eine **Suchliste**, keine Sperrliste. Ein voller Paketname darf jeden Hub nennen (unten).

**Pflege:** `aios --hubs` zeigt die Liste mit Herkunft (Vault, Home). `aios --hubs add <name> [<url>] [--vault]` und `aios --hubs remove <name> [--vault]` ändern sie in Home bzw. mit `--vault` an der Vault-Root, mit Plan und Bestätigung (Spec 01, I7). `/aios-package` versteht Sätze wie „füge den Hub aibex-hub hinzu" (V0.4, Memo 25).

### Paket finden

| Angabe | Suche |
|---|---|
| `<paket>` | jeder Hub der Hub-Liste der Reihe nach: `git ls-remote --tags <basis>/<paket>` |
| `<hub>/<paket>` | nur dieser Hub. Steht `<hub>` in der Hub-Liste, gilt dessen Basis-URL, sonst `https://github.com/<hub>` (für Tests umgelenkt mit `AIOS_GITHUB`, Spec 04) |
| `--from <repo>` | genau dieses Repo (lokaler Pfad oder URL), *Pflegeprojekte* |

Ein Treffer ist ein Repo mit mindestens einem Tag `v<SemVer>`, dessen `manifest.yaml` im gewählten Tag `name: <paket>` trägt. Tags anderer Form werden übergangen.

| Treffer | Verhalten |
|---|---|
| genau einer | auflösen und holen |
| keiner | Abbruch mit den durchsuchten Hubs |
| mehrere | Abbruch mit Exit-Code 3 und der Liste der Hubs; der Skill fragt nach und ruft `aios --fetch <paket> --hub <hub>` bzw. mit `<hub>/<paket>` auf |

Ein Hub außerhalb der Hub-Liste wird ohne Hinweis verwendet; AIOS nimmt ihn nicht in die Liste auf und bietet das auch nicht an (V0.4, Memo 25).

Nach dem Holen ist ein Paket an seinen Hub gebunden: `lock.yaml` hält `hub` und `repo` fest, der Abgleich und `--upgrade` suchen nicht erneut.

### Index und Suche

Ein Hub darf ein Repo `aios-index` mit einer Datei `index.yaml` haben, muss aber nicht:

```yaml
schema: 1
packages:
  - name: skill-memo
    type: skill
    description: Memo-Stil der AIbex-Workspaces
  - name: app-taschenrechner
    type: app
    description: Programmierbarer Taschenrechner mit lernenden Kacheln
```

Der Index dient nur der Suche: `aios --library [<suchwort>]` listet je Hub der Hub-Liste die Pakete aus `index.yaml`; ohne Index bei GitHub-Hubs die Repos mit dem Topic **`aios-package`** (über `gh`). Ein Hub ohne beides lässt sich nicht durchsuchen, nur mit bekanntem Namen holen. `aios --library <paket>` zeigt die Versionen eines Pakets (aus den Tags). Den Index holt AIOS mit `git clone --depth 1` bzw. `git pull` nach `~/.aios/hub/<hub>/`.

**Zugriff aufs Netz:** Nur `aios --fetch`, `aios --library`, `aios --workspace` und `aios --contribute` greifen auf das Netz zu, und nur über `git` bzw. `gh` mit den Zugangsdaten des Users. Ohne Netz arbeitet `aios --fetch` ohne Argument mit dem Cache, wenn alle Versionen aus `lock.yaml` dort liegen.

## Resolver

Der Resolver bestimmt aus den gewünschten Paketen eines Projekts (`packages:` in seiner eigenen `.aios/config.yaml`) die zu holenden Versionen (V0.4, Memo 15, F5). Pakete der Projekte darüber zählen nicht (V0.4, Memo 17):

1. Für jedes gewünschte Paket den Hub bestimmen (*Paket finden*, bei gebundenen Paketen aus `lock.yaml`) und seine Versionen aus den Tags holen.
2. Je Paket die **höchste Version** wählen, die alle Bereiche erfüllt, die bis jetzt dafür gelten (aus `packages:` und aus `depends` bereits gewählter Pakete).
3. Ihr `manifest.yaml` lesen (aus dem Cache bzw. nach Download): `requires.aios` gegen die für das Zielprojekt gültige AIOS-Version prüfen (ohne Vorabkennung), `depends` als neue Bereiche aufnehmen. Eine Abhängigkeit wird **zuerst im Hub des verlangenden Pakets** gesucht, auch wenn dieser nicht in der Hub-Liste steht, dann in der Hub-Liste (V0.4, Memos 21, 26). Mehrere Treffer in der Hub-Liste führen zum Abbruch wie unter *Paket finden*.
4. Ändert ein neuer Bereich die Wahl eines bereits gewählten Pakets, wird dieses neu gewählt und Schritt 3 wiederholt, bis sich nichts mehr ändert.
5. Erfüllt keine Version alle Bereiche eines Pakets oder passt `requires.aios` bei keiner passenden Version: Abbruch mit einer Liste der Konflikte (Paket, Bereiche, Herkunft je Bereich). Es gibt kein Backtracking über ältere Versionen anderer Pakete.

Zyklen in `depends` sind erlaubt, solange die Bereiche erfüllbar sind. Ein Paket, das in `lock.yaml` steht und dessen Version alle Bereiche weiter erfüllt, bleibt bei dieser Version (kein stilles Update). Ein Update gibt es nur mit `aios --fetch --upgrade [<name>]`.

## Holen — `aios --fetch`

`aios --fetch` holt Pakete ganz in ein Projekt (Anwender-Site, V0.4, Memos 09, 23). Die Skills dazu sind `/aios-fetch` und darüber `/aios-package` (Spec 03).

| CLI | Wirkung |
|---|---|
| `aios --fetch <paket>[<bereich>] [--hub <hub>] [--to <projekt>]` | Paket in `packages:` aufnehmen bzw. dort ändern, auflösen, holen, ausrollen, registrieren |
| `aios --fetch <hub>/<paket>[<bereich>] [--to <projekt>]` | ebenso, aus genau diesem Hub |
| `aios --fetch <paket>[<bereich>] --from <repo> [--to <projekt>]` | ebenso, aus einem Git-Repo außerhalb der Hubs (Pflegeprojekt) |
| `aios --fetch [--to <projekt>]` | Projekt mit `lock.yaml` abgleichen (z. B. nach `git pull`, auf einem anderen Rechner) |
| `aios --fetch --upgrade [<paket>] [--to <projekt>]` | höchste passende Versionen neu wählen |
| `aios --fetch --remove <paket> [--to <projekt>]` | Paket entfernen |
| `aios --library [<suchwort> \| <paket>]` | Pakete der Hubs suchen bzw. Versionen eines Pakets |
| `aios --hubs [add <name> [<url>] \| remove <name>] [--vault]` | Hub-Liste zeigen bzw. ändern |

**Pflegeprojekte:** Mit `--from <repo>` (lokaler Pfad oder URL eines Git-Repos mit `manifest.yaml` und Tags `v<version>`) kommt ein Paket aus diesem Repo, z. B. aus einem Projekt, in dem der Skill gepflegt wird. `packages:` und `lock.yaml` halten das Repo fest (`from`), der Abgleich holt das Paket wieder von dort. Geholt wird auch hier nur eine getaggte Version. Fehlt das Repo beim Abgleich (z. B. ein lokaler Pfad auf einem anderen Rechner), meldet `aios --fetch` das je Paket und nimmt die Version aus dem Cache, wenn sie dort liegt (V0.4, Memo 18, Q4).

**Ziel** ist das Projekt der Session oder `--to <projekt>` (F4). Ein Paket in einem Projekt gilt für dieses Projekt und alle Projekte der Kette darunter, solange dort kein näheres Paket gleichen Namens liegt. Der Skill fragt nach dem Ziel und schlägt das Root-Projekt vor.

**Ablauf:**

1. `packages:` in `<ziel>/.aios/config.yaml` mit dem neuen Eintrag lesen. `packages:` der Projekte darüber wird nicht berücksichtigt.
2. Auflösen (*Resolver*).
3. Pakete in den Cache holen: `git clone --depth 1 --branch v<version> <repo>` nach `~/.aios/packages/<hub>/<name>/<version>/`, Commit-SHA merken. Ein vorhandener Cache-Eintrag wird wiederverwendet, wenn sein Commit zu `lock.yaml` passt.
4. Vorschau: je Paket `new`, `upgrade X → Y`, `remove`, `unchanged` mit Hub; Dateien, die sich in `@!Package/<name>/` ändern; direkt geänderte Kopien; Arbeitspferde mit ihren Skripten; Änderungen an `config.yaml` und `lock.yaml`.
5. Nach Ja: je Paket den Inhalt ohne `.git` nach `<ziel>/@/@!Package/<name>/` spiegeln (nur dieser Ordner), die Marke schreiben, `packages:` und `lock.yaml` schreiben. Skripte der Arbeitspferde führt `aios --fetch` nicht aus; es nennt je Arbeitspferd den Befehl `aios --worker <paket>/<name> install` (*Arbeitspferde*).
6. Ausrollen: Ein neu geholtes Paket wirkt mit **allen** Elementen, solange `packages:` keine Auswahl `only` nennt (V0.4, Memo 24, H2).
7. Projekt-Skills im Projekt der Session registrieren (Spec 03).

**Jedes Projekt ist in sich vollständig** (V0.4, Memo 17): Abhängigkeiten werden immer in dasselbe Ziel geholt wie das Paket, das sie verlangt, auch wenn ein Projekt darüber dasselbe Paket schon hat. `lock.yaml` eines Projekts beschreibt damit alles, was es braucht, und Änderungen an Paketen darüber können es nicht brechen. Liegt dasselbe Paket in der Kette mehrfach, gilt das nächstgelegene (*Vorrang*).

**Marke `.aios-deploy`** (F3): `@!Package/<name>/.aios-deploy` mit `name`, `version`, `hub`, `repo`, `commit` und `digest` (Verfahren wie Spec 04, *`.aios/registry`*, über alle Dateien des Pakets ohne die Marke). Weicht der Inhalt vom `digest` ab, meldet `aios --fetch` die Kopie als „direkt geändert" und ersetzt sie nach Rückfrage.

**Abgleich ohne Argument:** Für jedes Paket aus `lock.yaml` des Ziels prüfen, ob `@!Package/<name>/` mit Version und `digest` übereinstimmt. Fehlende, abweichende und direkt geänderte Kopien werden aus dem Cache bzw. dem Hub neu gespiegelt. Ein Paketordner mit Marke, der in `lock.yaml` nicht mehr steht, wird nach Rückfrage entfernt.

**Entfernen:** `--remove <paket>` entfernt den Eintrag aus `packages:`, löst neu auf, bricht ab, solange ein Arbeitspferd des Pakets installiert ist (Hinweis auf `aios --worker <paket>/<name> remove`), und entfernt `@!Package/<name>/` sowie Pakete, die nur noch als Abhängigkeit dieses Pakets im Ziel lagen. Projekte darunter sind davon nicht betroffen, weil sie ihre Abhängigkeiten selbst enthalten. Verlangt ein anderes Paket es noch, bricht `--remove` mit dieser Angabe ab.

## Ausrollen — `aios --deploy`

Ausrollen legt fest, **welche Elemente** eines geholten Pakets im Projekt wirken (V0.4, Memos 23, 24). Es kopiert nichts; es ändert nur die Auswahl `only` in `packages:`. Der Skill dazu ist `/aios-deploy` (Spec 03).

| CLI | Wirkung |
|---|---|
| `aios --deploy <paket> --only <element>… [--to <projekt>]` | nur diese Elemente des Pakets wirken (`only:` in `packages:`) |
| `aios --deploy <paket> --all [--to <projekt>]` | alle Elemente wirken (`only:` entfernt) |
| `aios --deploy [--to <projekt>]` | zeigt je Paket die Elemente und ob sie ausgerollt sind; schreibt nichts |

Nach einer Änderung registriert `aios --deploy` die Projekt-Skills im Projekt der Session neu (Spec 03). Ein Element, das das Paket nicht hat, ist ein Fehler. `only` gilt nur für Pakete aus `packages:`; Abhängigkeiten werden immer ganz ausgerollt (H4).

**Nicht ausgerollte Elemente wirken nicht** (H3): Sie werden nicht registriert, nicht als Assistent aufgelöst, ihr Wissen kommt nicht in den Master-Kontext, und ihre Befehle sind nicht aufrufbar. `/aios-context` nennt sie als „fetched, not deployed".

### Wirkung ausgerollter Elemente

Ein ausgerolltes Element wirkt über die Masterspace-Kette (Spec 02, 03):

| Element | Wirkung |
|---|---|
| `skills/<name>/` | Projekt-Skill wie ein Blueprint `@!Skill/<name>/` desselben Masterspace; wird registriert (Spec 03) |
| `assistants/<name>/` | Assistent wie `@!Assistant/<name>/` desselben Masterspace; zuordnen mit `/aios-assistant` |
| `knowledge/` | Teil des Masterspace: Dateien darin werden nach den Klassen von Spec 02 eingeteilt, als lägen sie direkt in `@/` (K6); Pfadangaben im Master-Kontext nennen den Ort in `@!Package/<name>/knowledge/` |
| `commands/<name>` | aufrufbar mit `aios --run <name> [argumente]` in Projekten, für die das Paket gilt |
| `gui` | Oberfläche einer App; der Skill dieses Namens zeigt sie. `/aios-gui` listet die Oberflächen ausgerollter Apps unter der Kachel *Apps* (Spec 03, *Oberflächen*) |

**Vorrang** (V0.4, Memo 12): Zuerst gilt der nächstgelegene Masterspace (Spec 01, Grundregel 3). Innerhalb eines Masterspace gewinnt ein lokaler Blueprint in `@!Skill/` bzw. `@!Assistant/` vor einem Element gleichen Namens aus `@!Package/`. `/aios-context` meldet jede solche Verdeckung. Zwei Pakete mit Elementen gleichen Namens im selben Masterspace sind ein Fehler, den `aios --fetch` vor dem Schreiben meldet.

## Konfiguration und Lock

`<ziel>/.aios/config.yaml` nennt unter `packages:` die gewünschten Pakete (Spec 04). Ein Eintrag ist ein Bereich oder eine Abbildung mit `range` und optional `hub`, `from` und `only`:

```yaml
aios: 0.4.0
packages:
  app-taschenrechner: "~=0.1.0"
  knowledge-scorpio: {range: "~=0.1.0", hub: aibex-hub}
  skill-sammlung: {range: "~=1.0", only: [memo]}
assistant: none
```

`<ziel>/.aios/lock.yaml` schreibt nur AIOS. Es ist versioniert:

```yaml
# written by AIOS (fetch, workspace), do not edit
schema: 1
packages:
  app-taschenrechner:
    version: 0.1.0
    hub: aibex-aios
    repo: https://github.com/aibex-aios/app-taschenrechner
    tag: v0.1.0
    commit: 3f2a…
    requested: "~=0.1.0"
  skill-memo:
    version: 6.0.0
    hub: aibex-aios
    repo: https://github.com/aibex-aios/skill-memo
    tag: v6.0.0
    commit: 9c1d…
    required_by: [app-taschenrechner]
workspace:
  AA-AIbex-AIOS: 8f31…
```

`requested` steht bei Paketen aus `packages:`, `required_by` bei Abhängigkeiten, `from` statt `hub` bei Paketen aus einem Pflegeprojekt. `workspace` hält den eingefrorenen Stand eines Workspace (unten). `lock.yaml` wird mit PyYAML gelesen.

## Arbeitspferde

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
| Aufruf | `aios --worker <paket>/<name> install\|remove\|start\|stop [--to <projekt>]`, für ein Paket in `@!Package/` des Ziels (Projekt der Session oder `--to`); `aios --worker` ohne Argument zeigt die Arbeitspferde des Projekts mit ihrem Stand |
| Bestätigung | jedes Skript nur nach eigener Bestätigung: Plan mit Pfad und Inhalt des Skripts, dann `--yes` (Spec 01, I7). `aios --fetch` führt keine Skripte aus, auch nicht mit `--yes`; es nennt den Befehl für `install` (V0.4, Memo 41) |
| Ausführung | mit `bash`, Arbeitsverzeichnis `@!Package/<name>/`, Umgebung `AIOS_PACKAGE` (Ordner des Pakets), `AIOS_PROJECT`, `AIOS_DATA` (= `<projekt>/@Data/<name>/`) |
| Stand | je Rechner in `~/.aios/workers.yaml` (installiert ja/nein, Version), nicht im Projekt-Repo; `start` und `stop` nur für installierte Arbeitspferde |
| Entfernen | `aios --fetch --remove` bricht ab, solange ein Arbeitspferd des Pakets installiert ist |
| Fehler | Exit ≠ 0 bei `install`: AIOS ruft `remove` auf und meldet beides; das Arbeitspferd gilt als nicht installiert |

Arbeitspferde gehören zum Paket, nicht zu einem Element; `only` schaltet sie nicht ab.

## Umstellung von v0.3

`skills:` und `assistants:` aus v0.3 gehen in `packages:` auf (V0.4, Memos 09, 47). Die Namen werden nach der Art abgebildet: `skills: <name>` ist das Paket `skill-<name>`, `assistants: <name>` das Paket `assistent-<name>` (`memo` → `skill-memo`, `gaertner` → `assistent-gaertner`). Einträge der Form `<assistant>/<skill>` haben kein Paket und werden mit Warnung übergangen.

**Lesen:** Bis zur Umstellung liest v0.4 beide Schlüssel als gewünschte Pakete mit dem Standardbereich der alten Version (`memo: 6.0.0` gilt als `skill-memo: "~=6.0"`). Ein Eintrag ohne Paket in der Hub-Liste wird mit Warnung übergangen. Geschrieben wird dabei nichts.

**Umstellung:** `aios --activate v0.4.<n> <pfad>` bietet sie für `<pfad>` und alle Projekte darunter an, im selben Plan wie die Aktivierung und mit derselben Bestätigung. Je Eintrag gilt: Gibt es die alte Version im Hub, wird der Standardbereich dieser Version eingetragen; sonst die höchste Version, und der Plan nennt den Wechsel (z. B. `astronom` 0.1.0 → `assistent-astronom` 0.2.0). Die Umstellung schreibt die Einträge nach `packages:`, entfernt sie aus `skills:` bzw. `assistants:`, entfernt die Blueprints mit Marke aus `@!Skill/` und `@!Assistant/` und holt die Pakete (wie `aios --fetch`). Lokale Blueprints ohne Marke und Einträge ohne Paket bleiben. Weil die `.gitignore`-Vorlage jetzt `.aios/registry` statt `.aios/manifest` enthält (Spec 04), melden Konsistenzprüfung und `/aios-integrity` in Projekten aus v0.3 die fehlende Zeile; `aios --init` ergänzt sie.

## Daten von Apps — `@Data/`

Daten, die eine App im Projekt erzeugt, liegen in `<projekt>/@Data/<paket>/` (F6). `@Data/` ist ein Schlüsselordner wie `@Memo/`: Er gehört nicht zum Masterspace, wird nicht in den Kontext geladen und ist versioniert. Die App legt `@Data/<paket>/` selbst an, wenn sie zum ersten Mal schreibt (V0.4, Memo 18, Q3). `aios --fetch --remove` lässt `@Data/` unberührt.

## Workspaces

Ein **Workspace** ist ein AIOS-Projekt, das in `.aios/workspace.yaml` Repos mit Revision und Pfad nennt (V0.4, Memo 10). Das Projekt mit dieser Datei ist das **Wurzelprojekt** des Workspace. Es hat ein eigenes Repo; die Projekte des Workspace liegen darunter, verschachtelt, und sind im jeweils darüberliegenden Repo ausgeschlossen (Spec 05, S4). Ein Paket im Workspace liegt als Checkout an seinem Pfad (Entwickler-Site), in einem Vault als Kopie in `@!Package/` (Anwender-Site).

Ein **Projekt des Workspace** ist ein Repo an seinem Pfad. Mit `@/` ist es zugleich ein AIOS-Projekt. Ohne `@/` ist es ein **Fremd-Repo**, z. B. ein Paket-Repo oder das Code-Repo: kein Container, nicht Teil des Master-Kontexts, und `aios --integrity` prüft es nur über `workspace.yaml` (V0.4, Memo 18, L2). Projekte des Workspace müssen keine Pakete sein.

`aios --workspace` arbeitet nur in einem mit AIOS aktivierten Vault (Spec 01, I4).

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
  - name: app-taschenrechner
    remote: aibex
    revision: v0.1.0
    path: AT-Taschenrechner/app-taschenrechner
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
| `aios --workspace init <repo> [<ordner>] [--group <g>…]` | Wurzelprojekt nach `<ordner>` klonen (Standard: Name des Repos, im Ordner der Session), dann alle Projekte aus seiner `workspace.yaml` |
| `aios --workspace update [<pfad>] [--group <g>…]` | fehlende Projekte klonen, vorhandene auf die Revision bringen |
| `aios --workspace freeze [<pfad>]` | Commit-SHA jedes Projekts in `lock.yaml` des Wurzelprojekts schreiben (Abschnitt `workspace`) |
| `aios --workspace status [<pfad>]` | je Projekt: vorhanden, Zweig, Revision enthalten, voraus/hinter dem Remote, offene Änderungen |

`<pfad>` ist das Wurzelprojekt oder ein Ordner darunter; AIOS sucht die nächste `workspace.yaml` aufwärts. Ohne `--group` gelten alle Projekte; mit `--group` nur Projekte dieser Gruppen und Projekte ohne Gruppe.

**Klonen:** `git clone <url> <path>`. Ist `revision` ein Zweig, wird er ausgecheckt. Ist sie ein Tag oder Commit, legt AIOS einen lokalen Zweig `ws/<revision>` an diesem Commit an und checkt ihn aus. Es gibt kein *detached HEAD* (V0.4, Memo 10). Danach trägt AIOS `/<path>/` in die `.gitignore` des Repos darüber ein, wenn sie fehlt, und committet nur diese Zeile („AIOS: <path> als Projekt des Workspace ausgeschlossen", I9).

**Update** (nur fast-forward): Ist `revision` ein Zweig, `git fetch` und `git merge --ff-only origin/<zweig>`. Ist sie ein Tag oder Commit und enthält der ausgecheckte Zweig ihn nicht, wird der Zweig per fast-forward auf diesen Commit gesetzt, wenn das möglich ist. Ist ein fast-forward nicht möglich (eigene Commits, nicht committete Änderungen, anderer Zweig ausgecheckt), lässt AIOS das Projekt unverändert und meldet es mit dem Grund. `update` schreibt nichts in die Projekte außer durch Klonen und fast-forward.

**Status** zeigt eine Tabelle wie `aios --integrity` (Spec 05):

```
Workspace A-AIOS — 2026-10-21

Project          Path                     Branch    Revision   Remote   Changes
AA-AIbex-AIOS    AA-AIbex-AIOS            main      ok         ok       ok
app-taschenrechner AT-Taschenrechner/…    ws/v0.1.0 ok         —        2 changed
aibex-aios       AB-Code/aibex-aios       —         missing    —        —
```

Alle Befehle außer `status` sind schreibend und folgen I7 (Plan, `--plan`, `--yes`).

## Rückfluss — `aios --contribute`

Ein Rückfluss bringt Dateien von der Anwender-Site zurück in ein Paket-Repo seines Hubs (V0.4, Memo 11). Er ist kein Modul.

`aios --contribute <datei>… --to <paket> [--message <text>]`:

1. Paket aus `lock.yaml` der Kette bestimmen (Hub und Repo), `gh` und Anmeldung prüfen; ohne Zugang: Meldung, nichts anlegen.
2. Plan: Repo, Zweig `contrib/<gh-user>/<datum>-<kurzname>`, Ziel `contrib/<gh-user>/<dateiname>`, Titel des Pull Requests.
3. Nach Ja: Repo in ein temporäres Verzeichnis klonen (bei fehlenden Schreibrechten einen Fork), Zweig anlegen, Dateien kopieren, committen, pushen und mit `gh pr create` den Pull Request gegen den Standardzweig anlegen. Ausgabe: URL des Pull Requests.

Der Maintainer prüft und übernimmt den Beitrag in den Inhalt des Pakets, beim Taschenrechner nach `knowledge/@!Kacheln/` (unten), und taggt eine neue Version. Mit `aios --fetch --upgrade` kommt er zu anderen Usern (V0.4, Memo 19, L3). Wird ein Beitrag als eigenes Paket veröffentlicht (z. B. `type: knowledge`), ist er ein Paket, aber kein Modul (V0.4, Memo 11).

**Tests:** `gh` wird nicht umgelenkt. Die Tests legen eine Attrappe für `gh` in den `PATH` des Sandkastens, Zweig und Push gehen in einen Hub unter `file://` (V0.4, Memo 19, L4).

## Demo-App Taschenrechner

Paket `app-taschenrechner` (`type: app`) im Repo `aibex-aios/app-taschenrechner`, Version `0.1.0`. Es zeigt Holen, Version, Abgleich und Rückfluss (V0.4, Memos 01, 05).

| Element | Inhalt |
|---|---|
| Skill `taschenrechner-gui` | Oberfläche (`gui.yaml`) mit einem HTML-Teil `rechner.html` |
| Skill `taschenrechner` | speichert, liest und listet Kachel-Funktionen in `@Data/app-taschenrechner/kacheln.yaml`; bietet mitgelieferte Kacheln an |
| `knowledge` | `knowledge/@!Kacheln/<name>.yaml`: mitgelieferte Kacheln, verborgen (Spec 02), also nicht im Kontext |
| Tasten | `0`–`9`, `.`, `+`, `−`, `×`, `÷`, `=`, `C`, vier Kacheln `K1`–`K4`, **Lernen**; `× =` rechnet mit der aktuellen Zahl (Quadrat), ein zweites `=` wiederholt die letzte Rechnung (V0.4, Memo 49) |
| Lernen | erster Druck startet die Aufnahme der folgenden Tasten, zweiter Druck beendet sie; die nächste gedrückte Kachel übernimmt die Folge |
| Kachel | spielt ihre Tastenfolge ab, als würde sie getippt |
| Speichern | Der HTML-Teil kann keine Dateien schreiben. Nach dem Belegen einer Kachel sendet er mit `sendPrompt` eine Nachricht an Claude, die den Skill `taschenrechner` aufruft und die Belegung speichert (Spec 01, I7: Claude zeigt, was gespeichert wird). Beim Öffnen setzt `aios --gui --skill taschenrechner-gui --html` die Datei über den Platzhalter `{{aios-data kacheln.yaml}}` in den HTML-Teil ein (Spec 03) |
| Mitgeliefert | Der Skill `taschenrechner` zeigt die Kacheln aus `knowledge/@!Kacheln/` als „mitgeliefert" und übernimmt eine davon auf Wunsch in `@Data/app-taschenrechner/kacheln.yaml` (V0.4, Memo 19, L3) |
| Rückfluss | `aios --contribute @Data/app-taschenrechner/kacheln.yaml --to app-taschenrechner` |

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
| P1 | AIOS schreibt in `@!Package/` nur mit `aios --fetch` und nur ganze Paketordner mit Marke. |
| P2 | `lock.yaml` schreiben nur `aios --fetch` und `aios --workspace freeze`. |
| P3 | Skripte eines Pakets (Arbeitspferde, Befehle) laufen nie ohne Bestätigung, außer `aios --run` mit einem Befehl, den der User selbst aufruft. |
| P4 | `aios --workspace` verschiebt keinen Zweig außer per fast-forward und verwirft nie Änderungen. |
| P5 | `aios --contribute` schreibt nur in einen neuen Zweig; es pusht nie auf den Standardzweig. |
| P6 | `@Data/` wird von keinem Befehl außer der App selbst geändert; `--remove` lässt ihn stehen. |
| P7 | `aios --deploy` kopiert nichts; es ändert nur `only` in `packages:`. |

## Entschiedene Festlegungen

Die beim Schreiben getroffenen Festlegungen sind entschieden: S1–S9 in V0.4, Memo 17 (S9 als „jedes Projekt ist in sich vollständig"), L1–L6 und Q1–Q7 in den Memos 18–20, Hubs und Hub-Liste in den Memos 21, 22, 25 und 26, holen und ausrollen mit H1–H5 in den Memos 23–26, die Wissenspakete in Memo 27.
