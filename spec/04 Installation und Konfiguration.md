---
title: "Installation und Konfiguration"
date: 2026-10-01
author: iHux
status: Spec
tags: [spec, aios, v0.2, installation, konfiguration]
number: 04
related:
  - "Spec 01 AIbex AIOS v0.2 — Überblick"
  - "Spec 02 Master-Kontext"
  - "Spec 03 Skills und Assistenten"
  - "Memo 04 Der Vault §AIOS, Repo und Installation (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 21 Repo ohne Vault und Skill-Gruppen (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 09 Parallele Versionen und Aktivierung je Projekt (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 10 Das Verzeichnis .aios — global, Vault und Projekt (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 12 Umfang von AIOS v0.1.0 — Entscheidungen vor der Spec (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 15 Jeder Skill hat eine Version (Konzeptprojekt PAA-AIbex-AIOS-V0.2)"
  - "Memo 16, 17 Demo-Assistenten (Konzeptprojekt PAA-AIbex-AIOS-V0.2)"
---

# Installation und Konfiguration

Diese Spec regelt, welche Dateien AIOS v0.2 wo anlegt, ihre Formate, die Konfiguration mit Übertrumpfung, die Weiterleiter und das CLI `aios`. Plattformen: macOS und Linux.

## Dateistrukturen

### Rechner — `/opt/aios/`

```
/opt/aios/
├── installations.yaml
├── shared/                         in v0.2 leer
└── v0.2.0/                         unveränderlich
    ├── VERSION
    ├── bin/
    │   ├── aios
    │   └── aios-context
    ├── lib/aios/                   Python-Paket: Logik von aios und aios-context
    ├── skills/
    │   ├── aios/aios-<name>/SKILL.md   AIOS-Skills (vollständig)
    │   └── basic/memo/6.0.0/SKILL.md   mitgelieferte Skills, je Skill-Version
    ├── assistants/
    │   └── demo/gaertner/0.1.0/ASSISTANT.md   Demo-Assistenten, je Version
    ├── templates/
    │   ├── forwarder               Quelle der Weiterleiter in ~/bin
    │   └── gitignore               Vorlage für /aios-init
    ├── doc/
    │   ├── spec/                   die Spec dieser Version (Pflicht)
    │   └── tutorials/              Tutorials (v0.2: Demo-Assistenten)
    └── python/                     venv mit PyYAML, vorkompiliert
```

Künftig kommt `doc/wiki/` hinzu.

| Pfad | angelegt von | Inhalt | änderbar |
|---|---|---|---|
| `/opt/aios/` | `aios --prepare` | gehört dem Benutzer (v0.2: ein Benutzer) | — |
| `/opt/aios/installations.yaml` | `aios --install`, `--remove-version` | Verzeichnis der Installationen | nur durch AIOS |
| `/opt/aios/v<version>/` | `aios --install` | vollständige Installation, danach schreibgeschützt | nie (I5) |

Kann `/opt/aios` nicht angelegt werden (kein `sudo`), gilt statt `/opt/aios` das Verzeichnis `~/.aios/versions/` mit demselben Aufbau.

### Benutzer — `~`

```
~/bin/
├── aios                            Weiterleiter
└── aios-context                    Weiterleiter
~/.aios/
├── config.yaml                     Voreinstellungen
├── installations.yaml              eigene Einträge (z. B. Entwicklungsstand, Ersatzort)
├── repo                            Pfad des Klons, aus dem zuletzt installiert wurde
├── versions/v<version>/            Ersatzort der Installationen ohne sudo
├── hooks-backup.json               vom Installieren ersetzte Hook-Einträge
├── cache/<id>/part-<n>.md          Part-Dateien des Master-Kontexts
└── logs/aios.log
~/.claude/
├── settings.json                   Hooks
└── skills/aios-<name>/SKILL.md     versionsneutrale AIOS-Skills
```

| Pfad | angelegt von | entfernt von |
|---|---|---|
| `~/bin/aios`, `~/bin/aios-context` | erstes `aios --install` | `aios --uninstall` |
| `~/.aios/config.yaml` | erstes `aios --install` (nur wenn fehlend) | nie |
| `~/.aios/installations.yaml`, `logs/`, `cache/` | bei Bedarf | `cache/`: Einträge älter als 7 Tage bei jedem `--load` |
| `~/.aios/repo` | `aios --install` aus einem Klon | nie |
| `~/.aios/versions/v<version>/` | `aios --install`, wenn `/opt/aios` nicht eingerichtet werden kann | `aios --remove-version` |
| `~/.aios/hooks-backup.json` | erstes `aios --install` | `aios --uninstall` (nach Wiederherstellung) |
| Hooks in `~/.claude/settings.json` | erstes `aios --install` | `aios --uninstall` |
| `~/.claude/skills/aios-*/` | jedes `aios --install` | `aios --uninstall` |

`ai-brain` in `~/bin` bleibt unverändert. `aios --uninstall` entfernt nur Weiterleiter und Skill-Hüllen, die AIOS erkennbar selbst geschrieben hat (Kopfzeile des Weiterleiters bzw. `` !`aios --skill `` im Rumpf).

### Vault

```
§<Vault>/
├── .aios/config.yaml               Aktivierung, Manifest
└── @/                              Root-Masterspace (Klassen, Spec 02)
    ├── @!Skill/<name>/             nach /aios-deploy
    └── @!Assistant/<name>/         nach /aios-deploy
```

| Pfad | angelegt von | Git |
|---|---|---|
| `.aios/config.yaml` | `aios --activate`, `/aios-deploy` | ja, falls der Vault ein Repo ist |
| `@/` | `aios --activate`, falls fehlend | ja |
| `@/@!Skill/<name>/`, `@/@!Assistant/<name>/` | `/aios-deploy` | ja |

### Projekt

```
<Projekt>/
├── .git/
├── .gitignore
├── @/
├── @Memo/
├── .aios/
│   ├── config.yaml                 optional
│   └── manifest                    Build-Output
└── .claude/skills/<name>/          Build-Output
```

| Pfad | angelegt von | Git | vom User bearbeitbar |
|---|---|---|---|
| `@/`, `@Memo/`, `.gitignore`, `.git/` | `/aios-init` | ja | ja |
| `.aios/config.yaml` | `aios --activate <projekt>`, `/aios-deploy --to <projekt>` | ja | ja |
| `.aios/manifest` | Registrierung (Spec 03) | nie | nein |
| `.claude/skills/<name>/` | Registrierung | nie | nein |

Lokale Skills werden als Blueprint in `@/@!Skill/<name>/` geschrieben, nicht direkt in `.claude/skills/`.

## Formate

### `.aios/config.yaml`

```yaml
aios: 0.2.0
skills:
  memo: 6.0.0
assistants:
  gaertner: 0.1.0
hosts: [claude-code]
```

| Schlüssel | erlaubt in | Wert | Regel |
|---|---|---|---|
| `aios` | Vault, Projekt | Version ohne `v` | aktiviert AIOS (Spec 02); muss als einzelne Zeile `aios: <version>` stehen, weil die Weiterleiter sie ohne YAML-Parser lesen |
| `skills` | Vault, Projekt | Name → exakte Version | Manifest der installierten Skills (Spec 03) |
| `assistants` | Vault, Projekt | Name → exakte Version | Manifest der ausgerollten Assistenten (Spec 03) |
| `hosts` | alle Ebenen | Liste | in v0.2 nur `claude-code` |
| `inline_limit` | Home | Zeichenzahl | Grenze für die Inline-Ladung, Standard 9000 |

`aios` in `~/.aios/config.yaml` ist nicht erlaubt: Die Voreinstellung des Rechners darf keinen Vault aktivieren (Grundregel 6). Unbekannte Schlüssel, Schlüssel auf einer Ebene, auf der sie nicht erlaubt sind, und ein `aios`-Wert, der keine Version ist, werden mit Warnung ignoriert.

`config.yaml` verwendet eine Untermenge von YAML, die AIOS ohne PyYAML liest: Zeilen `schlüssel: wert` ohne Einrückung, Listen als `[a, b]` oder als eingerückte `- eintrag`, eine eingerückte Ebene `name: wert` (für `skills` und `assistants`; der Name darf `/` enthalten, für Assistenten-Skills `assistant/skill`), Kommentare mit `#`, Werte in Anführungszeichen und Blocktexte (`schlüssel: >` bzw. `|` mit eingerückten Zeilen, wie im Frontmatter einer `ASSISTANT.md`). Jeder Schlüssel darf je Datei nur einmal vorkommen. Eine Datei außerhalb dieser Untermenge wird in der Kette mit Warnung übergangen; `aios --activate` und `aios --deactivate` brechen dann ab, ohne sie zu ändern.

### Konfigurationskette

Gelesen wird von `cwd` aufwärts jede `.aios/config.yaml` bis zur Vault-Root, danach `~/.aios/config.yaml`. **Je Schlüssel gilt der nächstgelegene Eintrag**; bei `skills` und `assistants` je Name. Außerhalb eines Vaults gilt nur `~/.aios/config.yaml`; liegt `~` in einem Vault, zählt `~/.aios/config.yaml` trotzdem als Ebene *Home*. `aios --config [<pfad>]` zeigt die wirksamen Werte mit ihrer Herkunft.

| Rang | Quelle |
|---|---|
| 1 | Umgebungsvariable `AIOS_HOME` (Pfad einer Installation oder eines Entwicklungsstands) — nur für die Wahl der Version |
| 2 | `<cwd>/.aios/config.yaml` |
| 3 | `.aios/config.yaml` übergeordneter Projekte, aufwärts |
| 4 | `§<Vault>/.aios/config.yaml` |
| 5 | `~/.aios/config.yaml` (ohne `aios`) |

### `installations.yaml`

```yaml
v0.2.0: /opt/aios/v0.2.0
```

Eine Zeile je Version, `v<version>: <pfad>`. `~/.aios/installations.yaml` hat dasselbe Format; bei gleichem Namen gewinnt der Eintrag des Benutzers.

### `.aios/manifest`

```yaml
# written by AIOS (registration), do not edit
schema: 1
registered:
  memo:
    source: "/…/§Demo/@/@!Skill/memo"
    version: 6.0.0
    digest: sha256:…
```

`digest` ist SHA-256 über alle Dateien des Skills, je Datei in Pfadfolge `<relativer pfad>⏎<inhalt>⏎`; die Registrierung erkennt damit Änderungen am Blueprint und an der Kopie in `.claude/skills/`. `version` ist immer gesetzt, weil Skills ohne Version nicht registriert werden (Spec 03). Das Manifest hat dieses feste Format und wird nur von AIOS geschrieben.

### Hooks in `~/.claude/settings.json`

```json
{
  "hooks": {
    "SessionStart":     [ { "hooks": [ { "type": "command", "command": "aios-context --session" } ] } ],
    "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "aios-context --advise" } ] } ]
  }
}
```

Zusammengeführt mit dem `json`-Modul von Python; andere Schlüssel und fremde Hooks bleiben erhalten, auch fremde Hooks in derselben Gruppe. Die Hooks `ai-brain --session` bzw. `ai-brain --advise` werden entfernt und in `~/.aios/hooks-backup.json` gesichert, im selben Aufbau wie `settings.json` (`{"hooks": {…}}`). Ist `settings.json` kein gültiges JSON, bricht `aios` ab, bevor etwas geschrieben wird.

### Versionsneutrale AIOS-Skills

```markdown
---
name: aios-init
description: "<Beschreibung aus /opt/aios/v<version>/skills/aios/aios-init/SKILL.md>"
allowed-tools: Bash(aios --skill *), <allowed-tools aus derselben SKILL.md>
---

!`aios --skill aios-init`
```

`aios --skill <name>` gibt den Rumpf (ohne Frontmatter) der `SKILL.md` der **gültigen** Version aus; gültig ist die Version, die der Weiterleiter für `cwd` wählt. Beschreibung und `allowed-tools` werden bei jedem `aios --install` aus der installierten Version übernommen. Der Rumpf eines AIOS-Skills enthält keine `!`-Befehle, weil Claude Code die Ausgabe von `` !`aios --skill …` `` nicht noch einmal auswertet; er weist Claude an, die Befehle selbst auszuführen.

v0.2 liefert die AIOS-Skills `aios-context`, `aios-init`, `aios-register`, `aios-status`, `aios-deploy` und `aios-assistant` (Spec 02, 03).

### `.gitignore`-Vorlage

```gitignore
.DS_Store
.claude/skills/
.aios/manifest
```

## Umlenkung für Tests

Alle festen Orte lassen sich über Umgebungsvariablen umlenken, damit Tests in einem Sandkasten laufen und den Rechner nicht verändern:

| Variable | ersetzt | Standard |
|---|---|---|
| `AIOS_PREFIX` | `/opt/aios` | `/opt/aios` |
| `HOME` | `~` (damit `~/bin`, `~/.aios`) | Home-Verzeichnis |
| `AIOS_CLAUDE_DIR` | `~/.claude` | `$HOME/.claude` |
| `AIOS_SUDO` | Programm für `sudo` | `sudo` |
| `AIOS_STUP_URL` | Quelle von stup (auch `file://`) | `https://raw.githubusercontent.com/bluccino/tool-stup/master/bin/stup` |
| `AIOS_PIP` | Befehl, der `python/requirements.txt` in die venv installiert; gesetzt wird die venv ohne `pip` angelegt | `<venv>/bin/python -m pip install -q -r` |

Tests rufen damit nie das echte `sudo` auf und greifen nie auf das Netzwerk zu.

Weiterleiter, `aios` und `aios-context` verwenden ausschließlich diese Variablen, nie fest verdrahtete Pfade.

## Weiterleiter

`~/bin/aios` und `~/bin/aios-context` enthalten keine Logik außer der Wahl der Version. Beide sind Kopien desselben Skripts `templates/forwarder`, das `aios --install` unter beiden Namen nach `~/bin` legt; das Werkzeug ergibt sich aus dem Namen, unter dem es aufgerufen wird.

1. Ist `AIOS_HOME` gesetzt: `$AIOS_HOME/bin/<tool>` aufrufen.
2. Sonst vom physischen `cwd` (`pwd -P`) aufwärts bis zur Vault-Root die erste Zeile `aios: <version>` in einer `.aios/config.yaml` suchen. Außerhalb eines Vaults wird nicht gesucht, und `~/.aios/config.yaml` zählt nie, auch wenn `~` in einem Vault liegt.
3. Gefunden: `v<version>` in `~/.aios/installations.yaml`, danach in `/opt/aios/installations.yaml` nachschlagen und `<pfad>/bin/<tool>` mit allen Argumenten aufrufen. Nicht installiert: Fehler mit Hinweis auf `aios --install v<version>`.
4. Nicht gefunden:
   - `aios`: die höchste installierte Version aufrufen.
   - `aios-context`: **Legacy-Modus**, d. h. `ai-brain` mit denselben Argumenten aufrufen, falls vorhanden (`--session`, `--advise`, `--load`, `--context`); sonst nichts ausgeben. Ausnahme `--id`: Ausgabe von `ai-brain --id` mit angehängtem `mode=legacy`, außerhalb eines Vaults `mode=none` (Spec 02).

„Höchste Version" gilt nach Semver: `0.10.0` liegt über `0.2.0`, eine Vorabversion wie `0.2.0-dev` unter `0.2.0`. In `installations.yaml` darf ein Pfad in Anführungszeichen stehen und mit `~/` beginnen.

Alle Argumente werden unverändert durchgereicht, auch `-?`, `--help` und `--version`. Die eigenen Optionen der Weiterleiter haben deshalb drei Striche:

| Option | Wirkung |
|---|---|
| `---which` | gewählte Installation und Grund, z. B. `tool=aios-context kind=aios target=/opt/aios/v0.2.0/bin/aios-context why=aios: 0.2.0 in /…/§Demo/.aios/config.yaml` |
| `---version` | Version des Weiterleiters |
| `---help` | Hilfe |

Die Weiterleiter lesen nur kleine Dateien und greifen nie auf das Netzwerk zu.

## CLI `aios`

| Befehl | Wirkung |
|---|---|
| `aios -?`, `--help`, `--version` | Hilfe bzw. Version des laufenden Programms |
| `aios --prepare` | Rechner vorbereiten |
| `aios --install [v<version>]` | Version installieren (schließt `--prepare` ein) |
| `aios --activate v<version> [<pfad>]` | Vault oder Projekt an eine Version binden |
| `aios --deactivate [<pfad>]` | Bindung lösen |
| `aios --config [<pfad>]` | wirksame Konfiguration mit der Herkunft je Schlüssel, nur lesend |
| `aios --versions` | installierte Versionen und ihre Orte |
| `aios --remove-version v<version>` | Installation entfernen |
| `aios --uninstall` | Benutzereinrichtung entfernen |
| `aios --register [<pfad>]` | Projekt-Skills registrieren, mit Vorschau (Spec 03) |
| `aios --deploy <name>==<version> [--to <projekt>] [--assistant <name>] [--from <pflegeprojekt>]` | eine Version eines Skills oder Assistenten ausrollen (Spec 03) |
| `aios --deploy [--to <projekt>] [--from <pflegeprojekt>]` | Blueprints mit dem Manifest abgleichen (Spec 03) |
| `aios --library` | Skills und Assistenten der Bibliothek mit ihren Versionen |
| `aios --skill <name>` | Rumpf eines AIOS-Skills der gültigen Version (für die versionsneutralen Skills) |
| `aios --init [<pfad>]` | Ordner zum Projekt machen (Spec 03, *Initialisieren*) |

Alle schreibenden Befehle zeigen zuerst einen Plan und fragen `[Y/n]` (I7). Für Skills, die im Bash-Werkzeug keine Rückfrage beantworten können, gibt es zwei Schalter: `--plan` zeigt nur den Plan und schreibt nichts (Exit 0), `--yes` überspringt die Frage. Ein Skill zeigt den Plan, fragt im Chat und ruft erst nach Ja mit `--yes` auf; ohne Eingabe auf stdin wird nie geschrieben. `bin/aios` und die Weiterleiter sind Bash-Skripte nach der Bash-Konvention (Help-, Version- und Dispatch-Blöcke, Fallback); die Logik hinter `aios` und `aios-context` läuft in Python im venv der Installation (`python/`). `--prepare`, `--install`, `--versions`, `--remove-version` und `--uninstall` verwenden nur die Standardbibliothek, weil sie aus einem Klon mit dem `python3` des Systems laufen, bevor eine venv existiert. Voraussetzungen sind `python3` ab 3.9 und `git`.

### `aios --prepare`

| Prüfung | fehlt → |
|---|---|
| `/opt/aios` existiert und ist beschreibbar | anlegen, wenn das übergeordnete Verzeichnis beschreibbar ist; sonst `sudo mkdir -p /opt/aios && sudo chown $USER /opt/aios`; ohne `sudo` Rückfall auf `~/.aios/versions/`: Installationen liegen dann in `~/.aios/versions/v<version>/` und werden in `~/.aios/installations.yaml` eingetragen, damit die Weiterleiter sie finden |
| `~/bin`, `~/etc`, `~/tmp`, `~/git` | anlegen |
| stup vorhanden und aktuell | installieren nach `~/bin/stup` bzw. aktualisieren (von `bluccino/tool-stup`, Vergleich mit `stup --version`); ist die Quelle nicht erreichbar, nur eine Warnung, sofern stup vorhanden ist |
| `~/bin/profile.sh` | mit `stup --profile` anlegen, nur wenn sie fehlt; nie überschreiben |

Ist alles vorhanden: „Rechner vorbereitet", keine Rückfrage.

### `aios --install [v<version>]`

Aufgerufen aus einem Klon des Repos `aibex-aios` (`./bin/aios --install …`) oder über den Weiterleiter; dann gilt der Klon aus `~/.aios/repo`.

1. **Version bestimmen:** angegeben oder der höchste Tag `v<MAJOR.MINOR.PATCH>` im Repo (Vorabversionen wie `v0.3.0-rc1` nur, wenn angegeben); vorher `git fetch --tags`, sofern der Klon einen Remote hat.
2. **Vorbereitung prüfen:** ist der Rechner nicht vorbereitet, gehören die Schritte von `--prepare` in den Plan.
3. **Plan zeigen**, einmal fragen; muss `sudo` nach einem Passwort fragen, steht das im Plan.
4. **Installieren**, falls `v<version>` noch nicht installiert ist: Stand des Tags mit `git archive` nach `/opt/aios/v<version>/` übertragen (Abbildung siehe *Repo*), venv in `python/` anlegen und `pyyaml` installieren, `python -m compileall`, Dateien schreibschützen, Eintrag in `installations.yaml`.
5. **Benutzer einrichten**, was fehlt: Weiterleiter nach `~/bin` (angelegt von `--prepare`); ein vorhandener Weiterleiter wird nur durch einen neueren ersetzt, der Prototyp (`~/bin/aios` mit `~/etc/aios/`) immer. `~/.aios/config.yaml` mit `hosts: [claude-code]`, Hooks eintragen und `ai-brain`-Hooks sichern, `~/.aios/repo` merken.
6. **AIOS-Skills** der Gruppe `aios` als Hüllen in `~/.claude/skills/aios-*/` schreiben (bei jedem Install). Skills der übrigen Gruppen und Assistenten werden nicht registriert, sondern ausgerollt (Spec 03).

Das Übertragen geschieht in ein temporäres Verzeichnis neben dem Ziel, das erst am Ende umbenannt wird; ein Abbruch hinterlässt keine halbe Installation.

Eine bereits installierte Version wird nicht erneut installiert (I5, I8).

### `aios --activate v<version> [<pfad>]`

| Schritt | Regel |
|---|---|
| Pfad | angegeben oder `cwd` |
| Prüfung | Pfad liegt in einem Vault; `v<version>` ist installiert, sonst Abbruch mit Hinweis auf `aios --install` |
| Vault-Root | ist der Pfad eine Vault-Root (Name beginnt mit `§`) und fehlt `@/`, wird `@/` mit Hinweis angelegt |
| Projekt | ist der Pfad kein Projekt (kein `@/`) und keine Vault-Root: Abbruch mit Hinweis auf `/aios-init` |
| Wirkung | `aios: <version>` in `<pfad>/.aios/config.yaml` schreiben bzw. ersetzen |
| Version | mit oder ohne `v` angegeben, geschrieben ohne `v`; steht dieselbe Version schon in der Datei: „nichts zu tun", keine Rückfrage |
| Hinweis | Master-Kontext und Registrierung gelten ab dem nächsten Chat |

### `aios --deactivate [<pfad>]`

Entfernt den Schlüssel `aios` aus `<pfad>/.aios/config.yaml`. Danach gilt die Festlegung darüber, sonst der Legacy-Modus; beides wird gemeldet. `skills` und andere Schlüssel bleiben stehen, ebenso Kommentare; eine leere Datei wird entfernt, ein danach leeres `.aios/` ebenfalls. Steht kein `aios` in der Datei: „nichts zu tun".

### `aios --remove-version v<version>`

Entfernt `/opt/aios/v<version>/` (bzw. `~/.aios/versions/v<version>/`) und den Eintrag in `installations.yaml` nach Warnung und Bestätigung. Zeigt der Eintrag auf ein anderes Verzeichnis, etwa einen Klon als Entwicklungsstand, wird nur der Eintrag entfernt. Ist die Version die einzige installierte, wird zusätzlich auf `aios --uninstall` hingewiesen.

### `aios --uninstall`

Entfernt die Benutzereinrichtung: Weiterleiter, AIOS-Skills in `~/.claude/skills/aios-*/`, die AIOS-Hooks; stellt die Hooks aus `~/.aios/hooks-backup.json` wieder her. Installationen in `/opt/aios`, `~/.aios/config.yaml` sowie alle `.aios/` in Vaults und Projekten bleiben erhalten.

## Repo `aibex-aios` und Abbildung auf die Installation

```
aibex-aios/                          GitHub aibex-hub/aibex-aios, Tags v<version>
├── README.md
├── CLAUDE.md                        Regeln für die Arbeit am Repo
├── VERSION                          Entwicklungsstand, z. B. 0.2.0-dev
├── bin/                             aios (Einstieg: ./bin/aios --install), aios-context
├── lib/aios/                        Python-Paket
├── skills/
│   ├── aios/<name>/SKILL.md         AIOS-Skills
│   └── basic/<name>/SKILL.md        Grundausstattung, version im Frontmatter
├── assistants/
│   └── demo/<name>/ASSISTANT.md     Demo-Assistenten, version im Frontmatter
├── templates/                       forwarder (Weiterleiter), gitignore (Vorlage für /aios-init)
├── python/requirements.txt          pyyaml
├── spec/                            diese Spec (gepflegt aus dem Konzeptprojekt)
├── doc/tutorials/                   Tutorials; künftig auch doc/wiki/
├── dev/                             Entwickler-Doku, nicht installiert
├── tests/                           Tests im Sandkasten (tests/run), nicht installiert;
│                                    tests/live/: Tests mit echten Claude-Sessions (kosten Tokens)
├── etc/image/                       Bilder des README, nicht installiert
└── .pimp/                           optionale Entwicklungsumgebung (venv @aios)
```

Das Repo enthält keinen Vault. Vaults legt der User an und bindet sie mit `aios --activate` an eine Version; die Tests legen ihre Vaults im Sandkasten an.

**Skill-Gruppen:** Skills liegen in `skills/<gruppe>/<name>/`. Nur die Gruppe `aios` ist besonders: Ihre Skills schreibt `aios --install` als versionsneutrale AIOS-Skills nach `~/.claude/skills/` (Spec 03). Alle übrigen Gruppen (v0.2: `basic`; künftig z. B. `project`, `mail`) enthalten normale Skills, die mit `aios --deploy` ausgerollt werden.

**Assistenten-Gruppen:** Assistenten der Bibliothek liegen in `assistants/<gruppe>/<name>/` (v0.2: `demo`), jeweils mit `ASSISTANT.md`, privaten Skills und Wissen (Spec 03, *Assistenten*), und werden ebenfalls mit `aios --deploy` ausgerollt. Gruppen dienen nur der Ordnung: Namen sind über alle Skills und Assistenten der Bibliothek eindeutig, `aios --deploy memo==6.0.0` und `aios --deploy gaertner==0.1.0` nennen keine Gruppe.

| Repo | Installation |
|---|---|
| `bin/`, `lib/`, `templates/` | `v<version>/bin/`, `v<version>/lib/`, `v<version>/templates/` |
| `VERSION` | `v<version>/VERSION`, beim Installieren mit der Version des Tags überschrieben |
| `skills/aios/<name>/` | `v<version>/skills/aios/<name>/` |
| `skills/<gruppe>/<name>/` (übrige Gruppen) | `v<version>/skills/<gruppe>/<name>/<skill-version>/`, Skill-Version aus dem Frontmatter |
| `assistants/<gruppe>/<name>/` | `v<version>/assistants/<gruppe>/<name>/<assistant-version>/`, Version aus dem Frontmatter der `ASSISTANT.md` |
| `python/requirements.txt` | `v<version>/python/` (venv) |
| `spec/` | `v<version>/doc/spec/` |
| `doc/tutorials/`, `doc/wiki/` (künftig) | `v<version>/doc/tutorials/`, `v<version>/doc/wiki/` |

Ein Release (Tag `v<version>`) ist nur vollständig, wenn `spec/` den Soll-Stand dieser Version beschreibt.

Ein Entwicklungsstand wird ohne Installation genutzt, indem `~/.aios/installations.yaml` auf die Wurzel des Klons zeigt (z. B. `v0.2.0-dev: ~/git/AIbex/aibex-aios`) oder `AIOS_HOME` auf diesen Ort gesetzt wird. Die Weiterleiter finden dort wie in einer Installation `bin/aios` und `bin/aios-context`. Im Entwicklungsstand liegen die übrigen Skill-Gruppen und die Assistenten ohne Versionsebene vor (`skills/basic/memo/`, `assistants/demo/gaertner/`); `aios` liest ihre Version aus dem Frontmatter.

## Legacy und Umstieg

| Situation | Verhalten |
|---|---|
| Vault ohne `aios:` in der Kette | Legacy-Modus über `ai-brain` (Spec 02) |
| Umstieg eines Vaults (z. B. `§AIbex`) | `@Skill` nach `@!Skill` verschieben und jedem Skill ein `version:` geben (ohne Version wird er nicht registriert); weitere `@`-Ordner prüfen, ob sie *Laden* bleiben sollen; `aios --activate v<version> <vault>` |
| Rückkehr | `aios --deactivate <vault>`; vollständig mit `aios --uninstall` |

Ein Rechner mit dem Prototyp von `aios` (Kopie nach `~/bin`, Konfiguration in `~/etc/aios/`) wird beim ersten `aios --install` umgestellt: Der Weiterleiter ersetzt `~/bin/aios`, `~/etc/aios/` wird entfernt.
