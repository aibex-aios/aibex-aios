---
title: "AIbex AIOS v0.2 — Überblick"
date: 2026-10-01
author: iHux
status: Spec
tags: [spec, aios, v0.2]
number: 01
related:
  - "Spec 02 Master-Kontext"
  - "Spec 03 Skills und Assistenten"
  - "Spec 04 Installation und Konfiguration"
  - "Memo 12 Umfang von AIOS v0.1.0 — Entscheidungen vor der Spec (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 13 Bestätigte Annahmen für die Spec v0.1 (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 13 Umfang von v0.2, Memos 01–12 nach V0.3 (Konzeptprojekt PAA-AIbex-AIOS-V0.2)"
  - "Memo 18 Keine Installationen von v0.1 (Konzeptprojekt PAA-AIbex-AIOS-V0.2)"
---

# AIbex AIOS v0.2 — Überblick

## Definition

**AIbex AIOS ist ein Betriebssystem für den Kontext von KI-Assistenten.** Es verwaltet, welches Wissen ein Chat lädt, bei Bedarf liest oder nicht sieht, und stellt dafür Dateisystem-Konventionen, Assistenten und Skills bereit. Die Ausführung übernimmt ein Host (in v0.2: Claude Code).

AIOS hat keinen Kernel, kein Scheduling und keine Prozessisolation. Sessions, Modellaufrufe und Werkzeuge stellt der Host bereit. AIOS setzt darauf auf, mit Konventionen im Dateisystem, Hooks, Skills und einem Installer.

| Betriebssystem | AIOS |
|---|---|
| Dateisystem | Vault mit `§`-Wurzel und Verzeichnisbaum |
| Speicherverwaltung | Klassen *Laden* (resident), *Verfügbar* (bei Bedarf eingelesen), *Verborgen* (nicht eingeblendet) |
| Adressraum eines Prozesses | Master-Space-Kette: der Kontext, den ein Chat sieht |
| Programm starten | Chat mit einem Assistenten aktivieren |
| Treiber, Pakete | Registrierung der Skills beim Host |
| Boot | SessionStart-Hook |

## Diese Spec

Die Spec v0.2 besteht aus vier Dokumenten, die sich nicht wiederholen:

| Spec | Inhalt |
|---|---|
| **01 Überblick** (dieses Dokument) | Definition, Begriffe, Umfang, Vorabversionen, Invarianten, Abnahmetest, offene Punkte |
| **02 Master-Kontext** | Projekt und Kette, Klassen, `aios-context`, Hooks, `/aios-context`, Legacy-Modus |
| **03 Skills und Assistenten** | Arten von Skills, Versionen, `/aios-deploy`, `/aios-register`, Assistenten, `/aios-assistant`, `/aios-init`, `/aios-status` |
| **04 Installation und Konfiguration** | Dateistrukturen, Formate, CLI `aios`, Versionen und Aktivierung, Weiterleiter |

Die Begründungen stehen in den Memos der Konzeptprojekte unter `§AIbex/P-Projekte/AI/PA-AIbex-AIOS/`: `PAA-AIbex-AIOS-V0.1/@Memo/` für die Grundlage, `PAA-AIbex-AIOS-V0.2/@Memo/` (Memos 13–18) für die Änderungen in v0.2. Die Spec beschreibt nur den Soll-Stand. Sie wird im Repo `aibex-aios` unter `spec/` gepflegt und mit jeder Version nach `doc/spec/` ausgeliefert.

## Begriffe

| Begriff | Bedeutung |
|---|---|
| **Vault** | Verzeichnisbaum, dessen Wurzel mit `§` beginnt (z. B. `§Demo`); in der Regel ein Obsidian-Vault |
| **Vault-Root** | das `§`-Verzeichnis selbst |
| **Masterspace** | ein Verzeichnis namens `@`; Container von Unterverzeichnissen je einer Klasse |
| **Projekt** | jeder Ordner mit `@/`; die Vault-Root ist das **Root-Projekt**; Projekte können Unterprojekte enthalten |
| **Container** | Ordner ohne `@/`; gliedert nur, trägt keinen Kontext bei |
| **Root-Masterspace** | `@/` der Vault-Root |
| **lokaler Masterspace** | `@/` des Projekts, in dem ein Chat läuft |
| **Master-Space-Kette** | die Masterspaces aller Projekte vom Projekt des Chats aufwärts bis zum Root-Projekt |
| **Master-Kontext** | der geladene Teil der Master-Space-Kette: alles, was beim Chatbeginn in den Kontext des Hosts gelangt, einschließlich des Inhaltsverzeichnisses des verfügbaren Wissens |
| **verfügbares Wissen** | die Dateien der Klasse *Verfügbar* in der Kette; gehört nicht zum Master-Kontext, das Modell liest sie bei Bedarf |
| **Klasse** | *Laden* (`@…`), *Verfügbar* (`@@…`), *Verborgen* (`@!…`); steht im Namen eines Unterverzeichnisses eines Masterspace |
| **Blueprint** | Beschreibung eines Skills, Prompts oder Assistenten in einem verborgenen Verzeichnis (`@!Skill`, `@!Prompt`, `@!Assistant`) |
| **Build-Output** | aus Blueprints erzeugte Dateien für den Host (z. B. `.claude/skills/`); nie Quelle, jederzeit neu erzeugbar |
| **AIOS-Skill** | Skill, der zu AIOS selbst gehört (Präfix `aios-`); global registriert |
| **Projekt-Skill** | Skill aus `@!Skill` der Kette, projektlokal registriert |
| **Assistent** | eine Rolle, die AIOS dem KI-Assistenten des Hosts gibt: Bündel aus Rollentext, Prompt, Skills, Wünschen an Modell und Werkzeuge und eigenem Wissen in `@!Assistant/<name>/`. Wie der Host ihn umsetzt, regelt die Abbildung je Host (Spec 03) |
| **Bibliothek** | was eine AIOS-Version zum Ausrollen bereitstellt: Skills in `skills/<gruppe>/` außer der Gruppe `aios` und Assistenten in `assistants/<gruppe>/` (`aios --library`) |
| **mitgelieferter Skill** | normaler Skill der Bibliothek (in v0.2: `memo`) |
| **Demo-Assistent** | Assistent der Bibliothek zum Ausprobieren und für Tutorials (in v0.2: `gaertner`, `astronom`) |
| **installierter Skill** | Skill, der über ein Manifest mit Version ausgerollt wurde |
| **lokaler Skill** | Skill, der im Projekt selbst geschrieben wurde und in keinem Manifest steht |
| **Host** | das Programm, das die Session ausführt; in v0.2 nur Claude Code |
| **Installation** | eine AIOS-Version auf dem Rechner, `/opt/aios/v<version>/` |
| **Aktivierung** | Bindung eines Vaults oder Projekts an eine installierte Version (`.aios/config.yaml`) |
| **Legacy-Modus** | Verhalten ohne Aktivierung: wie `ai-brain` |
| **Weiterleiter** | Programm in `~/bin` ohne eigene Logik, das die gültige Version bestimmt und deren Programm aufruft |

## Grundregeln

1. **Der Pfad liefert den Projektkontext, der Assistent die Persönlichkeit und die Auswahl von Skills und Wissen.**
2. **Chat-Verzeichnis = Projektverzeichnis.** Innerhalb eines Vaults läuft ein Chat immer in einem Projekt; ein Ordner ohne `@/` wird initialisiert oder verlassen (Spec 02).
3. **Der nächstgelegene Eintrag gewinnt**: bei Blueprints entlang der Kette und bei Schlüsseln der Konfiguration.
4. **Blueprint ist Quelle, Build-Output ist abgeleitet.**
5. **Installieren und Aktivieren sind getrennt**: Installieren betrifft keinen Vault, Aktivieren bindet einen Vault oder ein Projekt.
6. **AIOS ist pro Vault eingeschaltet**: ohne Aktivierung in der Kette gilt der Legacy-Modus.
7. **Jeder Skill und jeder Assistent hat eine Version** (Semver `MAJOR.MINOR.PATCH`, Spec 03).

## Umfang von v0.2

v0.2 baut auf v0.1 auf und ändert drei Dinge: Der Agent heißt jetzt **Assistent** (Schlüsselwörter `assistant`), jeder Skill braucht eine **Version**, und die Bibliothek liefert die **Demo-Assistenten** `gaertner` und `astronom` mit.

| in v0.2 | nicht in v0.2 |
|---|---|
| Master-Kontext mit drei Klassen, `aios-context`, Legacy-Modus | Module, Distributionen, Modulkatalog |
| AIOS-Skills `/aios-context`, `/aios-init`, `/aios-status`, `/aios-assistant`, `/aios-deploy`, `/aios-register` | `/aios-config`, `/aios-gui` |
| Projekt-Skills mit Registrierung beim Session-Start | Abhängigkeiten zwischen Skills |
| Versionen für jeden Skill und Assistenten, Manifeste `skills:` und `assistants:` | Update-Hinweise für Skills |
| Bibliothek mit `memo` und den Demo-Assistenten `gaertner`, `astronom` | weitere mitgelieferte Skills, Ausrollen von Assistenten aus Pflegeprojekten |
| Assistenten ohne Zustand in der Desktop-App | dauerhafte Zuordnung eines Assistenten zum Projekt (v0.3), CLI-Launcher, Werkzeugbeschränkung |
| mehrere installierte Versionen, Aktivierung pro Vault oder Projekt | Mehrbenutzer-Gruppe `aios` |
| `.aios/config.yaml` mit `aios`, `skills`, `assistants`, `hosts` | `distribution`, `mandant`, `beitrag`, `capabilities` |
| macOS und Linux | Windows |
| Host Claude Code | Codex, Hybrid-Betrieb |
| — | Migration von Vaults aus v0.1, Nebeneinander mit v0.1 |

## Vorabversionen

Alle Versionen unter 1.0 sind Alpha- und Beta-Versionen; an Kunden wird erst ab v1.0 ausgeliefert. Das gilt für AIOS selbst und für die Skills und Assistenten der Bibliothek, die deshalb mit `0.1.0` beginnen (Ausnahme: `memo` behält seine Versionsfolge, 6.0.0).

Vor v1.0 wird keine Migration zwischen Versionen verlangt: Eine neue Version darf Begriffe, Ordnernamen und Formate ändern, ohne Migrationspfad und ohne Kompatibilitätsmodus. Die Versionsbindung (`aios:` in `.aios/config.yaml`) hält einen Vault auf seiner Version lauffähig. v0.2 kennt deshalb weder `@!Agent/` noch `AGENT.md` noch `/aios-agent`; ein Ordner `@!Agent/` ist für v0.2 ein gewöhnlicher verborgener Ordner. Migrierbarkeit wird ab v1.0 angestrebt.

## Invarianten

AIOS v0.2 hält diese Regeln in jedem Befehl ein:

| # | Regel |
|---|---|
| I1 | AIOS ändert nie ein bestehendes Memo in `@Memo/`. |
| I2 | AIOS schreibt in einen Masterspace `@/` nur über `/aios-deploy`, und nur nach `@!Skill/<name>/`, `@!Assistant/<name>/` bzw. `@!Assistant/<name>/@!Skill/<name>/`. Ausnahme: `aios --activate` und `/aios-init` legen ein fehlendes, leeres `@/` an. |
| I3 | AIOS registriert nie einen Skill aus einem Masterspace global; global liegen nur AIOS-Skills. |
| I4 | AIOS fasst in Vaults ohne Aktivierung nichts an und verhält sich dort wie `ai-brain`. Einzige Ausnahme ist `aios --activate`, das die Aktivierung schreibt; `aios --deploy`, `aios --init` und die Registrierung brechen ab bzw. tun nichts. |
| I5 | AIOS verändert nie eine installierte Version in `/opt/aios/v<version>/`. |
| I6 | AIOS fasst in `.claude/skills/` nur Ordner an, die in `.aios/manifest` stehen oder die es beim Registrieren neu anlegt; Ordner, die schon da sind und nicht im Manifest stehen, nie. |
| I7 | Jeder schreibende Befehl zeigt vorher, was er tut, und wartet auf Bestätigung; Ausnahme ist die Registrierung beim Session-Start. Ein Skill holt den Plan mit `--plan`, fragt im Chat und ruft erst nach Ja mit `--yes` auf (Spec 04). |
| I8 | Jeder Befehl ist idempotent: Ein zweiter Aufruf ohne Änderung ändert nichts. |

## Abnahmetest

v0.2 ist fertig, wenn dieser Ablauf auf einem Rechner ohne AIOS gelingt. Jeder Schritt nennt das erwartete Ergebnis.

| # | Schritt | erwartet |
|---|---|---|
| 1 | Repo `aibex-aios` klonen, `./bin/aios --install v0.2.0` | Plan mit Vorbereitung und Installation; nach Ja: `/opt/aios/v0.2.0/`, Weiterleiter in `~/bin`, Hooks und AIOS-Skills in `~/.claude/` (darunter `aios-assistant`, kein `aios-agent`) |
| 2 | Chat in einem bestehenden Vault ohne Aktivierung (z. B. `§AIbex`) | Master-Kontext wie mit `ai-brain` (Legacy-Modus) |
| 3 | leeres Verzeichnis `§Demo` anlegen, `aios --activate v0.2.0 <§Demo>` | `§Demo/.aios/config.yaml` mit `aios: 0.2.0`, `§Demo/@/` angelegt |
| 4 | `§Demo/@/@Rule/stil.md`, `§Demo/@/@Wissen/@Content/inhalt.md` und `§Demo/@/@Wissen/@@Kapitel/kapitel.md` anlegen | — |
| 5 | Ordner `§Demo/Garten` anlegen, Chat darin öffnen | Hinweis „kein initialisiertes Projekt" mit den Wahlmöglichkeiten initialisieren oder ins Root-Projekt wechseln |
| 6 | Initialisieren wählen | `/aios-init`: `@/`, `@Memo/`, `.gitignore`, `git init`, erster Commit |
| 7 | neuen Chat in `§Demo/Garten` öffnen, `/aios-context` | Master-Kontext mit `stil.md` und `inhalt.md`; `kapitel.md` als verfügbares Wissen gelistet |
| 8 | `aios --library`; `/aios-deploy memo==6.0.0` mit Ziel `§Demo` | `memo`, `gaertner` und `astronom` mit Versionen gelistet; `§Demo/@/@!Skill/memo/`, `skills: {memo: 6.0.0}` in `§Demo/.aios/config.yaml`, `memo` in `Garten/.claude/skills/` registriert |
| 9 | `/aios-deploy gaertner==0.1.0` mit Ziel `§Demo`; `/aios-assistant Gärtner: Test` | `§Demo/@/@!Assistant/gaertner/` mit Marke, `assistants: {gaertner: 0.1.0}`; Persönlichkeit, Wissen und Skill `apfel-birnen-algebra` des Gärtners im Chat, Titel gesetzt; eine Sonne-Mond-Aufgabe lehnt er ab |
| 10 | Projekt `§Demo/Sternwarte` mit eigenem Skill `@/@!Skill/sterne/` (mit `version: 0.1.0`) und einem Skill `@/@!Skill/ohne-version/` ohne `version`; `/aios-deploy astronom==0.1.0` mit Ziel `Sternwarte`; Chat in `Sternwarte`, dann in `Garten` | in `Sternwarte`: `sterne` registriert, `ohne-version` nicht registriert und als `AIOS-WARNING` gemeldet, `/aios-assistant Astronom` aktiv; in `Garten`: `sterne` nicht registriert, `/aios-assistant Astronom` findet keinen Assistenten und listet den Gärtner |
| 11 | Memo schreiben, `/aios-status` | Status mit *Erledigt*, *Offen*, *Zuletzt* |
| 12 | `aios --deactivate <§Demo>` | Chat in `§Demo` wieder im Legacy-Modus |

## Offen

| # | Punkt | vorläufige Festlegung für v0.2 |
|---|---|---|
| O1 | Wirkt `/reload-skills` in einer interaktiven Session auf Skills, die nach dem Start angelegt wurden? | Getestet (V0.1, Memo 16): Ein beim Session-Start angelegter Skill ist erst im nächsten Chat verfügbar; die Registrierung ist darauf ausgelegt (Spec 03). Offen ist nur `/reload-skills` |
| O2 | Detailregeln der Klassen | siehe Spec 02, *Vorläufige Regeln der Klassen* |
