---
title: "Master-Kontext"
date: 2026-11-03
author: iHux
status: Spec
tags: [spec, aios, v0.6, master-kontext]
number: 02
related:
  - "Spec 01 AIbex AIOS v0.6 — Überblick"
  - "Spec 03 Skills und Assistenten"
  - "Spec 04 Installation und Konfiguration"
  - "Spec 05 Projekte"
  - "Spec 06 Pakete und Workspaces"
  - "Memo 01 Brainstorming — Masterspace-Klassen und Agenten (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memo 06 Projekt, Root-Projekt und Projektstatus (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memos 01, 06, 08, 14, 15, 22 (AA-AIbex-AIOS, @Memo/V0.3)"
  - "Memos 03, 04, 29, 35 (AA-AIbex-AIOS, @Memo/V0.5)"
  - "Memos 12, 14, 15, 17, 21–23, 25, 31, 33 (AA-AIbex-AIOS, @Memo/V0.6)"
---

# Master-Kontext

Diese Spec regelt, welches Wissen ein Chat bekommt, den **Master-Kontext** (geladen) und das **verfügbare Wissen** (bei Bedarf gelesen): wie AIOS Vault, Art des Vaults, Projekt und Kette bestimmt, wie die Klassen eines Masterspace wirken, was das CLI `aios --context` ausgibt (einschließlich des Blocks der Kernel-Skills), was die Hooks tun (einschließlich des Assistenten der Session, der Konsistenzprüfung und der Freigabe von Befehlen) und was der Skill `/aios-context` zeigt. Begriffe siehe Spec 01, Dateistrukturen und Formate siehe Spec 04, Assistenten siehe Spec 03, Struktur eines Projekts siehe Spec 05.

## Vault, Projekt und Kette

Ausgangspunkt ist immer das Arbeitsverzeichnis `cwd` der Session, als **physischer Pfad** (Symlinks aufgelöst). So hat ein Projekt dieselbe id, wie immer `cwd` erreicht wurde, und ein Vault wird auch über einen Symlink ohne `§` im Namen erkannt. Dasselbe gilt für die Weiterleiter (Spec 04).

| Schritt | Regel |
|---|---|
| **Vault-Root** | das nächste Verzeichnis oberhalb von `cwd` (einschließlich `cwd`), dessen Name mit `§` beginnt. Gibt es keines, ist die Session **außerhalb eines Vaults**. |
| **Art des Vaults** | Allein `<vault-root>/.aios/config.yaml` entscheidet mit `aios:` bzw. `legacy:` (Tabelle *Arten von Vaults*). Ein `aios:` oder `legacy:` in der `.aios/config.yaml` eines anderen Ordners wird übergangen; im A/W meldet der Hook es als `AIOS-WARNING` (Spec 04, *Formate*). `~/.aios/config.yaml` bindet nie. |
| **Projekt** | `cwd` selbst, wenn es ein `@/` hat. Hat `cwd` kein `@/`, ist das Projekt **nicht initialisiert** (siehe unten). |
| **Master-Space-Kette** | alle Verzeichnisse `D/@` mit `D` von der Vault-Root abwärts bis `cwd`, sofern `D/@` existiert; Reihenfolge von der Vault-Root zum Projekt |

Ein Chat im Root-Projekt ist erlaubt; die Kette besteht dann nur aus dem Root-Masterspace. In einer Arbeitskopie tritt diese an die Stelle des Projekts, in dem sie liegt (unten, *Arbeitskopie*).

### Arten von Vaults

| `<vault-root>/.aios/config.yaml` | Art | Modus (`--id`) | Wirkung der Hooks |
|---|---|---|---|
| `aios:` ≥ 0.6.0 | **A/W** | `aios-<version>` | AIBOS-Verhalten nach dieser Spec |
| `aios:` < 0.6.0 | **Vault mit Altbindung** | `alt-<version>` | Der Weiterleiter ruft den Kernel dieser Version (Spec 04); er verhält sich nach der Spec seiner Version |
| `legacy: ai-brain` | **Legacy-Vault** | `legacy` | Legacy-Modus (unten) |
| keines von beiden | **Vault ohne Bindung** | `none` | keine; wie außerhalb eines Vaults |
| keine Vault-Root | **außerhalb eines Vaults** | `none` | keine |

Stehen `aios:` und `legacy:` in derselben Datei, gilt `aios:`; der Hook meldet es im A/W als `AIOS-WARNING` und `/aios-integrity` meldet es (V0.6, Memo 17). **Außerhalb eines A/W** heißt in dieser Spec: Vault ohne Bindung oder außerhalb eines Vaults. Dort geben die Hooks nichts aus (Spec 01, I12); in einem Legacy-Vault und in einem Vault mit Altbindung bestimmt das jeweilige Programm, was ausgegeben wird.

### Nicht initialisiertes Projekt

Liegt `cwd` in einem A/W und hat kein `@/`, gilt:

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

Hat `cwd` ein `@/`, prüft der SessionStart-Hook beim **ersten Start einer Session** (`source` `startup`) die Struktur des Projekts nach Spec 05. Nach Resume, Clear und Compaction prüft er nicht; eine abgelehnte Ergänzung wird in derselben Session also nicht erneut angeboten. In einer Arbeitskopie (unten, *Arbeitskopie*) prüft er ebenfalls nicht: Eine Ergänzung landete auf dem Branch der Arbeitskopie bzw. im Repo des gewählten Ordners. Fehlt etwas, gibt der Hook vor dem Master-Kontext `PROJECT-INCOMPLETE` mit der Liste der Lücken aus. Claude bietet vor der ersten inhaltlichen Antwort an, die Lücken mit `aios --init` zu ergänzen (Plan und Rückfrage, Spec 05). Anders als beim nicht initialisierten Projekt arbeitet der Chat auch weiter, wenn der User ablehnt.

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

Die Detailregeln sind offen (Spec 01, O2). Für v0.6 gilt vorläufig:

| # | Regel |
|---|---|
| K1 | Ein Unterverzeichnis ohne Präfix erbt die Klasse seines übergeordneten Verzeichnisses. |
| K2 | Mit der Ordnung *Laden* < *Verfügbar* < *Verborgen* gilt auf einem Pfad die strengste Klasse: ein `@X` innerhalb von `@!Skill` bleibt verborgen, ein `@@X` innerhalb von `@Wissen` ist verfügbar. |
| K3 | Dateien direkt in `@/` gehören zur Klasse *Laden*. |
| K4 | Berücksichtigt werden nur Dateien mit der Endung `.md`. Andere Dateien (Bilder, PDFs) bleiben liegen und werden nicht geladen. Dateien und Verzeichnisse, deren Name mit `.` beginnt (z. B. `.obsidian/`, `.gitkeep`), werden übergangen. |
| K5 | Die id des Master-Kontexts wird aus `cwd`, den Pfaden und Inhalten aller geladenen Dateien und den Pfaden des verfügbaren Wissens gebildet, also genau aus dem, was der Master-Kontext enthält (siehe `aios --context --id`). Inhalte des verfügbaren Wissens und verborgene Dateien gehen nicht ein. Genau: die ersten 8 Hex-Zeichen von SHA-256 über `cwd <cwd>⏎`, je geladener Datei `load <pfad>⏎<inhalt>⏎`, je Datei des verfügbaren Wissens `available <pfad>⏎` und, im A/W, `kernel-skills <version>⏎` mit der Version des laufenden Kernels (für den Block der Kernel-Skills, unten), in der Reihenfolge des Master-Kontexts. Der Assistent geht nicht ein; er hat eigene Marken. |
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

### Block der Kernel-Skills

Im A/W enthält der Master-Kontext nach dem Inhaltsverzeichnis des verfügbaren Wissens den Block `<aios-kernel-skills>`. Er steht innerhalb der Marken mit der id, wird also mit dem Master-Kontext geladen, nach einer Compaction neu ausgegeben und von `AIOS-CONTEXT-CHECK` mit geprüft (V0.6, Memos 23, 25). Er führt jeden Kernel-Skill des laufenden Kernels (Spec 03, *Arten von Skills*) mit Name und Aufruf auf, sortiert nach Namen, ohne Beschreibung (V0.6, Memo 46):

```
<aios-kernel-skills>
Kernel skills of AIBOS (descriptions in the registered skills). A skill is triggered by
/<name> or by a matching request of the user; load its instructions with the call, run
alone as one Bash command (no cd, no ; && | around it: AIBOS permits only the call alone),
and follow them.
- aios-init — /Users/…/.aios/bin/aios --skill aios-init
- …
</aios-kernel-skills>
```

Der Hinweis, den Aufruf allein als einen Bash-Befehl auszuführen, folgt aus *Freigabe*, E3: Einen verketteten Aufruf (mit `cd`, `;`, `&&`, `|`) gibt AIBOS nicht frei, und der Host fragt (V0.6, Memo 98, B17).

Der Aufruf nennt den absoluten Pfad des Weiterleiters (Spec 04). Der Block nennt keine `allowed-tools`; die Befehle gibt der Hook `PreToolUse` frei (*Hooks*). Er steht neben den registrierten Hüllen (Spec 03): Sie tragen `/<name>` in jedem Host und die Beschreibungen, an denen die Auslösung über einen Satz hängt; der Block nennt Namen und Aufruf auch dort, wo die Registrierung fehlt. Mit 12 Kernel-Skills hat er etwa 1000 Zeichen (gemessen 997 mit `/Users/hux`).

## CLI `aios --context`

`aios --context` ist die Gruppe des Befehls `aios`, die die Hooks und die lesenden Kernel-Skills aufrufen (V0.5, Memos 03, 04, 35); bis v0.4 hieß sie `aios-context`. `~/.aios/bin/aios` ist ein Weiterleiter auf die gültige Version; nur diese Gruppe ruft in einem Legacy-Vault `ai-brain` auf (Spec 04). `ai-brain` bleibt unverändert installiert und wird von AIOS nicht verändert.

| Aufruf | Wirkung |
|---|---|
| `aios --context --session` | SessionStart-Hook (liest Hook-JSON von stdin, nimmt dessen `cwd`, `session_id` und `source`), siehe *Hooks* |
| `aios --context --advise` | UserPromptSubmit-Hook (liest Hook-JSON von stdin), siehe *Hooks* |
| `aios --context --permit` | PreToolUse-Hook für Bash, das Skill-Werkzeug und `Read` (liest Hook-JSON von stdin, nimmt `cwd`, `tool_name` und `tool_input.command`, `tool_input.skill` bzw. `tool_input.file_path`), siehe *Freigabe* |
| `aios --context [<pfad>]` | gibt den Master-Kontext von `cwd` bzw. `<pfad>` aus (Format siehe *Ausgabe*) |
| `aios --context --load [<pfad>]` | schreibt den Master-Kontext in Part-Dateien unter `~/.aios/cache/<id>/` (je höchstens 40.000 Zeichen, geschnitten an Zeilenenden) und gibt die Liste aus; einmal je id, Cache-Einträge älter als 7 Tage werden entfernt |
| `aios --context --id [<pfad>]` | gibt `id=<id> files=<n> cwd=<cwd> mode=<aios-0.6.0 | alt-0.5.1 | legacy | none>` aus; `aios-<version>` ist die Version des laufenden Programms, `alt-<version>` die Version einer Altbindung (*Arten von Vaults*) |
| `aios --context --list [<pfad>]` | Aufstellung für `/aios-context` (siehe dort) |
| `aios --context --sync [--yes\|--plan]` | Registrierung der Projekt-Skills (Spec 03, *Registrieren*), mit Vorschau; mit `--yes` ohne Rückfrage |
| `aios --context --assistant <name> [--load [<pfad>]]` | gibt den Kontext eines Assistenten aus (Spec 03, *Assistenten*); mit `--load` als Part-Dateien unter `~/.aios/cache/a-<name>-<id>/` wie bei `--load`, für `<pfad>` statt des Arbeitsverzeichnisses |
| `aios --context --assistants` | Assistenten der Kette mit Titel, Version und Beschreibung |
| `aios --context --assignment [<pfad>] [--session <id>]` | wirksamer Assistent: `assistant=<name\|none> from=<pfad der config.yaml\|->`; mit `--session` der Assistent der Session aus dem Merker, sonst die Zuordnung des Projekts (Spec 03) |

Hilfe und Version gibt `aios -?` bzw. `aios --version` aus (Spec 04). Außerhalb eines A/W geben `--session`, `--advise`, `--permit`, `aios --context` ohne Option und `--load` nichts auf stdout aus; `--id` meldet `id=- files=0 cwd=<cwd> mode=none`. In einem Vault mit Altbindung ruft schon der Weiterleiter den alten Kernel auf; läuft `aios --context` 0.6 selbst, meldet `--id` `mode=alt-<version>` und die übrigen Aufrufe geben nichts aus. Im Legacy-Modus meldet `--id` die Ausgabe von `ai-brain --id` mit angehängtem `mode=legacy` (ohne `ai-brain`: `id=- files=0 cwd=<cwd> mode=legacy`); so erkennt `/aios-context` den Modus. Das gilt für den Weiterleiter und für `aios --context` selbst.

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
<aios-context id="3fa91c02" files="12" cwd="/…/§Demo/G-Garten" version="0.6.0">
<aios-file class="load" src="/…/§Demo/@/@Rule/stil.md">
… Inhalt …
</aios-file>
…
<aios-available>
- … (siehe oben)
</aios-available>
<aios-kernel-skills>
… (siehe oben)
</aios-kernel-skills>
</aios-context id="3fa91c02">
```

| Element | Bedeutung |
|---|---|
| `<aios-context id=… >` … `</aios-context id=…>` | Anfangs- und Endmarke; der Master-Kontext gilt nur als geladen, wenn beide Marken mit derselben id im Kontext stehen; `version` ist die Version des laufenden Programms |
| `<aios-file class="load" src=…>` | eine geladene Datei mit absolutem Pfad |
| `<aios-available>` | Inhaltsverzeichnis des verfügbaren Wissens (Teil des Master-Kontexts) |
| `<aios-kernel-skills>` | Block der Kernel-Skills (Teil des Master-Kontexts) |

In allen Texten, die AIOS ausgibt (Master-Kontext, Anweisungen, Texte der Hooks), steht für `aios` der absolute Pfad des Weiterleiters, z. B. `/Users/…/.aios/bin/aios --context --load "<cwd>"`; `~/.aios/bin` steht beim User in der Regel nicht im `PATH` (Spec 04). Die Beispiele in dieser Spec schreiben kurz `aios`.

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

Läuft die Session in einer Arbeitskopie, steht davor:

```
AIOS-WORKTREE: this session runs in a git worktree on branch <branch>
 (<arbeitskopie>), not in the chosen folder <gewählter ordner>.
 Before your first work, tell the user in one sentence that results land on
 branch <branch> and not in the chosen folder. After writing work (files
 changed or committed), offer to merge the branch into <gewählter ordner>
 instead of only reporting it as done.
```

### Arbeitskopie

Ein Host kann eine Session statt im gewählten Ordner in einer **Arbeitskopie** starten, einem verknüpften Git-Worktree auf einem eigenen Branch (die Desktop-App von Claude Code z. B. in `<projekt>/.claude/worktrees/<name>/`, Branch `claude/<name>`). Was die Session schreibt und committet, landet dann auf diesem Branch und erscheint im gewählten Ordner erst nach dem Übernehmen (V0.5, Memo 71, B6). AIOS ändert daran nichts; es macht es sichtbar (Memo 73):

| Punkt | Regel |
|---|---|
| Erkennen | `git rev-parse --git-dir` und `--git-common-dir` in `cwd` sind verschieden und das gemeinsame Git-Verzeichnis heißt `.git` |
| Branch | `git symbolic-ref --short HEAD`, ohne Branch `detached HEAD` |
| Arbeitskopie | `git rev-parse --show-toplevel` |
| gewählter Ordner | der Ordner über dem gemeinsamen `.git`, dazu der Pfad von `cwd` relativ zur Arbeitskopie |
| Ausgabe | SessionStart-Hook bei jedem `source`, im A/W auch in einem nicht initialisierten Ordner: `AIOS-WORKTREE` vor `PROJECT-UNINITIALIZED`; die Konsistenzprüfung entfällt |
| Kette | Liegt die Arbeitskopie im Ordner ihres Haupt-Repos (dessen `.git` ist `<haupt>/.git`, ihre `.git`-Datei zeigt auf `<haupt>/.git/worktrees/<name>`), tritt sie an die Stelle von `<haupt>`: Die Kette führt von `cwd` bis zur Arbeitskopie und dann oberhalb von `<haupt>` weiter; Masterspace und `.aios/config.yaml` von `<haupt>` und der Ordner dazwischen gehören nicht dazu. Ist `<haupt>` die Vault-Root, endet die Kette an der Arbeitskopie, und deren `.aios/config.yaml` gilt als Konfiguration des Vaults (V0.5, Memo 79: B9). Erkannt wird das an der `.git`-Datei, ohne `git` aufzurufen |

Arbeitskopien unter `.claude/worktrees/` schließt die `.gitignore`-Vorlage aus (Spec 04); so erscheinen sie im gewählten Ordner nicht als neue Dateien und erfüllen S4 (Spec 05). `/aios-integrity` steigt nicht in Ordner mit `.` ab.

## Hooks

`aios --install` trägt in `~/.claude/settings.json` drei Hooks ein, jeden mit dem absoluten Pfad des Weiterleiters, und entfernt dabei die Hooks von `ai-brain` (Spec 04). Alle drei rufen nur den Weiterleiter auf. Die Wirkung beschreibt die Tabelle für den A/W; außerhalb eines A/W geben sie nichts aus, in einem Legacy-Vault und einem Vault mit Altbindung gilt *Arten von Vaults*.

| Hook | Aufruf | Verhalten |
|---|---|---|
| **SessionStart** (Start, Resume, Clear, nach Compaction) | `aios --context --session` | 1. außerhalb eines A/W: nichts. 2. Legacy-Vault: Verhalten von `ai-brain --session`. 3. im A/W: Registrierung der Kernel-Skills und Projekt-Skills ohne Rückfrage (`--sync --yes`), bei Änderungen eine Zeile `AIOS-SKILLS: … — effective from the next chat` (Spec 03). 4. in einer Arbeitskopie: `AIOS-WORKTREE` (*Arbeitskopie*). 5. bei nicht initialisiertem Projekt: `PROJECT-UNINITIALIZED`; sonst bei `source` `startup` und nicht in einer Arbeitskopie die Konsistenzprüfung, bei Lücken `PROJECT-INCOMPLETE`. 6. Master-Kontext mit dem Block der Kernel-Skills inline, wenn er höchstens `inline_limit` Zeichen hat (Standard 9000), sonst `AIOS-CONTEXT-MANDATORY` mit der Liste der Part-Dateien. 7. Assistent der Session bestimmen und den Merker schreiben (unten); ist es nicht `none`, seinen Kontext ausgeben, inline mit `AIOS-ASSISTANT` oder bei mehr als `inline_limit` Zeichen `AIOS-ASSISTANT-MANDATORY` mit Part-Dateien |
| **UserPromptSubmit** | `aios --context --advise` | außerhalb eines A/W: nichts. Legacy-Vault: Verhalten von `ai-brain --advise`. Im A/W, für das `cwd` dieses Prompts: `AIOS-CONTEXT-CHECK: expected id=<id>` mit der Anweisung, bei fehlenden Marken „Lade Master-Kontext" zu sagen, `aios --context --load "<cwd>"` auszuführen, alle Part-Dateien vollständig zu lesen und „Master-Kontext geladen (id <id>)" zu melden. Ist der Assistent der Session für dieses `cwd` nicht `none` (unten), zusätzlich `AIOS-ASSISTANT-CHECK`. Fehlen auf dem Rechner Arbeitspferde aus `lock.yaml` der Kette, zusätzlich `AIOS-WORKERS: missing <paket> <version>, … — run aios --fetch` (Spec 07; V0.5, Memo 29) |
| **PreToolUse** (Matcher `Bash|Skill|Read`) | `aios --context --permit` | außerhalb eines A/W, in einem Legacy-Vault und einem Vault mit Altbindung: nichts. Im A/W: Freigabe nach *Freigabe* (unten) |

Die Hooks erzeugen außer der Registrierung, dem Merker der Session und dem Log keine Dateien und fragen nie nach. Alle nehmen `cwd` aus dem Hook-JSON auf stdin, ohne JSON das Arbeitsverzeichnis des Prozesses; im Legacy-Modus erhält `ai-brain` dasselbe JSON. Das `cwd` gilt je Aufruf: Wechselt die Session ihr Arbeitsverzeichnis, richten sich die nächsten Aufrufe nach dem neuen (Spec 01, Grundregel 10; V0.6, Memo 31). Warnungen der Konfigurationskette gibt `--session` im A/W als Zeilen `AIOS-WARNING: …` aus. Ein scheiternder Hook schreibt den Fehler immer als eine Zeile `<zeitpunkt> <hook> cwd=<cwd> <fehler>` nach `~/.aios/log/context.log` und endet mit Exit 0: Ein Hook bricht nie die Session ab. Im A/W gibt er zusätzlich eine Zeile `AIOS-WARNING: aios --context --session failed: …` aus, außerhalb nichts (V0.6, Memos 12, 15, 45); `--permit` gibt nie eine Warnung aus.

### Freigabe

`aios --context --permit` gibt im A/W die Befehle von AIBOS ohne Rückfrage frei, damit Kernel-Skills und Hüllen ohne globale Regel in `permissions` arbeiten (V0.6, Memos 20–23). Es gibt `permissionDecision: "allow"` (Hook-JSON von Claude Code, `hookSpecificOutput`) genau dann aus, wenn alle Bedingungen gelten:

| # | Bedingung |
|---|---|
| E1 | `cwd` liegt in einem A/W. |
| E2 | Der Befehl beginnt mit dem absoluten Pfad eines Weiterleiters des Kernels (`~/.aios/bin/aios` oder `/opt/aios/bin/aios`, ausgeschrieben), auch in einfachen oder doppelten Anführungszeichen um genau diesen Pfad, gefolgt von einem Leerzeichen oder dem Ende. Arbeitspferde unter `~/.aios/bin/` und alle anderen Befehle gibt es nicht frei. |
| E3 | Der Befehl ist ein einzelner Befehl: Er enthält keines der Zeichen bzw. keine der Folgen `;`, `&`, `|`, `` ` ``, `$(`, `>`, `<`, Zeilenumbruch. |
| E4 | Keine `deny`- oder `ask`-Regel aus `~/.claude/settings.json`, aus `.claude/settings.json` und `.claude/settings.local.json` im `cwd` und aus den Managed Settings (macOS `/Library/Application Support/ClaudeCode/managed-settings.json`, Linux `/etc/claude-code/managed-settings.json`) trifft den Befehl. Ausgewertet werden `Bash`, `Bash(<befehl>)`, `Bash(<präfix>:*)` und `Bash(<muster mit *>)`; ein Muster anderer Form zählt als Treffer. Eine unlesbare Einstellungsdatei gibt nichts frei (V0.6, Memo 47). |

Für das **Skill-Werkzeug** gibt der Hook `permissionDecision: "allow"` aus, wenn alle Bedingungen gelten (V0.6, Memo 65, B10):

| # | Bedingung |
|---|---|
| S1 | `cwd` liegt in einem A/W. |
| S2 | `tool_input.skill` ist ein Kernel-Skill dieses Kernels oder der Alias `gui` und als Hülle des Kernels registriert (`source: "kernel"` in `.aios/registry` des `cwd` oder eines Ordners darüber). Andere Skills gibt er nicht frei. |
| S3 | Keine `deny`- oder `ask`-Regel aus den Dateien von E4 trifft den Skill. Ausgewertet werden `Skill`, `Skill(<name>)`, `Skill(<präfix>:*)` und `Skill(<muster mit *>)`; ein Muster anderer Form zählt als Treffer. |

Für das Werkzeug **`Read`** gibt der Hook `permissionDecision: "allow"` aus, wenn alle Bedingungen gelten. So liest eine Session die Part-Dateien des Master-Kontexts und eines Assistenten (`aios --context --load`, `--assistant … --load`) ohne Rückfrage, obwohl `~/.aios/cache/` außerhalb ihrer Arbeitsverzeichnisse liegt (V0.6, Memos 100, 101, B18), und ebenso Spec und Tutorials der Version, an die ihr Vault gebunden ist (V0.6, Memos 116, 120, H9):

| # | Bedingung |
|---|---|
| R1 | `cwd` liegt in einem A/W. |
| R2 | `tool_input.file_path` ist ein absoluter Pfad, der nach dem Auflösen von `..` und Symlinks unter `~/.aios/cache/` oder unter `<installation>/doc/` liegt (nicht der Ordner selbst). `<installation>` ist das Verzeichnis der Version, an die der Vault des `cwd` gebunden ist (`aios:` der Vault-Root), wie es `installations.yaml` nennt (`~/.aios/versions/v<version>/` oder `/opt/aios/v<version>/`, Spec 04). Ist die gebundene Version nicht installiert, gibt es diesen Ort nicht. `doc/` anderer installierter Versionen und andere Dateien gibt er nicht frei, auch nicht in `~/.aios/`. |
| R3 | Keine `deny`- oder `ask`-Regel aus den Dateien von E4 trifft die Datei. Ausgewertet werden `Read`, `Read(~/<muster>)` und `Read(//<muster>)` mit `*` und `**`; `Read(**)` und ein Muster mit `[`, `]` oder `?` zählen als Treffer. Andere Formen beziehen sich auf ein Projekt oder den Ordner einer Einstellungsdatei und treffen diese Orte nicht. |

Sonst gibt der Hook nichts aus, und der Host fragt wie gewohnt; ebenso für ein anderes Werkzeug als `Bash`, `Skill` oder `Read` im Hook-JSON. Ein Fehler gibt nie frei. Regeln, die den Weiterleiter mit `~` schreiben, trifft E4 nicht; Claude Code achtet sie selbst (V0.6, Memo 47, F55). Claude Code lässt `deny`- und `ask`-Regeln einem `allow` aus `PreToolUse` ohnehin vorgehen (V0.6, Memo 22); E4 bleibt als zweite Sicherung für Hosts, die das anders handhaben. Befehle in `` !`…` `` eines Skills laufen nicht durch `PreToolUse`; sie gibt das `allowed-tools` der Hülle frei (Spec 03; V0.6, Memo 29).

### Assistent der Session

`source` im Hook-JSON entscheidet, woher der Assistent der Session kommt (V0.3, Memo 06):

| `source` | Bedeutung | Assistent der Session |
|---|---|---|
| `startup` | neuer Chat | Zuordnung des Projekts (Spec 03, *Zuordnung*) |
| `clear` | `/clear`, gilt als neuer Chat | Zuordnung des Projekts |
| `resume` | fortgesetzter Chat | der Assistent aus dem Merker der Session |
| `compact` | nach einer Compaction | der Assistent aus dem Merker der Session |

- **Merker:** `~/.aios/sessions/<session_id>.yaml` mit `cwd`, `assistant` (Name oder `none`) und `used` (Zeitpunkt der letzten Verwendung). Der Hook schreibt ihn bei `startup` und `clear` neu und aktualisiert `used` bei jedem Aufruf; `aios --assistant` schreibt ihn beim Wechsel (Spec 03). Fehlt der Merker bei `resume` oder `compact` (z. B. Session aus der Zeit vor v0.3), gilt die Zuordnung des Projekts und der Merker wird angelegt.
- **Nur im eigenen Projekt:** Der Merker gilt nur, solange das `cwd` des Aufrufs im Projekt liegt, in dem er geschrieben wurde (V0.6, Memo 45). In einem anderen Projekt gilt dessen Zuordnung (Spec 03), und der Merker bleibt unverändert; kehrt die Session zurück, gilt er wieder. Ein Assistent wandert also nicht mit, wenn die Session ihr Arbeitsverzeichnis wechselt (Spec 01, Grundregel 10; V0.6, Memo 33).
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
 `aios --context --assistant <name> --load "<cwd>"` via Bash, read every
 listed part file completely, and continue in this role.
```

Die Anweisungen nennen den Pfad ausdrücklich als Argument, damit die id nicht davon abhängt, in welchem Verzeichnis das Bash-Werkzeug gerade steht, und damit der Aufruf ein einziger Befehl ohne `cd` bleibt, den der PreToolUse-Hook freigibt (E3). Die Zeichenzahl für `inline_limit` zählt Zeichen, nicht Bytes und gilt für Master-Kontext und Assistent getrennt.

## Legacy-Modus

In einem Legacy-Vault (`legacy: ai-brain` an der Vault-Root, *Arten von Vaults*) verhält sich `aios --context` exakt wie `ai-brain` in der Version, die beim Installieren von AIOS vorlag. Ein Legacy-Vault ist kein A/W; den Kontext liefert `ai-brain`, das der User ausdrücklich eingetragen hat (V0.6, Memo 17). Ist `ai-brain` nicht installiert, verhält sich der Legacy-Vault wie ein Vault ohne Bindung. Meist ruft schon der Weiterleiter `ai-brain` auf; läuft `aios --context` selbst (z. B. über `AIOS_HOME`), reicht es den Aufruf an `ai-brain` weiter (Ausnahme `--id`, siehe oben):

| Aspekt | Legacy-Modus |
|---|---|
| geladen | alle `.md`-Dateien aller `@/` entlang des Pfads, ohne Klassen |
| Marken | `<masterspace id="…">` wie bei `ai-brain` |
| Skills | keine Registrierung |
| Projekt | keine Prüfung auf `@/`, kein `PROJECT-UNINITIALIZED`, keine Konsistenzprüfung |
| Assistent | keiner, kein Merker |
| Skill `/masterspace` | funktioniert weiter |

Damit laufen Vaults, die noch nicht auf AIOS umgestellt sind (z. B. `§iHux`), unverändert weiter, sobald sie markiert sind; die Markierung trägt der Umstieg nach Rückfrage ein (Spec 04, *Legacy und Umstieg*). Ein `§`-Ordner ohne Markierung und ohne Bindung ist wirkungslos.

## Skill `/aios-context`

Kernel-Skill, Nachfolger von `/masterspace`. Auslöser: `/aios-context`, „Master-Kontext", „was ist geladen?", „Kontext prüfen".

**Ablauf:**

1. `aios --context --id` ausführen.
2. `mode=none`: „Kein AIBOS-Workspace — kein Master-Kontext." und beenden. `mode=legacy`: auf `/masterspace` verweisen und beenden. `mode=alt-<version>`: auf `aios --activate v0.6.<n> <vault-root>` verweisen und beenden.
3. Prüfen, ob beide Marken `<aios-context id="<id>"` und `</aios-context id="<id>">` im Kontext stehen. Erinnerungen, Zusammenfassungen und Hook-Meldungen zählen nicht.
4. Fehlen sie oder steht eine andere id im Kontext: „Master-Kontext veraltet (`<alt>` → `<neu>`)" bzw. „Lade Master-Kontext", `aios --context --load "<cwd>"`, alle Part-Dateien vollständig lesen, Endmarke prüfen.
5. `aios --context --list "<cwd>"` ausführen und die Aufstellung zeigen. `--list` beginnt mit `Master context id <id>, AIOS <version> — <Projekt>`; der Skill ersetzt diese Zeile durch „Master-Kontext geladen (id …)". Im Legacy-Modus gibt `--list` nur einen Verweis auf `/masterspace` aus, außerhalb eines Vaults „No vault — no master context.".

**Aufstellung:**

```
Master-Kontext geladen (id 3fa91c02, AIOS 0.6.0) — G-Garten

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

Die Zeile *Assistant* zeigt die Zuordnung des Projekts (`<name>`, `none` oder `inherit` mit Herkunft). Weicht der Assistent der Session davon ab (Spec 03, *Wechsel*), nennt der Skill beide. *Hidden* zählt die Blueprints der Masterspaces und die ausgerollten Skills und Assistenten der Pakete; bei diesen steht `(<masterspace>, package <paket>)` (V0.5, Memo 71, O2). Der Abschnitt *Packages* nennt je Masterspace der Kette die geholten Pakete mit Version, Hub und ausgerollten Elementen, verdeckte Elemente (Spec 06, *Vorrang*) und nicht ausgerollte Elemente (`fetched, not deployed`). Ein Paket ohne Elemente (z. B. `worker-*`, `distribution-*`) zeigt `no elements`, eines, dessen Elemente alle nicht ausgerollt sind, `no elements deployed` (O3). Der Skill ändert nichts außer dem Nachladen. Stimmen Blueprints und registrierte Skills nicht überein, weist er auf `/aios-register` hin.
