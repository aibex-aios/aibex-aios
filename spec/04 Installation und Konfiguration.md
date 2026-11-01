---
title: "Installation und Konfiguration"
date: 2026-11-01
author: iHux
status: Spec
tags: [spec, aios, v0.6, installation, konfiguration]
number: 04
related:
  - "Spec 01 AIbex AIOS v0.6 — Überblick"
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
  - "Memos 02, 03, 06, 07, 12, 14–19, 21, 24, 28–30 (AA-AIbex-AIOS, @Memo/V0.6)"
  - "Memos 79–84 (AA-AIbex-AIOS, @Memo/V0.6): v0.6.1"
---

# Installation und Konfiguration

Diese Spec regelt, welche Dateien AIOS v0.6 wo anlegt, ihre Formate, die Konfiguration mit Übertrumpfung, die Weiterleiter, das CLI `aios` und den Umstieg von v0.5. Plattformen: macOS und Linux.

AIBOS schreibt nur in drei Bereiche (Spec 01, Grundregel 11, I13): a) `~/.aios`, b) das Innere von Vaults, c) die eigenen Hook-Einträge in `~/.claude/settings.json`. Nach `/opt/aios` installiert es nur mit `aios --install --system` (V0.6, Memo 14, K4).

## Dateistrukturen

### Installationen — `~/.aios/` oder `/opt/aios/`

Eine Installation hat an beiden Orten denselben Aufbau. **Standard** ist `~/.aios/`: Kernel in `~/.aios/versions/v<version>/`, Arbeitspferde in `~/.aios/workers/`, Verzeichnisse `~/.aios/installations.yaml` und `~/.aios/workers.yaml`. Mit `aios --install --system` (computerweit, mit `sudo`) liegt dasselbe unter `/opt/aios/`, wie bis v0.5:

```
/opt/aios/                          bzw. ~/.aios/ mit versions/ statt der Versionen direkt
├── installations.yaml
├── workers.yaml                    Verzeichnis der Arbeitspferde (Spec 07)
├── workers/<paket>/v<version>/     Installationen der Arbeitspferde, unveränderlich (Spec 07)
├── shared/                         in v0.6 leer
└── v0.6.0/                         unveränderlich (unter ~/.aios: versions/v0.6.0/)
    ├── VERSION
    ├── bin/
    │   └── aios
    ├── lib/aios/                   Python-Paket: Logik von aios
    ├── manifest.yaml               Paket-Manifest des Kernels (type: kernel, Spec 06)
    ├── skills/
    │   └── aios/aios-<name>/SKILL.md   Kernel-Skills (vollständig; aios-gui mit gui.yaml)
    ├── templates/
    │   ├── forwarder               Quelle des Weiterleiters ~/.aios/bin/aios
    │   └── gitignore               Vorlage für aios --init
    ├── doc/
    │   ├── spec/                   die Spec dieser Version (Pflicht)
    │   └── tutorials/              Tutorials (Demo-Assistenten, Projekte)
    └── python/                     venv mit PyYAML, vorkompiliert
```

Künftig kommt `doc/wiki/` hinzu.

| Pfad | angelegt von | Inhalt | änderbar |
|---|---|---|---|
| `~/.aios/` bzw. `/opt/aios/` | `aios --install` (`/opt/aios` nur mit `--system`) | gehört dem Benutzer (v0.6: ein Benutzer) | — |
| `installations.yaml` | `aios --install`, `--remove-version` | Verzeichnis der Installationen | nur durch AIOS |
| `versions/v<version>/` bzw. `/opt/aios/v<version>/` | `aios --install` | vollständige Installation, danach schreibgeschützt | nie (I5) |
| `workers/<paket>/v<version>/` | setup eines Arbeitspferds (`aios --fetch`, `aios --install`) | Installation einer Version eines Arbeitspferds, danach schreibgeschützt | nie (Spec 07, A2) |
| `workers.yaml` | setup und remove | Verzeichnis der Arbeitspferde | nur durch AIOS |

Installationen aus früheren Versionen unter `/opt/aios/` bleiben gültig; die Weiterleiter finden sie weiter (*Weiterleiter*). Arbeitspferde richtet AIBOS dort ein, wo es `/opt/aios/workers.yaml` schon gibt, sonst unter `~/.aios/` (Spec 07).

### Benutzer — `~`

```
~/.aios/
├── bin/aios                        Weiterleiter des Kernels
├── bin/<programm>                  Weiterleiter der Arbeitspferde (Spec 07)
├── config.yaml                     Voreinstellungen
├── installations.yaml              Installationen unter ~/.aios und eigene Einträge (z. B. Entwicklungsstand)
├── repo                            Pfad des Klons, aus dem zuletzt installiert wurde (darf außerhalb von ~/.aios liegen)
├── versions/v<version>/            Installationen des Kernels (Standard)
├── workers/, workers.yaml          Installationen der Arbeitspferde (Standard, Spec 07)
├── hooks-backup.json               vom Installieren ersetzte Hook-Einträge
├── cache/<id>/part-<n>.md          Part-Dateien des Master-Kontexts (Assistenten: cache/a-<name>-<id>/)
├── sessions/<session-id>.yaml      Merker: Assistent der Session (Spec 02)
├── packages/<hub>/<name>/<version>/ Cache der geholten Pakete (Spec 06)
├── hub/<hub>/                      Klon des Index-Repos eines Hubs, falls vorhanden (Spec 06)
└── log/context.log                 Fehler der Hooks außerhalb eines A/W und von --permit (Spec 02)
~/.claude/
└── settings.json                   drei AIOS-Hooks
```

| Pfad | angelegt von | entfernt von |
|---|---|---|
| `~/.aios/bin/aios` | erstes `aios --install` | `aios --uninstall` |
| `~/.aios/bin/<programm>` | erstes setup eines Arbeitspferds mit diesem Programm | remove der letzten Version (Spec 07) |
| `~/.aios/config.yaml` | erstes `aios --install` (nur wenn fehlend) | nie |
| `~/.aios/installations.yaml`, `log/`, `cache/`, `packages/`, `hub/` | bei Bedarf | `cache/`: Einträge älter als 7 Tage bei jedem `--load` |
| `~/.aios/sessions/` | SessionStart-Hook, `aios --assistant` | Merker mit `used` älter als 30 Tage beim Session-Start (`startup`); ganz bei `aios --uninstall` |
| `~/.aios/repo` | `aios --install` aus einem Klon | nie |
| `~/.aios/versions/v<version>/` | `aios --install` ohne `--system` | `aios --remove-version` |
| `~/.aios/hooks-backup.json` | erstes `aios --install` | `aios --uninstall` (nach Wiederherstellung) |
| Hooks in `~/.claude/settings.json` | erstes `aios --install` | `aios --uninstall` |

AIBOS legt nichts in `~/bin`, `~/etc`, `~/tmp` oder `~/git` an und ändert keine Startdatei der Shell; `~/.aios/bin` steht deshalb in der Regel nicht im `PATH`, und Hooks, Hüllen und Texte von AIOS rufen den Weiterleiter mit absolutem Pfad auf (V0.6, Memos 06, 07). `ai-brain` in `~/bin` bleibt unverändert. Ein Weiterleiter `~/bin/aios` früherer Versionen bleibt stehen (Altbestand, *Legacy und Umstieg*). Hüllen früherer Versionen in `~/.claude/skills/aios-*/` und `~/.claude/skills/gui/` entfernt der Umstieg, `aios --uninstall` ebenso; beide entfernen nur, was AIOS erkennbar selbst geschrieben hat (Kopfzeile des Weiterleiters bzw. `` !`aios --skill `` oder `` !`aios --gui `` im Rumpf).

### Vault

```
§<Vault>/
├── .git/                           Root-Projekt (Spec 05)
├── .gitignore                      mit den Ausschlüssen der Unterprojekte
├── .aios/config.yaml               Bindung oder Markierung, Pakete, Zuordnung
├── .aios/lock.yaml                 aufgelöste Pakete (Spec 06)
├── .aios/registry                  Build-Output
├── .claude/skills/<name>/          Build-Output: Hüllen der Kernel-Skills und des Alias, Projekt-Skills (Spec 03)
└── @/                              Root-Masterspace (Klassen, Spec 02)
    ├── @!Skill/<name>/             lokale Blueprints
    ├── @!Assistant/<name>/         lokale Blueprints
    └── @!Package/<name>/           nach aios --fetch (Spec 06)
```

| Pfad | angelegt von | Git |
|---|---|---|
| `.aios/config.yaml` | `aios --activate`, `aios --fetch`, `aios --deploy`, `aios --hubs --vault`, `aios --assistant`; `legacy:` der Umstieg nach Rückfrage | ja |
| `.aios/registry`, `.claude/skills/<name>/` | Registrierung (Spec 03) | nie |
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
| `.aios/config.yaml` | `aios --fetch --to <projekt>`, `aios --deploy --to <projekt>`, `aios --assistant`, `aios --init --assistant` | ja | ja |
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
aios: 0.6.0
packages:
  skill-memo: "~=6.0"
  assistant-gaertner: "~=0.2.0"
  knowledge-scorpio: {range: "~=0.1.0", hub: aibex-hub}
assistant: gaertner
hosts: [claude-code]
```

| Schlüssel | erlaubt in | Wert | Regel |
|---|---|---|---|
| `aios` | Vault-Root | Version ohne `v` | bindet den Vault an eine Version (Spec 02, *Arten von Vaults*); muss als einzelne Zeile `aios: <version>` stehen, weil die Weiterleiter sie ohne YAML-Parser lesen. In einem Projekt wird er mit Warnung übergangen, `aios --integrity` meldet ihn (Spec 01, I14; V0.6, Memos 14, 16) |
| `legacy` | Vault-Root | `ai-brain` | Markierung des Legacy-Modus (Spec 02); als einzelne Zeile `legacy: ai-brain`. Neben `aios` gilt `aios`, mit Warnung (V0.6, Memo 17) |
| `packages` | Vault, Projekt | Name → Bereich oder `{range, hub, from, only}` | gewünschte Pakete dieses Projekts, nicht vererbt (Spec 06, *Konfiguration und Lock*) |
| `skills`, `assistants` | Vault, Projekt | Name → exakte Version | aus v0.3; gelten als `packages` mit `==<version>` (Spec 06, *Umstellung von v0.3*) |
| `assistant` | Vault, Projekt | `<name>`, `none` oder `inherit` | Zuordnung des Assistenten (Spec 03, *Zuordnung*); fehlt der Schlüssel, gilt `inherit` |
| `hosts` | alle Ebenen | Liste | in v0.6 nur `claude-code` |
| `hubs` | Home, Vault-Root | Liste von Namen bzw. `name: url` | Hub-Liste in Suchreihenfolge; die Vault-Root vor Home, bei gleichem Namen gilt die Vault-Root; ohne Eintrag `[aibex-aios]` (Spec 06, *Hub-Liste*) |
| `inline_limit` | Home | Zeichenzahl | Grenze für die Inline-Ladung von Master-Kontext und Assistent, Standard 9000 |

`aios`, `legacy` und `assistant` in `~/.aios/config.yaml` sind nicht erlaubt: Die Voreinstellung des Rechners darf keinen Vault binden (Grundregel 6) und keinen Assistenten festlegen (Grundregel 8). Unbekannte Schlüssel, Schlüssel auf einer Ebene, auf der sie nicht erlaubt sind, ein `aios`-Wert, der keine Version ist, und ein `assistant`-Wert, der kein gültiger Name ist, werden mit Warnung ignoriert.

`config.yaml` verwendet eine Untermenge von YAML, die AIOS ohne PyYAML liest: Zeilen `schlüssel: wert` ohne Einrückung, Listen als `[a, b]` oder als eingerückte `- eintrag`, eine eingerückte Ebene `name: wert` (für `packages` sowie `skills` und `assistants` aus v0.3), als Wert auch eine einzeilige Abbildung `{schlüssel: wert, …}` mit Listen `[a, b]` darin (für `packages`), Listen mit gemischten Einträgen `- name` und `- name: wert` (für `hubs`), Kommentare mit `#`, Werte in Anführungszeichen und Blocktexte (`schlüssel: >` bzw. `|` mit eingerückten Zeilen, wie im Frontmatter einer `ASSISTANT.md`). Jeder Schlüssel darf je Datei nur einmal vorkommen. Eine Datei außerhalb dieser Untermenge wird in der Kette mit Warnung übergangen; `aios --activate`, `aios --deactivate` und `aios --assistant` brechen dann ab, ohne sie zu ändern.

### Konfigurationskette

Gelesen wird von `cwd` aufwärts jede `.aios/config.yaml` bis zur Vault-Root, danach `~/.aios/config.yaml`. **Je Schlüssel gilt der nächstgelegene Eintrag**. Ausnahmen: `aios` und `legacy` gelten nur aus der Vault-Root. `packages` gilt nur im eigenen Projekt und wird nicht vererbt, weil jedes Projekt seine Pakete vollständig selbst enthält (Spec 06); die geholten und ausgerollten Pakete wirken trotzdem über die Kette. `hubs` wird aus Vault-Root und Home zusammengesetzt (Spec 06, *Hub-Liste*). Beim Schlüssel `assistant` zählt der Wert `inherit` als „kein Eintrag": Die Suche geht weiter nach oben (Spec 03). Außerhalb eines Vaults gilt nur `~/.aios/config.yaml`; liegt `~` in einem Vault, zählt `~/.aios/config.yaml` trotzdem als Ebene *Home*. `aios --config [<pfad>]` zeigt die wirksamen Werte mit ihrer Herkunft.

| Rang | Quelle |
|---|---|
| 1 | Umgebungsvariable `AIOS_HOME` (Pfad einer Installation oder eines Entwicklungsstands) — nur für die Wahl der Version |
| 2 | `<cwd>/.aios/config.yaml` |
| 3 | `.aios/config.yaml` übergeordneter Projekte, aufwärts |
| 4 | `§<Vault>/.aios/config.yaml` |
| 5 | `~/.aios/config.yaml` (ohne `aios`, `legacy` und `assistant`) |

### `installations.yaml`

```yaml
v0.6.0: ~/.aios/versions/v0.6.0
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
  aios-init:
    source: kernel
    version: 0.6.0
    digest: sha256:…
```

Bei den Hüllen der Kernel-Skills und des Alias `gui` steht `source: kernel` und als `version` die Version des Kernels, der sie geschrieben hat (Spec 03, *Kernel-Skills im Vault*). `digest` ist SHA-256 über alle Dateien des Skills, je Datei in Pfadfolge `<relativer pfad>⏎<inhalt>⏎`; die Registrierung erkennt damit Änderungen am Blueprint und an der Kopie in `.claude/skills/`. `version` ist immer gesetzt, weil Skills ohne Version nicht registriert werden (Spec 03). Die Registry hat dieses feste Format und wird nur von AIOS geschrieben; in v0.3 hieß sie `.aios/manifest`. `aios --skill aios-memo` liest sie, um den Vorrang von `memo` zu prüfen (Spec 03).

### Merker der Session — `~/.aios/sessions/<session-id>.yaml`

```yaml
# written by AIOS (session), do not edit
cwd: "/…/§Demo/G-Garten"
assistant: gaertner
used: 2026-10-03T14:05:00
```

`assistant` ist ein Name oder `none`, nie `inherit`. Geschrieben vom SessionStart-Hook und von `aios --assistant --session` (Spec 02, 03), gelesen vom Hook, von `aios --context --assignment --session` und `aios --gui --session`; er gilt nur, solange das `cwd` des Aufrufs gleich seinem `cwd` ist (Spec 02). Format: die Untermenge von `config.yaml`.

### Hooks in `~/.claude/settings.json`

```json
{
  "hooks": {
    "SessionStart":     [ { "hooks": [ { "type": "command", "command": "/Users/…/.aios/bin/aios --context --session" } ] } ],
    "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "/Users/…/.aios/bin/aios --context --advise" } ] } ],
    "PreToolUse":       [ { "matcher": "Bash|Skill", "hooks": [ { "type": "command", "command": "/Users/…/.aios/bin/aios --context --permit" } ] } ]
  }
}
```

`aios --install` schreibt den absoluten Pfad des Weiterleiters aus (V0.6, Memo 06). Zusammengeführt mit dem `json`-Modul von Python; andere Schlüssel und fremde Hooks bleiben erhalten, auch fremde Hooks in derselben Gruppe. Vorhandene AIOS-Hooks (`aios --context --session` bzw. `--advise`, auch mit `~/bin/aios` oder ohne Pfad) ersetzt `aios --install` an ihrer Stelle durch den Aufruf mit absolutem Pfad; der Hook `PreToolUse` kommt dazu (V0.6, Memo 19, F10). Die Hooks `ai-brain --session` bzw. `ai-brain --advise` werden entfernt und in `~/.aios/hooks-backup.json` gesichert, im selben Aufbau wie `settings.json` (`{"hooks": {…}}`). Ist `settings.json` kein gültiges JSON, bricht `aios` ab, bevor etwas geschrieben wird. Hooks `aios-context --session` bzw. `--advise` aus v0.3 und v0.4 ersetzt `aios --install` durch die neuen Aufrufe (V0.5, Memo 04). Regeln in `permissions` schreibt AIBOS nicht (Spec 01, I13).

### Hüllen der Kernel-Skills und des Alias

```markdown
---
name: aios-init
description: "<Feld description aus <installation>/skills/aios/aios-init/SKILL.md, ungekürzt>"
allowed-tools: Bash(/Users/…/.aios/bin/aios --skill aios-init)
---

!`/Users/…/.aios/bin/aios --skill aios-init`
```

Die Hüllen schreibt die Registrierung im A/W an die Vault-Root und in die Projekte (Spec 03, *Kernel-Skills im Vault*), mit dem absoluten Pfad des Weiterleiters; `allowed-tools` nennt nur den eigenen Aufruf, alle weiteren Befehle gibt der Hook `PreToolUse` frei (Spec 02, *Freigabe*; V0.6, Memos 29, 30). `aios --skill <name>` gibt den Rumpf (ohne Frontmatter) der `SKILL.md` der **gültigen** Version aus; gültig ist die Version, die der Weiterleiter für `cwd` wählt. Außerhalb eines A/W gibt es nur `Kein AIBOS-Workspace: <cwd>` auf stderr aus und endet mit Exit-Code 1 (Spec 03). Die Beschreibung wird bei jeder Registrierung aus der gültigen Version übernommen. Der Rumpf eines Kernel-Skills enthält keine `!`-Befehle, weil Claude Code die Ausgabe von `` !`aios --skill …` `` nicht noch einmal auswertet; er weist Claude an, die Befehle selbst auszuführen. Braucht ein Skill die Session-ID (`aios-assistant`, `aios-context`), bleibt der Aufruf `` !`aios --skill <name>` ``, den jede Version versteht, und die Hülle nennt die ID in einer Textzeile nach dem Aufruf: `` Session-ID dieses Chats: `${CLAUDE_SESSION_ID}` ``. Claude Code ersetzt den Platzhalter im Text der Hülle (V0.3, Memo 31); der Rumpf schreibt `<session-id>` und verweist auf diese Zeile. So bleibt der Aufruf in der Hülle gleich, wenn der Vault an eine neue Version gebunden wird (V0.3, Memo 50). `aios --skill <name> --session <id>` setzt die ID für `<session-id>` direkt in den Rumpf ein (für Tests und Aufrufe von Hand).

Der Alias `/gui` hat dieselbe Form mit festem Text:

```markdown
---
name: gui
description: "Zeigt die Oberfläche des aktiven Assistenten (AIbex AIOS). Auslöser: /gui, „Oberfläche", „Menü"."
allowed-tools: Bash(/Users/…/.aios/bin/aios --gui --session *)
---

!`/Users/…/.aios/bin/aios --gui --session ${CLAUDE_SESSION_ID}`
```

v0.6 liefert die Kernel-Skills `aios-context`, `aios-init`, `aios-register`, `aios-status`, `aios-package`, `aios-fetch`, `aios-deploy`, `aios-distribution`, `aios-assistant`, `aios-integrity`, `aios-memo` und `aios-gui` sowie den Alias `gui` (Spec 02, 03, 05). Das Feld `allowed-tools` in der `SKILL.md` eines Kernel-Skills wird nicht mehr in die Hülle übernommen.

### `.gitignore`-Vorlage

```gitignore
.DS_Store
.claude/skills/
.claude/worktrees/
.agents/
.aios/registry
.aios/backup/
```

`.claude/worktrees/` enthält Arbeitskopien, die der Host für eine Session anlegen kann (V0.5, Memos 71, 73), `.agents/` Kopien von Skills für andere Agenten (V0.5, Memo 10), `.aios/backup/` die Sicherung während eines Plans (Spec 06).

## Umlenkung für Tests

Alle festen Orte lassen sich über Umgebungsvariablen umlenken, damit Tests in einem Sandkasten laufen und den Rechner nicht verändern:

| Variable | ersetzt | Standard |
|---|---|---|
| `AIOS_PREFIX` | `/opt/aios` (Installationen mit `--system` und solche früherer Versionen) | `/opt/aios` |
| `HOME` | `~` (damit `~/.aios`) | Home-Verzeichnis |
| `AIOS_CLAUDE_DIR` | `~/.claude` | `$HOME/.claude` |
| `AIOS_SUDO` | Programm für `sudo` | `sudo` |
| `AIOS_STUP_URL` | Quelle von stup (auch `file://`), nur für `aios --prepare` (Altbestand) | `https://raw.githubusercontent.com/bluccino/tool-stup/master/bin/stup` |
| `AIOS_HUBS` | Hub-Liste für Tests, ersetzt `hubs` aus Vault-Root und Home: Einträge `name=url` (auch `file://`), durch Leerzeichen getrennt | — |
| `AIOS_GITHUB` | Basis-URL für Hubs außerhalb der Hub-Liste (statt `https://github.com/`), für Tests auch `file://` | `https://github.com/` |
| `AIOS_PIP` | Befehl, der `python/requirements.txt` in die venv installiert; gesetzt wird die venv ohne `pip` angelegt | `<venv>/bin/python -m pip install -q -r` |
| `AIOS_TEST_FAIL` | `<n>` lässt den n-ten Schritt eines Plans scheitern, `<n>:crash` beendet den Prozess dort ohne Aufräumen (Tests der Sicherung, Spec 06; V0.5, Memo 51) | — |
| `AIOS_PREPARE_PATH` | `PATH` für die Prüfung der Grund- und Entwicklerausstattung in `aios --prepare` und `aios --install` (V0.5, Memo 49) | `PATH` |
| `AIOS_MANAGED_SETTINGS` | Managed Settings für `aios --context --permit` (Spec 02, *Freigabe*), statt der Standardorte | — |
| `AIOS_PIP_FIND_LINKS` | Ordner mit Wheels für das setup von Arbeitspferden: `pip` läuft dann mit `--no-index --find-links <ordner>`, nie ohne `--no-index` (Spec 07) | — |

Tests rufen damit nie das echte `sudo` auf und greifen nie auf das Netzwerk zu.

Weiterleiter und `aios` verwenden ausschließlich diese Variablen, nie fest verdrahtete Pfade.

## Weiterleiter

`~/.aios/bin/aios` enthält keine Logik außer der Wahl der Version; `aios --install` legt es aus `templates/forwarder` an. Ein `~/bin/aios` früherer Versionen bleibt als Altbestand stehen und wählt die Version nach seinen eigenen Regeln; Hooks und Hüllen rufen ab v0.6 nur `~/.aios/bin/aios` auf (V0.6, Memo 07). Einen Weiterleiter `~/bin/aios-context` (v0.4) und `~/etc/aios/` (Prototyp) entfernt `aios --install` ab v0.6 nicht mehr; der Plan nennt sie als Altbestand (V0.6, Memo 49, F59). `aios --install` erkennt einen Weiterleiter an beiden Kopfzeilen (`# forwarder: ~/bin/aios` bis 0.3.1, `# forwarder: ~/.aios/bin/aios` ab 0.4.0). Bei `aios --context --permit` und einer Version unter 0.6 endet der Weiterleiter still mit Exit 0, ohne den alten Kernel aufzurufen (V0.6, Memo 47). Die Weiterleiter der Arbeitspferde unter `~/.aios/bin/` regelt Spec 07.

1. Ist `AIOS_HOME` gesetzt: `$AIOS_HOME/bin/aios` aufrufen.
2. `aios --activate v<version> …`: Ist diese Version installiert, wird sie aufgerufen, unabhängig davon, an welche Version `cwd` gebunden ist; so aktiviert immer die genannte Version (V0.3, Memo 54, A1). Ist sie nicht installiert, gilt die übliche Wahl, und die gewählte Version meldet die fehlende Installation.
3. `aios --install distribution-…` (auch mit Hub-Präfix): die höchste installierte Version, unabhängig von `cwd`; ist sie älter als 0.5, Fehler mit Hinweis auf `aios --install v0.5.<n>` (Weiterleiter 0.3.0; V0.5, Memo 55).
4. Sonst vom physischen `cwd` (`pwd -P`) aufwärts die Vault-Root suchen und dort in `.aios/config.yaml` die Zeilen `aios: <version>` und `legacy: ai-brain` lesen. Andere `.aios/config.yaml` zählen nicht (Spec 01, I14). Außerhalb eines Vaults wird nicht gesucht, und `~/.aios/config.yaml` zählt nie, auch wenn `~` in einem Vault liegt.
5. `aios:` gefunden: `v<version>` in `~/.aios/installations.yaml`, danach in `/opt/aios/installations.yaml` nachschlagen und `<pfad>/bin/aios` mit allen Argumenten aufrufen; das gilt auch für eine Altbindung an 0.5 (Spec 02, *Arten von Vaults*). Nicht installiert: bei `aios --context …` nichts ausgeben (`--id`: `mode=none`) und den Fehler ins Log schreiben (Spec 02), sonst Fehler mit Hinweis auf `aios --install v<version>`.
6. Kein `aios:`:
   - `aios --context …` mit `legacy: ai-brain`: **Legacy-Modus**, d. h. `ai-brain` mit den Argumenten nach `--context` aufrufen, falls vorhanden (`--session`, `--advise`, `--load`, `--context`; `--permit` gibt nichts aus); sonst nichts ausgeben. Ausnahme `--id`: Ausgabe von `ai-brain --id` mit angehängtem `mode=legacy` (Spec 02). Nur die Gruppe `--context` ruft `ai-brain` auf (V0.5, Memo 03).
   - `aios --context …` ohne Markierung (Vault ohne Bindung, außerhalb eines Vaults): nichts ausgeben; `--id` meldet `mode=none` (Spec 02).
   - jeder andere Aufruf: die höchste installierte Version aufrufen.

Ist `cwd` an eine Version unter 0.5 gebunden, ruft der Weiterleiter `aios --context …` als `<installation>/bin/aios-context …` dieser Version auf (Weiterleiter 0.3.1). So behalten Vaults auf v0.3 und v0.4 nach der Installation von v0.5 ihren Master-Kontext, bis sie mit `aios --activate v0.5.<n>` umgestellt sind (V0.5, Memos 04, 63).

„Höchste Version" gilt nach Semver: `0.10.0` liegt über `0.3.0`, eine Vorabversion wie `0.3.0-dev` unter `0.3.0`. In `installations.yaml` darf ein Pfad in Anführungszeichen stehen und mit `~/` beginnen.

Alle Argumente werden unverändert durchgereicht, auch `-?`, `--help` und `--version`. Die eigenen Optionen der Weiterleiter haben deshalb drei Striche:

| Option | Wirkung |
|---|---|
| `---which` | gewählte Installation und Grund, z. B. `tool=aios kind=aios target=/Users/…/.aios/versions/v0.6.0/bin/aios why=aios: 0.6.0 in /…/§Demo/.aios/config.yaml` |
| `---version` | Version des Weiterleiters |
| `---help` | Hilfe |

Die Weiterleiter lesen nur kleine Dateien und greifen nie auf das Netzwerk zu.

## CLI `aios`

| Befehl | Wirkung |
|---|---|
| `aios -?`, `--help`, `--version` | Hilfe bzw. Version des laufenden Programms |
| `aios --prepare [--dev]` | Altbestand: Rechner nach v0.5 vorbereiten; wird von keinem Befehl und keiner Anleitung mehr verwendet |
| `aios --install [v<version>] [--system]` | Version installieren, nach `~/.aios/versions/` bzw. mit `--system` nach `/opt/aios/`; beim ersten Install von v0.6 mit dem Umstieg (*Legacy und Umstieg*) |
| `aios --install distribution-<name>[<bereich>] [<vault>] [--from <repo>]` | Distribution installieren bzw. aktualisieren: Kernel, Arbeitspferde, Pakete im Vault (Spec 06, *Distributionen*) |
| `aios --context [--list \| --id \| --load <pfad> \| --assistant <name> \| --assistants \| --assignment \| --session \| --advise \| --permit]` | Master-Kontext und Assistenten lesen, für Hooks und lesende Skills; Freigabe für den Hook `PreToolUse` (Spec 02) |
| `aios --activate v<version> [<vault-root>]` | Vault an eine Version binden, nur an der Vault-Root |
| `aios --deactivate [<vault-root>]` | Bindung lösen |
| `aios --config [<pfad>]` | wirksame Konfiguration mit der Herkunft je Schlüssel, nur lesend |
| `aios --versions` | installierte Versionen und ihre Orte |
| `aios --remove-version v<version>` | Installation entfernen |
| `aios --uninstall` | Benutzereinrichtung entfernen |
| `aios --register [<pfad>]` | Hüllen der Kernel-Skills und Projekt-Skills registrieren, mit Vorschau (Spec 03) |
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
| `aios --skill <name> [--session <id>]` | Rumpf eines Kernel-Skills der gültigen Version (für die Hüllen), nur im A/W; außerhalb `Kein AIBOS-Workspace: <cwd>`, Exit-Code 1; mit `--session` ist `<session-id>` im Rumpf ersetzt |
| `aios --assistant <name\|none\|inherit> [--to <projekt>] [--session <id>]` | Assistent dem Projekt zuordnen (Spec 03, *Wechsel*) |
| `aios --gui [--session <id>] [--html]` | Rumpf des Oberflächen-Skills des aktiven Assistenten bzw. mit `--html` das HTML-Fragment (Spec 03, *Oberflächen*); `aios --gui --aios` für die AIOS-Oberfläche, `aios --gui --apps` für die Liste der Oberflächen ausgerollter Apps, `aios --gui --skill <oberfläche> [--html]` für die Oberfläche einer App |
| `aios --init [<pfad>] [--assistant <wert>] [--name <name>] [--accept-name]` | Ordner zum Projekt machen oder ein Projekt ergänzen (Spec 05) |
| `aios --integrity [<pfad>]` | Integrität des Projekts und aller Unterprojekte prüfen, nur lesend (Spec 05) |

Alle schreibenden Befehle zeigen zuerst einen Plan und fragen `[Y/n]` (I7). Für Skills, die im Bash-Werkzeug keine Rückfrage beantworten können, gibt es zwei Schalter: `--plan` zeigt nur den Plan und schreibt nichts (Exit 0), `--yes` überspringt die Frage. Ein Skill zeigt den Plan, fragt im Chat und ruft erst nach Ja mit `--yes` auf; ohne Eingabe auf stdin wird nie geschrieben. Mit `--yes` gibt ein Befehl nur noch das Ergebnis in wenigen Zeilen und Fehler aus. **Sprache:** Alle Ausgaben von `aios` auf stdout und stderr sind englisch, auch Berichte und Aufstellungen; deutsch bleiben nur die Commit-Nachrichten, die AIOS schreibt, die Meldung `Kein AIBOS-Workspace` sowie die Rümpfe der Kernel-Skills (V0.3, Memo 53, 54). Claude spricht mit dem User in dessen Sprache. `bin/aios` und die Weiterleiter sind Bash-Skripte nach der Bash-Konvention (Help-, Version- und Dispatch-Blöcke, Fallback); die Logik hinter `aios` läuft in Python im venv der Installation (`python/`). `--prepare`, `--install`, `--versions`, `--remove-version` und `--uninstall` verwenden nur die Standardbibliothek, weil sie aus einem Klon mit dem `python3` des Systems laufen, bevor eine venv existiert. Voraussetzung ist die **Grundausstattung**: `python3` ≥ 3.11 mit den Modulen `venv` und `pip`, `git`. `aios --install` prüft sie selbst (unten).

### `aios --prepare`

**Altbestand:** `aios --prepare` bleibt bestehen, wird aber von keinem Befehl, keinem Installer und keiner Anleitung mehr verwendet; es legt Verzeichnisse außerhalb von `~/.aios` an und gehört damit nicht zu AIBOS (V0.6, Memos 06, 07). Es verhält sich wie in v0.5:

| Prüfung | fehlt → |
|---|---|
| `/opt/aios` existiert und ist beschreibbar | anlegen, wenn das übergeordnete Verzeichnis beschreibbar ist; sonst `sudo mkdir -p /opt/aios && sudo chown $USER /opt/aios`; ohne `sudo` Rückfall auf `~/.aios/versions/`: Installationen liegen dann in `~/.aios/versions/v<version>/` und werden in `~/.aios/installations.yaml` eingetragen, damit die Weiterleiter sie finden |
| `~/bin`, `~/etc`, `~/tmp`, `~/git` | anlegen |
| stup vorhanden und aktuell | installieren nach `~/bin/stup` bzw. aktualisieren (von `bluccino/tool-stup`, Vergleich mit `stup --version`); ist die Quelle nicht erreichbar, nur eine Warnung, sofern stup vorhanden ist |
| `~/bin/profile.sh` | mit `stup --profile` anlegen, nur wenn sie fehlt; nie überschreiben |
| **Grundausstattung:** `python3` ≥ 3.11 mit den Modulen `venv` und `pip`, `git` | Meldung mit dem Weg dazu (z. B. Paketverwaltung des Systems, auf macOS `brew install python`); AIOS installiert nichts davon ohne Rückfrage. Ohne Grundausstattung installiert `aios --install` nichts (Version und Distribution), und es gibt kein setup von Arbeitspferden; Pakete ohne Arbeitspferde lassen sich weiter holen (V0.5, Memo 31). 3.11, weil Arbeitspferde wie `yt-dlp` und `deno` es verlangen; das `python3` von macOS (3.9) genügt nicht (V0.5, Memos 90, 91: B11) |
| **Entwicklerausstattung** (nur `--dev`): zusätzlich `gh` | Meldung mit dem Weg dazu; gebraucht für Veröffentlichen und `aios --contribute` |

Ist alles vorhanden: „Rechner vorbereitet", keine Rückfrage. `deno` ist keine Voraussetzung, sondern das Arbeitspferd `worker-deno` (Spec 07).

### `aios --install [v<version>]`

Aufgerufen aus einem Klon des Repos `aibex-aios` (`./bin/aios --install …`) oder über den Weiterleiter; dann gilt der Klon aus `~/.aios/repo`.

1. **Version bestimmen:** angegeben oder der höchste Tag `v<MAJOR.MINOR.PATCH>` im Repo (Vorabversionen wie `v0.3.0-rc1` nur, wenn angegeben); vorher `git fetch --tags`, sofern der Klon einen Remote hat.
2. **Grundausstattung prüfen:** fehlt sie, meldet `aios --install`, was fehlt und wie es zu installieren ist (z. B. auf macOS `brew install python`), und bricht ab, ohne etwas zu schreiben (V0.6, Memo 07).
3. **Plan zeigen und fragen**; mit `--system` steht im Plan, dass `sudo` nach einem Passwort fragen kann; ohne `sudo` bricht `--system` ab, mit Hinweis auf den Standardort (V0.6, Memo 44, F49). Schritte mit eigener Frage nennt der Plan als Zeile „(then with its own question: …)"; gefragt wird nach dem Ja zum Plan (F60). Beim ersten Install von v0.6 enthält der Plan den Umstieg (*Legacy und Umstieg*), mit den dort genannten eigenen Fragen.
4. **Installieren**, falls `v<version>` noch nicht installiert ist: Stand des Tags mit `git archive` nach `~/.aios/versions/v<version>/` (mit `--system`: `/opt/aios/v<version>/`) übertragen (Abbildung siehe *Repo*), venv in `python/` anlegen und `pyyaml` installieren, `python -m compileall`, Dateien schreibschützen, Eintrag in `installations.yaml` desselben Orts.
5. **Benutzer einrichten**, was fehlt: Weiterleiter nach `~/.aios/bin/aios`; ein vorhandener wird nur durch einen neueren ersetzt. Nichts in `~/bin`; ein `~/bin/aios` früherer Versionen nennt der Plan als Altbestand und lässt es stehen. `~/.aios/config.yaml` mit `hosts: [claude-code]`, die drei Hooks mit absolutem Pfad eintragen bzw. an ihrer Stelle ersetzen (*Hooks in `~/.claude/settings.json`*) und `ai-brain`-Hooks sichern, `~/.aios/repo` merken.
6. **Keine globalen Hüllen:** `aios --install` schreibt nichts nach `~/.claude/skills/`; die Hüllen der Kernel-Skills entstehen mit der Registrierung im Vault (Spec 03). Pakete holt der User mit `aios --fetch` bzw. `/aios-package` (Spec 06).
7. **Bekannte Vaults** nennt der Plan mit ihrer Art (Spec 02, *Arten von Vaults*): Vaults mit Altbindung mit dem Befehl `aios --activate v0.6.<n> <vault>`; bekannt sind die Vaults aus den Merkern der Sessions (`cwd`), aus `~/.aios/repo` und aus den Projekten in `workers.yaml`; nur bekannte Vaults zählen (V0.6, Memo 49, F61). Für die Markierung `legacy: ai-brain` bietet der Plan bekannte Vaults ohne Bindung und die `§`-Ordner daneben im selben Elternordner an.

Das Übertragen geschieht in ein temporäres Verzeichnis neben dem Ziel, das erst am Ende umbenannt wird; ein Abbruch hinterlässt keine halbe Installation.

Eine bereits installierte Version wird nicht erneut installiert (I5, I8).

### `aios --install distribution-<name>`

Erkennt AIOS am Argument ein Paket `distribution-<name>` statt einer Version, installiert es eine Distribution (Spec 06, *Distributionen*; V0.5, Memos 26, 27):

1. Distribution aus der Hub-Liste bzw. mit `--from <repo>` aus einem lokalen Repo (getaggte Version) lesen, auflösen (Kernel aus `kernel:`, Pakete mit Abhängigkeiten).
2. Ziel: `<vault>` oder der Vault von `cwd`.
3. Ein Plan mit zwei Teilen: **Rechner** (Kernel installieren, falls fehlend, wie `aios --install v<version>`; Arbeitspferde einrichten, Spec 07) und **Vault** (an den Kernel binden, mit Umstellung, falls nötig; Pakete holen, `packages:` und `lock.yaml` der Vault-Root schreiben; registrieren, immer im Ziel-Vault, unabhängig vom Arbeitsverzeichnis; V0.6, Memo 03, K2). Der Plan nennt offene Dateien des Ziels, die er ändert (Spec 06, *Holen*). Ein Ja.
4. Zuerst der Rechnerteil; scheitert er, bleibt der Vault unberührt. Dann der Vaultteil mit Sicherung (Spec 06, *Holen*).

Ist die Distribution schon installiert, aktualisiert derselbe Befehl auf die höchste Version im Bereich.

**Frischer Rechner ohne PyYAML** (V0.5, Memos 71, 73: B7): Läuft `aios` aus einem Klon und fehlt im `python3` des Systems PyYAML (das ist die Regel, z. B. bei Homebrew oder einer Linux-Distribution), kann AIOS die Manifeste nicht lesen, bevor ein Kernel installiert ist. Derselbe Befehl zeigt dann **zwei Pläne** nacheinander:

1. **Plan des Kernels**, nur mit der Standardbibliothek: Version aus der Zeile `kernel: "==X.Y.Z"` der gewählten Version der Distribution (Auflösung über die Tags der Hubs bzw. `--from`), ohne `kernel:` die Bindung der Vault-Root, sonst der höchste Release-Tag des Klons. Der Plan entspricht `aios --install v<version>` und nennt als letzte Zeile `then: aios --install … with AIOS v<version> (plan of the distribution)`. Ein Ja.
2. Danach übergibt AIOS mit `exec` an `bin/aios` der neuen Installation, mit denselben Argumenten (auch `--plan` bzw. `--yes`); diese zeigt den Plan der Distribution wie oben. Ein zweites Ja.

Ist der Kernel schon installiert, entfällt der erste Plan. Mit `--plan` zeigt der Befehl nur den Plan des Kernels; mit `--yes` laufen beide ohne Rückfrage. Läuft `aios` nicht aus einem Klon und fehlt PyYAML, bricht es mit Hinweis auf `aios --install` ab.

Ziel der Arbeitspferde ist der Ort nach *Installationen* (Spec 07); der Plan nennt ihn.

### `aios --activate v<version> [<vault-root>]`

| Schritt | Regel |
|---|---|
| Pfad | angegeben oder `cwd` |
| Prüfung | Pfad ist eine Vault-Root (Name beginnt mit `§`), sonst Abbruch mit Hinweis auf die Vault-Root, die gebunden werden kann (V0.6, Memo 16, F5); `v<version>` ist installiert, sonst Abbruch mit Hinweis auf `aios --install` |
| Vault-Root | Die Aktivierung macht sie zum Root-Projekt: Was von der Struktur eines Projekts fehlt (`@/`, `.git` mit Branch `main`, `.gitignore`), gehört in den Plan und wird nach Ja angelegt, mit erstem Commit wie bei `aios --init` (Spec 05; V0.3, Memo 23). Die Namensregel gilt für die Vault-Root nicht |
| Wirkung | `aios: <version>` in `<vault-root>/.aios/config.yaml` schreiben bzw. ersetzen; eine Markierung `legacy:` in derselben Datei wird dabei entfernt. `.aios/config.yaml` ist Teil des ersten Commits, sonst committet `aios --activate` nicht |
| Registrierung | ab v0.6: die Hüllen der Kernel-Skills und des Alias an der Vault-Root und in allen Projekten des Vaults (Spec 03; V0.6, Memo 30, F18) |
| Hüllen früherer Versionen | Hängt danach kein bekannter Vault mehr an einer Version unter 0.6 (*Installieren*, Schritt 7), bietet der Plan an, die globalen Hüllen in `~/.claude/skills/aios-*/` und `~/.claude/skills/gui/` zu entfernen, mit eigener Frage; fremde Ordner bleiben (V0.6, Memo 30, F19) |
| Offene Dateien | Der Plan nennt offene Dateien des Vaults, die er ändert oder committet, zusammengefasst je Paketordner wie Spec 06, *Holen*, Schritt 4; er committet sie nicht selbst (V0.6, Memos 02, 81) |
| Version | mit oder ohne `v` angegeben, geschrieben ohne `v`; steht dieselbe Version schon in der Datei, fehlt nichts von der Struktur und ist die Registrierung aktuell: „nichts zu tun", keine Rückfrage |
| Umstellung | Pakete, die mit der neuen Version nicht laufen, im selben Plan mit allen Unterschritten (Spec 06, *Paketwechsel bei der Aktivierung*); von v0.3 bzw. v0.4 ebenso (Spec 06, *Umstellung von v0.3*, *Umstellung von v0.4*) |
| Hinweis | Master-Kontext und Registrierung gelten ab dem nächsten Chat |

### `aios --deactivate [<vault-root>]`

Entfernt den Schlüssel `aios` aus `<vault-root>/.aios/config.yaml`. Danach ist der Vault ohne Bindung und damit wirkungslos; das wird gemeldet, mit dem Hinweis auf `legacy: ai-brain` für den Legacy-Modus. `skills`, `assistant` und andere Schlüssel bleiben stehen, ebenso Kommentare; eine leere Datei wird entfernt, ein danach leeres `.aios/` ebenfalls. `@/`, `.git` und `.gitignore` bleiben. Steht kein `aios` in der Datei: „nichts zu tun".

### `aios --remove-version v<version>`

Entfernt `~/.aios/versions/v<version>/` (bzw. `/opt/aios/v<version>/`) und den Eintrag in `installations.yaml` nach Warnung und Bestätigung. Zeigt der Eintrag auf ein anderes Verzeichnis, etwa einen Klon als Entwicklungsstand, wird nur der Eintrag entfernt. Ist die Version die einzige installierte, wird zusätzlich auf `aios --uninstall` hingewiesen.

### `aios --uninstall`

Entfernt die Benutzereinrichtung: den Weiterleiter `~/.aios/bin/aios`, Hüllen früherer Versionen in `~/.claude/skills/aios-*/` und `~/.claude/skills/gui/`, die drei AIOS-Hooks und `~/.aios/sessions/`; stellt die Hooks aus `~/.aios/hooks-backup.json` wieder her und nennt ein `~/bin/aios` früherer Versionen, ohne es zu entfernen. Installationen in `~/.aios/versions/` und `/opt/aios`, `~/.aios/config.yaml` sowie alle `.aios/` und `.claude/skills/` in Vaults und Projekten bleiben erhalten; die Hüllen dort finden ohne Weiterleiter nichts mehr und können mit `/aios-register` nach einer neuen Installation erneuert werden.

## Repo `aibex-aios` und Abbildung auf die Installation

```
aibex-aios/                          GitHub aibex-aios/aibex-aios, Tags v<version>
├── README.md
├── CLAUDE.md                        Regeln für die Arbeit am Repo
├── manifest.yaml                    Paket-Manifest des Kernels (type: kernel, Spec 06)
├── VERSION                          Entwicklungsstand, z. B. 0.5.0-dev
├── bin/                             aios (Einstieg: ./bin/aios --install)
├── lib/aios/                        Python-Paket
├── skills/aios/<name>/SKILL.md      Kernel-Skills (aios-gui mit gui.yaml)
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

**Skills:** Das Repo enthält nur noch die Kernel-Skills (`skills/aios/`). Die Registrierung schreibt ihre Hüllen im A/W an die Vault-Root und in die Projekte (Spec 03). Der Rumpf von `skills/aios/aios-memo/` ist der Rumpf von `memo` in der Version 6.0.0 und wird nicht angeglichen (Spec 03). Die bisherige Bibliothek (`skills/basic/`, `assistants/demo/`) ist in eigene Paket-Repos übergegangen (`aibex-aios/skill-memo`, `aibex-aios/assistant-gaertner`, `aibex-aios/assistant-astronom`, Spec 06); ihre Historie bleibt im Repo `aibex-aios` bis zum Tag `v0.3.1`.

| Repo | Installation |
|---|---|
| `bin/`, `lib/`, `templates/` | `v<version>/bin/`, `v<version>/lib/`, `v<version>/templates/` |
| `manifest.yaml`, `VERSION` | `v<version>/manifest.yaml`, `v<version>/VERSION` (beim Installieren mit der Version des Tags überschrieben) |
| `skills/aios/<name>/` | `v<version>/skills/aios/<name>/` |
| `python/requirements.txt` | `v<version>/python/` (venv) |
| `spec/` | `v<version>/doc/spec/` |
| `doc/tutorials/`, `doc/wiki/` (künftig) | `v<version>/doc/tutorials/`, `v<version>/doc/wiki/` |

Ein Release (Tag `v<version>`) ist nur vollständig, wenn `spec/` den Soll-Stand dieser Version beschreibt und `version` in `manifest.yaml` dem Tag entspricht.

Ein Entwicklungsstand wird ohne Installation genutzt, indem `~/.aios/installations.yaml` auf die Wurzel des Klons zeigt (z. B. `v0.6.0-dev: ~/git/AIbex/aibex-aios`) oder `AIOS_HOME` auf diesen Ort gesetzt wird. Der Weiterleiter findet dort wie in einer Installation `bin/aios`.

## Legacy und Umstieg

| Situation | Verhalten |
|---|---|
| Vault ohne `aios:` und ohne `legacy:` an der Vault-Root | wirkungslos (Spec 02, *Arten von Vaults*) |
| Vault mit `legacy: ai-brain` | Legacy-Modus über `ai-brain` (Spec 02) |
| Vault mit `aios: 0.5.<n>` (Altbindung) | läuft mit v0.5 weiter, solange die Version installiert ist; Kernel-Skills über die globalen Hüllen von v0.5; Umstellung mit `aios --activate v0.6.<n> <vault>` (unten, *Umstieg auf v0.6*) |
| `aios:` in einem Projekt (aus v0.5 erlaubt) | wird ab v0.6 übergangen, mit Warnung; die Bindung gilt nur von der Vault-Root (Spec 01, I14) |
| Vault mit `aios: 0.2.0` | läuft mit v0.2 weiter; Umstellung mit `aios --activate v0.3.0 <vault>`, danach ergänzt die Aktivierung die Struktur des Root-Projekts und die Konsistenzprüfung meldet Lücken in den Projekten (Spec 05) |
| Umstieg eines Vaults (z. B. `§AIbex`) | `@Skill` nach `@!Skill` verschieben und jedem Skill ein `version:` geben (ohne Version wird er nicht registriert); weitere `@`-Ordner prüfen, ob sie *Laden* bleiben sollen; `aios --activate v<version> <vault>`; Projekte ohne eigenes Repo mit `aios --init` ergänzen (Spec 05). Versionen und Tags der Pflegeprojekte sind Teil dieses Umstiegs, nicht von AIOS |
| Vault mit `aios: 0.3.<n>` | läuft mit v0.3 weiter, solange `aios-context` installiert ist; Umstellung mit `aios --activate v0.5.<n> <vault>` (bzw. `v0.4.<n>`), die Aktivierung bietet die Umstellung von `skills:` und `assistants:` auf `packages:` an (Spec 06, *Umstellung von v0.3*); `.aios/manifest` wird beim nächsten Registrieren durch `.aios/registry` ersetzt |
| Vault mit `aios: 0.4.<n>` | läuft mit v0.4 weiter, solange `aios-context` installiert ist; nach der Installation von v0.5 gibt es kein `aios-context` mehr, deshalb Umstellung mit `aios --activate v0.5.<n> <vault>` (Spec 06, *Umstellung von v0.4*) |
| Rückkehr | `aios --deactivate <vault>`; vollständig mit `aios --uninstall` |

Ein Rechner mit dem Prototyp von `aios` (Kopie nach `~/bin`, Konfiguration in `~/etc/aios/`) wurde bis v0.5 beim ersten `aios --install` umgestellt; ab v0.6 bleibt `~/bin` unberührt, der Plan nennt den Prototyp als Altbestand.

### Umstieg auf v0.6

Der Umstieg eines Rechners mit v0.5 läuft in vier Schritten, jeder mit Plan und eigener Rückfrage (V0.6, Memos 24, 26, 30):

| # | Schritt | Wirkung |
|---|---|---|
| 1 | `<klon>/bin/aios --install v0.6.<n>` aus dem Klon (README, *Install*); ein getipptes `aios` erreicht über `~/bin/aios` noch den Installer von v0.5 (V0.6, Memo 56, B7) | Kernel nach `~/.aios/versions/`, Weiterleiter `~/.aios/bin/aios`, AIOS-Hooks an ihrer Stelle mit absolutem Pfad, Hook `PreToolUse` neu; `~/bin/aios` und fremde Hooks bleiben. Für jeden bekannten `§`-Ordner ohne Bindung fragt der Plan, wenn `ai-brain` vorhanden ist, ob er mit `legacy: ai-brain` markiert werden soll (V0.6, Memo 17, F9); mit `--yes` wird nicht markiert, der Plan nennt dann die Zeile. Vaults mit Altbindung nennt er mit dem Befehl für Schritt 3; ihre globalen Hüllen bleiben |
| 2 | Probe-Vault mit `aios: 0.6.<n>` (Spec 01, *Abnahmetest*; V0.6, Memo 16, F6) | 0.6 wird erprobt, ohne einen Vault mit Altbindung zu berühren |
| 3 | `aios --activate v0.6.<n> <vault>` je Vault mit Altbindung | Bindung an 0.6, Registrierung der Hüllen im Vault |
| 4 | im Plan von Schritt 3, sobald kein bekannter Vault mehr an 0.5 hängt | Angebot, die globalen Hüllen (12 `aios-*` und `gui`) zu entfernen; erst danach gilt Spec 01, Grundregel 6 auf dem Rechner |

Bis Schritt 4 bedient der Weiterleiter beide Kernel: einen Vault mit Altbindung mit v0.5, einen A/W mit v0.6. Die globalen Hüllen von v0.5 gewinnen beim Host vor gleichnamigen registrierten Hüllen im Vault (Spec 03, *Vorrang*); sie rufen `aios --skill` über den `PATH` auf (`~/bin/aios`), der die Version nach der Bindung wählt (V0.6, Memo 26, F17).
