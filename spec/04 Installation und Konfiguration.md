---
title: "Installation und Konfiguration"
date: 2026-10-01
author: iHux
status: Spec
tags: [spec, aios, v0.1, installation, konfiguration]
number: 04
related:
  - "Spec 01 AIbex AIOS v0.1 — Überblick"
  - "Spec 02 Master-Kontext"
  - "Spec 03 Skills und Agenten"
  - "Memo 04 Der Vault §AIOS, Repo und Installation (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 21 Repo ohne Vault und Skill-Gruppen (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 09 Parallele Versionen und Aktivierung je Projekt (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 10 Das Verzeichnis .aios — global, Vault und Projekt (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 12 Umfang von AIOS v0.1.0 — Entscheidungen vor der Spec (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
---

# Installation und Konfiguration

Diese Spec regelt, welche Dateien AIOS v0.1 wo anlegt, ihre Formate, die Konfiguration mit Übertrumpfung, die Weiterleiter und das CLI `aios`. Plattformen: macOS und Linux.

## Dateistrukturen

### Rechner — `/opt/aios/`

```
/opt/aios/
├── installations.yaml
├── shared/                         in v0.1 leer
└── v0.1.0/                         unveränderlich
    ├── VERSION
    ├── bin/
    │   ├── aios
    │   └── aios-context
    ├── lib/aios/                   Python-Paket: Logik von aios und aios-context
    ├── skills/
    │   ├── aios/aios-<name>/SKILL.md   AIOS-Skills (vollständig)
    │   └── basic/memo/6.0.0/SKILL.md   mitgelieferte Skills, je Skill-Version
    ├── templates/
    │   └── gitignore               Vorlage für /aios-init
    ├── doc/
    │   └── spec/                   die Spec dieser Version (Pflicht)
    └── python/                     venv mit PyYAML, vorkompiliert
```

Künftig kommen `doc/tutorials/` und `doc/wiki/` hinzu.

| Pfad | angelegt von | Inhalt | änderbar |
|---|---|---|---|
| `/opt/aios/` | `aios --prepare` | gehört dem Benutzer (v0.1: ein Benutzer) | — |
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
├── installations.yaml              eigene Einträge (z. B. Entwicklungsstand)
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
| `~/.aios/hooks-backup.json` | erstes `aios --install` | `aios --uninstall` (nach Wiederherstellung) |
| Hooks in `~/.claude/settings.json` | erstes `aios --install` | `aios --uninstall` |
| `~/.claude/skills/aios-*/` | jedes `aios --install` | `aios --uninstall` |

`ai-brain` in `~/bin` bleibt unverändert.

### Vault

```
§<Vault>/
├── .aios/config.yaml               Aktivierung, Manifest
└── @/                              Root-Masterspace (Klassen, Spec 02)
    └── @!Skill/<name>/             nach /aios-deploy
```

| Pfad | angelegt von | Git |
|---|---|---|
| `.aios/config.yaml` | `aios --activate`, `/aios-deploy` | ja, falls der Vault ein Repo ist |
| `@/` | `aios --activate`, falls fehlend | ja |
| `@/@!Skill/<name>/` | `/aios-deploy` | ja |

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
aios: 0.1.0
skills:
  memo: 6.0.0
hosts: [claude-code]
```

| Schlüssel | erlaubt in | Wert | Regel |
|---|---|---|---|
| `aios` | Vault, Projekt | Version ohne `v` | aktiviert AIOS (Spec 02); muss als einzelne Zeile `aios: <version>` stehen, weil die Weiterleiter sie ohne YAML-Parser lesen |
| `skills` | Vault, Projekt | Name → exakte Version | Manifest der installierten Skills (Spec 03) |
| `hosts` | alle Ebenen | Liste | in v0.1 nur `claude-code` |
| `inline_limit` | Home | Zeichenzahl | Grenze für die Inline-Ladung, Standard 9000 |

`aios` in `~/.aios/config.yaml` ist nicht erlaubt: Die Voreinstellung des Rechners darf keinen Vault aktivieren (Grundregel 6). Unbekannte Schlüssel werden mit Warnung ignoriert.

### Konfigurationskette

Gelesen wird von `cwd` aufwärts jede `.aios/config.yaml` bis zur Vault-Root, danach `~/.aios/config.yaml`. **Je Schlüssel gilt der nächstgelegene Eintrag**; bei `skills` je Skillname.

| Rang | Quelle |
|---|---|
| 1 | Umgebungsvariable `AIOS_HOME` (Pfad einer Installation oder eines Entwicklungsstands) — nur für die Wahl der Version |
| 2 | `<cwd>/.aios/config.yaml` |
| 3 | `.aios/config.yaml` übergeordneter Projekte, aufwärts |
| 4 | `§<Vault>/.aios/config.yaml` |
| 5 | `~/.aios/config.yaml` (ohne `aios`) |

### `installations.yaml`

```yaml
v0.1.0: /opt/aios/v0.1.0
```

Eine Zeile je Version, `v<version>: <pfad>`. `~/.aios/installations.yaml` hat dasselbe Format; bei gleichem Namen gewinnt der Eintrag des Benutzers.

### `.aios/manifest`

```yaml
schema: 1
registered:
  memo:
    source: /…/§Demo/@/@!Skill/memo
    version: 6.0.0
    digest: sha256:…
```

`digest` ist die Prüfsumme über alle Dateien des Skills; die Registrierung erkennt damit Änderungen.

### Hooks in `~/.claude/settings.json`

```json
{
  "hooks": {
    "SessionStart":     [ { "hooks": [ { "type": "command", "command": "aios-context --session" } ] } ],
    "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "aios-context --advise" } ] } ]
  }
}
```

Eingetragen per `jq`-Merge; andere Schlüssel und fremde Hooks bleiben erhalten. Einträge mit `ai-brain --session` bzw. `ai-brain --advise` werden entfernt und in `~/.aios/hooks-backup.json` gesichert.

### Versionsneutrale AIOS-Skills

```markdown
---
name: aios-init
description: <Beschreibung aus /opt/aios/v<version>/skills/aios/aios-init/SKILL.md>
---

!`aios --skill aios-init`
```

`aios --skill <name>` gibt den Rumpf (ohne Frontmatter) der `SKILL.md` der **gültigen** Version aus. Die Beschreibung wird bei jedem `aios --install` aus der installierten Version übernommen.

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

Weiterleiter, `aios` und `aios-context` verwenden ausschließlich diese Variablen, nie fest verdrahtete Pfade.

## Weiterleiter

`~/bin/aios` und `~/bin/aios-context` enthalten keine Logik außer der Wahl der Version:

1. Ist `AIOS_HOME` gesetzt: `$AIOS_HOME/bin/<tool>` aufrufen.
2. Sonst von `cwd` aufwärts bis zur Vault-Root die erste Zeile `aios: <version>` in einer `.aios/config.yaml` suchen.
3. Gefunden: `v<version>` in `~/.aios/installations.yaml`, danach in `/opt/aios/installations.yaml` nachschlagen und `<pfad>/bin/<tool>` mit allen Argumenten aufrufen. Nicht installiert: Fehler mit Hinweis auf `aios --install v<version>`.
4. Nicht gefunden:
   - `aios`: die höchste installierte Version aufrufen.
   - `aios-context`: **Legacy-Modus**, d. h. `ai-brain` mit denselben Argumenten aufrufen, falls vorhanden (`--session`, `--advise`, `--load`, `--id`, `--context`); sonst nichts ausgeben.

Die Weiterleiter lesen nur kleine Dateien und greifen nie auf das Netzwerk zu.

## CLI `aios`

| Befehl | Wirkung |
|---|---|
| `aios -?`, `--help`, `--version` | Hilfe bzw. Version des laufenden Programms |
| `aios --prepare` | Rechner vorbereiten |
| `aios --install [v<version>]` | Version installieren (schließt `--prepare` ein) |
| `aios --activate v<version> [<pfad>]` | Vault oder Projekt an eine Version binden |
| `aios --deactivate [<pfad>]` | Bindung lösen |
| `aios --versions` | installierte Versionen und ihre Orte |
| `aios --remove-version v<version>` | Installation entfernen |
| `aios --uninstall` | Benutzereinrichtung entfernen |
| `aios --deploy …`, `aios --register` | Spec 03 |
| `aios --skill <name>` | Rumpf eines AIOS-Skills der gültigen Version (für die versionsneutralen Skills) |

Alle schreibenden Befehle zeigen zuerst einen Plan und fragen `[Y/n]` (I7). `bin/aios` und die Weiterleiter sind Bash-Skripte nach der Bash-Konvention (Help-, Version- und Dispatch-Blöcke, Fallback); die Logik hinter `aios` und `aios-context` läuft in Python im venv der Installation (`python/`). Nur das Bootstrap von `./bin/aios --install`, bevor die venv existiert, kommt ohne Python-Pakete aus.

### `aios --prepare`

| Prüfung | fehlt → |
|---|---|
| `/opt/aios` existiert und ist beschreibbar | `sudo mkdir -p /opt/aios && sudo chown $USER /opt/aios`; ohne `sudo` Rückfall auf `~/.aios/versions/` |
| `~/bin`, `~/etc`, `~/tmp`, `~/git` | anlegen |
| stup vorhanden und aktuell | installieren bzw. aktualisieren (von `bluccino/tool-stup`) |
| `~/bin/profile.sh` | mit `stup --profile` anlegen, nur wenn sie fehlt; nie überschreiben |

Ist alles vorhanden: „Rechner vorbereitet", keine Rückfrage.

### `aios --install [v<version>]`

Aufgerufen aus einem Klon des Repos `aibex-aios` (`./bin/aios --install …`) oder über den Weiterleiter.

1. **Version bestimmen:** angegeben oder der höchste Tag `v<MAJOR.MINOR.PATCH>` im Repo (nach `git fetch --tags`).
2. **Vorbereitung prüfen:** ist der Rechner nicht vorbereitet, gehören die Schritte von `--prepare` in den Plan.
3. **Plan zeigen**, einmal fragen; muss `sudo` nach einem Passwort fragen, steht das im Plan.
4. **Installieren**, falls `v<version>` noch nicht installiert ist: Stand des Tags mit `git archive` nach `/opt/aios/v<version>/` übertragen (Abbildung siehe *Repo*), venv in `python/` anlegen und `pyyaml` installieren, `python -m compileall`, Dateien schreibschützen, Eintrag in `installations.yaml`.
5. **Benutzer einrichten**, beim ersten Mal: Weiterleiter nach `~/bin` (bzw. in das erste beschreibbare Verzeichnis im `PATH`, wenn `~/bin` fehlt), `~/.aios/config.yaml` mit `hosts: [claude-code]`, Hooks eintragen und `ai-brain`-Hooks sichern.
6. **AIOS-Skills** in `~/.claude/skills/aios-*/` schreiben (bei jedem Install).

Eine bereits installierte Version wird nicht erneut installiert (I5, I8).

### `aios --activate v<version> [<pfad>]`

| Schritt | Regel |
|---|---|
| Pfad | angegeben oder `cwd` |
| Prüfung | Pfad liegt in einem Vault; `v<version>` ist installiert, sonst Abbruch mit Hinweis auf `aios --install` |
| Vault-Root | ist der Pfad eine Vault-Root (Name beginnt mit `§`) und fehlt `@/`, wird `@/` mit Hinweis angelegt |
| Projekt | ist der Pfad kein Projekt (kein `@/`) und keine Vault-Root: Abbruch mit Hinweis auf `/aios-init` |
| Wirkung | `aios: <version>` in `<pfad>/.aios/config.yaml` schreiben bzw. ersetzen |
| Hinweis | Master-Kontext und Registrierung gelten ab dem nächsten Chat |

### `aios --deactivate [<pfad>]`

Entfernt den Schlüssel `aios` aus `<pfad>/.aios/config.yaml`. Danach gilt die Festlegung darüber, sonst der Legacy-Modus. `skills` und andere Schlüssel bleiben stehen; eine leere Datei wird entfernt.

### `aios --remove-version v<version>`

Entfernt `/opt/aios/v<version>/` und den Eintrag in `installations.yaml` nach Warnung und Bestätigung. Ist die Version die einzige installierte, wird zusätzlich auf `aios --uninstall` hingewiesen.

### `aios --uninstall`

Entfernt die Benutzereinrichtung: Weiterleiter, AIOS-Skills in `~/.claude/skills/aios-*/`, die AIOS-Hooks; stellt die Hooks aus `~/.aios/hooks-backup.json` wieder her. Installationen in `/opt/aios`, `~/.aios/config.yaml` sowie alle `.aios/` in Vaults und Projekten bleiben erhalten.

## Repo `aibex-aios` und Abbildung auf die Installation

```
aibex-aios/                          GitHub aibex-hub/aibex-aios, Tags v<version>
├── README.md
├── CLAUDE.md                        Regeln für die Arbeit am Repo
├── VERSION                          Entwicklungsstand, z. B. 0.1.0-dev
├── bin/                             aios (Einstieg: ./bin/aios --install), aios-context
├── lib/aios/                        Python-Paket
├── skills/
│   ├── aios/<name>/SKILL.md         AIOS-Skills
│   └── basic/<name>/SKILL.md        Grundausstattung, version im Frontmatter
├── templates/
├── python/requirements.txt          pyyaml
├── spec/                            diese Spec (gepflegt aus dem Konzeptprojekt)
├── doc/                             künftig: tutorials/, wiki/
├── dev/                             Entwickler-Doku, nicht installiert
├── tests/                           Tests im Sandkasten (tests/run), nicht installiert
├── etc/image/                       Bilder des README, nicht installiert
└── .pimp/                           optionale Entwicklungsumgebung (venv @aios)
```

Das Repo enthält keinen Vault. Vaults legt der User an und bindet sie mit `aios --activate` an eine Version; die Tests legen ihre Vaults im Sandkasten an.

**Skill-Gruppen:** Skills liegen in `skills/<gruppe>/<name>/`. Nur die Gruppe `aios` ist besonders: Ihre Skills schreibt `aios --install` als versionsneutrale AIOS-Skills nach `~/.claude/skills/` (Spec 03). Alle übrigen Gruppen (v0.1: `basic`; künftig z. B. `project`, `mail`) enthalten normale Skills, die mit `aios --deploy` ausgerollt werden. Die Gruppe dient nur der Ordnung: Skill-Namen sind über alle Gruppen eindeutig, `aios --deploy memo==6.0.0` nennt keine Gruppe.

| Repo | Installation |
|---|---|
| `bin/`, `lib/`, `templates/` | `v<version>/bin/`, `v<version>/lib/`, `v<version>/templates/` |
| `VERSION` | `v<version>/VERSION`, beim Installieren mit der Version des Tags überschrieben |
| `skills/aios/<name>/` | `v<version>/skills/aios/<name>/` |
| `skills/<gruppe>/<name>/` (übrige Gruppen) | `v<version>/skills/<gruppe>/<name>/<skill-version>/`, Skill-Version aus dem Frontmatter |
| `python/requirements.txt` | `v<version>/python/` (venv) |
| `spec/` | `v<version>/doc/spec/` |
| `doc/tutorials/`, `doc/wiki/` (künftig) | `v<version>/doc/tutorials/`, `v<version>/doc/wiki/` |

Ein Release (Tag `v<version>`) ist nur vollständig, wenn `spec/` den Soll-Stand dieser Version beschreibt.

Ein Entwicklungsstand wird ohne Installation genutzt, indem `~/.aios/installations.yaml` auf die Wurzel des Klons zeigt (z. B. `v0.2.0-dev: ~/git/AIbex/aibex-aios`) oder `AIOS_HOME` auf diesen Ort gesetzt wird. Die Weiterleiter finden dort wie in einer Installation `bin/aios` und `bin/aios-context`. Im Entwicklungsstand liegen die übrigen Skill-Gruppen ohne Versionsebene vor (`skills/basic/memo/`); `aios` liest ihre Version aus dem Frontmatter.

## Legacy und Umstieg

| Situation | Verhalten |
|---|---|
| Vault ohne `aios:` in der Kette | Legacy-Modus über `ai-brain` (Spec 02) |
| Umstieg eines Vaults (z. B. `§AIbex`) | `@Skill` nach `@!Skill` verschieben; weitere `@`-Ordner prüfen, ob sie *Laden* bleiben sollen; `aios --activate v<version> <vault>` |
| Rückkehr | `aios --deactivate <vault>`; vollständig mit `aios --uninstall` |

Das heutige Skript `aibex-aios/bin/aios` 0.1.0 (Kopie nach `~/bin`, Konfiguration in `~/etc/aios/`) ist ein Prototyp und wird durch den hier beschriebenen Stand ersetzt.
