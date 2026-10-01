---
title: "Skills und Assistenten"
date: 2026-10-01
author: iHux
status: Spec
tags: [spec, aios, v0.2, skills, assistenten]
number: 03
related:
  - "Spec 01 AIbex AIOS v0.2 — Überblick"
  - "Spec 02 Master-Kontext"
  - "Spec 04 Installation und Konfiguration"
  - "Memo 02 Aktivierung eines Agenten in Claude Code (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 03 Registrierung der Skills in Claude Code (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 06 Projekt, Root-Projekt und Projektstatus (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 14 Assistent statt Agent (Konzeptprojekt PAA-AIbex-AIOS-V0.2)"
  - "Memo 15 Jeder Skill hat eine Version (Konzeptprojekt PAA-AIbex-AIOS-V0.2)"
  - "Memo 16, 17 Demo-Assistenten (Konzeptprojekt PAA-AIbex-AIOS-V0.2)"
---

# Skills und Assistenten

Diese Spec regelt die Arten von Skills, ihre Versionen, das Ausrollen und Registrieren, die Assistenten sowie die AIOS-Skills `/aios-deploy`, `/aios-register`, `/aios-assistant`, `/aios-init` und `/aios-status`. Der Skill `/aios-context` steht in Spec 02, Dateistrukturen, Formate und das CLI `aios` in Spec 04.

## Arten von Skills

| Art | Quelle | registriert in | Verwaltung |
|---|---|---|---|
| **AIOS-Skill** | `/opt/aios/v<version>/skills/aios/` | global `~/.claude/skills/aios-*/` (versionsneutral, Spec 04) | `aios --install` |
| **Projekt-Skill** | `@!Skill/<name>/` eines Masterspace der Kette | `<Projekt>/.claude/skills/<name>/` | Registrierung (siehe unten) |
| **Assistenten-Skill** | `@!Assistant/<assistant>/@!Skill/<name>/` oder `@!Skill/<name>/` der Kette, genannt in `skills:` der `ASSISTANT.md` | nicht registriert; `/aios-assistant` lädt ihn als Kontext | `/aios-assistant` |

Innerhalb der Projekt- und Assistenten-Skills wird unterschieden:

| | installiert | lokal |
|---|---|---|
| Herkunft | über `/aios-deploy` aus Bibliothek oder Pflegeprojekt | im Projekt geschrieben |
| Manifest | steht in `skills:` einer `.aios/config.yaml` | steht in keinem Manifest |
| Version | Pflicht | Pflicht; ein neuer lokaler Skill beginnt mit `0.1.0` |
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
| `version` | ja, für jeden Skill | Semver `MAJOR.MINOR.PATCH`; Claude Code erkennt Skills mit diesem Feld ohne Einschränkung (V0.1, Memo 16) |

Ein Blueprint ohne gültige `version` gilt wie ein Blueprint mit falschem `name`: Er wird nicht registriert und nicht als Assistenten-Skill geladen, sondern gemeldet (Registrieren, Assistenten).

## Versionen

| Aspekt | Regel |
|---|---|
| **Veröffentlichung** | Eine Version eines Skills aus einem Pflegeprojekt ist ein Git-Tag `<name>-v<version>` (z. B. `memo-v6.0.0`); `version` im Frontmatter des getaggten Stands muss übereinstimmen |
| **Bibliothek** | Skills liegen in `/opt/aios/v<version>/skills/<gruppe>/<name>/<skill-version>/`, Assistenten in `/opt/aios/v<version>/assistants/<gruppe>/<name>/<assistant-version>/` (v0.2: Gruppen `basic` und `demo`, Spec 04); ihre Versionen sind unabhängig von der AIOS-Version. Im Repo tragen sie die Tags `<name>-v<version>` |
| **Manifest** | `skills:` und `assistants:` in `.aios/config.yaml` nennen je Name eine **exakte** Version; Bereiche gibt es nicht |
| **Übertrumpfung** | je Name: der nächstgelegene Eintrag in der Konfigurationskette gewinnt (Spec 04) |
| **Ort** | Das Manifest eines Projekts gehört zu den Blueprints in `@/@!Skill/` und `@/@!Assistant/` genau dieses Projekts |

## Ausrollen — `/aios-deploy`

Ausrollen legt fest, **wo** ein Skill oder Assistent gilt: Es kopiert eine Version als Blueprint in einen Masterspace und trägt sie ins Manifest ein.

**Aufruf:**

| Skill | CLI | Wirkung |
|---|---|---|
| `/aios-deploy memo==6.0.0` | `aios --deploy memo==6.0.0 [--to <projekt>] [--assistant <name>] [--from <pflegeprojekt>]` | eine Version eines Skills ausrollen |
| `/aios-deploy gaertner==0.1.0` | `aios --deploy gaertner==0.1.0 [--to <projekt>]` | eine Version eines Assistenten der Bibliothek ausrollen |
| `/aios-deploy` | `aios --deploy [--to <projekt>] [--from <pflegeprojekt>]` | das Projekt mit seinem Manifest abgleichen |
| — | `aios --library` | Skills und Assistenten der Bibliothek mit ihren Versionen |

| Option | Bedeutung | Standard |
|---|---|---|
| `--to <projekt>` | Zielprojekt (ein Ordner mit `@/` oder eine Vault-Root) | das Projekt der Session; der Skill fragt nach und schlägt das Root-Projekt vor |
| `--assistant <name>` | nur für Skills: Ziel ist `@!Assistant/<name>/@!Skill/` des Zielprojekts | — |
| `--from <pflegeprojekt>` | nur für Skills: Quelle ist ein Git-Repo mit `@Skill/<name>/` und dem Tag `<name>-v<version>` | Bibliothek der gültigen AIOS-Version |

**Skill oder Assistent:** Ohne `--from` wird `<name>` in der Bibliothek gesucht. Namen sind über alle Skills und Assistenten der Bibliothek eindeutig; ein Name ist also entweder ein Skill oder ein Assistent. Assistenten werden in v0.2 nur aus der Bibliothek ausgerollt.

**Ablauf:**

1. Quelle bestimmen und prüfen: Version vorhanden (Bibliothek) bzw. Tag vorhanden und Frontmatter passend (Pflegeprojekt).
2. Ziel bestimmen: `<ziel>/@/@!Skill/<name>/`, `<ziel>/@/@!Assistant/<assistant>/@!Skill/<name>/` bzw. für einen Assistenten `<ziel>/@/@!Assistant/<name>/`.
3. Vorschau: `new`, `changed`, `remove` je Datei, dazu die Änderung am Manifest (`memo: 5.2.0 -> 6.0.0`). Weicht der vorhandene Blueprint vom ausgerollten Stand ab (Prüfsumme in der Marke), wird er als „direkt geändert" gemeldet; ein gleichnamiger lokaler Blueprint ohne Marke ebenfalls. Beide werden ersetzt.
4. Nach Ja: Blueprint spiegeln (nur dieser eine Ordner) mit der Marke `.aios-deploy`, Manifest `<ziel>/.aios/config.yaml` schreiben (nur die Zeile des Skills bzw. Assistenten; Kommentare und andere Zeilen bleiben).
5. Bei einem Projekt-Skill die Projekt-Skills im Projekt der Session registrieren (wie `/aios-register`); bei Assistenten und Assistenten-Skills entfällt das, weil sie nicht registriert werden.

**Marke `.aios-deploy`:** Jeder ausgerollte Blueprint enthält die Datei `.aios-deploy` mit `name`, `version`, `source` (`library` oder Pfad des Pflegeprojekts) und `digest` (Prüfsumme der ausgerollten Dateien ohne die Marke, Verfahren wie Spec 04, *Manifest*). Sie wird mit dem Blueprint versioniert und unterscheidet ausgerollte von lokalen Blueprints. Bei einem Assistenten umfasst `digest` den ganzen Ordner einschließlich seiner privaten Skills und seines Wissens, ausgenommen Unterordner `@!Skill/<name>/` mit eigener Marke (Skills, die später mit `--assistant` hinzugefügt wurden).

**Manifeste:** Ein Assistent steht in `assistants:` als `<name>: <version>`. Ein Skill, der mit `--assistant <name>` ausgerollt wurde, steht in `skills:` als `<assistant>/<skill>: <version>`. Die privaten Skills eines ausgerollten Assistenten gehören zu seiner Version und stehen nicht einzeln im Manifest.

Ohne Argument gleicht `/aios-deploy` alle Einträge in `skills:` und `assistants:` des Zielprojekts mit den Blueprints ab (z. B. nach `git pull` oder auf einem anderen Rechner): Ein fehlender, direkt geänderter oder in einer anderen Version vorliegender Blueprint wird aus seiner Quelle neu ausgerollt. Quelle ist das mit `--from` genannte Pflegeprojekt, sonst das Pflegeprojekt aus der Marke, sonst die Bibliothek; ist keine Quelle zu finden, wird das mit Warnung gemeldet. Ein Blueprint mit Marke, dessen Eintrag aus dem Manifest entfernt wurde, wird nach Rückfrage entfernt; lokale Blueprints ohne Marke bleiben unberührt.

**Bibliothek in v0.2:**

| Name | Art | Gruppe | Version | Inhalt |
|---|---|---|---|---|
| `memo` | Skill | `basic` | 6.0.0 | neutrale Fassung des Memo-Stils ohne Bezüge auf einen bestimmten Vault |
| `gaertner` | Assistent | `demo` | 0.1.0 | Titel „Gärtner"; bodenständig, rechnet nur mit Äpfeln und Birnen; privater Skill `apfel-birnen-algebra` 0.1.0; Wissen: Grundlagen (Laden), Sortenkunde und Veredelung (Verfügbar) |
| `astronom` | Assistent | `demo` | 0.1.0 | Titel „Astronom"; poetisch-präzise, rechnet nur mit Sonne und Mond; privater Skill `sonne-mond-zahlen` 0.1.0 |

Die Demo-Assistenten werden im Repo `aibex-aios` gepflegt. Ihre Inhalte enthalten keine Pfade oder Bezüge auf einen bestimmten Vault; der Rollentext nennt in einem Satz, dass es sich um einen Demo-Assistenten handelt, dessen Inhalte der Veranschaulichung dienen. Ihre Grenzen sind gewollt: Der Gärtner lehnt Sonne-Mond-Aufgaben freundlich ab, der Astronom Apfel-Birne-Aufgaben. So zeigt das Ergebnis, welcher Assistent und welcher Skill aktiv sind.

Skills und Assistenten der Bibliothek rollt nur der User aus; `aios --install` bietet es nicht an.

## Registrieren — `/aios-register`

Registrieren macht die geltenden Projekt-Skills **für Claude Code aufrufbar**.

**Algorithmus** (für das Projekt der Session; registriert wird nur, wenn `cwd` ein initialisiertes Projekt mit `@/` in einem aktivierten Vault ist, sonst nichts):

1. Alle `<D>/@/@!Skill/<name>/` der Master-Space-Kette sammeln (private Skills eines Assistenten in `@!Assistant/…/@!Skill/` gehören nicht dazu). Bei gleichem Namen gewinnt der nächstgelegene Masterspace. Übersprungen und gemeldet werden reservierte Namen (`aios-*`), ungültige Namen, Ordner ohne `SKILL.md`, Skills, deren `name` nicht dem Verzeichnisnamen entspricht, und Skills ohne gültige `version`.
2. Mit `<Projekt>/.claude/skills/` und `<Projekt>/.aios/manifest` vergleichen.
3. **neu**: kopieren; **geändert** (anderer Inhalt oder andere Quelle des Blueprints, oder die Kopie in `.claude/skills/` wurde verändert): ersetzen; **weggefallen** (im Manifest, aber nicht mehr in der Kette oder nicht mehr gültig): entfernen. Skills in `.claude/skills/`, die nicht im Manifest stehen, bleiben unberührt und werden gemeldet, wenn ein Blueprint denselben Namen hat.
4. `.aios/manifest` schreiben (Format Spec 04).

| Aufruf | Rückfrage | Anlass |
|---|---|---|
| SessionStart-Hook (`aios-context --sync --yes`) | nein | jeder Session-Start in einem aktivierten Vault |
| `/aios-register`, `aios --register [<pfad>]`, `aios-context --sync` | ja, mit Vorschau | manueller Anstoß, z. B. nach `/aios-deploy`; der Skill holt mit `--plan` die Vorschau, fragt im Chat und führt nach Ja `--yes` aus |

**Wirksamkeit:** Claude Code übernimmt Skills, die nach dem Start einer Session angelegt werden, nicht zuverlässig in diese Session (V0.1, Memo 16). Die Registrierung beim Session-Start stellt deshalb den Stand für den **nächsten** Chat her. Ändert sie etwas, meldet der Hook `AIOS-SKILLS: <Änderungen> — wirksam ab dem nächsten Chat` (z. B. `AIOS-SKILLS: new memo; changed shared — wirksam ab dem nächsten Chat`); übersprungene Blueprints meldet er als `AIOS-WARNING`, z. B. `AIOS-WARNING: skill ohne-version has no version, not registered`. Weil die Kopie im Projekt selbst liegt, ist ein Skill aus einem Masterspace oberhalb auch dann verfügbar, wenn das Projekt ein eigenes Git-Repo ist (V0.1, Memo 27). `/aios-register`, `/aios-deploy` und `/aios-init` sagen nach dem Registrieren: „Der Skill ist ab dem nächsten Chat verfügbar (oder nach `/reload-skills`)." Ob `/reload-skills` das zuverlässig leistet, ist offen (Spec 01, O1).

## Assistenten

Ein Assistent ist eine Rolle, die AIOS dem KI-Assistenten des Hosts gibt: wer spricht, was er weiß und welche Skills er hat. **Abbildung auf Claude Code (v0.2):** `/aios-assistant` lädt den Assistenten ohne Zustand als Kontext in den laufenden Chat; die Agentenfunktion von Claude Code (`.claude/agents/`, Subagenten) wird nicht verwendet.

### Aufbau

```
<Projekt>/@/
├── @!Prompt/<prompt>.md                   Persönlichkeit, wiederverwendbar
├── @!Skill/<skill>/SKILL.md               geteilte Skills
└── @!Assistant/<assistant>/
    ├── ASSISTANT.md                       Bündel und Rollentext
    ├── .aios-deploy                       nur bei ausgerollten Assistenten
    ├── @!Skill/<skill>/SKILL.md           private Skills (optional)
    └── @Wissen/                           Wissen des Assistenten, mit Klassen
        ├── @Grundlagen/…                  Laden, wenn der Assistent aktiv ist
        ├── @Content/…                     Laden: Inhaltsverzeichnis
        └── @@Thema/…                      Verfügbar
```

`ASSISTANT.md`:

```markdown
---
name: gaertner
title: Gärtner
version: 0.1.0
description: Bodenständiger Gärtner, rechnet ausschließlich mit Äpfeln und Birnen
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
| `name` | ja | gleich dem Verzeichnisnamen; Kleinbuchstaben, Ziffern, Bindestriche |
| `title` | ja | Anzeigename für `/aios-assistant` |
| `version` | ja | Semver `MAJOR.MINOR.PATCH`; ein neuer lokaler Assistent beginnt mit `0.1.0` |
| `description` | ja | eine Zeile |
| `prompt` | nein | Name einer Datei in `@!Prompt/` |
| `skills` | nein | Namen von Skills |
| `model` | nein | Wunsch an den Host, Modell je Host; in der Desktop-App nur ein Hinweis an den User |
| `tools` | nein | Wunsch an den Host, neutrale Namen; in v0.2 nur dokumentierend, nicht erzwungen |

**Auflösung von `prompt` und `skills`:** zuerst im Assistentenordner (`<assistant>/@!Prompt/<prompt>.md`, `<assistant>/@!Skill/<skill>/SKILL.md`), danach in den Masterspaces der Kette vom Projekt aufwärts (`<D>/@/@!Prompt/…`, `<D>/@/@!Skill/…`); der nächstgelegene Treffer gewinnt. Ein nicht gefundener Name und ein Skill ohne gültige `version` sind Fehler, die `/aios-assistant` meldet.

**Assistenten der Kette:** alle `<D>/@/@!Assistant/<name>/ASSISTANT.md`; bei gleichem Namen gewinnt der nächstgelegene Masterspace. `name` muss dem Verzeichnisnamen entsprechen, `version` muss gültig sein; ein Assistent, der das nicht erfüllt, wird nicht aufgelöst und von `aios-context --assistants` und `/aios-assistant` gemeldet. Das Frontmatter wird mit der YAML-Untermenge von Spec 04 gelesen (mit Blocktexten wie `description: >`); `model` darf ein einzelner Wert (`model: opus`) oder je Host angegeben sein. Assistenten gibt es nur in einem mit AIOS aktivierten Vault. `aios-context --assistants` listet sie mit Titel, Version und Beschreibung.

**Wissen des Assistenten:** Der Assistentenordner wird nach den Klassen von Spec 02 eingeteilt, als wäre er ein Masterspace: Dateien und Ordner ohne Präfix werden geladen (ohne `ASSISTANT.md`), `@@…` ist verfügbar, `@!…` (auch `@!Prompt`, `@!Skill`) verborgen. Dateien, deren Name mit `.` beginnt (z. B. `.aios-deploy`), werden übergangen.

### Aktivieren — `/aios-assistant`

Auslöser: `/aios-assistant <Name>[: <Titel>]`, z. B. `/aios-assistant Gärtner: Teste Apfel-Birne`. Die Aktivierung ist **ohne Zustand**: Sie schreibt nichts nach `.claude/` oder `.aios/`.

1. `<Name>` gegen `title` bzw. `name` aller Assistenten der Kette auflösen (ohne Rücksicht auf Groß-/Kleinschreibung; Umlaute gelten als `ae`, `oe`, `ue`, `ss`, sodass „Gärtner" auch `gaertner` trifft). Kein oder mehrdeutiger Treffer: verfügbare Assistenten listen.
2. `aios-context --assistant <name>` ausführen. Es gibt in `<aios-assistant name="…" title="…" version="…" src="…">` … `</aios-assistant name="…">` aus: einen Block `<aios-assistant-meta>` mit `description`, `model`, `tools`, `skills`, dann als `<aios-file class="…">` den Prompt (`prompt`), den Text der `ASSISTANT.md` ohne Frontmatter (`assistant`), die geladenen Dateien des Assistentenordners (`load`), das Inhaltsverzeichnis seines verfügbaren Wissens (`<aios-available>`) und die `SKILL.md` aller genannten Skills (`skill`). Die Endmarke zeigt, dass alles gelesen wurde.
3. Diese Ausgabe vollständig lesen.
4. Titel setzen: in der Desktop-App mit dem App-Werkzeug zum Setzen des Session-Titels; in der CLI den User bitten, `/rename <Titel>` einzugeben.
5. Kurz bestätigen („Gärtner aktiv"), `model` gegebenenfalls als Hinweis nennen, danach in der Rolle antworten.

Die Aktivierung gilt bis zum Ende des Chats. Nach einer Compaction muss sie wiederholt werden; der Skill weist darauf hin.

## Initialisieren — `/aios-init`

Macht das Arbeitsverzeichnis zum Projekt. Auslöser: `/aios-init`, Wahl (1) nach `PROJECT-UNINITIALIZED` (Spec 02). Die Arbeit macht `aios --init [<pfad>]`; der Skill holt mit `--plan` die Vorschau, fragt im Chat und führt nach Ja `--yes` aus.

| Schritt | Wirkung |
|---|---|
| Prüfen | `cwd` liegt in einem aktivierten Vault, ist nicht die Vault-Root und hat kein `@/`. Liegt `cwd` bereits in einem Git-Repo, steht das als Hinweis im Plan, bevor `git init` ausgeführt wird; ist `cwd` selbst schon ein Git-Repo, entfällt `git init` |
| Vorschau | Liste der anzulegenden Dateien; Anlegen erst nach Ja |
| Anlegen | `@/` und `@Memo/` mit `.gitkeep`, fehlende Zeilen der `.gitignore`-Vorlage (Spec 04; vorhandene Zeilen bleiben), `git init` mit dem Branch `main` |
| Registrieren | Projekt-Skills registrieren (wie `aios-context --sync --yes`) |
| Commit | erster Commit „AIOS: Projekt initialisiert" mit `.gitignore`, `@/.gitkeep`, `@Memo/.gitkeep`; scheitert er (z. B. ohne Git-Identität), nur eine Warnung |
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
