---
title: "Skills und Assistenten"
date: 2026-10-25
author: iHux
status: Spec
tags: [spec, aios, v0.5, skills, assistenten]
number: 03
related:
  - "Spec 01 AIbex AIOS v0.5 — Überblick"
  - "Spec 02 Master-Kontext"
  - "Spec 04 Installation und Konfiguration"
  - "Spec 05 Projekte"
  - "Spec 06 Pakete und Workspaces"
  - "Spec 07 Arbeitspferde"
  - "Memo 02 Aktivierung eines Agenten in Claude Code (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memo 03 Registrierung der Skills in Claude Code (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memos 14–17 Assistent, Versionen, Demo-Assistenten (AA-AIbex-AIOS, @Memo/V0.2)"
  - "Memos 01–07, 09–11, 13, 18–20, 25, 26 (AA-AIbex-AIOS, @Memo/V0.3)"
  - "Memos 05, 07, 12, 17, 34, 35 (AA-AIbex-AIOS, @Memo/V0.5)"
---

# Skills und Assistenten

Diese Spec regelt die Arten von Skills, ihre Versionen, das Ausführungsmodell, das Registrieren, die Assistenten mit ihrer Zuordnung zum Projekt, die Oberflächen sowie die AIOS-Skills `/aios-package`, `/aios-fetch`, `/aios-deploy`, `/aios-distribution`, `/aios-register`, `/aios-assistant`, `/aios-gui`, `/aios-memo` und den Alias `/gui`. Der Skill `/aios-context` und die Hooks stehen in Spec 02, `/aios-init`, `/aios-integrity` und `/aios-status` in Spec 05, Dateistrukturen, Formate und das CLI `aios` in Spec 04, Pakete, Hubs, Holen, Ausrollen und Distributionen in Spec 06, Arbeitspferde in Spec 07.

## Arten von Skills

| Art | Quelle | registriert in | Verwaltung |
|---|---|---|---|
| **AIOS-Skill** | `/opt/aios/v<version>/skills/aios/` | global `~/.claude/skills/aios-*/` (versionsneutral, Spec 04) | `aios --install` |
| **Alias** | in `aios` eingebaut | global `~/.claude/skills/gui/` (versionsneutral, Spec 04) | `aios --install` |
| **Projekt-Skill** | `@!Skill/<name>/` oder `@!Package/<paket>/skills/<name>/` eines Masterspace der Kette | `<Projekt>/.claude/skills/<name>/` | Registrierung (siehe unten) |
| **Assistenten-Skill** | `@!Assistant/<assistant>/@!Skill/<name>/` oder `@!Skill/<name>/` der Kette, genannt in `skills:` oder `gui:` der `ASSISTANT.md` | nicht registriert; der Kontext des Assistenten enthält ihn | Assistent (siehe unten) |

Innerhalb der Projekt- und Assistenten-Skills wird unterschieden:

| | aus einem Paket | lokal |
|---|---|---|
| Herkunft | aus einem Paket, geholt mit `/aios-fetch` und ausgerollt (Spec 06) | im Projekt geschrieben (`@!Skill/`) |
| Manifest | das Paket steht in `packages:` bzw. `lock.yaml` | steht in keinem Manifest |
| Version | Pflicht | Pflicht; ein neuer lokaler Skill beginnt mit `0.1.0` |
| Änderungen | nur über eine neue Version des Pakets; direkte Änderungen meldet `/aios-fetch` | frei |

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
| **Veröffentlichung** | Ein Skill oder Assistent wird als Paket veröffentlicht: Tag `v<version>` im Repo des Pakets (Spec 06). Die `version` im Frontmatter eines Skills bzw. Assistenten ist seine eigene Version und muss nicht der des Pakets gleichen |
| **Manifest** | `packages:` in `.aios/config.yaml` nennt je Paket einen Bereich, `lock.yaml` die aufgelöste Version (Spec 06) |
| **Übertrumpfung** | je Name: der nächstgelegene Eintrag in der Konfigurationskette gewinnt (Spec 04) |
| **Ort** | Die Pakete eines Projekts liegen in `@/@!Package/` genau dieses Projekts |

## Ausführungsmodell

Ein Skill hat keinen eigenen Steuerprozess (V0.5, Memo 12). Claude Code erkennt am Auslöser den registrierten Skill und lädt sein `SKILL.md` in den Chat; das Modell arbeitet die Schritte als Anleitung ab.

| Wer | tut was |
|---|---|
| Modell | liest die Anleitung, schreibt jeden Befehl als Aufruf des Bash-Werkzeugs, wertet Ausgabe und Exit-Code aus, entscheidet über den nächsten Schritt |
| Claude Code | führt den Befehl auf dem Rechner aus: eigener Prozess je Aufruf, Benutzerkonto und Profil des Users, Ordner der Session; vorher greift der Berechtigungsmodus der Session |
| Skripte eines Skills | Werkzeugkästen mit Unterbefehlen, nur mit der Standardbibliothek von Python, aufgerufen über `python3` |
| Arbeitspferde | externe Programme, aufgerufen über ihren Weiterleiter `~/.aios/bin/<programm>`, nie über den `PATH` des Users (Spec 07) |

Regeln für Skill-Autoren:

- **Zwischenwerte** (Pfade, Nummern) überleben einen Aufruf nicht; das `SKILL.md` sagt, dass sie aus der Ausgabe übernommen und wörtlich eingesetzt werden, oder fasst mehrere Schritte in einen Aufruf.
- **Fehlt ein Arbeitspferd**, meldet der Skill, dass das Paket nicht vollständig geladen ist, und nennt höchstens `aios --fetch`; **Installationsanweisungen im Chat gibt es nicht**, und ein Skill löst nie ein setup aus (Spec 01, I10).
- Deterministisches und Prüfbares gehört in Skripte bzw. Arbeitspferde, Verständnis und Formulierung zum Modell.

## Pakete — `/aios-package`, `/aios-fetch`, `/aios-deploy`

Skills und Assistenten kommen als **Pakete** in ein Projekt: Ein Paket wird vom Hub **geholt** (`aios --fetch`, nach `@/@!Package/<name>/`), seine Elemente werden **ausgerollt** (`aios --deploy`), und ausgerollte Skills werden **registriert** (`aios --register`). Hubs, Aufruf, Ablauf, Marke, Abgleich, Entfernen, Ausrollen und Vorrang regelt Spec 06. Für diese Spec gilt:

- Ein ausgerollter Skill aus `@!Package/<paket>/skills/<name>/` ist ein Projekt-Skill wie ein Blueprint `@!Skill/<name>/` desselben Masterspace, ein ausgerollter Assistent aus `@!Package/<paket>/assistants/<name>/` ein Assistent wie `@!Assistant/<name>/`. Nicht ausgerollte Elemente zählen nicht (Spec 06, H3).
- Innerhalb eines Masterspace gewinnt der lokale Blueprint vor dem Element aus einem Paket; über Masterspaces hinweg gewinnt der nächstgelegene (Spec 06, *Vorrang*).
- Lokale Blueprints in `@!Skill/` und `@!Assistant/` schreibt nur der User; AIOS schreibt sie nicht (Spec 01, I2).

**Skills** (AIOS-Skills des Kernels, damit es kein Henne-Ei-Problem gibt; V0.4, Memos 23, 25):

| Skill | Rolle | Auslöser | ruft auf |
|---|---|---|---|
| `/aios-package` | **Paketmanager** für Anwender: holen, entfernen, aktualisieren, suchen, zeigen, was geholt ist, Hub-Liste pflegen; bedient sich der beiden Hilfs-Skills | „/aios-package", „installiere …", „hole …", „lade …", „entferne …", „deinstalliere …", „aktualisiere …", „welche Pakete bzw. Apps gibt es?", „was ist installiert?", „Hub hinzufügen"; englisch *install*, *remove*, *update*, *list packages* | `aios --library`, `aios --hubs`, `/aios-fetch`, `/aios-deploy`; bei einer Distribution `aios --install distribution-<name>` |
| `/aios-fetch` | Hilfs-Skill: ein Paket laden (holen, Arbeitspferde einrichten, registrieren), abgleichen, `--upgrade`, `--remove`; zeigt im Plan das setup der Arbeitspferde (Spec 07) | „/aios-fetch", „Paket holen", „Paket laden" | `aios --fetch` |
| `/aios-deploy` | Hilfs-Skill: Elemente eines geholten Pakets ausrollen (`--only`, `--all`) oder zeigen | „/aios-deploy", „ausrollen", „freischalten" | `aios --deploy` |

`/aios-package` versteht unscharfe Namen („installiere mir den Rechner"): Es sucht mit `aios --library` in Namen und Beschreibungen der Pakete der Hub-Liste und fragt bei mehreren Treffern nach. Einen vollen Paketnamen `<hub>/<paket>` gibt es unverändert weiter. Meldet `aios --fetch`, dass ein Name in mehreren Hubs liegt, fragt es, welcher gemeint ist. Es fragt nach dem Ziel und schlägt das Root-Projekt vor. Wie jeder schreibende Skill holt es den Plan mit `--plan`, fragt im Chat und ruft erst nach Ja mit `--yes` auf (Spec 01, I7). Nach dem Holen sagt es, dass neue Skills ab dem nächsten Chat verfügbar sind, und nennt bei einer App ihre Oberfläche (*Oberflächen*).

**Pakete der Grundausstattung in v0.5** (neue Versionen mit `requires.aios: ">=0.4,<0.6"`; V0.5, Memo 41):

| Paket | Hub | Typ | Version | Inhalt |
|---|---|---|---|---|
| `skill-memo` | `aibex-aios` | `skill` | 6.0.1 | Skill `memo`: neutrale Fassung des Memo-Stils ohne Bezüge auf einen bestimmten Vault |
| `assistant-gaertner` | `aibex-aios` | `assistant` | 0.3.0 | Assistent `gaertner`, Titel „Gärtner"; bodenständig, jede Antwort beginnt mit „👩‍🌾 " (V0.4, Memo 70), rechnet nur mit Äpfeln und Birnen; private Skills `apfel-birnen-algebra` 0.1.0 und `gaertner-gui` 0.1.0 (Oberfläche mit Apfel-Birnen-Rechner als HTML-Teil); Wissen: Grundlagen (Laden), Sortenkunde und Veredelung (Verfügbar) |
| `assistant-astronom` | `aibex-aios` | `assistant` | 0.3.0 | Assistent `astronom`, Titel „Astronom"; poetisch-präzise, jede Antwort beginnt mit „💫 " (V0.4, Memo 70), rechnet nur mit Sonne und Mond; privater Skill `sonne-mond-zahlen` 0.1.0; keine Oberfläche. Nennt Sterndaten aus verfügbarem Wissen, ohne zu rechnen (V0.4, Memo 27) |
| `app-taschenrechner` | `aibex-aios` | `app` | 0.5.0 | RPN-Taschenrechner nach dem HP-15C mit Funktionstasten A–D; Skills `taschenrechner` und `taschenrechner-gui` (Spec 06) |
| `knowledge-orion` | `aibex-aios` | `knowledge` | 0.1.1 | die 20 hellsten Sterne des Orion: Name, Helligkeit, Radius, Entfernung, Temperatur, Spektralklasse, Art, als Tabelle in `knowledge/@@Orion/Sterne.md`, mit Quelle |
| `knowledge-scorpio` | `aibex-hub` | `knowledge` | 0.1.1 | ebenso für das Sternbild Skorpion, `knowledge/@@Skorpion/Sterne.md`; Testpaket für einen zweiten Hub |

Paketnamen folgen dem Muster `<typ>-<name>` (Spec 06, *Paketnamen*); die Elemente darin behalten ihre Namen. `assistant-gaertner` und `assistant-astronom` sind neue Repos mit dem Inhalt von `assistent-gaertner` bzw. `assistent-astronom` 0.2.1; die alten Repos bleiben, ihr README verweist auf den neuen Namen (V0.5, Memo 05). Die Demo-Assistenten liegen in eigenen Paket-Repos. Ihre Inhalte enthalten keine Pfade oder Bezüge auf einen bestimmten Vault; der Rollentext nennt in einem Satz, dass es sich um einen Demo-Assistenten handelt, dessen Inhalte der Veranschaulichung dienen. Ihre Grenzen sind gewollt: Der Gärtner lehnt Sonne-Mond-Aufgaben freundlich ab, der Astronom Apfel-Birne-Aufgaben. So zeigt das Ergebnis, welcher Assistent und welcher Skill aktiv sind. Die Wissenspakete hängen nicht vom Astronomen ab und er nicht von ihnen; er findet ihr Wissen über die Kette (Spec 02, K6).

Pakete holt nur der User; `aios --install` bietet es nicht an.

## Distributionen — `/aios-distribution`

AIOS-Skill zum Zusammenstellen einer Distribution (Spec 06, *Distributionen*; V0.5, Memos 34, 35). Auslöser: „/aios-distribution", „Distribution zusammenstellen", „Distribution anlegen".

| # | Schritt | Ergebnis |
|---|---|---|
| 1 | Name und Zweck klären | `distribution-<name>`, `description` |
| 2 | Ausgangsprojekt wählen (Standard: Projekt der Session) | Pakete mit Versionen aus `lock.yaml`, Kernel aus `aios:` |
| 3 | ergänzen oder streichen (Auswahl aus `aios --library`) | Zusammenstellung; Abhängigkeiten erscheinen nicht in `depends` |
| 4 | prüfen mit dem Resolver | alle Pakete auflösbar, exakte Versionen, `kernel:` passt zu `requires.aios`, keine Konflikte |
| 5 | Plan zeigen, fragen, Repo anlegen | lokales Repo `distribution-<name>/` mit `manifest.yaml`, `README.md` und Lizenz, Ort nach den Vorgaben des Users, sonst `@Package/`; lokaler Commit, kein Tag |
| 6 | Probe vorschlagen | `aios --install distribution-<name> --from <repo> <leerer Vault>`; den leeren Vault legt der Skill auf Wunsch in einem Test- oder Scratchpad-Ordner an, nie im Vault des Users |
| 7 | melden | Ort, Inhalt, nächster Schritt: lokal taggen, veröffentlichen |

Der Skill veröffentlicht nicht; das bleibt dem User bzw. Anja (`anja-veroeffentlichen`), jeder Schritt nach außen mit eigener Rückfrage. Die Hülle erlaubt `Bash(aios --library *)`, `Bash(aios --install * --plan)` und das Anlegen des Repos nach Plan und Rückfrage.

## Registrieren — `/aios-register`

Registrieren macht die geltenden Projekt-Skills **für Claude Code aufrufbar**.

**Algorithmus** (für das Projekt der Session; registriert wird nur, wenn `cwd` ein initialisiertes Projekt mit `@/` in einem aktivierten Vault ist, sonst nichts):

1. Alle `<D>/@/@!Skill/<name>/` und die ausgerollten `<D>/@/@!Package/<paket>/skills/<name>/` (Spec 06) der Master-Space-Kette sammeln (private Skills eines Assistenten in `@!Assistant/…/@!Skill/` bzw. `…/assistants/…/@!Skill/` gehören nicht dazu). Bei gleichem Namen gewinnt der nächstgelegene Masterspace, darin der lokale Blueprint vor dem Paket (Spec 06). Übersprungen und gemeldet werden reservierte Namen (`aios-*`, `gui`), ungültige Namen, Ordner ohne `SKILL.md`, Skills, deren `name` nicht dem Verzeichnisnamen entspricht, und Skills ohne gültige `version`.
2. Mit `<Projekt>/.claude/skills/` und `<Projekt>/.aios/registry` vergleichen.
3. **neu**: kopieren; **geändert** (anderer Inhalt oder andere Quelle des Blueprints, oder die Kopie in `.claude/skills/` wurde verändert): ersetzen; **weggefallen** (in der Registry, aber nicht mehr in der Kette oder nicht mehr gültig): entfernen. Skills in `.claude/skills/`, die nicht in der Registry stehen, bleiben unberührt und werden gemeldet, wenn ein Blueprint denselben Namen hat.
4. `.aios/registry` schreiben (Format Spec 04). Eine alte `.aios/manifest` aus v0.3 wird dabei entfernt.

| Aufruf | Rückfrage | Anlass |
|---|---|---|
| SessionStart-Hook (`aios --context --sync --yes`) | nein | jeder Session-Start in einem aktivierten Vault |
| `aios --init` | mit dem Plan von `aios --init` | Initialisieren und Ergänzen eines Projekts (Spec 05) |
| `/aios-register`, `aios --register [<pfad>]`, `aios --context --sync` | ja, mit Vorschau | manueller Anstoß, z. B. nach `/aios-fetch`; der Skill holt mit `--plan` die Vorschau, fragt im Chat und führt nach Ja `--yes` aus |

**Wirksamkeit:** Claude Code übernimmt Skills, die nach dem Start einer Session angelegt werden, nicht zuverlässig in diese Session (V0.1, Memo 16). Die Registrierung beim Session-Start stellt deshalb den Stand für den **nächsten** Chat her. Ändert sie etwas, meldet der Hook `AIOS-SKILLS: <Änderungen> — effective from the next chat` (z. B. `AIOS-SKILLS: new memo; changed shared — effective from the next chat`); übersprungene Blueprints meldet er als `AIOS-WARNING`, z. B. `AIOS-WARNING: skill ohne-version has no version, not registered`. Weil die Kopie im Projekt selbst liegt, ist ein Skill aus einem Masterspace oberhalb auch dann verfügbar, wenn das Projekt ein eigenes Git-Repo ist (V0.1, Memo 27). `/aios-register`, `/aios-package`, `/aios-fetch`, `/aios-deploy` und `/aios-init` sagen nach dem Registrieren: „Der Skill ist ab dem nächsten Chat verfügbar (oder nach `/reload-skills`)." Ob `/reload-skills` das zuverlässig leistet, ist offen (Spec 01, O1).

## Assistenten

Ein Assistent ist eine Rolle, die AIOS dem KI-Assistenten des Hosts gibt: wer spricht, was er weiß, welche Skills und welche Oberfläche er hat. **Abbildung auf Claude Code (v0.5):** Der Assistent ist dem Projekt zugeordnet; die Hooks laden ihn als Kontext in jeden Chat des Projekts (Spec 02, *Assistent der Session*). Die Agentenfunktion von Claude Code (`.claude/agents/`, Subagenten) wird nicht verwendet.

### Aufbau

```
<Projekt>/@/
├── @!Prompt/<prompt>.md                   Persönlichkeit, wiederverwendbar
├── @!Skill/<skill>/SKILL.md               geteilte Skills
└── @!Assistant/<assistant>/
    ├── ASSISTANT.md                       Bündel und Rollentext
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
| `tools` | nein | Wunsch an den Host, neutrale Namen; in v0.5 nur dokumentierend, nicht erzwungen |

**Auflösung von `prompt`, `skills` und `gui`:** zuerst im Assistentenordner (`<assistant>/@!Prompt/<prompt>.md`, `<assistant>/@!Skill/<skill>/SKILL.md`), danach in den Masterspaces der Kette vom Projekt aufwärts (`<D>/@/@!Prompt/…`, `<D>/@/@!Skill/…`, `<D>/@/@!Package/<paket>/skills/…`); der nächstgelegene Treffer gewinnt. Ein nicht gefundener Name, ein Skill ohne gültige `version` und ein `gui`, das nicht in `skills` steht, sind Fehler, die `aios --context --assistant` meldet.

**Assistenten der Kette:** alle `<D>/@/@!Assistant/<name>/ASSISTANT.md` und `<D>/@/@!Package/<paket>/assistants/<name>/ASSISTANT.md`; bei gleichem Namen gewinnt der nächstgelegene Masterspace, darin der lokale Assistent vor dem Paket. `name` muss dem Verzeichnisnamen entsprechen, `version` muss gültig sein; ein Assistent, der das nicht erfüllt, wird nicht aufgelöst und von `aios --context --assistants` und `/aios-assistant` gemeldet. Das Frontmatter wird mit der YAML-Untermenge von Spec 04 gelesen (mit Blocktexten wie `description: >`); `model` darf ein einzelner Wert (`model: opus`) oder je Host angegeben sein. Assistenten gibt es nur in einem mit AIOS aktivierten Vault. `aios --context --assistants` listet sie mit Titel, Version und Beschreibung.

**Wissen des Assistenten:** Der Assistentenordner wird nach den Klassen von Spec 02 eingeteilt, als wäre er ein Masterspace: Dateien und Ordner ohne Präfix werden geladen (ohne `ASSISTANT.md`), `@@…` ist verfügbar, `@!…` (auch `@!Prompt`, `@!Skill`) verborgen. Dateien, deren Name mit `.` beginnt (z. B. `.aios-deploy`), werden übergangen.

**Kontext eines Assistenten:** `aios --context --assistant <name>` gibt in `<aios-assistant name="…" title="…" version="…" src="…">` … `</aios-assistant name="…">` aus: einen Block `<aios-assistant-meta>` mit `description`, `model`, `tools`, `skills`, `gui`, dann als `<aios-file class="…">` den Prompt (`prompt`), den Text der `ASSISTANT.md` ohne Frontmatter (`assistant`), die geladenen Dateien des Assistentenordners (`load`), das Inhaltsverzeichnis seines verfügbaren Wissens (`<aios-available>`) und die `SKILL.md` aller genannten Skills (`skill`). Die Endmarke zeigt, dass alles gelesen wurde. Diese Ausgabe verwenden die Hooks (Spec 02) und `/aios-assistant`.

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
   project G-Garten: Gärtner → Astronom
   applies to all new chats in G-Garten and in its subprojects with inherit
   ```

   Hat der User den Wechsel in seinem Aufruf schon ausdrücklich bestätigt, entfällt die Rückfrage.
3. Nach Ja `aios --assistant <wert> [--to <projekt>] --yes --session <session-id>`: schreibt `assistant:` in `.aios/config.yaml` (nur diese Zeile; Kommentare und andere Zeilen bleiben) und setzt den Merker der Session auf den neuen wirksamen Assistenten (Spec 02). Die Session-ID nennt die Hülle in einer Textzeile mit dem Platzhalter `${CLAUDE_SESSION_ID}`, den Claude Code im Text eines Skills ersetzt (V0.3, Memo 31; Spec 04).
4. Ist der neue wirksame Assistent nicht `none`: `aios --context --assistant <name>` ausführen und die Ausgabe vollständig lesen. Bei `none`: die bisherige Rolle ablegen.
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

Setzen: AIOS setzt den Titel nicht selbst, weil die Session-ID von Claude Code nicht die der Desktop-App ist (V0.3, Memo 59, A4; V0.4, Memo 20). Claude schlägt den Titel vor und bittet den User, den Chat umzubenennen: in der Desktop-App in der Seitenleiste, in der CLI mit `/rename <Titel>`. AIOS fügt den Assistenten nicht in den Titel ein; welcher Assistent aktiv ist, sagt Claude in seiner Bestätigung.

## Oberflächen — `/aios-gui` und `/gui`

Eine Oberfläche ist eine **Abkürzung zu Prompts und Skills** für Anwender, die keine Befehle kennen. Alles läuft weiter über den Assistenten und die Regeln von AIOS, z. B. die Rückfrage vor dem Schreiben (I7).

| Aufruf | Oberfläche | Inhalt |
|---|---|---|
| `/aios-gui` | **AIOS-Oberfläche**, gleich für alle Projekte | Aufgaben von AIOS (Tabelle unten) |
| `/gui` | **Oberfläche des Assistenten der Session** | was der Assistent seinem Anwender anbietet, z. B. beim Gärtner den Apfel-Birnen-Rechner |

### Beschreibung einer Oberfläche

Eine Oberfläche ist in erster Linie eine **Beschreibung** (V0.3, Memo 25): eine Datei `gui.yaml` im Ordner des Oberflächen-Skills, daneben optionale HTML-Teile. Der Oberflächen-Skill ist ein gewöhnlicher Skill mit eigenem Namen (z. B. `gaertner-gui`), mit `SKILL.md` und `version`; er kann auch unter seinem Namen aufgerufen werden. Ein Assistent hat **eine** Oberfläche, seine Startseite; weitere Werkzeuge sind Kacheln darauf. Eine App hat ebenso eine Oberfläche (`contents.gui`, Spec 06); sie wird über ihren Skill aufgerufen oder über die Kachel *Apps* von `/aios-gui`, nicht über `/gui` (V0.4, Memo 29).

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
| `tiles[].skill` | eines von drei | Skill, den die Kachel aufruft; sie sendet den Satz `Run the skill /<skill>.`, weil die Desktop-App über `sendPrompt` gesendete Nachrichten verwirft, die mit `/` beginnen (V0.3, Memo 60) |
| `tiles[].html` | eines von drei | Dateiname eines HTML-Teils im Ordner des Oberflächen-Skills; läuft in der Oberfläche ohne Claude, z. B. ein Rechner |
| `tiles[].icon` | nein | ein neutrales Wort für ein Symbol, z. B. `calculator`, `book`, `gear` |

`gui.yaml` wird mit PyYAML gelesen (nicht mit der Untermenge von Spec 04). Ein HTML-Teil einer App darf Platzhalter `{{aios-data <datei>}}` enthalten; `aios --gui` setzt dafür den Inhalt von `@Data/<paket>/<datei>` des Projekts der Session als JSON ein (`null`, wenn die Datei fehlt), damit die Oberfläche gespeicherte Daten der App zeigt (V0.4, Memo 49). Ein HTML-Teil ist ein Fragment ohne `<html>`, `<head>` und `<body>`, mit eingebettetem CSS und JavaScript und ohne Zugriff auf das Netz außer auf die vom Host erlaubten Quellen. Er darf die Hilfsfunktion `sendPrompt(text)` des Hosts verwenden.

### Darstellung

| Host | Darstellung |
|---|---|
| Desktop-App mit HTML-Oberflächen | `aios --gui --html` erzeugt aus der Beschreibung ein HTML-Fragment: Überschrift, Intro, Kacheln als Schaltflächen (`prompt` und `skill` über `sendPrompt`, verbunden in einem `<script>`-Block, weil Hosts Inline-Handler wie `onclick` entfernen; alle Skripte, auch die der HTML-Teile, stehen am Ende auf oberster Ebene, weil die Desktop-App nur solche Skripte ausführt (V0.3, Memo 60)), HTML-Teile eingebettet, darunter die Zeile „If a tile only fills the input field, press Enter. If nothing happens, name the tile in the chat." Claude zeigt es mit dem Werkzeug des Hosts für HTML-Oberflächen im Chat. Nennt der User danach eine Kachel im Chat, weil die Kacheln nicht reagieren, bietet Claude dieselben Kacheln als Menü an (A10; V0.4, Memo 31) |
| CLI und Desktop-App ohne HTML-Oberflächen (Spec 01, O4) | Menü mit dem Auswahlwerkzeug (`AskUserQuestion`), höchstens 4 Einträge je Ebene, bei mehr Kacheln mit „Weitere …"; Kacheln mit `html` fehlen dort und werden als Hinweis genannt |

Die Oberfläche erscheint, wenn `/aios-gui` oder `/gui` aufgerufen wird; sie ist nicht dauerhaft sichtbar.

### `/gui`

`/gui` ist ein **Alias**: eine feste, versionsneutrale Hülle in `~/.claude/skills/gui/` (Spec 04). Es gibt nur diesen einen Alias (V0.3, Memo 25). Der Rumpf entsteht beim Aufruf mit `aios --gui --session ${CLAUDE_SESSION_ID}`:

1. Assistent bestimmen: der Assistent der Session aus dem Merker (Spec 02); ohne Merker die Zuordnung des Projekts.
2. Hat er ein `gui:`, gibt `aios --gui` den Rumpf des Oberflächen-Skills aus, erweitert um die Anweisung, die Oberfläche nach *Darstellung* zu zeigen.
3. Ist kein Assistent aktiv oder nennt er kein `gui:`: „The assistant <title> has no surface." bzw. „No assistant active.", jeweils mit „AIOS surface: `/aios-gui`".

Weil der Rumpf beim Aufruf aufgelöst wird, zeigt `/gui` nach einem Wechsel des Assistenten sofort die neue Oberfläche, ohne neue Registrierung.

### Oberfläche einer App

Die Oberfläche einer App ist der Skill, den `contents.gui` ihres Pakets nennt (Spec 06). Er ruft `aios --gui --skill <oberfläche> [--html]` auf: Überschrift und Anweisung *Show the surface* bzw. das Fragment mit den Platzhaltern der App. `aios --gui --apps` listet die Oberflächen der ausgerollten Apps der Kette, für die Kachel *Apps* von `/aios-gui`.

### `/aios-gui`

AIOS-Skill mit der Oberfläche von AIOS selbst. Ihre Beschreibung liegt im AIOS-Skill (`skills/aios/aios-gui/gui.yaml`) und hat diese Kacheln:

| Kachel | sendet |
|---|---|
| Projekt initialisieren | `/aios-init` (Dialog *Projekt initialisieren*, Spec 02) |
| Kontext und Konfiguration | `/aios-context`, danach `aios --config` |
| Assistent zuordnen | `/aios-assistant` mit Auswahl aus `aios --context --assistants`, `none`, `inherit` |
| Pakete | `/aios-package` (suchen, holen, zeigen, was geholt ist) |
| Apps | Oberflächen der ausgerollten Apps der Kette (`contents.gui`, Spec 06); die Kachel sendet einen Prompt, Claude holt die Liste mit `aios --gui --apps` und zeigt sie als Auswahl; eine Auswahl ruft den Oberflächen-Skill der App auf, z. B. `/taschenrechner-gui`; ohne Apps der Hinweis auf `/aios-package` |
| Pakete abgleichen und Skills registrieren | `/aios-fetch` (Abgleich), `/aios-register` |
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
| Vorrang | Ist im Projekt ein Skill `memo` registriert (`memo` in `.aios/registry`), gibt `aios --skill aios-memo` statt des Rumpfs nur aus: „Use `/memo` — the skill `memo` is registered in this project." Zusätzlich sagt die Beschreibung von `aios-memo`: „Nur verwenden, wenn kein Skill `memo` verfügbar ist." |
| Regeln, die auf `memo` verweisen | gelten ersatzweise mit `aios-memo`, wenn `memo` nicht ausgerollt oder nicht registriert ist |
