---
title: "Master-Kontext"
date: 2026-09-30
author: iHux
status: Spec
tags: [spec, aios, v0.1, master-kontext]
number: 02
related:
  - "Spec 01 AIbex AIOS v0.1 — Überblick"
  - "Spec 03 Skills und Agenten"
  - "Spec 04 Installation und Konfiguration"
  - "Memo 01 Brainstorming — Masterspace-Klassen und Agenten (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 06 Projekt, Root-Projekt und Projektstatus (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
---

# Master-Kontext

Diese Spec regelt, welches Wissen ein Chat bekommt: wie AIOS Vault, Projekt und Kette bestimmt, wie die Klassen eines Masterspace wirken, was das CLI `aios-context` ausgibt, was die Hooks tun und was der Skill `/aios-context` zeigt. Begriffe siehe Spec 01, Dateistrukturen und Formate siehe Spec 04.

## Vault, Projekt und Kette

Ausgangspunkt ist immer das Arbeitsverzeichnis `cwd` der Session.

| Schritt | Regel |
|---|---|
| **Vault-Root** | das nächste Verzeichnis oberhalb von `cwd` (einschließlich `cwd`), dessen Name mit `§` beginnt. Gibt es keines, ist die Session **außerhalb eines Vaults**. |
| **Aktivierung** | Die `.aios/config.yaml` von `cwd` aufwärts bis zur Vault-Root werden gelesen (Spec 04). Steht in einer davon ein Schlüssel `aios:`, ist die Session **aktiviert** mit der Version des nächstgelegenen Eintrags. Sonst gilt der **Legacy-Modus**. `~/.aios/config.yaml` aktiviert nie. |
| **Projekt** | `cwd` selbst, wenn es ein `@/` hat. Hat `cwd` kein `@/`, ist das Projekt **nicht initialisiert** (siehe unten). |
| **Master-Space-Kette** | alle Verzeichnisse `D/@` mit `D` von der Vault-Root abwärts bis `cwd`, sofern `D/@` existiert; Reihenfolge von der Vault-Root zum Projekt |

Ein Chat im Root-Projekt ist erlaubt; die Kette besteht dann nur aus dem Root-Masterspace.

### Nicht initialisiertes Projekt

Liegt `cwd` in einem aktivierten Vault und hat kein `@/`, gilt:

1. `X` ist das nächste Verzeichnis oberhalb von `cwd` mit `@/`. Weil die Vault-Root ein `@/` hat, gibt es `X` immer.
2. Der SessionStart-Hook lädt den Master-Kontext der Kette bis `X` und gibt zusätzlich die Anweisung `PROJECT-UNINITIALIZED` aus (Format siehe *Ausgabe*).
3. Claude stellt vor der ersten inhaltlichen Antwort die Wahl:
   - **(1) Projekt initialisieren** → `/aios-init` (Spec 03)
   - **(2) ins Projekt `X` wechseln** → in der Desktop-App über das Werkzeug zum Wechsel des Arbeitsverzeichnisses; in der CLI: Chat beenden und in `X` neu starten
4. Bis zur Entscheidung gibt der Chat keine inhaltlichen Antworten.

Eine dritte Wahl („ohne AIOS fortfahren") gibt es nicht.

## Klassen

Die Klasse eines Unterverzeichnisses eines Masterspace steht im Namen. Erkannt wird in dieser Reihenfolge:

| Präfix | Klasse | Wirkung |
|---|---|---|
| `@!` | **Verborgen** | nie Kontext; Blueprints (`@!Skill`, `@!Prompt`, `@!Agent`) |
| `@@` | **Verfügbar** | gehört zum Master-Kontext, wird nur bei Bedarf gelesen; im Kontext steht ein Inhaltsverzeichnis |
| `@` | **Laden** | wird zu Beginn des Chats vollständig geladen |

`@@` und `@!` werden vor `@` geprüft; sonst würde `@@Kapitel` als *Laden* mit dem Namen `@Kapitel` gelesen.

Die Klassifikation ist rekursiv: Innerhalb eines Verzeichnisses einer Klasse können wieder Unterverzeichnisse mit Präfix liegen, z. B. `@/@Wissen/@Content/` (Laden) und `@/@Wissen/@@Kapitel1/` (Verfügbar).

### Vorläufige Regeln der Klassen

Die Detailregeln sind offen (Spec 01, O2). Für v0.1 gilt vorläufig:

| # | Regel |
|---|---|
| K1 | Ein Unterverzeichnis ohne Präfix erbt die Klasse seines übergeordneten Verzeichnisses. |
| K2 | Mit der Ordnung *Laden* < *Verfügbar* < *Verborgen* gilt auf einem Pfad die strengste Klasse: ein `@X` innerhalb von `@!Skill` bleibt verborgen, ein `@@X` innerhalb von `@Wissen` ist verfügbar. |
| K3 | Dateien direkt in `@/` gehören zur Klasse *Laden*. |
| K4 | Berücksichtigt werden nur Dateien mit der Endung `.md`. Andere Dateien (Bilder, PDFs) bleiben liegen und werden nicht geladen. |
| K5 | Die Masterspace-id wird aus `cwd`, den Pfaden und Inhalten aller *geladenen* Dateien und den Pfaden der *verfügbaren* Dateien gebildet (siehe `aios-context --id`). Verborgene Dateien gehen nicht ein. |

### Inhaltsverzeichnis des verfügbaren Teils

Für jede verfügbare Datei der Kette enthält der geladene Kontext eine Zeile mit absolutem Pfad und der ersten Überschrift der Datei:

```
<aios-available>
- /…/§Demo/@/@Wissen/@@Kapitel1/kapitel.md — Kapitel 1: Grundlagen
</aios-available>
```

Ein handgeschriebenes Inhaltsverzeichnis mit der Spalte „Lesen, wenn …" kann zusätzlich als *Laden* abgelegt werden (z. B. `@Wissen/@Content/`) und ist die genauere Hilfe für das Modell.

## CLI `aios-context`

`aios-context` ist das Werkzeug, das die Hooks und die AIOS-Skills aufrufen. `~/bin/aios-context` ist ein Weiterleiter auf die gültige Version (Spec 04). `ai-brain` bleibt unverändert installiert und wird von AIOS nicht verändert.

| Aufruf | Wirkung |
|---|---|
| `aios-context --session` | SessionStart-Hook (liest Hook-JSON von stdin, nimmt dessen `cwd`), siehe *Hooks* |
| `aios-context --advise` | UserPromptSubmit-Hook, siehe *Hooks* |
| `aios-context --context` | gibt den Master-Kontext von `cwd` aus (Format siehe *Ausgabe*) |
| `aios-context --load` | schreibt den Master-Kontext in Part-Dateien unter `~/.aios/cache/<id>/` (je höchstens 40.000 Zeichen) und gibt die Liste aus |
| `aios-context --id` | gibt `id=<id> files=<n> cwd=<cwd> mode=<aios-0.1.0 | legacy | none>` aus |
| `aios-context --list` | Aufstellung für `/aios-context` (siehe dort) |
| `aios-context --sync` | Registrierung der Projekt-Skills (Spec 03, *Registrieren*), mit Vorschau; mit `--yes` ohne Rückfrage |
| `aios-context --agent <name>` | gibt den Kontext eines Agenten aus (Spec 03, *Agenten*) |
| `aios-context --version` | Version des laufenden Programms |
| `aios-context -?`, `--help` | Hilfe |

Außerhalb eines Vaults geben `--session` und `--advise` nichts aus; `--id` meldet `mode=none`.

### Ausgabe

```
<aios-context id="3fa91c02" files="12" cwd="/…/§Demo/Garten" version="0.1.0">
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
| `<aios-context id=… >` … `</aios-context id=…>` | Anfangs- und Endmarke; der Master-Kontext gilt nur als geladen, wenn beide Marken mit derselben id im Kontext stehen |
| `<aios-file class="load" src=…>` | eine geladene Datei mit absolutem Pfad |
| `<aios-available>` | Inhaltsverzeichnis des verfügbaren Teils |

Die Anweisung bei nicht initialisiertem Projekt steht vor dem Master-Kontext:

```
PROJECT-UNINITIALIZED: <cwd> has no local masterspace (@/). Before your first
answer, ask the user: (1) initialize this folder as a project (/aios-init),
(2) continue in the project <X>. Give no other answer until the user decides.
```

## Hooks

`aios --install` trägt in `~/.claude/settings.json` zwei Hooks ein und entfernt dabei die Hooks von `ai-brain` (Spec 04). Beide rufen nur den Weiterleiter auf.

| Hook | Aufruf | Verhalten |
|---|---|---|
| **SessionStart** (Start, Resume, Clear, nach Compaction) | `aios-context --session` | 1. außerhalb eines Vaults: nichts. 2. Legacy-Modus: Verhalten von `ai-brain --session`. 3. aktiviert: Registrierung der Projekt-Skills ohne Rückfrage (`--sync --yes`), bei Änderungen eine Zeile `AIOS-SKILLS: … — wirksam ab dem nächsten Chat` (Spec 03). 4. bei nicht initialisiertem Projekt: `PROJECT-UNINITIALIZED`. 5. Master-Kontext inline, wenn er höchstens `inline_limit` Zeichen hat (Standard 9000), sonst `AIOS-CONTEXT-MANDATORY` mit der Liste der Part-Dateien |
| **UserPromptSubmit** | `aios-context --advise` | außerhalb eines Vaults: nichts. Legacy-Modus: Verhalten von `ai-brain --advise`. Aktiviert: `AIOS-CONTEXT-CHECK: expected id=<id>` mit der Anweisung, bei fehlenden Marken „Lade Master-Kontext" zu sagen, `aios-context --load` auszuführen, alle Part-Dateien vollständig zu lesen und „Master-Kontext geladen (id <id>)" zu melden |

Die Hooks erzeugen außer der Registrierung keine Dateien im Projekt und fragen nie nach.

## Legacy-Modus

Ohne Aktivierung in der Kette verhält sich `aios-context` exakt wie `ai-brain` in der Version, die beim Installieren von AIOS vorlag:

| Aspekt | Legacy-Modus |
|---|---|
| geladen | alle `.md`-Dateien aller `@/` entlang des Pfads, ohne Klassen |
| Marken | `<masterspace id="…">` wie bei `ai-brain` |
| Skills | keine Registrierung |
| Projekt | keine Prüfung auf `@/`, kein `PROJECT-UNINITIALIZED` |
| Skill `/masterspace` | funktioniert weiter |

Damit laufen Vaults, die noch nicht auf AIOS umgestellt sind (z. B. `§AIbex`), unverändert weiter.

## Skill `/aios-context`

AIOS-Skill, Nachfolger von `/masterspace`. Auslöser: `/aios-context`, „Master-Kontext", „was ist geladen?", „Kontext prüfen".

**Ablauf:**

1. `aios-context --id` ausführen.
2. `mode=none`: „Kein Vault — kein Master-Kontext." und beenden. `mode=legacy`: auf `/masterspace` verweisen und beenden.
3. Prüfen, ob beide Marken `<aios-context id="<id>"` und `</aios-context id="<id>">` im Kontext stehen. Erinnerungen, Zusammenfassungen und Hook-Meldungen zählen nicht.
4. Fehlen sie oder steht eine andere id im Kontext: „Master-Kontext veraltet (`<alt>` → `<neu>`)" bzw. „Lade Master-Kontext", `aios-context --load`, alle Part-Dateien vollständig lesen, Endmarke prüfen.
5. `aios-context --list` ausführen und die Aufstellung zeigen.

**Aufstellung:**

```
Master-Kontext geladen (id 3fa91c02, AIOS 0.1.0) — Garten

Kette       §Demo → Garten

Laden       3 Dateien, 4.120 Zeichen
  §Demo/@/@Rule/stil.md
  §Demo/@/@Wissen/@Content/inhalt.md
  …
Verfügbar   1 Datei (Inhaltsverzeichnis geladen)
  §Demo/@/@Wissen/@@Kapitel/kapitel.md
Verborgen   Blueprints: 2 Skills, 1 Agent, 1 Prompt
  Skills    memo 6.0.0 (§Demo) — registriert
            apfel-birnen-algebra (Agent obstgaertner, privat)
  Agenten   obstgaertner (§Demo)
```

Der Skill ändert nichts außer dem Nachladen. Stimmen Blueprints und registrierte Skills nicht überein, weist er auf `/aios-register` hin.
