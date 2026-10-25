---
title: "Master-Kontext"
date: 2026-10-25
author: iHux
status: Spec
tags: [spec, aios, v0.5, master-kontext]
number: 02
related:
  - "Spec 01 AIbex AIOS v0.5 — Überblick"
  - "Spec 03 Skills und Assistenten"
  - "Spec 04 Installation und Konfiguration"
  - "Spec 05 Projekte"
  - "Spec 06 Pakete und Workspaces"
  - "Memo 01 Brainstorming — Masterspace-Klassen und Agenten (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memo 06 Projekt, Root-Projekt und Projektstatus (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memos 01, 06, 08, 14, 15, 22 (AA-AIbex-AIOS, @Memo/V0.3)"
  - "Memos 03, 04, 29, 35 (AA-AIbex-AIOS, @Memo/V0.5)"
---

# Master-Kontext

Diese Spec regelt, welches Wissen ein Chat bekommt, den **Master-Kontext** (geladen) und das **verfügbare Wissen** (bei Bedarf gelesen): wie AIOS Vault, Projekt und Kette bestimmt, wie die Klassen eines Masterspace wirken, was das CLI `aios --context` ausgibt, was die Hooks tun (einschließlich des Assistenten der Session und der Konsistenzprüfung) und was der Skill `/aios-context` zeigt. Begriffe siehe Spec 01, Dateistrukturen und Formate siehe Spec 04, Assistenten siehe Spec 03, Struktur eines Projekts siehe Spec 05.

## Vault, Projekt und Kette

Ausgangspunkt ist immer das Arbeitsverzeichnis `cwd` der Session, als **physischer Pfad** (Symlinks aufgelöst). So hat ein Projekt dieselbe id, wie immer `cwd` erreicht wurde, und ein Vault wird auch über einen Symlink ohne `§` im Namen erkannt. Dasselbe gilt für die Weiterleiter (Spec 04).

| Schritt | Regel |
|---|---|
| **Vault-Root** | das nächste Verzeichnis oberhalb von `cwd` (einschließlich `cwd`), dessen Name mit `§` beginnt. Gibt es keines, ist die Session **außerhalb eines Vaults**. |
| **Aktivierung** | Die `.aios/config.yaml` von `cwd` aufwärts bis zur Vault-Root werden gelesen (Spec 04). Steht in einer davon ein Schlüssel `aios:`, ist die Session **aktiviert** mit der Version des nächstgelegenen Eintrags. Sonst gilt der **Legacy-Modus**. `~/.aios/config.yaml` aktiviert nie. |
| **Projekt** | `cwd` selbst, wenn es ein `@/` hat. Hat `cwd` kein `@/`, ist das Projekt **nicht initialisiert** (siehe unten). |
| **Master-Space-Kette** | alle Verzeichnisse `D/@` mit `D` von der Vault-Root abwärts bis `cwd`, sofern `D/@` existiert; Reihenfolge von der Vault-Root zum Projekt |

Ein Chat im Root-Projekt ist erlaubt; die Kette besteht dann nur aus dem Root-Masterspace.

### Nicht initialisiertes Projekt

Liegt `cwd` in einem aktivierten Vault und hat kein `@/`, gilt:

1. `X` ist das nächste Verzeichnis oberhalb von `cwd` mit `@/`. Weil `aios --activate` an der Vault-Root `@/` anlegt (Spec 04), gibt es `X` in der Regel. Fehlt es (die Vault-Root ist ein Container, weil `@/` dort entfernt wurde), ist die Kette leer und die Wahl (2) entfällt.
2. Der SessionStart-Hook lädt den Master-Kontext der Kette bis `X` und gibt zusätzlich die Anweisung `PROJECT-UNINITIALIZED` aus (Format siehe *Ausgabe*). Eine Vault-Root ohne `@/` ist ein Container und löst kein `PROJECT-UNINITIALIZED` aus.
3. Claude ruft vor der ersten inhaltlichen Antwort den Skill `/aios-init` auf und zeigt mit ihm den **Dialog *Projekt initialisieren*** (unten); `aios --init` läuft danach mit `--yes`, Claude beantwortet nie selbst eine Rückfrage von `aios` (V0.3, Memo 54, A2, A3).
4. Bis zur Entscheidung gibt der Chat keine inhaltlichen Antworten.

Eine Wahl „ohne AIOS fortfahren" gibt es nicht.

### Dialog *Projekt initialisieren*

Claude zeigt den Dialog mit dem Auswahlwerkzeug des Hosts (Claude Code: `AskUserQuestion`; Desktop-App als Dialog, CLI als Auswahlliste). Je Frage gibt es höchstens 4 Antworten und immer eine freie Eingabe.

```
Projekt initialisieren — G-Garten
  Titel:      [Garten]  [<Vorschlag>]  [freie Eingabe …]
  Assistent:  [inherit (Gärtner)]  [none]  [<Assistent>]  [freie Eingabe …]
  Anlegen:    [Ja, initialisieren]  [Ins Projekt §Demo wechseln]
```

| Frage | Antworten | Wirkung |
|---|---|---|
| **Titel** | Name des Ordners ohne Prefix, ein Vorschlag, freie Eingabe | Titel **dieses Chats** (Spec 03, *Titel*); wird nicht gespeichert |
| **Assistent** | `inherit` mit dem Assistenten, der geerbt würde, `none` und bis zu zwei Assistenten aus `aios --context --assistants`; andere über die freie Eingabe | Zuordnung des neuen Projekts (Spec 03); `inherit` wird nicht geschrieben |
| **Anlegen** | initialisieren oder ins Projekt `X` wechseln | initialisieren: `aios --init --yes` mit `--assistant <wert>` (außer bei `inherit`), danach Titel setzen; die Antwort ist die Rückfrage nach I7. Wechseln: in der Desktop-App über das Werkzeug zum Wechsel des Arbeitsverzeichnisses, in der CLI Chat beenden und in `X` neu starten |

Vor dem Dialog ruft Claude `aios --init --plan` auf. Meldet der Plan einen Verstoß gegen die Namensregel, folgt nach dem Dialog der Namensdialog von Spec 05. In Sessions ohne Fenster (`claude -p`) stellt Claude die Fragen als Text. Ein Hook kann keinen Dialog öffnen: Der Dialog erscheint nach der ersten Nachricht des Users im neuen Chat.

### Unvollständiges Projekt — Konsistenzprüfung

Hat `cwd` ein `@/`, prüft der SessionStart-Hook beim **ersten Start einer Session** (`source` `startup`) die Struktur des Projekts nach Spec 05. Nach Resume, Clear und Compaction prüft er nicht; eine abgelehnte Ergänzung wird in derselben Session also nicht erneut angeboten. Fehlt etwas, gibt der Hook vor dem Master-Kontext `PROJECT-INCOMPLETE` mit der Liste der Lücken aus. Claude bietet vor der ersten inhaltlichen Antwort an, die Lücken mit `aios --init` zu ergänzen (Plan und Rückfrage, Spec 05). Anders als beim nicht initialisierten Projekt arbeitet der Chat auch weiter, wenn der User ablehnt.

Geprüft wird nur die Struktur, keine Inhalte; ob geholte Pakete zu `lock.yaml` fehlen, meldet `aios --fetch` (Spec 06). Eine Vault-Root ohne `@/` wird nicht geprüft.

## Klassen

Die Klasse eines Unterverzeichnisses eines Masterspace steht im Namen. Erkannt wird in dieser Reihenfolge:

| Präfix | Klasse | Wirkung |
|---|---|---|
| `@!` | **Verborgen** | nie Kontext; Blueprints (`@!Skill`, `@!Prompt`, `@!Assistant`) und geholte Pakete (`@!Package`, Ausnahme K6) |
| `@@` | **Verfügbar** | verfügbares Wissen: gehört **nicht** zum Master-Kontext und wird nur bei Bedarf gelesen; im Master-Kontext steht sein Inhaltsverzeichnis |
| `@` | **Laden** | bildet den Master-Kontext; wird zu Beginn des Chats vollständig geladen |

`@@` und `@!` werden vor `@` geprüft; sonst würde `@@Kapitel` als *Laden* mit dem Namen `@Kapitel` gelesen.

Die Klassifikation ist rekursiv: Innerhalb eines Verzeichnisses einer Klasse können wieder Unterverzeichnisse mit Präfix liegen, z. B. `@/@Wissen/@Content/` (Laden) und `@/@Wissen/@@Kapitel1/` (Verfügbar).

### Vorläufige Regeln der Klassen

Die Detailregeln sind offen (Spec 01, O2). Für v0.5 gilt vorläufig:

| # | Regel |
|---|---|
| K1 | Ein Unterverzeichnis ohne Präfix erbt die Klasse seines übergeordneten Verzeichnisses. |
| K2 | Mit der Ordnung *Laden* < *Verfügbar* < *Verborgen* gilt auf einem Pfad die strengste Klasse: ein `@X` innerhalb von `@!Skill` bleibt verborgen, ein `@@X` innerhalb von `@Wissen` ist verfügbar. |
| K3 | Dateien direkt in `@/` gehören zur Klasse *Laden*. |
| K4 | Berücksichtigt werden nur Dateien mit der Endung `.md`. Andere Dateien (Bilder, PDFs) bleiben liegen und werden nicht geladen. Dateien und Verzeichnisse, deren Name mit `.` beginnt (z. B. `.obsidian/`, `.gitkeep`), werden übergangen. |
| K5 | Die id des Master-Kontexts wird aus `cwd`, den Pfaden und Inhalten aller geladenen Dateien und den Pfaden des verfügbaren Wissens gebildet, also genau aus dem, was der Master-Kontext enthält (siehe `aios --context --id`). Inhalte des verfügbaren Wissens und verborgene Dateien gehen nicht ein. Genau: die ersten 8 Hex-Zeichen von SHA-256 über `cwd <cwd>⏎`, je geladener Datei `load <pfad>⏎<inhalt>⏎` und je Datei des verfügbaren Wissens `available <pfad>⏎`, in der Reihenfolge des Master-Kontexts. Der Assistent geht nicht ein; er hat eigene Marken. |
| K6 | Ausnahme zu K2: Der Ordner `@!Package/<paket>/knowledge/` eines geholten Pakets, dessen Element `knowledge` ausgerollt ist (Spec 06), wird eingeteilt, als läge sein Inhalt direkt in `@/` desselben Masterspace (K1–K4 gelten darin). Er folgt in der Reihenfolge auf die übrigen Einträge des Masterspace, Pakete nach Namen sortiert (Spec 06). |

**Reihenfolge:** Masterspaces von der Vault-Root zum Projekt; innerhalb eines Masterspace je Verzeichnis nach Namen sortiert (Dateien und Verzeichnisse gemeinsam, Zeichencode), rekursiv. `files` zählt die geladenen Dateien.

### Inhaltsverzeichnis des verfügbaren Wissens

Für jede Datei des verfügbaren Wissens enthält der Master-Kontext eine Zeile mit absolutem Pfad und der ersten Überschrift der Datei (nach einem allfälligen Frontmatter; ohne Überschrift der Dateiname ohne `.md`):

```
<aios-available>
- /…/§Demo/@/@Wissen/@@Kapitel1/kapitel.md — Kapitel 1: Grundlagen
</aios-available>
```

Ein handgeschriebenes Inhaltsverzeichnis mit der Spalte „Lesen, wenn …" kann zusätzlich als *Laden* abgelegt werden (z. B. `@Wissen/@Content/`) und ist die genauere Hilfe für das Modell.

## CLI `aios --context`

`aios --context` ist die Gruppe des Befehls `aios`, die die Hooks und die lesenden AIOS-Skills aufrufen (V0.5, Memos 03, 04, 35); bis v0.4 hieß sie `aios-context`. `~/bin/aios` ist ein Weiterleiter auf die gültige Version; nur diese Gruppe fällt ohne Aktivierung auf `ai-brain` zurück (Spec 04). `ai-brain` bleibt unverändert installiert und wird von AIOS nicht verändert.

| Aufruf | Wirkung |
|---|---|
| `aios --context --session` | SessionStart-Hook (liest Hook-JSON von stdin, nimmt dessen `cwd`, `session_id` und `source`), siehe *Hooks* |
| `aios --context --advise` | UserPromptSubmit-Hook (liest Hook-JSON von stdin), siehe *Hooks* |
| `aios --context [<pfad>]` | gibt den Master-Kontext von `cwd` bzw. `<pfad>` aus (Format siehe *Ausgabe*) |
| `aios --context --load [<pfad>]` | schreibt den Master-Kontext in Part-Dateien unter `~/.aios/cache/<id>/` (je höchstens 40.000 Zeichen, geschnitten an Zeilenenden) und gibt die Liste aus; einmal je id, Cache-Einträge älter als 7 Tage werden entfernt |
| `aios --context --id [<pfad>]` | gibt `id=<id> files=<n> cwd=<cwd> mode=<aios-0.5.0 | legacy | none>` aus; `aios-<version>` ist die Version des laufenden Programms |
| `aios --context --list [<pfad>]` | Aufstellung für `/aios-context` (siehe dort) |
| `aios --context --sync [--yes\|--plan]` | Registrierung der Projekt-Skills (Spec 03, *Registrieren*), mit Vorschau; mit `--yes` ohne Rückfrage |
| `aios --context --assistant <name> [--load]` | gibt den Kontext eines Assistenten aus (Spec 03, *Assistenten*); mit `--load` als Part-Dateien unter `~/.aios/cache/a-<name>-<id>/` wie bei `--load` |
| `aios --context --assistants` | Assistenten der Kette mit Titel, Version und Beschreibung |
| `aios --context --assignment [<pfad>] [--session <id>]` | wirksamer Assistent: `assistant=<name\|none> from=<pfad der config.yaml\|->`; mit `--session` der Assistent der Session aus dem Merker, sonst die Zuordnung des Projekts (Spec 03) |

Hilfe und Version gibt `aios -?` bzw. `aios --version` aus (Spec 04). Außerhalb eines Vaults geben `--session`, `--advise`, `aios --context` ohne Option und `--load` nichts auf stdout aus; `--id` meldet `id=- files=0 cwd=<cwd> mode=none`. Im Legacy-Modus meldet `--id` die Ausgabe von `ai-brain --id` mit angehängtem `mode=legacy` (ohne `ai-brain`: `id=- files=0 cwd=<cwd> mode=legacy`); so erkennt `/aios-context` den Modus. Das gilt für den Weiterleiter und für `aios --context` selbst.

`--load` meldet:

```
AIOS-CONTEXT-LOAD id=<id> files=<n> parts=<p> cwd=<cwd>
Read each of the following part files completely (Read tool), in order:
   ~/.aios/cache/<id>/part-1.md
   …
The master context is loaded once </aios-context id="<id>"> (end of the last part) has been read.
```

`--assistant <name> --load` meldet dasselbe mit `AIOS-ASSISTANT-LOAD name=<name> version=<version> parts=<p>` und der Endmarke `</aios-assistant name="<name>">`.

### Ausgabe

```
<aios-context id="3fa91c02" files="12" cwd="/…/§Demo/G-Garten" version="0.5.0">
<aios-file class="load" src="/…/§Demo/@/@Rule/stil.md">
… Inhalt …
</aios-file>
…
<aios-available>
- … (siehe oben)
</aios-available>
</aios-context id="3fa91c02">
```

| Element | Bedeutung |
|---|---|
| `<aios-context id=… >` … `</aios-context id=…>` | Anfangs- und Endmarke; der Master-Kontext gilt nur als geladen, wenn beide Marken mit derselben id im Kontext stehen; `version` ist die Version des laufenden Programms |
| `<aios-file class="load" src=…>` | eine geladene Datei mit absolutem Pfad |
| `<aios-available>` | Inhaltsverzeichnis des verfügbaren Wissens (Teil des Master-Kontexts) |

Die Anweisungen zur Struktur des Projekts stehen vor dem Master-Kontext:

```
PROJECT-UNINITIALIZED: <cwd> has no local masterspace (@/). Before your first
answer, call the skill /aios-init (Skill tool) and follow it: it runs
`aios --init "<cwd>" --plan`, shows the dialog "Projekt initialisieren"
(title, assistant, initialize or continue in the project <X>) and, after the user's choice,
runs aios --init with --yes. Without that skill, do the same yourself: run the plan,
ask these questions, then run with --yes. Never answer a question of aios yourself.
Give no other answer until the user decides.
```

```
PROJECT-INCOMPLETE: <cwd> is an AIOS project but lacks: <lücke>, <lücke>.
Before your first answer, offer the user to complete it: call the skill /aios-init
(Skill tool) for "<cwd>" and follow it (plan from --plan, after yes run with
--yes; never answer a question of aios yourself).
If the user declines, continue normally and do not offer it again.
```

Die Lücken werden mit den Namen aus Spec 05 genannt (z. B. `own git repo`, `.gitignore lines: .aios/registry`, `exclusion in parent repo /…/§Demo`).

## Hooks

`aios --install` trägt in `~/.claude/settings.json` zwei Hooks ein und entfernt dabei die Hooks von `ai-brain` (Spec 04). Beide rufen nur den Weiterleiter auf.

| Hook | Aufruf | Verhalten |
|---|---|---|
| **SessionStart** (Start, Resume, Clear, nach Compaction) | `aios --context --session` | 1. außerhalb eines Vaults: nichts. 2. Legacy-Modus: Verhalten von `ai-brain --session`. 3. aktiviert: Registrierung der Projekt-Skills ohne Rückfrage (`--sync --yes`), bei Änderungen eine Zeile `AIOS-SKILLS: … — effective from the next chat` (Spec 03). 4. bei nicht initialisiertem Projekt: `PROJECT-UNINITIALIZED`; sonst bei `source` `startup` die Konsistenzprüfung, bei Lücken `PROJECT-INCOMPLETE`. 5. Master-Kontext inline, wenn er höchstens `inline_limit` Zeichen hat (Standard 9000), sonst `AIOS-CONTEXT-MANDATORY` mit der Liste der Part-Dateien. 6. Assistent der Session bestimmen und den Merker schreiben (unten); ist es nicht `none`, seinen Kontext ausgeben, inline mit `AIOS-ASSISTANT` oder bei mehr als `inline_limit` Zeichen `AIOS-ASSISTANT-MANDATORY` mit Part-Dateien |
| **UserPromptSubmit** | `aios --context --advise` | außerhalb eines Vaults: nichts. Legacy-Modus: Verhalten von `ai-brain --advise`. Aktiviert: `AIOS-CONTEXT-CHECK: expected id=<id>` mit der Anweisung, bei fehlenden Marken „Lade Master-Kontext" zu sagen, `aios --context --load "<cwd>"` auszuführen, alle Part-Dateien vollständig zu lesen und „Master-Kontext geladen (id <id>)" zu melden. Ist der Assistent der Session nicht `none`, zusätzlich `AIOS-ASSISTANT-CHECK`. Fehlen auf dem Rechner Arbeitspferde aus `lock.yaml` der Kette, zusätzlich `AIOS-WORKERS: missing <paket> <version>, … — run aios --fetch` (Spec 07; V0.5, Memo 29) |

Die Hooks erzeugen außer der Registrierung und dem Merker der Session keine Dateien und fragen nie nach. Beide nehmen `cwd` aus dem Hook-JSON auf stdin, ohne JSON das Arbeitsverzeichnis des Prozesses; im Legacy-Modus erhält `ai-brain` dasselbe JSON. Warnungen der Konfigurationskette gibt `--session` als Zeilen `AIOS-WARNING: …` aus. Scheitert ein Hook, gibt er eine Zeile `AIOS-WARNING: aios --context --session failed: …` aus und endet mit Exit 0: Ein Hook bricht nie die Session ab.

### Assistent der Session

`source` im Hook-JSON entscheidet, woher der Assistent der Session kommt (V0.3, Memo 06):

| `source` | Bedeutung | Assistent der Session |
|---|---|---|
| `startup` | neuer Chat | Zuordnung des Projekts (Spec 03, *Zuordnung*) |
| `clear` | `/clear`, gilt als neuer Chat | Zuordnung des Projekts |
| `resume` | fortgesetzter Chat | der Assistent aus dem Merker der Session |
| `compact` | nach einer Compaction | der Assistent aus dem Merker der Session |

- **Merker:** `~/.aios/sessions/<session_id>.yaml` mit `cwd`, `assistant` (Name oder `none`) und `used` (Zeitpunkt der letzten Verwendung). Der Hook schreibt ihn bei `startup` und `clear` neu und aktualisiert `used` bei jedem Aufruf; `aios --assistant` schreibt ihn beim Wechsel (Spec 03). Fehlt der Merker bei `resume` oder `compact` (z. B. Session aus der Zeit vor v0.3), gilt die Zuordnung des Projekts und der Merker wird angelegt.
- **Definition:** Geladen wird der Name aus dem Merker mit seiner aktuellen Definition aus der Kette. Ist der Name nicht auflösbar, gibt der Hook `AIOS-WARNING: assistant <name> not found, continuing without assistant` aus, und die Session läuft ohne Assistent.
- **Aufräumen:** Merker, deren `used` mehr als 30 Tage zurückliegt, entfernt der Hook bei `startup`.
- Der Merker ist lokal, weil Sessions lokal sind, und gilt nur für diese Session. Er ist keine persönliche Zuordnung (Spec 01, Grundregel 8).

**Texte der Hooks:**

```
AIOS-CONTEXT (loaded automatically by SessionStart hook):
<aios-context id="…"> … </aios-context id="…">
```

```
AIOS-CONTEXT-MANDATORY: the master context of this project is too large
 for direct injection (<n> > <inline_limit> characters). Before your first
 answer, tell the user "Lade Master-Kontext", read every part file listed
 below completely with the Read tool, then tell the user
 "Master-Kontext geladen (id <id>)".
AIOS-CONTEXT-LOAD … (Ausgabe von --load)
```

```
AIOS-ASSISTANT (assistant of this session, from <herkunft>):
 Take on this role for the whole session. In your first answer, confirm
 briefly "<Titel> aktiv" (and mention the model wish, if any).
<aios-assistant name="…" …> … </aios-assistant name="…">
```

`<herkunft>` ist `project <pfad der config.yaml>` bzw. `session`. Bei `AIOS-ASSISTANT-MANDATORY` steht statt des Kontexts die Ausgabe von `--assistant <name> --load` mit der Anweisung, alle Part-Dateien vollständig zu lesen.

```
AIOS-CONTEXT-CHECK: expected id=<id> (files=<n>, cwd=<cwd>).
 Before answering, verify that BOTH exact markers <aios-context id="<id>"
 and </aios-context id="<id>"> are present in your context (memory or a
 summary of earlier loading does not count). If not: tell the user
 "Lade Master-Kontext", run `aios --context --load "<cwd>"` via Bash, read every
 listed part file completely with the Read tool, then tell the user
 "Master-Kontext geladen (id <id>)". If both markers are present, do nothing.
```

```
AIOS-ASSISTANT-CHECK: expected assistant=<name> version=<version>.
 Verify that BOTH markers <aios-assistant name="<name>" and
 </aios-assistant name="<name>"> are present in your context. If not: run
 `aios --context --assistant <name> --load` via Bash in "<cwd>", read every
 listed part file completely, and continue in this role.
```

Die Anweisungen nennen den Pfad ausdrücklich, damit die id nicht davon abhängt, in welchem Verzeichnis das Bash-Werkzeug gerade steht. Die Zeichenzahl für `inline_limit` zählt Zeichen, nicht Bytes und gilt für Master-Kontext und Assistent getrennt.

## Legacy-Modus

Ohne Aktivierung in der Kette verhält sich `aios --context` exakt wie `ai-brain` in der Version, die beim Installieren von AIOS vorlag. Meist ruft schon der Weiterleiter `ai-brain` auf; läuft `aios --context` selbst (z. B. über `AIOS_HOME`), reicht es den Aufruf an `ai-brain` weiter (Ausnahme `--id`, siehe oben):

| Aspekt | Legacy-Modus |
|---|---|
| geladen | alle `.md`-Dateien aller `@/` entlang des Pfads, ohne Klassen |
| Marken | `<masterspace id="…">` wie bei `ai-brain` |
| Skills | keine Registrierung |
| Projekt | keine Prüfung auf `@/`, kein `PROJECT-UNINITIALIZED`, keine Konsistenzprüfung |
| Assistent | keiner, kein Merker |
| Skill `/masterspace` | funktioniert weiter |

Damit laufen Vaults, die noch nicht auf AIOS umgestellt sind (z. B. `§AIbex`), unverändert weiter.

## Skill `/aios-context`

AIOS-Skill, Nachfolger von `/masterspace`. Auslöser: `/aios-context`, „Master-Kontext", „was ist geladen?", „Kontext prüfen".

**Ablauf:**

1. `aios --context --id` ausführen.
2. `mode=none`: „Kein Vault — kein Master-Kontext." und beenden. `mode=legacy`: auf `/masterspace` verweisen und beenden.
3. Prüfen, ob beide Marken `<aios-context id="<id>"` und `</aios-context id="<id>">` im Kontext stehen. Erinnerungen, Zusammenfassungen und Hook-Meldungen zählen nicht.
4. Fehlen sie oder steht eine andere id im Kontext: „Master-Kontext veraltet (`<alt>` → `<neu>`)" bzw. „Lade Master-Kontext", `aios --context --load "<cwd>"`, alle Part-Dateien vollständig lesen, Endmarke prüfen.
5. `aios --context --list "<cwd>"` ausführen und die Aufstellung zeigen. `--list` beginnt mit `Master context id <id>, AIOS <version> — <Projekt>`; der Skill ersetzt diese Zeile durch „Master-Kontext geladen (id …)". Im Legacy-Modus gibt `--list` nur einen Verweis auf `/masterspace` aus, außerhalb eines Vaults „No vault — no master context.".

**Aufstellung:**

```
Master-Kontext geladen (id 3fa91c02, AIOS 0.5.0) — G-Garten

Chain                      §Demo → G-Garten
Assistant                  gaertner 0.2.0 (inherit, assigned in §Demo)

Master context (loaded)    3 files, 4,120 characters
  §Demo/@/@Rule/stil.md
  §Demo/@/@Wissen/@Content/inhalt.md
  …
Available knowledge        1 file (not loaded, table of contents in the master context)
  §Demo/@/@Wissen/@@Kapitel/kapitel.md
Hidden                     Blueprints: 2 skills, 1 assistant, 1 prompt
  Skills       memo 6.0.0 (§Demo) — registered
               apfel-birnen-algebra 0.1.0 (assistant gaertner, private)
  Assistants   gaertner 0.2.0 (§Demo)
Packages                   2 packages (§Demo)
  taschenrechner 0.1.0 (aibex-aios) — skills taschenrechner, taschenrechner-gui; knowledge
  memo 6.0.0 (aibex-aios) — skill memo: covered by local blueprint memo (§Demo)
  toolbox 1.0.0 (aibex-aios) — fetched, not deployed: skill zettel
```

Die Zeile *Assistant* zeigt die Zuordnung des Projekts (`<name>`, `none` oder `inherit` mit Herkunft). Weicht der Assistent der Session davon ab (Spec 03, *Wechsel*), nennt der Skill beide. Der Abschnitt *Packages* nennt je Masterspace der Kette die geholten Pakete mit Version, Hub und ausgerollten Elementen, verdeckte Elemente (Spec 06, *Vorrang*) und nicht ausgerollte Elemente (`fetched, not deployed`). Der Skill ändert nichts außer dem Nachladen. Stimmen Blueprints und registrierte Skills nicht überein, weist er auf `/aios-register` hin.
