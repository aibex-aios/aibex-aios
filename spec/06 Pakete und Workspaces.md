---
title: "Pakete und Workspaces"
date: 2026-10-25
author: iHux
status: Spec
tags: [spec, aios, v0.5, pakete, workspaces]
number: 06
related:
  - "Spec 01 AIbex AIOS v0.5 — Überblick"
  - "Spec 02 Master-Kontext"
  - "Spec 03 Skills und Assistenten"
  - "Spec 04 Installation und Konfiguration"
  - "Spec 05 Projekte"
  - "Spec 07 Arbeitspferde"
  - "Memos 01–29 (AA-AIbex-AIOS, @Memo/V0.4)"
  - "Memos 05, 07, 08, 11–37 (AA-AIbex-AIOS, @Memo/V0.5)"
---

# Pakete und Workspaces

Diese Spec regelt Pakete und Module: das Paket-Manifest `manifest.yaml`, Versionen und Bereiche, Hubs und die Hub-Liste, den Resolver, das Holen eines Pakets mit `aios --fetch`, das Ausrollen seiner Elemente mit `aios --deploy`, den aufgelösten Stand in `.aios/lock.yaml`, Distributionen, Workspaces mit `.aios/workspace.yaml` und `aios --workspace`, den Rückfluss mit `aios --contribute`, die Daten der Pakete in `@Data/` und die Demo-App Taschenrechner. Arbeitspferde (`type: worker`) stehen in Spec 07. Die Begriffe stehen in Spec 01, die Auflösung entlang der Kette in Spec 02 und 03, die Skills `/aios-package`, `/aios-fetch` und `/aios-deploy` in Spec 03, Dateistrukturen und CLI in Spec 04, Struktur und Integrität von Projekten in Spec 05. Die Gegenüberstellung mit Zephyr steht in V0.4, Memo 14.

## Pakete

Ein **Paket** ist eine versionierte Einheit aus einem oder mehreren Elementen, die eine Datei `manifest.yaml` beschreibt. **Elemente** sind die Teile, die in einem Projekt wirken: Skills, Assistenten, Wissen und Befehle. Ein **Modul** ist ein Paket, nach dessen Holen AIOS etwas Neues kann. Eine **App** ist ein Modul, das der Anwender direkt benutzt. Eine **Distribution** ist ein Paket, das optional einen Kernel und andere Pakete in exakten Versionen zusammenstellt (*Distributionen*; V0.4, Memos 04, 07; V0.5, Memos 25–27). Ein **Arbeitspferd** ist ein Paket vom Typ `worker` (Spec 07).

Jedes Paket liegt in einem eigenen Git-Repo in einem Hub. Eine Version ist ein Tag `v<version>` in diesem Repo, und `version` in `manifest.yaml` des getaggten Stands muss übereinstimmen. Der Kernel von AIOS ist ebenfalls ein Paket (`type: kernel`, Name `aios`, Repo `aibex-aios/aibex-aios`), wird aber mit `aios --install` installiert, nicht geholt (Spec 04).

**Paketnamen:** `<typ>-<name>`, die Art gleich dem Typ: `app-`, `assistant-`, `skill-`, `knowledge-`, `tutorial-`, `distribution-`, `worker-`; der Kernel heißt `aios` (V0.5, Memos 05, 15). AIOS wertet nur `type` aus; das Schema ist eine Konvention, die die Pakete von AIbex einhalten.

Für Pakete gelten drei Verben (V0.4, Memos 23, 24):

| Verb | Gegenstand | Bedeutung | CLI |
|---|---|---|---|
| **holen** (fetch) | Paket | eine Version eines Pakets ganz vom Hub ins Projekt holen | `aios --fetch` |
| **ausrollen** (deploy) | Element | festlegen, welche Elemente eines geholten Pakets im Projekt wirken; ohne Kopie | `aios --deploy` |
| **registrieren** (register) | Skill | ausgerollte Skills dem Host bekannt machen (Spec 03) | `aios --register` |

**Installieren** heißt, etwas auf den Rechner zu bringen: den Kernel und Arbeitspferde (je Version, nebeneinander) und Distributionen (Kernel, Arbeitspferde und, in einen Vault, ihre Pakete; Spec 04, 07). Für andere Pakete ist es nur ein Wort der Anwender, das `/aios-package` versteht.

### Aufbau eines Paket-Repos

```
<paket>/
├── manifest.yaml                   Pflicht
├── skills/<name>/SKILL.md          Skills (Format Spec 03)
├── assistants/<name>/ASSISTANT.md  Assistenten (Aufbau Spec 03)
├── knowledge/                      Wissen, mit Klassen wie ein Masterspace (Spec 02)
├── commands/<name>                 Befehle (ausführbar)
├── worker/                         Datei mit Hashes bzw. Skripte eines Arbeitspferds (nur type: worker, Spec 07)
├── contrib/<user>/…                Rückflüsse (aios --contribute)
└── README.md                       optional
```

Nur `manifest.yaml` ist Pflicht. Welche Ordner ein Paket hat, nennt `contents`.

### `manifest.yaml`

```yaml
name: app-taschenrechner
version: 0.1.0
type: app
description: Programmierbarer Taschenrechner mit lernenden Funktionstasten (Demo-App von AIOS)
requires:
  aios: ">=0.4,<0.6"
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
| `type` | ja | `kernel`, `app`, `assistant`, `skill`, `knowledge`, `tutorial`, `distribution`, `worker`; unbekannte Werte werden mit Warnung als `knowledge` behandelt |
| `description` | ja | ein Satz |
| `requires` | ja | `aios: "<bereich>"`, Bereich der AIOS-Version, in der das Paket läuft |
| `depends` | nein | Name → Bereich anderer Pakete; `aios` ist hier nicht erlaubt, dafür gibt es `requires` |
| `contents` | nein | `skills`, `assistants`, `commands`, `hooks` (Listen von Namen), `knowledge` (`true`), `gui` (Name eines Skills aus `skills`) |
| `worker` | bei `type: worker` | Art, Programme, Prüfung und Bauanleitung des Arbeitspferds (Spec 07); bei anderen Typen nicht erlaubt |
| `kernel` | nein | nur bei `type: distribution`: `"==<version>"` des Kernels (*Distributionen*) |
| `license` | nein | SPDX-Kennung oder Freitext |
| `userdata` | nein | beliebige Daten; AIOS wertet sie nicht aus |

`manifest.yaml` wird mit PyYAML gelesen. Ein Paket ist ein **Modul**, wenn `type` `kernel`, `app`, `assistant`, `skill` oder `worker` ist oder `contents` mindestens einen Skill, Assistenten, Befehl oder Hook nennt. Pakete vom Typ `knowledge`, `tutorial` und `distribution` ohne solche Inhalte sind keine Module (V0.4, Memo 04). Ein `worker` ist ein Modul ohne Elemente: Ausrollen, `only` und Registrieren wirken nicht (V0.5, Memo 30).

**Elemente** eines Pakets und ihre Namen beim Ausrollen: jeder Skill und jeder Assistent unter seinem Namen, jeder Befehl unter seinem Namen und das Wissen als `knowledge`. Die Namen sind innerhalb eines Pakets eindeutig.

**Prüfung beim Holen:** Jeder in `contents` genannte Name muss als Ordner bzw. Datei vorhanden sein, jeder Skill braucht eine gültige `version` (Spec 03), `gui` muss in `skills` stehen, Elementnamen dürfen sich nicht wiederholen. Bei `type: worker` gelten die Regeln von Spec 07 (`kind`, `programs`, Datei mit Hashes bzw. Skripte), bei `type: distribution` exakte Versionen (`==`) in `kernel` und `depends`. Ein Paket mit dem Feld `workers:` aus v0.4 wird abgelehnt, mit Hinweis auf `type: worker` (V0.5, Memo 30, L9). Ein Paket, das die Prüfung nicht besteht, wird nicht geholt.

**Hooks** (`contents.hooks`) sind im Format vorgesehen, in v0.5 aber ohne Wirkung: `aios --fetch` meldet sie und holt das Paket ohne sie.

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

Der Standard-Hub ist `aibex-aios` (`https://github.com/aibex-aios`). Für Tests gibt es einen zweiten Hub `aibex-hub` (V0.4, Memos 27, 28).

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

**Pflege:** `aios --hubs` zeigt die Liste mit Herkunft (Vault, Home). `aios --hubs add <name> [<url>] [--vault]` und `aios --hubs remove <name> [--vault]` ändern sie in Home bzw. mit `--vault` an der Vault-Root, mit Plan und Bestätigung (Spec 01, I7). Legt `add` die erste Hub-Liste an (es gibt noch keinen Eintrag `hubs:`), übernimmt AIOS den Standard-Hub `aibex-aios` an erster Stelle, damit er weiter gilt (V0.4, Memo 60). `/aios-package` versteht Sätze wie „füge den Hub aibex-hub hinzu" (V0.4, Memo 25).

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
    description: Programmierbarer Taschenrechner mit lernenden Funktionstasten
```

Der Index dient nur der Suche: `aios --library [<suchwort>]` listet je Hub der Hub-Liste die Pakete aus `index.yaml`; ohne Index bei GitHub-Hubs die Repos mit dem Topic **`aios-package`** (über `gh`). Ein Hub ohne beides lässt sich nicht durchsuchen, nur mit bekanntem Namen holen. `aios --library <paket>` zeigt die Versionen eines Pakets (aus den Tags), `aios --library <hub>/<paket>` nur die aus diesem Hub, auch außerhalb der Hub-Liste. Den Index holt AIOS mit `git clone --depth 1` bzw. `git pull` nach `~/.aios/hub/<hub>/`.

**Zugriff aufs Netz:** Nur `aios --fetch`, `aios --install`, `aios --library`, `aios --workspace` und `aios --contribute` greifen auf das Netz zu, und nur über `git` bzw. `gh` mit den Zugangsdaten des Users sowie über `pip` beim setup eines Arbeitspferds (Spec 07). Ohne Netz arbeitet `aios --fetch` ohne Argument mit dem Cache, wenn alle Versionen aus `lock.yaml` dort liegen.

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
| `aios --fetch <paket>[<bereich>] [--hub <hub>] [--to <projekt>]` | Paket in `packages:` aufnehmen bzw. dort ändern, auflösen, holen, Arbeitspferde einrichten, ausrollen, registrieren (**Paket laden**) |
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
4. Vorschau: je Paket `new`, `upgrade X → Y`, `remove`, `unchanged` mit Hub; Dateien, die sich in `@!Package/<name>/` ändern; direkt geänderte Kopien; je Arbeitspferd, das auf dem Rechner fehlt, das setup mit seinem Inhalt (Spec 07, *Abläufe*); Versionen von Arbeitspferden, die entfernt werden; Änderungen an `config.yaml` und `lock.yaml`.
5. Nach Ja: Sicherung anlegen (unten); je Paket den Inhalt ohne `.git` nach `<ziel>/@/@!Package/<name>/` spiegeln (nur dieser Ordner), die Marke schreiben, `packages:` und `lock.yaml` schreiben.
6. Arbeitspferde einrichten (setup, Spec 07), Abhängigkeiten zuerst; nicht mehr genutzte Versionen entfernen.
7. Ausrollen: Ein neu geholtes Paket wirkt mit **allen** Elementen, solange `packages:` keine Auswahl `only` nennt (V0.4, Memo 24, H2).
8. Projekt-Skills im Projekt der Session registrieren (Spec 03), **erst nach erfolgreichem setup** (V0.5, Memo 17).
9. Sicherung löschen.

**Alles oder nichts** (Spec 01, I11): Scheitert ein Schritt ab 5, stellt AIOS die Dateien aus der Sicherung wieder her und meldet den Schritt; der Vault steht wie vor dem Plan, registriert wird nichts. Die **Sicherung** liegt während des Plans unter `<ziel>/.aios/backup/` und enthält genau, was der Plan ändert: `.aios/config.yaml`, `.aios/lock.yaml`, die betroffenen Ordner in `@/@!Package/` und die Registrierung (`.claude/skills/`, `.aios/registry`) des Projekts der Session. Bleibt sie nach einem Abbruch liegen (z. B. Absturz), meldet `aios --fetch` sie und bietet die Wiederherstellung an (V0.5, Memos 28, 29). Das Repo des Projekts muss dafür nicht sauber sein.

**Jedes Projekt ist in sich vollständig** (V0.4, Memo 17): Abhängigkeiten werden immer in dasselbe Ziel geholt wie das Paket, das sie verlangt, auch wenn ein Projekt darüber dasselbe Paket schon hat. `lock.yaml` eines Projekts beschreibt damit alles, was es braucht, und Änderungen an Paketen darüber können es nicht brechen. Liegt dasselbe Paket in der Kette mehrfach, gilt das nächstgelegene (*Vorrang*).

**Marke `.aios-deploy`** (F3): `@!Package/<name>/.aios-deploy` mit `name`, `version`, `hub`, `repo`, `commit` und `digest` (Verfahren wie Spec 04, *`.aios/registry`*, über alle Dateien des Pakets ohne die Marke). Weicht der Inhalt vom `digest` ab, meldet `aios --fetch` die Kopie als „direkt geändert" und ersetzt sie nach Rückfrage.

**Abgleich ohne Argument:** Für jedes Paket aus `lock.yaml` des Ziels prüfen, ob `@!Package/<name>/` mit Version und `digest` übereinstimmt. Fehlende, abweichende und direkt geänderte Kopien werden aus dem Cache bzw. dem Hub neu gespiegelt. Arbeitspferde aus `lock.yaml`, deren Version auf dem Rechner fehlt (z. B. auf einem zweiten Rechner), werden im selben Plan eingerichtet (V0.5, Memo 29). Ein Paketordner mit Marke, der in `lock.yaml` nicht mehr steht, wird nach Rückfrage entfernt.

**Entfernen:** `--remove <paket>` entfernt den Eintrag aus `packages:`, löst neu auf und entfernt `@!Package/<name>/` sowie Pakete, die nur noch als Abhängigkeit dieses Pakets im Ziel lagen. Projekte darunter sind davon nicht betroffen, weil sie ihre Abhängigkeiten selbst enthalten. Verlangt ein anderes Paket es noch, bricht `--remove` mit dieser Angabe ab. Für ein Arbeitspferd wird das Projekt aus `workers.yaml` entfernt; eine Version, die kein Projekt mehr nutzt, wird im selben Plan entfernt (Spec 07).

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

## Distributionen

Eine Distribution stellt eine geprüfte Zusammenstellung zusammen: optional einen Kernel und Pakete in exakten Versionen (V0.5, Memos 25–27, 34).

```yaml
name: distribution-rothirsch
version: 1.0.0
type: distribution
description: Rothirsch — AIOS mit Video-Analyse und der Assistentin Anja
kernel: "==0.5.0"
depends:
  skill-video-analyse: "==0.2.0"
  assistant-anja: "==0.2.0"
```

| Regel | |
|---|---|
| Versionen | `kernel` und alle Einträge in `depends` mit `==`; neue Stände sind eine neue Version der Distribution, deren Version unabhängig von der des Kernels ist |
| Kernel | `kernel:` ist optional; ohne `kernel:` ist die Distribution eine reine Sammlung von Paketen, und `requires.aios` aller Pakete muss zum gebundenen Kernel passen |
| Abhängigkeiten | Abhängigkeiten der Pakete (z. B. `worker-yt-dlp` der Video-Analyse) stehen nicht in `depends`; der Resolver holt sie |
| Installieren | `aios --install distribution-<name> [<vault>] [--from <repo>]` (Spec 04): erst der Rechner (Kernel, Arbeitspferde), dann der Vault (binden, holen, registrieren); ein Plan, ein Ja. Scheitert der Rechnerteil, bleibt der Vault unberührt; schon Installiertes bleibt liegen. Scheitert der Vaultteil, gilt die Sicherung (*Holen*) |
| im Vault | die Distribution steht in `packages:` der Vault-Root (`distribution-rothirsch: "==1.0.0"`), ihre Pakete in `lock.yaml` mit `required_by: [distribution-rothirsch]` |
| eine je Vault | höchstens eine Distribution mit `kernel:` je Vault; eine zweite ist ein Konflikt im Plan; Distributionen ohne `kernel:` dürfen daneben stehen |
| anderer Kernel | ist der Vault an einen anderen Kernel gebunden, zeigt der Plan die Umstellung (`aios: 0.4.0 → 0.5.0`) samt der Umstellung des Vaults (*Umstellung*) und führt sie im selben Plan aus |
| Aktualisieren | `aios --install distribution-<name>` erneut, ohne Version die höchste; der Plan zeigt `upgrade 1.0.0 → 1.1.0` mit Kernel, Arbeitspferden und Paketen |
| Entfernen | `aios --fetch --remove distribution-<name>` nach den allgemeinen Regeln (*Holen*); die Bindung an den Kernel bleibt |
| Übersteuern | nur mit `only` (*Ausrollen*); eine andere Version eines Pakets der Distribution, z. B. durch einen eigenen Eintrag in `packages:`, ist ein Konflikt im Plan |
| `--from` | nimmt die Distribution aus dem Arbeitsbaum eines lokalen Repos (wie `aios --fetch --from`); ihre Pakete kommen weiter aus den Hubs |

Zusammengestellt werden Distributionen mit dem AIOS-Skill `/aios-distribution` (Spec 03).

## Konfiguration und Lock

`<ziel>/.aios/config.yaml` nennt unter `packages:` die gewünschten Pakete (Spec 04). Ein Eintrag ist ein Bereich oder eine Abbildung mit `range` und optional `hub`, `from` und `only`:

```yaml
aios: 0.5.0
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

`requested` steht bei Paketen aus `packages:`, `required_by` bei Abhängigkeiten, `from` statt `hub` bei Paketen aus einem Pflegeprojekt. `workspace` hält den eingefrorenen Stand eines Workspace (unten). AIOS schreibt `lock.yaml` in der festen Untermenge von YAML aus Spec 04, damit die Weiterleiter der Arbeitspferde es ohne PyYAML lesen können (Spec 07); AIOS selbst liest es mit PyYAML.

## Arbeitspferde

Arbeitspferde sind Pakete vom Typ `worker` und stehen in Spec 07. Das Feld `workers:` aus v0.4 gibt es nicht mehr (*Umstellung von v0.4*).

## Umstellung von v0.4

`aios --activate v0.5.<n> <pfad>` stellt `<pfad>` und alle Projekte darunter im selben Plan wie die Aktivierung um (V0.5, Memos 30, 35):

| Bestand | Umstellung |
|---|---|
| `assistent-gaertner`, `assistent-astronom` in `packages:` | umbenannt nach `assistant-gaertner` bzw. `assistant-astronom`; der Plan nennt jede Umbenennung; die Liste der Umbenennungen steht im Kernel |
| Pakete mit `workers:` | werden von v0.5 abgelehnt (*Prüfung beim Holen*); im Bestand gibt es nur das Testpaket `test-worker` |
| `~/.aios/workers.yaml` aus v0.4 | bleibt für Vaults auf v0.4 unberührt; v0.5 liest sie nicht |
| Pakete mit `requires.aios: ">=0.4,<0.5"` | lassen sich unter v0.5 nicht holen; der Plan nennt sie mit der höchsten Version, die zu v0.5 passt, oder als Konflikt |

## Umstellung von v0.3

`skills:` und `assistants:` aus v0.3 gehen in `packages:` auf (V0.4, Memos 09, 47). Die Namen werden nach der Art abgebildet: `skills: <name>` ist das Paket `skill-<name>`, `assistants: <name>` das Paket `assistant-<name>` (`memo` → `skill-memo`, `gaertner` → `assistant-gaertner`; in v0.4 hieß die Art `assistent-`, V0.5, Memo 05). Einträge der Form `<assistant>/<skill>` haben kein Paket und werden mit Warnung übergangen.

**Lesen:** Bis zur Umstellung liest AIOS beide Schlüssel als gewünschte Pakete mit dem Standardbereich der alten Version (`memo: 6.0.0` gilt als `skill-memo: "~=6.0"`). Ein Eintrag ohne Paket in der Hub-Liste wird mit Warnung übergangen. Geschrieben wird dabei nichts.

**Umstellung:** `aios --activate v0.4.<n> <pfad>` bzw. `v0.5.<n>` bietet sie für `<pfad>` und alle Projekte darunter an, im selben Plan wie die Aktivierung und mit derselben Bestätigung. Je Eintrag gilt: Gibt es die alte Version im Hub, wird der Standardbereich dieser Version eingetragen; sonst die höchste Version, und der Plan nennt den Wechsel (z. B. `astronom` 0.1.0 → `assistant-astronom` 0.2.0). Die Umstellung schreibt die Einträge nach `packages:`, entfernt sie aus `skills:` bzw. `assistants:`, entfernt die Blueprints mit Marke aus `@!Skill/` und `@!Assistant/` und holt die Pakete (wie `aios --fetch`). Lokale Blueprints ohne Marke und Einträge ohne Paket bleiben. Ein Blueprint mit Marke, dessen Inhalt nicht mehr zu ihrem `digest` passt (direkt geändert), bleibt ebenfalls: AIOS entfernt nur die Marke, er gilt damit als lokaler Blueprint und verdeckt das Paket (S6); der Plan nennt ihn mit „changed directly, stays as local blueprint" (V0.4, Memo 73, B6). Weil die `.gitignore`-Vorlage jetzt `.aios/registry` statt `.aios/manifest` enthält (Spec 04), melden Konsistenzprüfung und `/aios-integrity` in Projekten aus v0.3 die fehlende Zeile; `aios --init` ergänzt sie.

## Daten der Pakete — `@Data/`

Daten, die ein Paket im Projekt erzeugt, liegen in `<projekt>/@Data/<paket>/` (F6). Das gilt für jedes Paket, dessen Elemente schreiben: Apps, Assistenten und andere (V0.5, Memo 07); ein Assistent schreibt nach `@Data/assistant-<name>/`. Die Daten eines Arbeitspferds liegen unter `@Data/` des Pakets, das sie erzeugt, nicht unter `@Data/worker-<name>/` (Spec 07, K7). `@Data/` ist ein Schlüsselordner wie `@Memo/`: Er gehört nicht zum Masterspace, wird nicht in den Kontext geladen und ist versioniert. Das Paket legt `@Data/<paket>/` selbst an, wenn sie zum ersten Mal schreibt (V0.4, Memo 18, Q3). `aios --fetch --remove` lässt `@Data/` unberührt.

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
| `projects[].import` | nein | im Format vorgesehen, in v0.5 ohne Wirkung; `aios --workspace` meldet ihn und übergeht ihn |

Die Datei wird mit PyYAML gelesen und vom User gepflegt.

### `aios --workspace`

| Befehl | Wirkung |
|---|---|
| `aios --workspace init <repo> [<ordner>] [--group <g>…]` | Wurzelprojekt nach `<ordner>` klonen (Standard: Name des Repos, im Ordner der Session), dann alle Projekte aus seiner `workspace.yaml` |
| `aios --workspace update [<pfad>] [--group <g>…]` | fehlende Projekte klonen, vorhandene auf die Revision bringen |
| `aios --workspace freeze [<pfad>]` | Commit-SHA jedes Projekts in `lock.yaml` des Wurzelprojekts schreiben (Abschnitt `workspace`) |
| `aios --workspace status [<pfad>]` | je Projekt: vorhanden, Zweig, Revision enthalten, voraus/hinter dem Remote, offene Änderungen |

**Init:** Das geklonte Wurzelprojekt wird wie ein Projekt des Workspace behandelt: Ziel ist `<ordner>` im Ordner der Session, in einem aktivierten Vault (I4); liegt darüber ein Repo, trägt AIOS `/<ordner>/` in dessen `.gitignore` ein und committet nur diese Zeile (I9). Gibt es `<ordner>` schon, bricht `init` ab; für einen bestehenden Workspace gilt `update` (V0.4, Memo 57).

`<pfad>` ist das Wurzelprojekt oder ein Ordner darunter; AIOS sucht die nächste `workspace.yaml` aufwärts. Ohne `--group` gelten alle Projekte; mit `--group` nur Projekte dieser Gruppen und Projekte ohne Gruppe.

**Klonen:** `git clone <url> <path>`. Ist `revision` ein Zweig, wird er ausgecheckt. Ist sie ein Tag oder Commit, legt AIOS einen lokalen Zweig `ws/<revision>` an diesem Commit an und checkt ihn aus. Es gibt kein *detached HEAD* (V0.4, Memo 10). Danach trägt AIOS `/<path>/` in die `.gitignore` des Repos darüber ein, wenn sie fehlt, und committet nur diese Zeile („AIOS: <path> als Projekt des Workspace ausgeschlossen", I9).

**Update** (nur fast-forward): Ist `revision` ein Zweig, `git fetch` und `git merge --ff-only origin/<zweig>`. Ist sie ein Tag oder Commit und enthält der ausgecheckte Zweig ihn nicht, wird der Zweig per fast-forward auf diesen Commit gesetzt, wenn das möglich ist. Ist ein fast-forward nicht möglich (eigene Commits, nicht committete Änderungen, anderer Zweig ausgecheckt), lässt AIOS das Projekt unverändert und meldet es mit dem Grund. Ebenso unverändert bleibt ein Ordner am Pfad, der kein Git-Repo ist oder dessen `origin` auf ein anderes Repo zeigt als `workspace.yaml`; `status` und `aios --integrity` zeigen ihn weiter an (V0.4, Memo 57). `update` schreibt nichts in die Projekte außer durch Klonen und fast-forward.

**Freeze** schreibt in `lock.yaml` des Wurzelprojekts den Abschnitt `workspace:` mit `<name>: <commit-sha>` je geklontem Projekt; der Abschnitt `packages:` bleibt, und `aios --fetch` lässt `workspace:` stehen.

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

Jeder Beitrag bekommt einen eigenen Zweig und einen eigenen Pull Request; gibt es den Zweig schon, hängt AIOS `-2`, `-3` … an. Im neuen Zweig ersetzt die Datei `contrib/<gh-user>/<dateiname>` eine frühere desselben Namens; den Verlauf hält Git. Der Pull Request heißt „Beitrag: <dateiname> von <gh-user>" (oder `--message`) und nennt im Text das Paket, die geholte Version und den Commit aus `lock.yaml` (V0.4, Memo 55). Ohne Schreibrechte (`gh api repos/<owner>/<repo>` ohne `permissions.push`) legt AIOS mit `gh repo fork` einen Fork an und pusht den Zweig dorthin.

Der Maintainer prüft und übernimmt den Beitrag in den Inhalt des Pakets, beim Taschenrechner nach `knowledge/@!Funktionstasten/` (unten), und taggt eine neue Version. Mit `aios --fetch --upgrade` kommt er zu anderen Usern (V0.4, Memo 19, L3). Wird ein Beitrag als eigenes Paket veröffentlicht (z. B. `type: knowledge`), ist er ein Paket, aber kein Modul (V0.4, Memo 11).

**Tests:** `gh` wird nicht umgelenkt. Die Tests legen eine Attrappe für `gh` in den `PATH` des Sandkastens, Zweig und Push gehen in einen Hub unter `file://` (V0.4, Memo 19, L4).

## Demo-App Taschenrechner

Paket `app-taschenrechner` (`type: app`) im Repo `aibex-aios/app-taschenrechner`, Version `0.4.2` (Funktionstasten statt Kacheln, V0.4, Memo 54; README mit *LEARN* in 0.4.1, Memo 61; Hinweis zum Speichern im Chat in 0.4.2, Memo 67; ältere Versionen 0.1.x–0.3.x bleiben im Hub). Ein programmierbarer Taschenrechner mit umgekehrter polnischer Notation nach dem Vorbild des HP-15C. Er zeigt Holen, Version, Abgleich und Rückfluss (V0.4, Memos 01, 05, 51).

| Element | Inhalt |
|---|---|
| Skill `taschenrechner-gui` | Oberfläche (`gui.yaml`) mit einem HTML-Teil `rechner.html` |
| Skill `taschenrechner` | speichert, liest und listet Funktionstasten in `@Data/app-taschenrechner/funktionstasten.yaml`; bietet mitgelieferte Funktionstasten an |
| `knowledge` | `knowledge/@!Funktionstasten/<name>.yaml`: mitgelieferte Funktionstasten, verborgen (Spec 02), also nicht im Kontext |
| Tasten | vier Funktionstasten `A`–`D`; `7 8 9 ÷`, `4 5 6 ×`, `1 2 3 −`, `0 . CHS +`; unten **LEARN** und **ENTER**, je doppelt breit. Kein `=` und kein `C` (V0.4, Memo 51) |
| Stack | vier Register X, Y, Z, T mit Stack-Lift wie beim HP-15C: eine neue Zahl schiebt den Stack hoch, ENTER kopiert X nach Y und die nächste Zahl überschreibt X, eine Rechnung verknüpft Y mit X (Ergebnis in X, der Stack rückt nach, T bleibt), CHS wechselt das Vorzeichen. Quadrat: `ENTER ×`. Anzeige: X groß, Y klein darüber |
| LEARN | erster Druck startet die Aufnahme der folgenden Tasten, zweiter Druck beendet sie; die nächste gedrückte Funktionstaste übernimmt die Folge |
| Funktionstaste | beendet eine laufende Zahleneingabe und spielt dann ihre Tastenfolge ab, als würde sie getippt (`100` und *plus 19 %* ergibt 119) |
| Speichern | Der HTML-Teil kann keine Dateien schreiben. Nach dem Belegen einer Funktionstaste sendet er mit `sendPrompt` eine Nachricht an Claude, die den Skill `taschenrechner` aufruft und die Belegung speichert (Spec 01, I7: Claude zeigt, was gespeichert wird). Beim Öffnen setzt `aios --gui --skill taschenrechner-gui --html` die Datei über den Platzhalter `{{aios-data funktionstasten.yaml}}` in den HTML-Teil ein (Spec 03) |
| Mitgeliefert | Der Skill `taschenrechner` zeigt die Funktionstasten aus `knowledge/@!Funktionstasten/` als „mitgeliefert" und übernimmt eine davon auf Wunsch in `@Data/app-taschenrechner/funktionstasten.yaml` (V0.4, Memo 19, L3) |
| Rückfluss | `aios --contribute @Data/app-taschenrechner/funktionstasten.yaml --to app-taschenrechner` |

`funktionstasten.yaml`:

```yaml
A:
  title: Quadrat
  keys: ["ENTER", "×"]
B:
  title: plus 19 %
  keys: ["1", ".", "1", "9", "×"]
```

## Invarianten der Pakete

Zusätzlich zu Spec 01 (I1–I9):

| # | Regel |
|---|---|
| P1 | AIOS schreibt in `@!Package/` nur mit `aios --fetch` und nur ganze Paketordner mit Marke. |
| P2 | `lock.yaml` schreiben nur `aios --fetch`, `aios --install` (Distribution), `aios --activate` (Umstellung) und `aios --workspace freeze`. |
| P3 | Skripte und Installationen eines Pakets (setup und remove von Arbeitspferden, Befehle) laufen nie ohne Bestätigung, außer `aios --run` mit einem Befehl, den der User selbst aufruft; der Plan zeigt bei `kind: python` die Pakete, bei Skripten den Inhalt (Spec 07). |
| P4 | `aios --workspace` verschiebt keinen Zweig außer per fast-forward und verwirft nie Änderungen. |
| P5 | `aios --contribute` schreibt nur in einen neuen Zweig; es pusht nie auf den Standardzweig. |
| P6 | `@Data/<paket>/` wird von keinem Befehl außer dem Paket selbst geändert; `--remove` lässt ihn stehen. |
| P7 | `aios --deploy` kopiert nichts; es ändert nur `only` in `packages:`. |
| P8 | Ein Plan mit „alles oder nichts" legt vor dem ersten Schreiben eine Sicherung unter `.aios/backup/` an und löscht sie erst nach Erfolg (Spec 01, I11). |

## Entschiedene Festlegungen

Die beim Schreiben getroffenen Festlegungen sind entschieden: S1–S9 in V0.4, Memo 17 (S9 als „jedes Projekt ist in sich vollständig"), L1–L6 und Q1–Q7 in den Memos 18–20, Hubs und Hub-Liste in den Memos 21, 22, 25 und 26, holen und ausrollen mit H1–H5 in den Memos 23–26, die Wissenspakete in Memo 27. Für v0.5: Arbeitspferde und Paket laden in V0.5, Memos 15–22 und 28–33, Distributionen in den Memos 25–28 und 34, Paketnamen und Umstellung in den Memos 05, 30 und 35, `@Data/` in Memo 07, Skizze in Memo 37.
