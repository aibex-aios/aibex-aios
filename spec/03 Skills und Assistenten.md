---
title: "Skills und Assistenten"
date: 2026-10-03
author: iHux
status: Spec
tags: [spec, aios, v0.3, skills, assistenten]
number: 03
related:
  - "Spec 01 AIbex AIOS v0.3 — Überblick"
  - "Spec 02 Master-Kontext"
  - "Spec 04 Installation und Konfiguration"
  - "Spec 05 Projekte"
  - "Memo 02 Aktivierung eines Agenten in Claude Code (Konzeptprojekt AAA-AIbex-AIOS-V0.1)"
  - "Memo 03 Registrierung der Skills in Claude Code (Konzeptprojekt AAA-AIbex-AIOS-V0.1)"
  - "Memos 14–17 Assistent, Versionen, Demo-Assistenten (Konzeptprojekt AAA-AIbex-AIOS-V0.2)"
  - "Memos 01–07, 09–11, 13, 18–20, 25, 26 (Konzeptprojekt AAA-AIbex-AIOS-V0.3)"
---

# Skills und Assistenten

Diese Spec regelt die Arten von Skills, ihre Versionen, das Ausrollen und Registrieren, die Assistenten mit ihrer Zuordnung zum Projekt, die Oberflächen sowie die AIOS-Skills `/aios-deploy`, `/aios-register`, `/aios-assistant`, `/aios-gui`, `/aios-memo` und den Alias `/gui`. Der Skill `/aios-context` und die Hooks stehen in Spec 02, `/aios-init`, `/aios-integrity` und `/aios-status` in Spec 05, Dateistrukturen, Formate und das CLI `aios` in Spec 04.

## Arten von Skills

| Art | Quelle | registriert in | Verwaltung |
|---|---|---|---|
| **AIOS-Skill** | `/opt/aios/v<version>/skills/aios/` | global `~/.claude/skills/aios-*/` (versionsneutral, Spec 04) | `aios --install` |
| **Alias** | in `aios` eingebaut | global `~/.claude/skills/gui/` (versionsneutral, Spec 04) | `aios --install` |
| **Projekt-Skill** | `@!Skill/<name>/` eines Masterspace der Kette | `<Projekt>/.claude/skills/<name>/` | Registrierung (siehe unten) |
| **Assistenten-Skill** | `@!Assistant/<assistant>/@!Skill/<name>/` oder `@!Skill/<name>/` der Kette, genannt in `skills:` oder `gui:` der `ASSISTANT.md` | nicht registriert; der Kontext des Assistenten enthält ihn | Assistent (siehe unten) |

Innerhalb der Projekt- und Assistenten-Skills wird unterschieden:

| | installiert | lokal |
|---|---|---|
| Herkunft | über `/aios-deploy` aus Bibliothek oder Pflegeprojekt | im Projekt geschrieben |
| Manifest | steht in `skills:` einer `.aios/config.yaml` | steht in keinem Manifest |
| Version | Pflicht | Pflicht; ein neuer lokaler Skill beginnt mit `0.1.0` |
| Änderungen | nur über `/aios-deploy`; direkte Änderungen meldet `/aios-deploy` | frei |

**Reservierte Namen:** Namen mit dem Präfix `aios-` sind AIOS-Skills vorbehalten, der Name `gui` dem Alias. Ein Blueprint `@!Skill/aios-…/` oder `@!Skill/gui/` in einer Kette wird nicht registriert; `/aios-context` und `/aios-register` melden ihn. `none` und `inherit` sind als Namen von Assistenten reserviert; ein Assistent mit einem dieser Namen wird nicht aufgelöst und gemeldet.

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
| **Veröffentlichung** | Eine Version eines Skills aus einem Pflegeprojekt ist ein Git-Tag `<name>-v<version>` (z. B. `memo-v6.0.0`); `version` im Frontmatter des getaggten Stands muss übereinstimmen. Das gilt auch, wenn das Pflegeprojekt das Projekt der Session ist: Ausgerollt wird nur eine getaggte Version (V0.3, Memo 26) |
| **Bibliothek** | Skills liegen in `/opt/aios/v<version>/skills/<gruppe>/<name>/<skill-version>/`, Assistenten in `/opt/aios/v<version>/assistants/<gruppe>/<name>/<assistant-version>/` (v0.3: Gruppen `basic` und `demo`, Spec 04); ihre Versionen sind unabhängig von der AIOS-Version. Im Repo tragen sie die Tags `<name>-v<version>` |
| **Manifest** | `skills:` und `assistants:` in `.aios/config.yaml` nennen je Name eine **exakte** Version; Bereiche gibt es nicht |
| **Übertrumpfung** | je Name: der nächstgelegene Eintrag in der Konfigurationskette gewinnt (Spec 04) |
| **Ort** | Das Manifest eines Projekts gehört zu den Blueprints in `@/@!Skill/` und `@/@!Assistant/` genau dieses Projekts |

## Ausrollen — `/aios-deploy`

Ausrollen legt fest, **wo** ein Skill oder Assistent gilt: Es kopiert eine Version als Blueprint in einen Masterspace und trägt sie ins Manifest ein.

**Aufruf:**

| Skill | CLI | Wirkung |
|---|---|---|
| `/aios-deploy memo==6.0.0` | `aios --deploy memo==6.0.0 [--to <projekt>] [--assistant <name>] [--from <pflegeprojekt>]` | eine Version eines Skills ausrollen |
| `/aios-deploy gaertner==0.2.0` | `aios --deploy gaertner==0.2.0 [--to <projekt>]` | eine Version eines Assistenten der Bibliothek ausrollen |
| `/aios-deploy` | `aios --deploy [--to <projekt>] [--from <pflegeprojekt>]` | das Projekt mit seinem Manifest abgleichen |
| — | `aios --library` | Skills und Assistenten der Bibliothek mit ihren Versionen |

| Option | Bedeutung | Standard |
|---|---|---|
| `--to <projekt>` | Zielprojekt (ein Ordner mit `@/`) | das Projekt der Session; der Skill fragt nach und schlägt das Root-Projekt vor |
| `--assistant <name>` | nur für Skills: Ziel ist `@!Assistant/<name>/@!Skill/` des Zielprojekts | — |
| `--from <pflegeprojekt>` | nur für Skills: Quelle ist ein Git-Repo mit `@Skill/<name>/` und dem Tag `<name>-v<version>`, auch das Projekt der Session selbst | Bibliothek der gültigen AIOS-Version |

**Skill oder Assistent:** Ohne `--from` wird `<name>` in der Bibliothek gesucht. Namen sind über alle Skills und Assistenten der Bibliothek eindeutig; ein Name ist also entweder ein Skill oder ein Assistent. Assistenten werden in v0.3 nur aus der Bibliothek ausgerollt.

**Ablauf:**

1. Quelle bestimmen und prüfen: Version vorhanden (Bibliothek) bzw. Tag vorhanden und Frontmatter passend (Pflegeprojekt). Fehlt der Tag, bricht `aios --deploy` mit dem Hinweis ab, die Version zu taggen (`git tag <name>-v<version>`).
2. Ziel bestimmen: `<ziel>/@/@!Skill/<name>/`, `<ziel>/@/@!Assistant/<assistant>/@!Skill/<name>/` bzw. für einen Assistenten `<ziel>/@/@!Assistant/<name>/`.
3. Vorschau: `new`, `changed`, `remove` je Datei, dazu die Änderung am Manifest (`memo: 5.2.0 -> 6.0.0`). Weicht der vorhandene Blueprint vom ausgerollten Stand ab (Prüfsumme in der Marke), wird er als „direkt geändert" gemeldet; ein gleichnamiger lokaler Blueprint ohne Marke ebenfalls. Beide werden ersetzt.
4. Nach Ja: Blueprint spiegeln (nur dieser eine Ordner) mit der Marke `.aios-deploy`, Manifest `<ziel>/.aios/config.yaml` schreiben (nur die Zeile des Skills bzw. Assistenten; Kommentare und andere Zeilen bleiben).
5. Bei einem Projekt-Skill die Projekt-Skills im Projekt der Session registrieren (wie `/aios-register`); bei Assistenten und Assistenten-Skills entfällt das, weil sie nicht registriert werden.

**Marke `.aios-deploy`:** Jeder ausgerollte Blueprint enthält die Datei `.aios-deploy` mit `name`, `version`, `source` (`library` oder Pfad des Pflegeprojekts) und `digest` (Prüfsumme der ausgerollten Dateien ohne die Marke, Verfahren wie Spec 04, *Manifest*). Sie wird mit dem Blueprint versioniert und unterscheidet ausgerollte von lokalen Blueprints. Bei einem Assistenten umfasst `digest` den ganzen Ordner einschließlich seiner privaten Skills, seiner Oberfläche und seines Wissens, ausgenommen Unterordner `@!Skill/<name>/` mit eigener Marke (Skills, die später mit `--assistant` hinzugefügt wurden).

**Manifeste:** Ein Assistent steht in `assistants:` als `<name>: <version>`. Ein Skill, der mit `--assistant <name>` ausgerollt wurde, steht in `skills:` als `<assistant>/<skill>: <version>`. Die privaten Skills eines ausgerollten Assistenten gehören zu seiner Version und stehen nicht einzeln im Manifest.

Ohne Argument gleicht `/aios-deploy` alle Einträge in `skills:` und `assistants:` des Zielprojekts mit den Blueprints ab (z. B. nach `git pull` oder auf einem anderen Rechner): Ein fehlender, direkt geänderter oder in einer anderen Version vorliegender Blueprint wird aus seiner Quelle neu ausgerollt. Quelle ist das mit `--from` genannte Pflegeprojekt, sonst das Pflegeprojekt aus der Marke, sonst die Bibliothek; ist keine Quelle zu finden, wird das mit Warnung gemeldet. Ein Blueprint mit Marke, dessen Eintrag aus dem Manifest entfernt wurde, wird nach Rückfrage entfernt; lokale Blueprints ohne Marke bleiben unberührt.

**Bibliothek in v0.3:**

| Name | Art | Gruppe | Version | Inhalt |
|---|---|---|---|---|
| `memo` | Skill | `basic` | 6.0.0 | neutrale Fassung des Memo-Stils ohne Bezüge auf einen bestimmten Vault |
| `gaertner` | Assistent | `demo` | 0.2.0 | Titel „Gärtner"; bodenständig, rechnet nur mit Äpfeln und Birnen; private Skills `apfel-birnen-algebra` 0.1.0 und `gaertner-gui` 0.1.0 (Oberfläche mit Apfel-Birnen-Rechner als HTML-Teil); Wissen: Grundlagen (Laden), Sortenkunde und Veredelung (Verfügbar) |
| `astronom` | Assistent | `demo` | 0.1.0 | Titel „Astronom"; poetisch-präzise, rechnet nur mit Sonne und Mond; privater Skill `sonne-mond-zahlen` 0.1.0; keine Oberfläche |

Die Demo-Assistenten werden im Repo `aibex-aios` gepflegt. Ihre Inhalte enthalten keine Pfade oder Bezüge auf einen bestimmten Vault; der Rollentext nennt in einem Satz, dass es sich um einen Demo-Assistenten handelt, dessen Inhalte der Veranschaulichung dienen. Ihre Grenzen sind gewollt: Der Gärtner lehnt Sonne-Mond-Aufgaben freundlich ab, der Astronom Apfel-Birne-Aufgaben. So zeigt das Ergebnis, welcher Assistent und welcher Skill aktiv sind.

Skills und Assistenten der Bibliothek rollt nur der User aus; `aios --install` bietet es nicht an.

## Registrieren — `/aios-register`

Registrieren macht die geltenden Projekt-Skills **für Claude Code aufrufbar**.

**Algorithmus** (für das Projekt der Session; registriert wird nur, wenn `cwd` ein initialisiertes Projekt mit `@/` in einem aktivierten Vault ist, sonst nichts):

1. Alle `<D>/@/@!Skill/<name>/` der Master-Space-Kette sammeln (private Skills eines Assistenten in `@!Assistant/…/@!Skill/` gehören nicht dazu). Bei gleichem Namen gewinnt der nächstgelegene Masterspace. Übersprungen und gemeldet werden reservierte Namen (`aios-*`, `gui`), ungültige Namen, Ordner ohne `SKILL.md`, Skills, deren `name` nicht dem Verzeichnisnamen entspricht, und Skills ohne gültige `version`.
2. Mit `<Projekt>/.claude/skills/` und `<Projekt>/.aios/manifest` vergleichen.
3. **neu**: kopieren; **geändert** (anderer Inhalt oder andere Quelle des Blueprints, oder die Kopie in `.claude/skills/` wurde verändert): ersetzen; **weggefallen** (im Manifest, aber nicht mehr in der Kette oder nicht mehr gültig): entfernen. Skills in `.claude/skills/`, die nicht im Manifest stehen, bleiben unberührt und werden gemeldet, wenn ein Blueprint denselben Namen hat.
4. `.aios/manifest` schreiben (Format Spec 04).

| Aufruf | Rückfrage | Anlass |
|---|---|---|
| SessionStart-Hook (`aios-context --sync --yes`) | nein | jeder Session-Start in einem aktivierten Vault |
| `aios --init` | mit dem Plan von `aios --init` | Initialisieren und Ergänzen eines Projekts (Spec 05) |
| `/aios-register`, `aios --register [<pfad>]`, `aios-context --sync` | ja, mit Vorschau | manueller Anstoß, z. B. nach `/aios-deploy`; der Skill holt mit `--plan` die Vorschau, fragt im Chat und führt nach Ja `--yes` aus |

**Wirksamkeit:** Claude Code übernimmt Skills, die nach dem Start einer Session angelegt werden, nicht zuverlässig in diese Session (V0.1, Memo 16). Die Registrierung beim Session-Start stellt deshalb den Stand für den **nächsten** Chat her. Ändert sie etwas, meldet der Hook `AIOS-SKILLS: <Änderungen> — wirksam ab dem nächsten Chat` (z. B. `AIOS-SKILLS: new memo; changed shared — wirksam ab dem nächsten Chat`); übersprungene Blueprints meldet er als `AIOS-WARNING`, z. B. `AIOS-WARNING: skill ohne-version has no version, not registered`. Weil die Kopie im Projekt selbst liegt, ist ein Skill aus einem Masterspace oberhalb auch dann verfügbar, wenn das Projekt ein eigenes Git-Repo ist (V0.1, Memo 27). `/aios-register`, `/aios-deploy` und `/aios-init` sagen nach dem Registrieren: „Der Skill ist ab dem nächsten Chat verfügbar (oder nach `/reload-skills`)." Ob `/reload-skills` das zuverlässig leistet, ist offen (Spec 01, O1).

## Assistenten

Ein Assistent ist eine Rolle, die AIOS dem KI-Assistenten des Hosts gibt: wer spricht, was er weiß, welche Skills und welche Oberfläche er hat. **Abbildung auf Claude Code (v0.3):** Der Assistent ist dem Projekt zugeordnet; die Hooks laden ihn als Kontext in jeden Chat des Projekts (Spec 02, *Assistent der Session*). Die Agentenfunktion von Claude Code (`.claude/agents/`, Subagenten) wird nicht verwendet.

### Aufbau

```
<Projekt>/@/
├── @!Prompt/<prompt>.md                   Persönlichkeit, wiederverwendbar
├── @!Skill/<skill>/SKILL.md               geteilte Skills
└── @!Assistant/<assistant>/
    ├── ASSISTANT.md                       Bündel und Rollentext
    ├── .aios-deploy                       nur bei ausgerollten Assistenten
    ├── @!Skill/<skill>/SKILL.md           private Skills (optional)
    ├── @!Skill/<gui-skill>/               Oberfläche (optional): SKILL.md, gui.yaml, HTML-Teile
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
version: 0.2.0
description: Bodenständiger Gärtner, rechnet ausschließlich mit Äpfeln und Birnen
skills: [apfel-birnen-algebra, gaertner-gui, memo]
gui: gaertner-gui
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
| `name` | ja | gleich dem Verzeichnisnamen; Kleinbuchstaben, Ziffern, Bindestriche; nicht `none` oder `inherit` |
| `title` | ja | Anzeigename für `/aios-assistant` und die Bestätigung „<Titel> aktiv" |
| `version` | ja | Semver `MAJOR.MINOR.PATCH`; ein neuer lokaler Assistent beginnt mit `0.1.0` |
| `description` | ja | eine Zeile |
| `prompt` | nein | Name einer Datei in `@!Prompt/` |
| `skills` | nein | Namen von Skills |
| `gui` | nein | Name des Skills mit der Oberfläche des Assistenten; muss in `skills` stehen (siehe *Oberflächen*) |
| `model` | nein | Wunsch an den Host, Modell je Host; in der Desktop-App nur ein Hinweis an den User |
| `tools` | nein | Wunsch an den Host, neutrale Namen; in v0.3 nur dokumentierend, nicht erzwungen |

**Auflösung von `prompt`, `skills` und `gui`:** zuerst im Assistentenordner (`<assistant>/@!Prompt/<prompt>.md`, `<assistant>/@!Skill/<skill>/SKILL.md`), danach in den Masterspaces der Kette vom Projekt aufwärts (`<D>/@/@!Prompt/…`, `<D>/@/@!Skill/…`); der nächstgelegene Treffer gewinnt. Ein nicht gefundener Name, ein Skill ohne gültige `version` und ein `gui`, das nicht in `skills` steht, sind Fehler, die `aios-context --assistant` meldet.

**Assistenten der Kette:** alle `<D>/@/@!Assistant/<name>/ASSISTANT.md`; bei gleichem Namen gewinnt der nächstgelegene Masterspace. `name` muss dem Verzeichnisnamen entsprechen, `version` muss gültig sein; ein Assistent, der das nicht erfüllt, wird nicht aufgelöst und von `aios-context --assistants` und `/aios-assistant` gemeldet. Das Frontmatter wird mit der YAML-Untermenge von Spec 04 gelesen (mit Blocktexten wie `description: >`); `model` darf ein einzelner Wert (`model: opus`) oder je Host angegeben sein. Assistenten gibt es nur in einem mit AIOS aktivierten Vault. `aios-context --assistants` listet sie mit Titel, Version und Beschreibung.

**Wissen des Assistenten:** Der Assistentenordner wird nach den Klassen von Spec 02 eingeteilt, als wäre er ein Masterspace: Dateien und Ordner ohne Präfix werden geladen (ohne `ASSISTANT.md`), `@@…` ist verfügbar, `@!…` (auch `@!Prompt`, `@!Skill`) verborgen. Dateien, deren Name mit `.` beginnt (z. B. `.aios-deploy`), werden übergangen.

**Kontext eines Assistenten:** `aios-context --assistant <name>` gibt in `<aios-assistant name="…" title="…" version="…" src="…">` … `</aios-assistant name="…">` aus: einen Block `<aios-assistant-meta>` mit `description`, `model`, `tools`, `skills`, `gui`, dann als `<aios-file class="…">` den Prompt (`prompt`), den Text der `ASSISTANT.md` ohne Frontmatter (`assistant`), die geladenen Dateien des Assistentenordners (`load`), das Inhaltsverzeichnis seines verfügbaren Wissens (`<aios-available>`) und die `SKILL.md` aller genannten Skills (`skill`). Die Endmarke zeigt, dass alles gelesen wurde. Diese Ausgabe verwenden die Hooks (Spec 02) und `/aios-assistant`.

### Zuordnung

Der Assistent ist eine **Eigenschaft des Projekts** (Spec 01, Grundregel 8): Er steht ausschließlich im Projekt und gilt für alle User gleich (V0.3, Memo 04). Der Schlüssel `assistant:` in `<Projekt>/.aios/config.yaml` (oder `§<Vault>/.aios/config.yaml`) hat genau einen von drei Werten:

| Wert | Bedeutung |
|---|---|
| `<name>` | dieser Assistent; der Name wird über die Kette aufgelöst |
| `none` | kein Assistent: das gewöhnliche Claude Code antwortet |
| `inherit` | der Assistent des übergeordneten Projekts |

- **Fehlt der Schlüssel, gilt `inherit`.** Ein neues Projekt erbt also, ohne dass etwas geschrieben werden muss.
- `inherit` wird nach der Konfigurationskette von unten nach oben aufgelöst (Spec 04), bis eine `.aios/config.yaml` `none` oder `<name>` festlegt. Legt bis zur Vault-Root niemand etwas fest, gibt es keinen Assistenten.
- Ändert sich der Assistent eines übergeordneten Projekts, ändert sich der eines darunterliegenden Projekts nur bei `inherit` mit.
- `assistant` in `~/.aios/config.yaml` ist nicht erlaubt; der Rechner eines Users legt keinen Assistenten fest.
- Ist der zugeordnete Name in einem Unterprojekt nicht auflösbar, meldet der Session-Start das als Warnung, und der Chat läuft ohne Assistent. Ein Unterprojekt kann einen geerbten Assistenten mit einer eigenen Fassung gleichen Namens überschreiben (nächstgelegener Masterspace).
- `.aios/config.yaml` ist versioniert; ein Wechsel erreicht andere User in einer geteilten Ablage sofort, in einem Git-Repo nach Commit und Pull.

**Beispiel:** Die Vault-Root wechselt von `gaertner` auf `astronom`.

| Projekt | Wert | vorher | nachher |
|---|---|---|---|
| `§Demo/` | `astronom` (vorher `gaertner`) | Gärtner | Astronom |
| `G-Garten/` | `inherit` | Gärtner | Astronom |
| `G-Garten/B-Beet/` | (kein Eintrag) = `inherit` | Gärtner | Astronom |
| `L-Labor/` | `none` | kein Assistent | kein Assistent |
| `L-Labor/P-Probe/` | `inherit` | kein Assistent | kein Assistent |
| `S-Sternwarte/` | `gaertner` | Gärtner | Gärtner |

Ein Ordner ohne `@/` ist noch kein Projekt; dort hat `PROJECT-UNINITIALIZED` Vorrang (Spec 02). Die Zuordnung gilt für ihn, sobald er initialisiert ist.

### Wechsel — `/aios-assistant`

Auslöser: `/aios-assistant <Name>[: <Titel>]`, `/aios-assistant --none`, `/aios-assistant --inherit`, z. B. `/aios-assistant Gärtner: Teste Apfel-Birne`. Jeder Aufruf ist eine **Zuordnung zum Projekt**; eine Aktivierung nur für den laufenden Chat gibt es nicht (V0.3, Memo 07). Wer einen anderen Assistenten ausprobieren will, legt dafür ein Unterprojekt an.

| Aufruf | CLI | schreibt im Projekt der Session | Wirkung im laufenden Chat |
|---|---|---|---|
| `/aios-assistant <Name>` | `aios --assistant <name>` | `assistant: <name>` | sofortiger Wechsel in die Rolle |
| `/aios-assistant --none` | `aios --assistant none` | `assistant: none` | verlässt sofort die Rolle |
| `/aios-assistant --inherit` | `aios --assistant inherit` | `assistant: inherit` | übernimmt sofort den Assistenten des übergeordneten Projekts |

Mit `--to <projekt>` schreibt der Aufruf in ein anderes Projekt der Kette, z. B. die Vault-Root für den Standard des Vaults; der laufende Chat wechselt dann nur, wenn sich dadurch sein eigener wirksamer Assistent ändert.

**Ablauf:**

1. `<Name>` gegen `title` bzw. `name` aller Assistenten der Kette auflösen (ohne Rücksicht auf Groß-/Kleinschreibung; Umlaute gelten als `ae`, `oe`, `ue`, `ss`, sodass „Gärtner" auch `gaertner` trifft). Kein oder mehrdeutiger Treffer: verfügbare Assistenten listen.
2. `aios --assistant <wert> [--to <projekt>] --plan` zeigt, was sich ändert, und fragt einmal nach (I7), z. B.

   ```
   Projekt G-Garten: Gärtner → Astronom
   gilt für alle neuen Chats in G-Garten und in den Unterprojekten mit inherit
   ```

   Hat der User den Wechsel in seinem Aufruf schon ausdrücklich bestätigt, entfällt die Rückfrage.
3. Nach Ja `aios --assistant <wert> [--to <projekt>] --yes --session <session-id>`: schreibt `assistant:` in `.aios/config.yaml` (nur diese Zeile; Kommentare und andere Zeilen bleiben) und setzt den Merker der Session auf den neuen wirksamen Assistenten (Spec 02). Die Session-ID kommt aus dem Platzhalter `${CLAUDE_SESSION_ID}` der Hülle; ohne sie wird nur die Zuordnung geschrieben (Spec 01, O3).
4. Ist der neue wirksame Assistent nicht `none`: `aios-context --assistant <name>` ausführen und die Ausgabe vollständig lesen. Bei `none`: die bisherige Rolle ablegen.
5. Titel setzen, wenn einer angegeben ist (unten).
6. Kurz bestätigen („Astronom aktiv" bzw. „kein Assistent"), `model` gegebenenfalls als Hinweis nennen, danach in der Rolle antworten.

**Laufende Chats:** Ein Wechsel betrifft nur den Chat, der ihn ausführt, und Chats, die danach starten. Chats anderer User und andere Chats desselben Users behalten den Assistenten, mit dem sie begonnen haben, bis sie enden, auch über Compaction und Resume hinweg (V0.3, Memo 06; Spec 02).

### Titel

Der Titel ist der **Titel des Chats**: der Name der Session, der in der Desktop-App in der Seitenleiste erscheint (in der CLI: `/rename`). Er ist keine Eigenschaft des Projekts und wird nicht gespeichert (V0.3, Memo 09).

| Situation | Titel |
|---|---|
| Dialog *Projekt initialisieren* (Spec 02) | der im Dialog gewählte Titel, für diesen Chat |
| `/aios-assistant <Name>: <Titel>` | `<Titel>`, für diesen Chat |
| `/aios-assistant <Name>` ohne Titel | unverändert |
| neuer Chat, auch mit automatisch geladenem Assistenten | der Titel, den die App selbst vergibt; AIOS setzt keinen |
| Compaction, Resume | unverändert |

Setzen: in der Desktop-App mit dem App-Werkzeug zum Setzen des Session-Titels; in der CLI bittet Claude den User, `/rename <Titel>` einzugeben. AIOS fügt den Assistenten nicht in den Titel ein; welcher Assistent aktiv ist, sagt Claude in seiner Bestätigung.

## Oberflächen — `/aios-gui` und `/gui`

Eine Oberfläche ist eine **Abkürzung zu Prompts und Skills** für Anwender, die keine Befehle kennen. Alles läuft weiter über den Assistenten und die Regeln von AIOS, z. B. die Rückfrage vor dem Schreiben (I7).

| Aufruf | Oberfläche | Inhalt |
|---|---|---|
| `/aios-gui` | **AIOS-Oberfläche**, gleich für alle Projekte | Aufgaben von AIOS (Tabelle unten) |
| `/gui` | **Oberfläche des Assistenten der Session** | was der Assistent seinem Anwender anbietet, z. B. beim Gärtner den Apfel-Birnen-Rechner |

### Beschreibung einer Oberfläche

Eine Oberfläche ist in erster Linie eine **Beschreibung** (V0.3, Memo 25): eine Datei `gui.yaml` im Ordner des Oberflächen-Skills, daneben optionale HTML-Teile. Der Oberflächen-Skill ist ein gewöhnlicher Skill mit eigenem Namen (z. B. `gaertner-gui`), mit `SKILL.md` und `version`; er kann auch unter seinem Namen aufgerufen werden. Ein Assistent hat **eine** Oberfläche, seine Startseite; weitere Werkzeuge sind Kacheln darauf.

```yaml
title: Gärtner
intro: Was möchtest du heute im Garten wissen?
tiles:
  - title: Apfel-Birnen-Rechner
    text: Rechnet mit Äpfeln und Birnen, ohne Claude
    html: rechner.html
  - title: Sorte bestimmen
    text: Beschreibe den Apfel, ich bestimme die Sorte
    prompt: "Hilf mir, eine Apfelsorte zu bestimmen. Frag mich nach den Merkmalen."
  - title: Aufgabe rechnen
    text: Eine Apfel-Birnen-Aufgabe mit Rechenweg
    skill: apfel-birnen-algebra
    icon: calculator
```

| Feld | Pflicht | Regel |
|---|---|---|
| `title` | ja | Überschrift der Oberfläche |
| `intro` | nein | ein Satz unter der Überschrift |
| `tiles` | ja | Liste von 1 bis 12 Kacheln |
| `tiles[].title` | ja | Titel der Kachel |
| `tiles[].text` | nein | eine Zeile Erklärung |
| `tiles[].prompt` | eines von drei | Nachricht, die die Kachel an Claude sendet, als hätte der User sie getippt |
| `tiles[].skill` | eines von drei | Skill, den die Kachel aufruft (sendet `/<skill>`) |
| `tiles[].html` | eines von drei | Dateiname eines HTML-Teils im Ordner des Oberflächen-Skills; läuft in der Oberfläche ohne Claude, z. B. ein Rechner |
| `tiles[].icon` | nein | ein neutrales Wort für ein Symbol, z. B. `calculator`, `book`, `gear` |

`gui.yaml` wird mit PyYAML gelesen (nicht mit der Untermenge von Spec 04). Ein HTML-Teil ist ein Fragment ohne `<html>`, `<head>` und `<body>`, mit eingebettetem CSS und JavaScript und ohne Zugriff auf das Netz außer auf die vom Host erlaubten Quellen. Er darf die Hilfsfunktion `sendPrompt(text)` des Hosts verwenden.

### Darstellung

| Host | Darstellung |
|---|---|
| Desktop-App mit HTML-Oberflächen | `aios --gui --html` erzeugt aus der Beschreibung ein HTML-Fragment: Überschrift, Intro, Kacheln als Schaltflächen (`prompt` und `skill` über `sendPrompt`), HTML-Teile eingebettet. Claude zeigt es mit dem Werkzeug des Hosts für HTML-Oberflächen im Chat |
| CLI und Desktop-App ohne HTML-Oberflächen (Spec 01, O4) | Menü mit dem Auswahlwerkzeug (`AskUserQuestion`), höchstens 4 Einträge je Ebene, bei mehr Kacheln mit „Weitere …"; Kacheln mit `html` fehlen dort und werden als Hinweis genannt |

Die Oberfläche erscheint, wenn `/aios-gui` oder `/gui` aufgerufen wird; sie ist nicht dauerhaft sichtbar.

### `/gui`

`/gui` ist ein **Alias**: eine feste, versionsneutrale Hülle in `~/.claude/skills/gui/` (Spec 04). Es gibt nur diesen einen Alias (V0.3, Memo 25). Der Rumpf entsteht beim Aufruf mit `aios --gui --session ${CLAUDE_SESSION_ID}`:

1. Assistent bestimmen: der Assistent der Session aus dem Merker (Spec 02); ohne Session-ID oder ohne Merker die Zuordnung des Projekts (Spec 01, O3).
2. Hat er ein `gui:`, gibt `aios --gui` den Rumpf des Oberflächen-Skills aus, erweitert um die Anweisung, die Oberfläche nach *Darstellung* zu zeigen.
3. Ist kein Assistent aktiv oder nennt er kein `gui:`: „Der Assistent <Titel> hat keine Oberfläche." bzw. „Kein Assistent aktiv.", jeweils mit „AIOS-Oberfläche: `/aios-gui`".

Weil der Rumpf beim Aufruf aufgelöst wird, zeigt `/gui` nach einem Wechsel des Assistenten sofort die neue Oberfläche, ohne neue Registrierung.

### `/aios-gui`

AIOS-Skill mit der Oberfläche von AIOS selbst. Ihre Beschreibung liegt im AIOS-Skill (`skills/aios/aios-gui/gui.yaml`) und hat diese Kacheln:

| Kachel | sendet |
|---|---|
| Projekt initialisieren | `/aios-init` (Dialog *Projekt initialisieren*, Spec 02) |
| Kontext und Konfiguration | `/aios-context`, danach `aios --config` |
| Assistent zuordnen | `/aios-assistant` mit Auswahl aus `aios-context --assistants`, `none`, `inherit` |
| Skills ausrollen und registrieren | `/aios-deploy` (Abgleich), `/aios-register` |
| Integrität prüfen | `/aios-integrity` |
| Projektstatus | `/aios-status` |
| Memo schreiben | `/memo` oder `/aios-memo` (Vorrang siehe unten) |

## Memo-Stil — `/aios-memo`

AIOS-Skill, damit in jedem Projekt eines aktivierten Vaults ein wohldefinierter Memo-Stil verfügbar ist, ohne dass ein Memo-Skill ausgerollt werden muss (V0.3, Memo 18–20). Vergleich: Unter Linux gibt es immer `nano`, auch ohne einen anderen Editor.

| Aspekt | Regel |
|---|---|
| Inhalt | der Rumpf von `memo==6.0.0` (Nummer, Dateiname, Header-Block, Struktur, Formatierung, Obsidian-LaTeX); er wird nicht an spätere Versionen von `memo` angeglichen |
| Version | wie bei allen AIOS-Skills: versionsneutrale Hülle, Rumpf aus der für das Projekt gültigen AIOS-Version |
| `@Memo/` | legt der Skill an, wenn er das erste Memo eines Projekts schreibt und der Ordner fehlt; `aios --init` legt ihn nicht an (Spec 05) |
| Vorrang | Ist im Projekt ein Skill `memo` registriert (`memo` in `.aios/manifest`), gibt `aios --skill aios-memo` statt des Rumpfs nur aus: „Verwende `/memo` — in diesem Projekt ist der Skill `memo` registriert." Zusätzlich sagt die Beschreibung von `aios-memo`: „Nur verwenden, wenn kein Skill `memo` verfügbar ist." |
| Regeln, die auf `memo` verweisen | gelten ersatzweise mit `aios-memo`, wenn `memo` nicht ausgerollt oder nicht registriert ist |
