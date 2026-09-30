---
title: "Skills und Agenten"
date: 2026-10-01
author: iHux
status: Spec
tags: [spec, aios, v0.1, skills, agenten]
number: 03
related:
  - "Spec 01 AIbex AIOS v0.1 — Überblick"
  - "Spec 02 Master-Kontext"
  - "Spec 04 Installation und Konfiguration"
  - "Memo 02 Aktivierung eines Agenten in Claude Code (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 03 Registrierung der Skills in Claude Code (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 06 Projekt, Root-Projekt und Projektstatus (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
---

# Skills und Agenten

Diese Spec regelt die Arten von Skills, ihre Versionen, das Ausrollen und Registrieren, die Agenten sowie die AIOS-Skills `/aios-deploy`, `/aios-register`, `/aios-agent`, `/aios-init` und `/aios-status`. Der Skill `/aios-context` steht in Spec 02, Dateistrukturen, Formate und das CLI `aios` in Spec 04.

## Arten von Skills

| Art | Quelle | registriert in | Verwaltung |
|---|---|---|---|
| **AIOS-Skill** | `/opt/aios/v<version>/skills/aios/` | global `~/.claude/skills/aios-*/` (versionsneutral, Spec 04) | `aios --install` |
| **Projekt-Skill** | `@!Skill/<name>/` eines Masterspace der Kette | `<Projekt>/.claude/skills/<name>/` | Registrierung (siehe unten) |
| **Agenten-Skill** | `@!Agent/<agent>/@!Skill/<name>/` oder `@!Skill/<name>/` der Kette, genannt in `skills:` der `AGENT.md` | nicht registriert; `/aios-agent` lädt ihn als Kontext | `/aios-agent` |

Innerhalb der Projekt- und Agenten-Skills wird unterschieden:

| | installiert | lokal |
|---|---|---|
| Herkunft | über `/aios-deploy` aus Bibliothek oder Pflegeprojekt | im Projekt geschrieben |
| Manifest | steht in `skills:` einer `.aios/config.yaml` | steht in keinem Manifest |
| Version | Pflicht | optional |
| Änderungen | nur über `/aios-deploy`; direkte Änderungen meldet `/aios-deploy` | frei |

**Reservierte Namen:** Namen mit dem Präfix `aios-` sind AIOS-Skills vorbehalten. Ein Blueprint `@!Skill/aios-…/` in einer Kette wird nicht registriert; `/aios-context` und `/aios-register` melden ihn.

## Format eines Skills

Ein Skill ist ein Verzeichnis `<name>/` mit `SKILL.md` und optionalen Zusatzdateien.

```markdown
---
name: memo
version: 6.0.0
description: >
  Was der Skill tut und wann er auslöst (höchstens 1024 Zeichen).
---

# …
```

| Feld | Pflicht | Regel |
|---|---|---|
| `name` | ja | Kleinbuchstaben, Ziffern, Bindestriche, höchstens 64 Zeichen, gleich dem Verzeichnisnamen |
| `description` | ja | höchstens 1024 Zeichen |
| `version` | für installierte Skills | Semver `MAJOR.MINOR.PATCH`; Claude Code erkennt Skills mit diesem Feld ohne Einschränkung (Memo 16) |

## Versionen

| Aspekt | Regel |
|---|---|
| **Veröffentlichung** | Eine Version eines Skills aus einem Pflegeprojekt ist ein Git-Tag `<name>-v<version>` (z. B. `memo-v6.0.0`); `version` im Frontmatter des getaggten Stands muss übereinstimmen |
| **Mitgelieferte Skills** | liegen in `/opt/aios/v<version>/skills/<gruppe>/<name>/<skill-version>/` (v0.1: Gruppe `basic`, Spec 04); ihre Version ist unabhängig von der AIOS-Version |
| **Manifest** | `skills:` in `.aios/config.yaml` nennt je Skill eine **exakte** Version; Bereiche gibt es nicht |
| **Übertrumpfung** | je Skill: der nächstgelegene Eintrag in der Konfigurationskette gewinnt (Spec 04) |
| **Ort** | Das Manifest eines Projekts gehört zu den Blueprints in `@/@!Skill/` genau dieses Projekts |

## Ausrollen — `/aios-deploy`

Ausrollen legt fest, **wo** ein Skill gilt: Es kopiert eine Version als Blueprint in einen Masterspace und trägt sie ins Manifest ein.

**Aufruf:**

| Skill | CLI | Wirkung |
|---|---|---|
| `/aios-deploy memo==6.0.0` | `aios --deploy memo==6.0.0 [--to <projekt>] [--agent <name>] [--from <pflegeprojekt>]` | eine Version ausrollen |
| `/aios-deploy` | `aios --deploy [--to <projekt>]` | das Projekt mit seinem Manifest abgleichen |

| Option | Bedeutung | Standard |
|---|---|---|
| `--to <projekt>` | Zielprojekt (ein Ordner mit `@/` oder eine Vault-Root) | das Projekt der Session; der Skill fragt nach und schlägt das Root-Projekt vor |
| `--agent <name>` | Ziel ist `@!Agent/<name>/@!Skill/` des Zielprojekts | — |
| `--from <pflegeprojekt>` | Quelle ist ein Git-Repo mit `@Skill/<name>/` und dem Tag `<name>-v<version>` | Bibliothek der gültigen AIOS-Version |

**Ablauf:**

1. Quelle bestimmen und prüfen: Version vorhanden (Bibliothek) bzw. Tag vorhanden und Frontmatter passend (Pflegeprojekt).
2. Ziel bestimmen: `<ziel>/@/@!Skill/<name>/` bzw. `<ziel>/@/@!Agent/<agent>/@!Skill/<name>/`.
3. Vorschau: `new`, `changed`, `remove` je Datei, dazu die Änderung am Manifest (`memo: 5.2.0 → 6.0.0`). Weicht der vorhandene Blueprint von der im Manifest genannten Version ab, wird er als „direkt geändert" gemeldet.
4. Nach Ja: Blueprint spiegeln (nur dieser eine Ordner), Manifest `<ziel>/.aios/config.yaml` schreiben.
5. `/aios-register` im Projekt der Session aufrufen.

Ohne Argument gleicht `/aios-deploy` alle Einträge in `skills:` des Zielprojekts mit den Blueprints ab (z. B. nach `git pull` oder auf einem anderen Rechner). Ein Eintrag, der aus dem Manifest entfernt wurde, wird nach Rückfrage aus `@!Skill` entfernt.

Mitgelieferte Skills rollt nur der User aus; `aios --install` bietet es nicht an.

## Registrieren — `/aios-register`

Registrieren macht die geltenden Projekt-Skills **für Claude Code aufrufbar**.

**Algorithmus** (für das Projekt der Session):

1. Alle `@!Skill/<name>/` der Master-Space-Kette sammeln. Bei gleichem Namen gewinnt der nächstgelegene Masterspace. Reservierte Namen (`aios-*`) werden übersprungen.
2. Mit `<Projekt>/.claude/skills/` und `<Projekt>/.aios/manifest` vergleichen.
3. **neu**: kopieren; **geändert**: ersetzen; **weggefallen** (im Manifest, aber nicht mehr in der Kette): entfernen. Skills in `.claude/skills/`, die nicht im Manifest stehen, bleiben unberührt.
4. `.aios/manifest` schreiben (Format Spec 04).

| Aufruf | Rückfrage | Anlass |
|---|---|---|
| SessionStart-Hook (`aios-context --sync --yes`) | nein | jeder Session-Start in einem aktivierten Vault |
| `/aios-register`, `aios --register` | ja, mit Vorschau | manueller Anstoß, z. B. nach `/aios-deploy` |

**Wirksamkeit:** Claude Code übernimmt Skills, die nach dem Start einer Session angelegt werden, nicht zuverlässig in diese Session (Memo 16). Die Registrierung beim Session-Start stellt deshalb den Stand für den **nächsten** Chat her. Ändert sie etwas, meldet der Hook `AIOS-SKILLS: <Änderungen> — wirksam ab dem nächsten Chat`. `/aios-register`, `/aios-deploy` und `/aios-init` sagen nach dem Registrieren: „Der Skill ist ab dem nächsten Chat verfügbar (oder nach `/reload-skills`)." Ob `/reload-skills` das zuverlässig leistet, ist offen (Spec 01, O1).

## Agenten

### Aufbau

```
<Projekt>/@/
├── @!Prompt/<prompt>.md                   Persönlichkeit, wiederverwendbar
├── @!Skill/<skill>/SKILL.md               geteilte Skills
└── @!Agent/<agent>/
    ├── AGENT.md                           Bündel und Rollentext
    ├── @!Skill/<skill>/SKILL.md           private Skills (optional)
    └── @Wissen/                           Wissen des Agenten, mit Klassen
        ├── @Grundlagen/…                  Laden, wenn der Agent aktiv ist
        ├── @Content/…                     Laden: Inhaltsverzeichnis
        └── @@Thema/…                      Verfügbar
```

`AGENT.md`:

```markdown
---
name: obstgaertner
title: Obstgärtner
description: Bodenständiger Obstgärtner, rechnet ausschließlich mit Äpfeln und Birnen
prompt: obstgaertner
skills: [apfel-birnen-algebra, memo]
model:
  claude: sonnet
tools: [read, search]
---

## Handwerk
…
## Wissen
…
## Grenzen
…
```

| Feld | Pflicht | Regel |
|---|---|---|
| `name` | ja | gleich dem Verzeichnisnamen |
| `title` | ja | Anzeigename für `/aios-agent` |
| `description` | ja | eine Zeile |
| `prompt` | nein | Name einer Datei in `@!Prompt/` |
| `skills` | nein | Namen von Skills |
| `model` | nein | Modell je Host; in der Desktop-App nur ein Hinweis an den User |
| `tools` | nein | neutrale Namen; in v0.1 nur dokumentierend, nicht erzwungen |

**Auflösung von `prompt` und `skills`:** zuerst im Agentenordner, danach in den Masterspaces der Kette vom Projekt aufwärts; der nächstgelegene Treffer gewinnt. Ein nicht gefundener Name ist ein Fehler, den `/aios-agent` meldet.

### Aktivieren — `/aios-agent`

Auslöser: `/aios-agent <Name>[: <Titel>]`, z. B. `/aios-agent Obstgärtner: Teste Apfel-Birne`. Die Aktivierung ist **ohne Zustand**: Sie schreibt nichts nach `.claude/` oder `.aios/`.

1. `<Name>` gegen `title` bzw. `name` aller Agenten der Kette auflösen (ohne Rücksicht auf Groß-/Kleinschreibung und Umlaute). Kein oder mehrdeutiger Treffer: verfügbare Agenten listen.
2. `aios-context --agent <name>` ausführen. Es gibt in `<aios-agent name="…">` … `</aios-agent>` aus: den Prompt, den Text der `AGENT.md`, die geladenen Dateien und das Inhaltsverzeichnis des verfügbaren Wissens des Agentenordners sowie die `SKILL.md` aller genannten Skills.
3. Diese Ausgabe vollständig lesen.
4. Titel setzen: in der Desktop-App mit dem App-Werkzeug zum Setzen des Session-Titels; in der CLI den User bitten, `/rename <Titel>` einzugeben.
5. Kurz bestätigen („Obstgärtner aktiv"), `model` gegebenenfalls als Hinweis nennen, danach in der Rolle antworten.

Die Aktivierung gilt bis zum Ende des Chats. Nach einer Compaction muss sie wiederholt werden; der Skill weist darauf hin.

## Initialisieren — `/aios-init`

Macht das Arbeitsverzeichnis zum Projekt. Auslöser: `/aios-init`, Wahl (1) nach `PROJECT-UNINITIALIZED` (Spec 02).

| Schritt | Wirkung |
|---|---|
| Prüfen | `cwd` liegt in einem aktivierten Vault und hat kein `@/`. Liegt `cwd` bereits in einem Git-Repo, wird das gemeldet und nachgefragt, bevor `git init` ausgeführt wird |
| Vorschau | Liste der anzulegenden Dateien; Anlegen erst nach Ja |
| Anlegen | `@/`, `@Memo/`, `.gitignore` aus der Vorlage (Spec 04), `git init -b main` |
| Registrieren | `aios-context --sync --yes` |
| Commit | erster Commit mit `.gitignore` und den angelegten Ordnern (`.gitkeep` in leeren Ordnern) |
| Abschluss | Hinweis, dass der Master-Kontext für das neue Projekt ab dem nächsten Chat vollständig gilt |

Für das Root-Projekt ist `/aios-init` nicht nötig; `aios --activate` legt dort ein fehlendes `@/` an.

## Projektstatus — `/aios-status`

Rekonstruiert eine kurze Übersicht, **was im Projekt erledigt wurde und was offen ist**. Der Status wird nicht gespeichert. Auslöser: `/aios-status`, „Projektstatus", „Wo stehen wir?". Er läuft nur auf Anforderung.

| Quelle | ausgewertet |
|---|---|
| `@Memo/` | Header (`Datum`, `Status`, `Ersetzt`), Abschnitte *Offen* und *Caveats* |
| Git-Log des Projekts | Umsetzungsschritte, jüngster Commit |

1. Memos in Nummernfolge lesen; Header und die Abschnitte *Offen* und *Caveats* genau, den Rest überfliegen.
2. Abgleichen: Was ein späteres Memo entscheidet oder mit `Ersetzt` ablöst, gilt nicht mehr als offen. Bei Widerspruch gilt das spätere Memo.
3. Das Git-Log ergänzt Schritte, die in keinem Memo stehen.
4. Ausgabe im Chat:

```
Projektstatus <Projekt> — Stand <Datum>

Erledigt
- …
Offen
- …
Zuletzt: <hash> <Commit-Nachricht> (<Datum>)
```

Gespeichert wird der Status nur auf ausdrücklichen Wunsch, dann als gewöhnliches Memo.
