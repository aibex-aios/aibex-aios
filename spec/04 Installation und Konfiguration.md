---
title: "Installation und Konfiguration"
date: 2026-10-25
author: iHux
status: Spec
tags: [spec, aios, v0.5, installation, konfiguration]
number: 04
related:
  - "Spec 01 AIbex AIOS v0.5 — Überblick"
  - "Spec 02 Master-Kontext"
  - "Spec 03 Skills und Assistenten"
  - "Spec 05 Projekte"
  - "Spec 06 Pakete und Workspaces"
  - "Spec 07 Arbeitspferde"
  - "Memo 04 Der Vault §AIOS, Repo und Installation (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memo 09 Parallele Versionen und Aktivierung je Projekt (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memo 10 Das Verzeichnis .aios — global, Vault und Projekt (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memo 21 Repo ohne Vault und Skill-Gruppen (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memos 15–17 Versionen, Demo-Assistenten (AA-AIbex-AIOS, @Memo/V0.2)"
  - "Memos 03, 06, 11, 15, 23 (AA-AIbex-AIOS, @Memo/V0.3)"
  - "Memos 08–29 (AA-AIbex-AIOS, @Memo/V0.4)"
  - "Memos 03, 04, 20, 26–35 (AA-AIbex-AIOS, @Memo/V0.5)"
---

# Installation und Konfiguration

Diese Spec regelt, welche Dateien AIOS v0.5 wo anlegt, ihre Formate, die Konfiguration mit Übertrumpfung, die Weiterleiter und das CLI `aios`. Plattformen: macOS und Linux.

## Dateistrukturen

### Rechner — `/opt/aios/`

```
/opt/aios/
├── installations.yaml
├── workers.yaml                    Verzeichnis der Arbeitspferde (Spec 07)
├── workers/<paket>/v<version>/     Installationen der Arbeitspferde, unveränderlich (Spec 07)
├── shared/                         in v0.5 leer
└── v0.5.0/                         unveränderlich
    ├── VERSION
    ├── bin/
    │   └── aios
    ├── lib/aios/                   Python-Paket: Logik von aios
    ├── manifest.yaml               Paket-Manifest des Kernels (type: kernel, Spec 06)
    ├── skills/
    │   └── aios/aios-<name>/SKILL.md   AIOS-Skills (vollständig; aios-gui mit gui.yaml)
    ├── templates/
    │   ├── forwarder               Quelle der Weiterleiter in ~/bin
    │   └── gitignore               Vorlage für aios --init
    ├── doc/
    │   ├── spec/                   die Spec dieser Version (Pflicht)
    │   └── tutorials/              Tutorials (Demo-Assistenten, Projekte)
    └── python/                     venv mit PyYAML, vorkompiliert
```

Künftig kommt `doc/wiki/` hinzu.

| Pfad | angelegt von | Inhalt | änderbar |
|---|---|---|---|
| `/opt/aios/` | `aios --prepare` | gehört dem Benutzer (v0.5: ein Benutzer) | — |
| `/opt/aios/installations.yaml` | `aios --install`, `--remove-version` | Verzeichnis der Installationen | nur durch AIOS |
| `/opt/aios/v<version>/` | `aios --install` | vollständige Installation, danach schreibgeschützt | nie (I5) |
| `/opt/aios/workers/<paket>/v<version>/` | setup eines Arbeitspferds (`aios --fetch`, `aios --install`) | Installation einer Version eines Arbeitspferds, danach schreibgeschützt | nie (Spec 07, A2) |
| `/opt/aios/workers.yaml` | setup und remove | Verzeichnis der Arbeitspferde | nur durch AIOS |

Kann `/opt/aios` nicht angelegt werden (kein `sudo`), gilt statt `/opt/aios` das Verzeichnis `~/.aios/versions/` mit demselben Aufbau, für Arbeitspferde `~/.aios/workers/` und `~/.aios/workers.yaml`.

### Benutzer — `~`

```
~/bin/
└── aios                            Weiterleiter
~/.aios/
├── config.yaml                     Voreinstellungen
├── installations.yaml              eigene Einträge (z. B. Entwicklungsstand, Ersatzort)
├── repo                            Pfad des Klons, aus dem zuletzt installiert wurde
├── versions/v<version>/            Ersatzort der Installationen ohne sudo
├── hooks-backup.json               vom Installieren ersetzte Hook-Einträge
├── cache/<id>/part-<n>.md          Part-Dateien des Master-Kontexts (Assistenten: cache/a-<name>-<id>/)
├── sessions/<session-id>.yaml      Merker: Assistent der Session (Spec 02)
├── packages/<hub>/<name>/<version>/ Cache der geholten Pakete (Spec 06)
├── hub/<hub>/                      Klon des Index-Repos eines Hubs, falls vorhanden (Spec 06)
├── bin/<programm>                  Weiterleiter der Arbeitspferde (Spec 07)
├── workers/, workers.yaml          Ersatzort der Arbeitspferde ohne sudo (Spec 07)
└── logs/aios.log
~/.claude/
├── settings.json                   Hooks
└── skills/
    ├── aios-<name>/SKILL.md        versionsneutrale AIOS-Skills
    └── gui/SKILL.md                versionsneutraler Alias /gui
```

| Pfad | angelegt von | entfernt von |
|---|---|---|
| `~/bin/aios` | erstes `aios --install` | `aios --uninstall` |
| `~/.aios/bin/<programm>` | erstes setup eines Arbeitspferds mit diesem Programm | remove der letzten Version (Spec 07) |
| `~/.aios/config.yaml` | erstes `aios --install` (nur wenn fehlend) | nie |
| `~/.aios/installations.yaml`, `logs/`, `cache/`, `packages/`, `hub/` | bei Bedarf | `cache/`: Einträge älter als 7 Tage bei jedem `--load` |
| `~/.aios/sessions/` | SessionStart-Hook, `aios --assistant` | Merker mit `used` älter als 30 Tage beim Session-Start (`startup`); ganz bei `aios --uninstall` |
| `~/.aios/repo` | `aios --install` aus einem Klon | nie |
| `~/.aios/versions/v<version>/` | `aios --install`, wenn `/opt/aios` nicht eingerichtet werden kann | `aios --remove-version` |
| `~/.aios/hooks-backup.json` | erstes `aios --install` | `aios --uninstall` (nach Wiederherstellung) |
| Hooks in `~/.claude/settings.json` | erstes `aios --install` | `aios --uninstall` |
| `~/.claude/skills/aios-*/`, `~/.claude/skills/gui/` | jedes `aios --install` | `aios --uninstall` |

`ai-brain` in `~/bin` bleibt unverändert. `aios --uninstall` entfernt nur Weiterleiter und Skill-Hüllen, die AIOS erkennbar selbst geschrieben hat (Kopfzeile des Weiterleiters bzw. `` !`aios --skill `` oder `` !`aios --gui `` im Rumpf). Ein vorhandener Ordner `~/.claude/skills/gui/`, den AIOS nicht geschrieben hat, wird nicht überschrieben; `aios --install` meldet ihn, und `/gui` steht dann nicht zur Verfügung.

### Vault

```
§<Vault>/
├── .git/                           Root-Projekt (Spec 05)
├── .gitignore                      mit den Ausschlüssen der Unterprojekte
├── .aios/config.yaml               Aktivierung, Pakete, Zuordnung
├── .aios/lock.yaml                 aufgelöste Pakete (Spec 06)
└── @/                              Root-Masterspace (Klassen, Spec 02)
    ├── @!Skill/<name>/             lokale Blueprints
    ├── @!Assistant/<name>/         lokale Blueprints
    └── @!Package/<name>/           nach aios --fetch (Spec 06)
```

| Pfad | angelegt von | Git |
|---|---|---|
| `.aios/config.yaml` | `aios --activate`, `aios --fetch`, `aios --deploy`, `aios --hubs --vault`, `aios --assistant` | ja |
| `.aios/lock.yaml` | `aios --fetch`, `aios --install` (Distribution), `aios --activate` (Umstellung), `aios --workspace freeze` | ja |
| `@/`, `.git/`, `.gitignore` | `aios --activate` bzw. `aios --init`, falls fehlend | ja |
| `@/@!Skill/<name>/`, `@/@!Assistant/<name>/` | User | ja |
| `@/@!Package/<name>/` | `aios --fetch` | ja |

### Projekt

```
<Projekt>/
├── .git/
├── .gitignore
├── @/
├── @Memo/                          vom Memo-Skill beim ersten Memo angelegt
├── @Data/<paket>/                  Daten der Pakete (Spec 06)
├── .aios/
│   ├── config.yaml                 optional
│   ├── lock.yaml                   optional (Spec 06)
│   ├── workspace.yaml              nur im Wurzelprojekt eines Workspace (Spec 06)
│   ├── backup/                     Sicherung während eines Plans (Spec 06)
│   └── registry                    Build-Output
└── .claude/skills/<name>/          Build-Output
```

| Pfad | angelegt von | Git | vom User bearbeitbar |
|---|---|---|---|
| `@/`, `.gitignore`, `.git/` | `aios --init` (Spec 05) | ja | ja |
| `@Memo/` | `/memo` oder `/aios-memo` beim ersten Memo | ja | ja (Memos werden nie geändert, I1) |
| `.aios/config.yaml` | `aios --activate <projekt>`, `aios --fetch --to <projekt>`, `aios --deploy --to <projekt>`, `aios --assistant`, `aios --init --assistant` | ja | ja |
| `@Data/<paket>/` | das Paket (Spec 06) | ja | ja |
| `.aios/lock.yaml` | `aios --fetch`, `aios --install`, `aios --activate`, `aios --workspace freeze` | ja | nein |
| `.aios/backup/` | Plan mit „alles oder nichts" (Spec 06) | nie | nein |
| `.aios/workspace.yaml` | User | ja | ja |
| `.aios/registry` | Registrierung (Spec 03) | nie | nein |
| `.claude/skills/<name>/` | Registrierung | nie | nein |

Lokale Skills werden als Blueprint in `@/@!Skill/<name>/` geschrieben, nicht direkt in `.claude/skills/`.

## Formate

### `.aios/config.yaml`

```yaml
aios: 0.5.0
packages:
  skill-memo: "~=6.0"
  assistant-gaertner: "~=0.2.0"
  knowledge-scorpio: {range: "~=0.1.0", hub: aibex-hub}
assistant: gaertner
hosts: [claude-code]
```

| Schlüssel | erlaubt in | Wert | Regel |
|---|---|---|---|
| `aios` | Vault, Projekt | Version ohne `v` | aktiviert AIOS (Spec 02); muss als einzelne Zeile `aios: <version>` stehen, weil die Weiterleiter sie ohne YAML-Parser lesen |
| `packages` | Vault, Projekt | Name → Bereich oder `{range, hub, from, only}` | gewünschte Pakete dieses Projekts, nicht vererbt (Spec 06, *Konfiguration und Lock*) |
| `skills`, `assistants` | Vault, Projekt | Name → exakte Version | aus v0.3; gelten als `packages` mit `==<version>` (Spec 06, *Umstellung von v0.3*) |
| `assistant` | Vault, Projekt | `<name>`, `none` oder `inherit` | Zuordnung des Assistenten (Spec 03, *Zuordnung*); fehlt der Schlüssel, gilt `inherit` |
| `hosts` | alle Ebenen | Liste | in v0.5 nur `claude-code` |
| `hubs` | Home, Vault-Root | Liste von Namen bzw. `name: url` | Hub-Liste in Suchreihenfolge; die Vault-Root vor Home, bei gleichem Namen gilt die Vault-Root; ohne Eintrag `[aibex-aios]` (Spec 06, *Hub-Liste*) |
| `inline_limit` | Home | Zeichenzahl | Grenze für die Inline-Ladung von Master-Kontext und Assistent, Standard 9000 |

`aios` und `assistant` in `~/.aios/config.yaml` sind nicht erlaubt: Die Voreinstellung des Rechners darf keinen Vault aktivieren (Grundregel 6) und keinen Assistenten festlegen (Grundregel 8). Unbekannte Schlüssel, Schlüssel auf einer Ebene, auf der sie nicht erlaubt sind, ein `aios`-Wert, der keine Version ist, und ein `assistant`-Wert, der kein gültiger Name ist, werden mit Warnung ignoriert.

`config.yaml` verwendet eine Untermenge von YAML, die AIOS ohne PyYAML liest: Zeilen `schlüssel: wert` ohne Einrückung, Listen als `[a, b]` oder als eingerückte `- eintrag`, eine eingerückte Ebene `name: wert` (für `packages` sowie `skills` und `assistants` aus v0.3), als Wert auch eine einzeilige Abbildung `{schlüssel: wert, …}` mit Listen `[a, b]` darin (für `packages`), Listen mit gemischten Einträgen `- name` und `- name: wert` (für `hubs`), Kommentare mit `#`, Werte in Anführungszeichen und Blocktexte (`schlüssel: >` bzw. `|` mit eingerückten Zeilen, wie im Frontmatter einer `ASSISTANT.md`). Jeder Schlüssel darf je Datei nur einmal vorkommen. Eine Datei außerhalb dieser Untermenge wird in der Kette mit Warnung übergangen; `aios --activate`, `aios --deactivate` und `aios --assistant` brechen dann ab, ohne sie zu ändern.

### Konfigurationskette

Gelesen wird von `cwd` aufwärts jede `.aios/config.yaml` bis zur Vault-Root, danach `~/.aios/config.yaml`. **Je Schlüssel gilt der nächstgelegene Eintrag**. Ausnahmen: `packages` gilt nur im eigenen Projekt und wird nicht vererbt, weil jedes Projekt seine Pakete vollständig selbst enthält (Spec 06); die geholten und ausgerollten Pakete wirken trotzdem über die Kette. `hubs` wird aus Vault-Root und Home zusammengesetzt (Spec 06, *Hub-Liste*). Beim Schlüssel `assistant` zählt der Wert `inherit` als „kein Eintrag": Die Suche geht weiter nach oben (Spec 03). Außerhalb eines Vaults gilt nur `~/.aios/config.yaml`; liegt `~` in einem Vault, zählt `~/.aios/config.yaml` trotzdem als Ebene *Home*. `aios --config [<pfad>]` zeigt die wirksamen Werte mit ihrer Herkunft.

| Rang | Quelle |
|---|---|
| 1 | Umgebungsvariable `AIOS_HOME` (Pfad einer Installation oder eines Entwicklungsstands) — nur für die Wahl der Version |
| 2 | `<cwd>/.aios/config.yaml` |
| 3 | `.aios/config.yaml` übergeordneter Projekte, aufwärts |
| 4 | `§<Vault>/.aios/config.yaml` |
| 5 | `~/.aios/config.yaml` (ohne `aios` und `assistant`) |

### `installations.yaml`

```yaml
v0.5.0: /opt/aios/v0.5.0
```

Eine Zeile je Version, `v<version>: <pfad>`. `~/.aios/installations.yaml` hat dasselbe Format; bei gleichem Namen gewinnt der Eintrag des Benutzers.

### `lock.yaml` und `workers.yaml`

Beide schreibt nur AIOS, in einer festen Untermenge von YAML, die ein Bash-Skript ohne YAML-Parser lesen kann (V0.5, Memo 37, K-a): Einrückung immer zwei Leerzeichen je Ebene, ein Schlüssel je Zeile, Werte ohne Anführungszeichen außer bei Bereichen (`"~=0.1.0"`), Listen nur einzeilig `[a, b]`, keine Blocktexte, eine Kopfzeile `# written by AIOS (…), do not edit`. Das Format von `lock.yaml` steht in Spec 06 (*Konfiguration und Lock*).

```yaml
# written by AIOS (worker setup), do not edit
schema: 1
programs:
  yt-dlp: [worker-yt-dlp]
  deno: [worker-deno]
workers:
  worker-yt-dlp:
    0.1.0:
      kind: python
      check: ok
      projects: ["/Users/hux/vault/§Wald", "/Users/hux/vault/§Wald/P-Probe-Alt"]
  worker-deno:
    0.1.0:
      kind: python
      check: ok
      projects: ["/Users/hux/vault/§Wald"]
```

`programs` nennt je Programm die Pakete, die es bereitstellen (gelesen vom Weiterleiter, Spec 07). Unter `workers` steht je Paket und Version die Art, das letzte Ergebnis von `check` (`ok` oder `failed`) und die nutzenden Projekte. Der Ort einer Version ergibt sich aus dem Ort der Datei (`<workers.yaml>/../workers/<paket>/v<version>/`). Pfade mit Leerzeichen oder Sonderzeichen stehen in Anführungszeichen.

### `.aios/registry`

```yaml
# written by AIOS (registration), do not edit
schema: 1
registered:
  memo:
    source: "/…/§Demo/@/@!Skill/memo"
    version: 6.0.0
    digest: sha256:…
```

`digest` ist SHA-256 über alle Dateien des Skills, je Datei in Pfadfolge `<relativer pfad>⏎<inhalt>⏎`; die Registrierung erkennt damit Änderungen am Blueprint und an der Kopie in `.claude/skills/`. `version` ist immer gesetzt, weil Skills ohne Version nicht registriert werden (Spec 03). Die Registry hat dieses feste Format und wird nur von AIOS geschrieben; in v0.3 hieß sie `.aios/manifest`. `aios --skill aios-memo` liest sie, um den Vorrang von `memo` zu prüfen (Spec 03).

### Merker der Session — `~/.aios/sessions/<session-id>.yaml`

```yaml
# written by AIOS (session), do not edit
cwd: "/…/§Demo/G-Garten"
assistant: gaertner
used: 2026-10-03T14:05:00
```

`assistant` ist ein Name oder `none`, nie `inherit`. Geschrieben vom SessionStart-Hook und von `aios --assistant --session` (Spec 02, 03), gelesen vom Hook, von `aios --context --assignment --session` und `aios --gui --session`. Format: die Untermenge von `config.yaml`.

### Hooks in `~/.claude/settings.json`

```json
{
  "hooks": {
    "SessionStart":     [ { "hooks": [ { "type": "command", "command": "aios --context --session" } ] } ],
    "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "aios --context --advise" } ] } ]
  }
}
```

Zusammengeführt mit dem `json`-Modul von Python; andere Schlüssel und fremde Hooks bleiben erhalten, auch fremde Hooks in derselben Gruppe. Die Hooks `ai-brain --session` bzw. `ai-brain --advise` werden entfernt und in `~/.aios/hooks-backup.json` gesichert, im selben Aufbau wie `settings.json` (`{"hooks": {…}}`). Ist `settings.json` kein gültiges JSON, bricht `aios` ab, bevor etwas geschrieben wird. Hooks `aios-context --session` bzw. `--advise` aus v0.3 und v0.4 ersetzt `aios --install` durch die neuen Aufrufe (V0.5, Memo 04).

### Versionsneutrale AIOS-Skills und Alias

```markdown
---
name: aios-init
description: "<Beschreibung aus /opt/aios/v<version>/skills/aios/aios-init/SKILL.md>"
allowed-tools: Bash(aios --skill *), <allowed-tools aus derselben SKILL.md>
---

!`aios --skill aios-init`
```

`aios --skill <name>` gibt den Rumpf (ohne Frontmatter) der `SKILL.md` der **gültigen** Version aus; gültig ist die Version, die der Weiterleiter für `cwd` wählt. Beschreibung und `allowed-tools` werden bei jedem `aios --install` aus der installierten Version übernommen. Der Rumpf eines AIOS-Skills enthält keine `!`-Befehle, weil Claude Code die Ausgabe von `` !`aios --skill …` `` nicht noch einmal auswertet; er weist Claude an, die Befehle selbst auszuführen. Braucht ein Skill die Session-ID (`aios-assistant`, `aios-context`), bleibt der Aufruf `` !`aios --skill <name>` ``, den jede Version versteht, und die Hülle nennt die ID in einer Textzeile nach dem Aufruf: `` Session-ID dieses Chats: `${CLAUDE_SESSION_ID}` ``. Claude Code ersetzt den Platzhalter im Text der Hülle (V0.3, Memo 31); der Rumpf schreibt `<session-id>` und verweist auf diese Zeile. So bleibt die Hülle versionsneutral, auch für Projekte, die noch an eine ältere Version gebunden sind (V0.3, Memo 50). `aios --skill <name> --session <id>` setzt die ID für `<session-id>` direkt in den Rumpf ein (für Tests und Aufrufe von Hand).

Der Alias `/gui` hat dieselbe Form mit festem Text:

```markdown
---
name: gui
description: "Zeigt die Oberfläche des aktiven Assistenten (AIbex AIOS). Auslöser: /gui, „Oberfläche", „Menü"."
allowed-tools: Bash(aios --gui *), Bash(aios --context *)
---

!`aios --gui --session ${CLAUDE_SESSION_ID}`
```

v0.5 liefert die AIOS-Skills `aios-context`, `aios-init`, `aios-register`, `aios-status`, `aios-package`, `aios-fetch`, `aios-deploy`, `aios-distribution`, `aios-assistant`, `aios-integrity`, `aios-memo` und `aios-gui` sowie den Alias `gui` (Spec 02, 03, 05). Lesende Skills dürfen `Bash(aios --context *)`, nicht `Bash(aios *)` (V0.5, Memo 03).

### `.gitignore`-Vorlage

```gitignore
.DS_Store
.claude/skills/
.agents/
.aios/registry
.aios/backup/
```

`.agents/` enthält Kopien von Skills für andere Agenten (V0.5, Memo 10), `.aios/backup/` die Sicherung während eines Plans (Spec 06).

## Umlenkung für Tests

Alle festen Orte lassen sich über Umgebungsvariablen umlenken, damit Tests in einem Sandkasten laufen und den Rechner nicht verändern:

| Variable | ersetzt | Standard |
|---|---|---|
| `AIOS_PREFIX` | `/opt/aios` | `/opt/aios` |
| `HOME` | `~` (damit `~/bin`, `~/.aios`) | Home-Verzeichnis |
| `AIOS_CLAUDE_DIR` | `~/.claude` | `$HOME/.claude` |
| `AIOS_SUDO` | Programm für `sudo` | `sudo` |
| `AIOS_STUP_URL` | Quelle von stup (auch `file://`) | `https://raw.githubusercontent.com/bluccino/tool-stup/master/bin/stup` |
| `AIOS_HUBS` | Hub-Liste für Tests, ersetzt `hubs` aus Vault-Root und Home: Einträge `name=url` (auch `file://`), durch Leerzeichen getrennt | — |
| `AIOS_GITHUB` | Basis-URL für Hubs außerhalb der Hub-Liste (statt `https://github.com/`), für Tests auch `file://` | `https://github.com/` |
| `AIOS_PIP` | Befehl, der `python/requirements.txt` in die venv installiert; gesetzt wird die venv ohne `pip` angelegt | `<venv>/bin/python -m pip install -q -r` |
| `AIOS_PREPARE_PATH` | `PATH` für die Prüfung der Grund- und Entwicklerausstattung in `aios --prepare` und `aios --install` (V0.5, Memo 49) | `PATH` |
| `AIOS_PIP_FIND_LINKS` | Ordner mit Wheels für das setup von Arbeitspferden: `pip` läuft dann mit `--no-index --find-links <ordner>`, nie ohne `--no-index` (Spec 07) | — |

Tests rufen damit nie das echte `sudo` auf und greifen nie auf das Netzwerk zu.

Weiterleiter und `aios` verwenden ausschließlich diese Variablen, nie fest verdrahtete Pfade.

## Weiterleiter

`~/bin/aios` enthält keine Logik außer der Wahl der Version; `aios --install` legt es aus `templates/forwarder` an. Den Weiterleiter `~/bin/aios-context` gibt es ab v0.5 nicht mehr; `aios --install` entfernt ihn (V0.5, Memo 04). Die Weiterleiter der Arbeitspferde unter `~/.aios/bin/` regelt Spec 07.

1. Ist `AIOS_HOME` gesetzt: `$AIOS_HOME/bin/aios` aufrufen.
2. `aios --activate v<version> …`: Ist diese Version installiert, wird sie aufgerufen, unabhängig davon, an welche Version `cwd` gebunden ist; so aktiviert immer die genannte Version (V0.3, Memo 54, A1). Ist sie nicht installiert, gilt die übliche Wahl, und die gewählte Version meldet die fehlende Installation.
3. Sonst vom physischen `cwd` (`pwd -P`) aufwärts bis zur Vault-Root die erste Zeile `aios: <version>` in einer `.aios/config.yaml` suchen. Außerhalb eines Vaults wird nicht gesucht, und `~/.aios/config.yaml` zählt nie, auch wenn `~` in einem Vault liegt.
4. Gefunden: `v<version>` in `~/.aios/installations.yaml`, danach in `/opt/aios/installations.yaml` nachschlagen und `<pfad>/bin/aios` mit allen Argumenten aufrufen. Nicht installiert: Fehler mit Hinweis auf `aios --install v<version>`.
5. Nicht gefunden:
   - `aios --context …`: **Legacy-Modus**, d. h. `ai-brain` mit den Argumenten nach `--context` aufrufen, falls vorhanden (`--session`, `--advise`, `--load`, `--context`); sonst nichts ausgeben. Ausnahme `--id`: Ausgabe von `ai-brain --id` mit angehängtem `mode=legacy`, außerhalb eines Vaults `mode=none` (Spec 02). Nur die Gruppe `--context` fällt auf `ai-brain` zurück (V0.5, Memo 03).
   - jeder andere Aufruf: die höchste installierte Version aufrufen.

Ist `cwd` an eine Version unter 0.5 gebunden, übersetzt der Weiterleiter `aios --context` nicht; solche Vaults werden vor der Installation von v0.5 aktiviert (V0.5, Memo 04).

„Höchste Version" gilt nach Semver: `0.10.0` liegt über `0.3.0`, eine Vorabversion wie `0.3.0-dev` unter `0.3.0`. In `installations.yaml` darf ein Pfad in Anführungszeichen stehen und mit `~/` beginnen.

Alle Argumente werden unverändert durchgereicht, auch `-?`, `--help` und `--version`. Die eigenen Optionen der Weiterleiter haben deshalb drei Striche:

| Option | Wirkung |
|---|---|
| `---which` | gewählte Installation und Grund, z. B. `tool=aios kind=aios target=/opt/aios/v0.5.0/bin/aios why=aios: 0.5.0 in /…/§Demo/.aios/config.yaml` |
| `---version` | Version des Weiterleiters |
| `---help` | Hilfe |

Die Weiterleiter lesen nur kleine Dateien und greifen nie auf das Netzwerk zu.

## CLI `aios`

| Befehl | Wirkung |
|---|---|
| `aios -?`, `--help`, `--version` | Hilfe bzw. Version des laufenden Programms |
| `aios --prepare [--dev]` | Rechner vorbereiten; `--dev` mit Entwicklerausstattung |
| `aios --install [v<version>]` | Version installieren (schließt `--prepare` ein) |
| `aios --install distribution-<name>[<bereich>] [<vault>] [--from <repo>]` | Distribution installieren bzw. aktualisieren: Kernel, Arbeitspferde, Pakete im Vault (Spec 06, *Distributionen*) |
| `aios --context [--list \| --id \| --load <pfad> \| --assistant <name> \| --assistants \| --assignment \| --session \| --advise]` | Master-Kontext und Assistenten lesen, für Hooks und lesende Skills (Spec 02) |
| `aios --activate v<version> [<pfad>]` | Vault oder Projekt an eine Version binden |
| `aios --deactivate [<pfad>]` | Bindung lösen |
| `aios --config [<pfad>]` | wirksame Konfiguration mit der Herkunft je Schlüssel, nur lesend |
| `aios --versions` | installierte Versionen und ihre Orte |
| `aios --remove-version v<version>` | Installation entfernen |
| `aios --uninstall` | Benutzereinrichtung entfernen |
| `aios --register [<pfad>]` | Projekt-Skills registrieren, mit Vorschau (Spec 03) |
| `aios --fetch [<hub>/]<paket>[<bereich>] [--hub <hub>] [--from <repo>] [--to <projekt>]` | Paket laden: holen, Arbeitspferde einrichten, ausrollen, registrieren (Spec 06, 07) |
| `aios --fetch [--to <projekt>]` | Projekt mit `lock.yaml` abgleichen (Spec 06) |
| `aios --fetch --upgrade [<paket>] [--to <projekt>]`, `--remove <paket>` | Pakete aktualisieren bzw. entfernen (Spec 06) |
| `aios --deploy <paket> --only <element>… \| --all [--to <projekt>]`, `aios --deploy [--to <projekt>]` | Elemente eines geholten Pakets ausrollen bzw. zeigen (Spec 06) |
| `aios --library [<suchwort> \| <paket>]` | Pakete der Hub-Liste suchen bzw. Versionen eines Pakets (Spec 06) |
| `aios --hubs [add <name> [<url>] \| remove <name>] [--vault]` | Hub-Liste zeigen bzw. ändern (Spec 06) |
| `aios --workspace init <repo> [<ordner>] \| update \| freeze \| status [<pfad>] [--group <g>]` | Workspace klonen, abgleichen, einfrieren, prüfen (Spec 06) |
| `aios --contribute <datei>… --to <paket> [--message <text>]` | Rückfluss als Pull Request (Spec 06) |
| `aios --run <befehl> [argumente]` | ausgerollter Befehl eines Pakets (Spec 06) |
| `aios --worker [<paket> setup] [--to <projekt>]` | Arbeitspferde zeigen bzw. reparieren (Spec 07) |
| `aios --skill <name> [--session <id>]` | Rumpf eines AIOS-Skills der gültigen Version (für die versionsneutralen Skills); mit `--session` ist `<session-id>` im Rumpf ersetzt |
| `aios --assistant <name\|none\|inherit> [--to <projekt>] [--session <id>]` | Assistent dem Projekt zuordnen (Spec 03, *Wechsel*) |
| `aios --gui [--session <id>] [--html]` | Rumpf des Oberflächen-Skills des aktiven Assistenten bzw. mit `--html` das HTML-Fragment (Spec 03, *Oberflächen*); `aios --gui --aios` für die AIOS-Oberfläche, `aios --gui --apps` für die Liste der Oberflächen ausgerollter Apps, `aios --gui --skill <oberfläche> [--html]` für die Oberfläche einer App |
| `aios --init [<pfad>] [--assistant <wert>] [--name <name>] [--accept-name]` | Ordner zum Projekt machen oder ein Projekt ergänzen (Spec 05) |
| `aios --integrity [<pfad>]` | Integrität des Projekts und aller Unterprojekte prüfen, nur lesend (Spec 05) |

Alle schreibenden Befehle zeigen zuerst einen Plan und fragen `[Y/n]` (I7). Für Skills, die im Bash-Werkzeug keine Rückfrage beantworten können, gibt es zwei Schalter: `--plan` zeigt nur den Plan und schreibt nichts (Exit 0), `--yes` überspringt die Frage. Ein Skill zeigt den Plan, fragt im Chat und ruft erst nach Ja mit `--yes` auf; ohne Eingabe auf stdin wird nie geschrieben. Mit `--yes` gibt ein Befehl nur noch das Ergebnis in wenigen Zeilen und Fehler aus. **Sprache:** Alle Ausgaben von `aios` auf stdout und stderr sind englisch, auch Berichte und Aufstellungen; deutsch bleiben nur die Commit-Nachrichten, die AIOS schreibt, sowie die Rümpfe der AIOS-Skills (V0.3, Memo 53, 54). Claude spricht mit dem User in dessen Sprache. `bin/aios` und die Weiterleiter sind Bash-Skripte nach der Bash-Konvention (Help-, Version- und Dispatch-Blöcke, Fallback); die Logik hinter `aios` läuft in Python im venv der Installation (`python/`). `--prepare`, `--install`, `--versions`, `--remove-version` und `--uninstall` verwenden nur die Standardbibliothek, weil sie aus einem Klon mit dem `python3` des Systems laufen, bevor eine venv existiert. Voraussetzungen sind die Grundausstattung aus `aios --prepare`.

### `aios --prepare`

| Prüfung | fehlt → |
|---|---|
| `/opt/aios` existiert und ist beschreibbar | anlegen, wenn das übergeordnete Verzeichnis beschreibbar ist; sonst `sudo mkdir -p /opt/aios && sudo chown $USER /opt/aios`; ohne `sudo` Rückfall auf `~/.aios/versions/`: Installationen liegen dann in `~/.aios/versions/v<version>/` und werden in `~/.aios/installations.yaml` eingetragen, damit die Weiterleiter sie finden |
| `~/bin`, `~/etc`, `~/tmp`, `~/git` | anlegen |
| stup vorhanden und aktuell | installieren nach `~/bin/stup` bzw. aktualisieren (von `bluccino/tool-stup`, Vergleich mit `stup --version`); ist die Quelle nicht erreichbar, nur eine Warnung, sofern stup vorhanden ist |
| `~/bin/profile.sh` | mit `stup --profile` anlegen, nur wenn sie fehlt; nie überschreiben |
| **Grundausstattung:** `python3` ≥ 3.9 mit den Modulen `venv` und `pip`, `git` | Meldung mit dem Weg dazu (z. B. Paketverwaltung des Systems); AIOS installiert nichts davon ohne Rückfrage. Ohne Grundausstattung gibt es kein setup von Arbeitspferden; Pakete ohne Arbeitspferde lassen sich weiter holen (V0.5, Memo 31) |
| **Entwicklerausstattung** (nur `--dev`): zusätzlich `gh` | Meldung mit dem Weg dazu; gebraucht für Veröffentlichen und `aios --contribute` |

Ist alles vorhanden: „Rechner vorbereitet", keine Rückfrage. `deno` ist keine Voraussetzung, sondern das Arbeitspferd `worker-deno` (Spec 07).

### `aios --install [v<version>]`

Aufgerufen aus einem Klon des Repos `aibex-aios` (`./bin/aios --install …`) oder über den Weiterleiter; dann gilt der Klon aus `~/.aios/repo`.

1. **Version bestimmen:** angegeben oder der höchste Tag `v<MAJOR.MINOR.PATCH>` im Repo (Vorabversionen wie `v0.3.0-rc1` nur, wenn angegeben); vorher `git fetch --tags`, sofern der Klon einen Remote hat.
2. **Vorbereitung prüfen:** ist der Rechner nicht vorbereitet, gehören die Schritte von `--prepare` in den Plan.
3. **Plan zeigen**, einmal fragen; muss `sudo` nach einem Passwort fragen, steht das im Plan.
4. **Installieren**, falls `v<version>` noch nicht installiert ist: Stand des Tags mit `git archive` nach `/opt/aios/v<version>/` übertragen (Abbildung siehe *Repo*), venv in `python/` anlegen und `pyyaml` installieren, `python -m compileall`, Dateien schreibschützen, Eintrag in `installations.yaml`.
5. **Benutzer einrichten**, was fehlt: Weiterleiter nach `~/bin` (angelegt von `--prepare`); ein vorhandener Weiterleiter wird nur durch einen neueren ersetzt, der Prototyp (`~/bin/aios` mit `~/etc/aios/`) immer. `~/.aios/config.yaml` mit `hosts: [claude-code]`, Hooks eintragen und `ai-brain`-Hooks sichern, `~/.aios/repo` merken.
6. **AIOS-Skills** der Gruppe `aios` als Hüllen in `~/.claude/skills/aios-*/` und den Alias in `~/.claude/skills/gui/` schreiben (bei jedem Install). Pakete holt der User mit `aios --fetch` bzw. `/aios-package` (Spec 06).
7. **Umstieg auf v0.5** (beim ersten Install von v0.5): Hooks auf `aios --context --session` bzw. `--advise` umschreiben, `~/bin/aios-context` entfernen, die `allowed-tools` der Hüllen auf `Bash(aios --context *)` umstellen. Der Plan nennt jeden bekannten Vault, der an eine Version unter 0.5 gebunden ist, mit dem Befehl `aios --activate v0.5.<n> <vault>` (V0.5, Memo 04); bekannt sind die Vaults aus den Merkern der Sessions (`cwd`) und aus `~/.aios/repo`.

Das Übertragen geschieht in ein temporäres Verzeichnis neben dem Ziel, das erst am Ende umbenannt wird; ein Abbruch hinterlässt keine halbe Installation.

Eine bereits installierte Version wird nicht erneut installiert (I5, I8).

### `aios --install distribution-<name>`

Erkennt AIOS am Argument ein Paket `distribution-<name>` statt einer Version, installiert es eine Distribution (Spec 06, *Distributionen*; V0.5, Memos 26, 27):

1. Distribution aus der Hub-Liste bzw. mit `--from <repo>` aus dem Arbeitsbaum lesen, auflösen (Kernel aus `kernel:`, Pakete mit Abhängigkeiten).
2. Ziel: `<vault>` oder der Vault von `cwd`.
3. Ein Plan mit zwei Teilen: **Rechner** (Kernel installieren, falls fehlend, wie `aios --install v<version>`; Arbeitspferde einrichten, Spec 07) und **Vault** (an den Kernel binden, mit Umstellung, falls nötig; Pakete holen, `packages:` und `lock.yaml` der Vault-Root schreiben; registrieren). Ein Ja.
4. Zuerst der Rechnerteil; scheitert er, bleibt der Vault unberührt. Dann der Vaultteil mit Sicherung (Spec 06, *Holen*).

Ist die Distribution schon installiert, aktualisiert derselbe Befehl auf die höchste Version im Bereich.

### `aios --activate v<version> [<pfad>]`

| Schritt | Regel |
|---|---|
| Pfad | angegeben oder `cwd` |
| Prüfung | Pfad liegt in einem Vault; `v<version>` ist installiert, sonst Abbruch mit Hinweis auf `aios --install` |
| Vault-Root | ist der Pfad eine Vault-Root (Name beginnt mit `§`), macht die Aktivierung sie zum Root-Projekt: Was von der Struktur eines Projekts fehlt (`@/`, `.git` mit Branch `main`, `.gitignore`), gehört in den Plan und wird nach Ja angelegt, mit erstem Commit wie bei `aios --init` (Spec 05; V0.3, Memo 23). Die Namensregel gilt für die Vault-Root nicht |
| Projekt | ist der Pfad kein Projekt (kein `@/`) und keine Vault-Root: Abbruch mit Hinweis auf `/aios-init` |
| Wirkung | `aios: <version>` in `<pfad>/.aios/config.yaml` schreiben bzw. ersetzen; an der Vault-Root ist `.aios/config.yaml` Teil des ersten Commits, sonst committet `aios --activate` nicht |
| Version | mit oder ohne `v` angegeben, geschrieben ohne `v`; steht dieselbe Version schon in der Datei und fehlt nichts von der Struktur: „nichts zu tun", keine Rückfrage |
| Umstellung | von v0.3 bzw. v0.4 im selben Plan (Spec 06, *Umstellung von v0.3*, *Umstellung von v0.4*) |
| Hinweis | Master-Kontext und Registrierung gelten ab dem nächsten Chat |

### `aios --deactivate [<pfad>]`

Entfernt den Schlüssel `aios` aus `<pfad>/.aios/config.yaml`. Danach gilt die Festlegung darüber, sonst der Legacy-Modus; beides wird gemeldet. `skills`, `assistant` und andere Schlüssel bleiben stehen, ebenso Kommentare; eine leere Datei wird entfernt, ein danach leeres `.aios/` ebenfalls. `@/`, `.git` und `.gitignore` bleiben. Steht kein `aios` in der Datei: „nichts zu tun".

### `aios --remove-version v<version>`

Entfernt `/opt/aios/v<version>/` (bzw. `~/.aios/versions/v<version>/`) und den Eintrag in `installations.yaml` nach Warnung und Bestätigung. Zeigt der Eintrag auf ein anderes Verzeichnis, etwa einen Klon als Entwicklungsstand, wird nur der Eintrag entfernt. Ist die Version die einzige installierte, wird zusätzlich auf `aios --uninstall` hingewiesen.

### `aios --uninstall`

Entfernt die Benutzereinrichtung: Weiterleiter, AIOS-Skills in `~/.claude/skills/aios-*/`, den Alias `~/.claude/skills/gui/`, die AIOS-Hooks und `~/.aios/sessions/`; stellt die Hooks aus `~/.aios/hooks-backup.json` wieder her. Installationen in `/opt/aios`, `~/.aios/config.yaml` sowie alle `.aios/` in Vaults und Projekten bleiben erhalten.

## Repo `aibex-aios` und Abbildung auf die Installation

```
aibex-aios/                          GitHub aibex-aios/aibex-aios, Tags v<version>
├── README.md
├── CLAUDE.md                        Regeln für die Arbeit am Repo
├── manifest.yaml                    Paket-Manifest des Kernels (type: kernel, Spec 06)
├── VERSION                          Entwicklungsstand, z. B. 0.5.0-dev
├── bin/                             aios (Einstieg: ./bin/aios --install)
├── lib/aios/                        Python-Paket
├── skills/aios/<name>/SKILL.md      AIOS-Skills (aios-gui mit gui.yaml)
├── templates/                       forwarder (Weiterleiter), gitignore (Vorlage für aios --init)
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

**Skills:** Das Repo enthält nur noch die AIOS-Skills (`skills/aios/`). `aios --install` schreibt sie als versionsneutrale AIOS-Skills nach `~/.claude/skills/` (Spec 03). Der Rumpf von `skills/aios/aios-memo/` ist der Rumpf von `memo` in der Version 6.0.0 und wird nicht angeglichen (Spec 03). Die bisherige Bibliothek (`skills/basic/`, `assistants/demo/`) ist in eigene Paket-Repos übergegangen (`aibex-aios/skill-memo`, `aibex-aios/assistant-gaertner`, `aibex-aios/assistant-astronom`, Spec 06); ihre Historie bleibt im Repo `aibex-aios` bis zum Tag `v0.3.1`.

| Repo | Installation |
|---|---|
| `bin/`, `lib/`, `templates/` | `v<version>/bin/`, `v<version>/lib/`, `v<version>/templates/` |
| `manifest.yaml`, `VERSION` | `v<version>/manifest.yaml`, `v<version>/VERSION` (beim Installieren mit der Version des Tags überschrieben) |
| `skills/aios/<name>/` | `v<version>/skills/aios/<name>/` |
| `python/requirements.txt` | `v<version>/python/` (venv) |
| `spec/` | `v<version>/doc/spec/` |
| `doc/tutorials/`, `doc/wiki/` (künftig) | `v<version>/doc/tutorials/`, `v<version>/doc/wiki/` |

Ein Release (Tag `v<version>`) ist nur vollständig, wenn `spec/` den Soll-Stand dieser Version beschreibt und `version` in `manifest.yaml` dem Tag entspricht.

Ein Entwicklungsstand wird ohne Installation genutzt, indem `~/.aios/installations.yaml` auf die Wurzel des Klons zeigt (z. B. `v0.5.0-dev: ~/git/AIbex/aibex-aios`) oder `AIOS_HOME` auf diesen Ort gesetzt wird. Der Weiterleiter findet dort wie in einer Installation `bin/aios`.

## Legacy und Umstieg

| Situation | Verhalten |
|---|---|
| Vault ohne `aios:` in der Kette | Legacy-Modus über `ai-brain` (Spec 02) |
| Vault mit `aios: 0.2.0` | läuft mit v0.2 weiter; Umstellung mit `aios --activate v0.3.0 <vault>`, danach ergänzt die Aktivierung die Struktur des Root-Projekts und die Konsistenzprüfung meldet Lücken in den Projekten (Spec 05) |
| Umstieg eines Vaults (z. B. `§AIbex`) | `@Skill` nach `@!Skill` verschieben und jedem Skill ein `version:` geben (ohne Version wird er nicht registriert); weitere `@`-Ordner prüfen, ob sie *Laden* bleiben sollen; `aios --activate v<version> <vault>`; Projekte ohne eigenes Repo mit `aios --init` ergänzen (Spec 05). Versionen und Tags der Pflegeprojekte sind Teil dieses Umstiegs, nicht von AIOS |
| Vault mit `aios: 0.3.<n>` | läuft mit v0.3 weiter, solange `aios-context` installiert ist; Umstellung mit `aios --activate v0.5.<n> <vault>` (bzw. `v0.4.<n>`), die Aktivierung bietet die Umstellung von `skills:` und `assistants:` auf `packages:` an (Spec 06, *Umstellung von v0.3*); `.aios/manifest` wird beim nächsten Registrieren durch `.aios/registry` ersetzt |
| Vault mit `aios: 0.4.<n>` | läuft mit v0.4 weiter, solange `aios-context` installiert ist; nach der Installation von v0.5 gibt es kein `aios-context` mehr, deshalb Umstellung mit `aios --activate v0.5.<n> <vault>` (Spec 06, *Umstellung von v0.4*) |
| Rückkehr | `aios --deactivate <vault>`; vollständig mit `aios --uninstall` |

Ein Rechner mit dem Prototyp von `aios` (Kopie nach `~/bin`, Konfiguration in `~/etc/aios/`) wird beim ersten `aios --install` umgestellt: Der Weiterleiter ersetzt `~/bin/aios`, `~/etc/aios/` wird entfernt.
