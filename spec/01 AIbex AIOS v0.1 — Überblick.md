---
title: "AIbex AIOS v0.1 — Überblick"
date: 2026-09-30
author: iHux
status: Spec
tags: [spec, aios, v0.1]
number: 01
related:
  - "Spec 02 Master-Kontext"
  - "Spec 03 Skills und Agenten"
  - "Spec 04 Installation und Konfiguration"
  - "Memo 12 Umfang von AIOS v0.1.0 — Entscheidungen vor der Spec (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
  - "Memo 13 Bestätigte Annahmen für die Spec v0.1 (Konzeptprojekt PAA-AIbex-AIOS-V0.1)"
---

# AIbex AIOS v0.1 — Überblick

## Definition

**AIbex AIOS ist ein Betriebssystem für den Kontext von KI-Assistenten.** Es verwaltet, welches Wissen ein Chat lädt, bei Bedarf liest oder nicht sieht, und stellt dafür Dateisystem-Konventionen, Agenten und Skills bereit. Die Ausführung übernimmt ein Host (in v0.1: Claude Code).

AIOS hat keinen Kernel, kein Scheduling und keine Prozessisolation. Sessions, Modellaufrufe und Werkzeuge stellt der Host bereit. AIOS setzt darauf auf, mit Konventionen im Dateisystem, Hooks, Skills und einem Installer.

| Betriebssystem | AIOS |
|---|---|
| Dateisystem | Vault mit `§`-Wurzel und Verzeichnisbaum |
| Speicherverwaltung | Klassen *Laden* (resident), *Verfügbar* (bei Bedarf eingelesen), *Verborgen* (nicht eingeblendet) |
| Adressraum eines Prozesses | Master-Space-Kette: der Kontext, den ein Chat sieht |
| Programm starten | Chat mit einem Agenten aktivieren |
| Treiber, Pakete | Registrierung der Skills beim Host |
| Boot | SessionStart-Hook |

## Diese Spec

Die Spec v0.1 besteht aus vier Dokumenten, die sich nicht wiederholen:

| Spec | Inhalt |
|---|---|
| **01 Überblick** (dieses Dokument) | Definition, Begriffe, Umfang, Invarianten, Abnahmetest, offene Punkte |
| **02 Master-Kontext** | Projekt und Kette, Klassen, `aios-context`, Hooks, `/aios-context`, Legacy-Modus |
| **03 Skills und Agenten** | Arten von Skills, Versionen, `/aios-deploy`, `/aios-register`, Agenten, `/aios-agent`, `/aios-init`, `/aios-status` |
| **04 Installation und Konfiguration** | Dateistrukturen, Formate, CLI `aios`, Versionen und Aktivierung, Weiterleiter |

Die Begründungen stehen in den Memos 01 bis 15 des Konzeptprojekts `§AIbex/P-Projekte/AI/PA-AIbex-AIOS/PAA-AIbex-AIOS-V0.1/@Memo/`; die Spec beschreibt nur den Soll-Stand. Sie wird im Repo `aibex-aios` unter `spec/` gepflegt und mit jeder Version nach `doc/spec/` ausgeliefert.

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
| **Blueprint** | Beschreibung eines Skills, Prompts oder Agenten in einem verborgenen Verzeichnis (`@!Skill`, `@!Prompt`, `@!Agent`) |
| **Build-Output** | aus Blueprints erzeugte Dateien für den Host (z. B. `.claude/skills/`); nie Quelle, jederzeit neu erzeugbar |
| **AIOS-Skill** | Skill, der zu AIOS selbst gehört (Präfix `aios-`); global registriert |
| **Projekt-Skill** | Skill aus `@!Skill` der Kette, projektlokal registriert |
| **Agent** | Bündel aus Prompt, Skills, Modell, Werkzeugen und eigenem Wissen in `@!Agent/<name>/` |
| **mitgelieferter Skill** | normaler Skill, den AIOS in einer Bibliothek bereitstellt (in v0.1: `memo`) |
| **installierter Skill** | Skill, der über ein Manifest mit Version ausgerollt wurde |
| **lokaler Skill** | Skill, der im Projekt selbst geschrieben wurde und in keinem Manifest steht |
| **Host** | das Programm, das die Session ausführt; in v0.1 nur Claude Code |
| **Installation** | eine AIOS-Version auf dem Rechner, `/opt/aios/v<version>/` |
| **Aktivierung** | Bindung eines Vaults oder Projekts an eine installierte Version (`.aios/config.yaml`) |
| **Legacy-Modus** | Verhalten ohne Aktivierung: wie `ai-brain` |
| **Weiterleiter** | Programm in `~/bin` ohne eigene Logik, das die gültige Version bestimmt und deren Programm aufruft |

## Grundregeln

1. **Der Pfad liefert den Projektkontext, der Agent die Persönlichkeit und die Auswahl von Skills und Wissen.**
2. **Chat-Verzeichnis = Projektverzeichnis.** Innerhalb eines Vaults läuft ein Chat immer in einem Projekt; ein Ordner ohne `@/` wird initialisiert oder verlassen (Spec 02).
3. **Der nächstgelegene Eintrag gewinnt**: bei Blueprints entlang der Kette und bei Schlüsseln der Konfiguration.
4. **Blueprint ist Quelle, Build-Output ist abgeleitet.**
5. **Installieren und Aktivieren sind getrennt**: Installieren betrifft keinen Vault, Aktivieren bindet einen Vault oder ein Projekt.
6. **AIOS ist pro Vault eingeschaltet**: ohne Aktivierung in der Kette gilt der Legacy-Modus.

## Umfang von v0.1

| in v0.1 | nicht in v0.1 |
|---|---|
| Master-Kontext mit drei Klassen, `aios-context`, Legacy-Modus | Module, Distributionen, Modulkatalog |
| AIOS-Skills `/aios-context`, `/aios-init`, `/aios-status`, `/aios-agent`, `/aios-deploy`, `/aios-register` | `/aios-config` |
| Projekt-Skills mit Registrierung beim Session-Start | Abhängigkeiten zwischen Skills |
| Skill-Versionen und Manifest `skills:` | Update-Hinweise für Skills |
| mitgelieferter Skill `memo` | weitere mitgelieferte Skills |
| Agenten ohne Zustand in der Desktop-App | CLI-Launcher mit `--agent`, Werkzeugbeschränkung |
| mehrere installierte Versionen, Aktivierung pro Vault oder Projekt | Mehrbenutzer-Gruppe `aios` |
| `.aios/config.yaml` mit `aios`, `skills`, `hosts` | `distribution`, `mandant`, `beitrag`, `capabilities` |
| macOS und Linux | Windows |
| Host Claude Code | Codex, Hybrid-Betrieb |

## Invarianten

AIOS v0.1 hält diese Regeln in jedem Befehl ein:

| # | Regel |
|---|---|
| I1 | AIOS ändert nie ein bestehendes Memo in `@Memo/`. |
| I2 | AIOS schreibt in einen Masterspace `@/` nur über `/aios-deploy`, und nur nach `@!Skill/<name>/` bzw. `@!Agent/<name>/@!Skill/<name>/`. Ausnahme: `aios --activate` und `/aios-init` legen ein fehlendes, leeres `@/` an. |
| I3 | AIOS registriert nie einen Skill aus einem Masterspace global; global liegen nur AIOS-Skills. |
| I4 | AIOS fasst in Vaults ohne Aktivierung nichts an und verhält sich dort wie `ai-brain`. |
| I5 | AIOS verändert nie eine installierte Version in `/opt/aios/v<version>/`. |
| I6 | AIOS fasst in `.claude/skills/` nur an, was in `.aios/manifest` steht. |
| I7 | Jeder schreibende Befehl zeigt vorher, was er tut, und wartet auf Bestätigung; Ausnahme ist die Registrierung beim Session-Start. |
| I8 | Jeder Befehl ist idempotent: Ein zweiter Aufruf ohne Änderung ändert nichts. |

## Abnahmetest

v0.1 ist fertig, wenn dieser Ablauf auf einem Rechner ohne AIOS gelingt. Jeder Schritt nennt das erwartete Ergebnis.

| # | Schritt | erwartet |
|---|---|---|
| 1 | Repo `aibex-aios` klonen, `./bin/aios --install v0.1.0` | Plan mit Vorbereitung und Installation; nach Ja: `/opt/aios/v0.1.0/`, Weiterleiter in `~/bin`, Hooks und AIOS-Skills in `~/.claude/` |
| 2 | Chat in einem bestehenden Vault ohne Aktivierung (z. B. `§AIbex`) | Master-Kontext wie mit `ai-brain` (Legacy-Modus) |
| 3 | leeres Verzeichnis `§Demo` anlegen, `aios --activate v0.1.0 <§Demo>` | `§Demo/.aios/config.yaml` mit `aios: 0.1.0`, `§Demo/@/` angelegt |
| 4 | `§Demo/@/@Rule/stil.md`, `§Demo/@/@Wissen/@Content/inhalt.md` und `§Demo/@/@Wissen/@@Kapitel/kapitel.md` anlegen | — |
| 5 | Ordner `§Demo/Garten` anlegen, Chat darin öffnen | Hinweis „kein initialisiertes Projekt" mit den Wahlmöglichkeiten initialisieren oder ins Root-Projekt wechseln |
| 6 | Initialisieren wählen | `/aios-init`: `@/`, `@Memo/`, `.gitignore`, `git init`, erster Commit |
| 7 | neuen Chat in `§Demo/Garten` öffnen, `/aios-context` | Master-Kontext mit `stil.md` und `inhalt.md`; `kapitel.md` als verfügbares Wissen gelistet |
| 8 | `/aios-deploy memo==6.0.0` mit Ziel `§Demo` | `§Demo/@/@!Skill/memo/`, `skills: {memo: 6.0.0}` in `§Demo/.aios/config.yaml`, `memo` in `Garten/.claude/skills/` registriert |
| 9 | Agent `obstgaertner` in `§Demo/@/@!Agent/` mit eigenem Wissen und privatem Skill anlegen; `/aios-agent Obstgärtner: Test` | Persönlichkeit, Wissen und Skill des Agenten im Chat, Titel gesetzt |
| 10 | Projekt `§Demo/Sternwarte` mit eigenem Skill in `@/@!Skill/`; Chat in `Garten` | der Skill aus `Sternwarte` ist in `Garten` nicht registriert |
| 11 | Memo schreiben, `/aios-status` | Status mit *Erledigt*, *Offen*, *Zuletzt* |
| 12 | `aios --deactivate <§Demo>` | Chat in `§Demo` wieder im Legacy-Modus |

## Offen

| # | Punkt | vorläufige Festlegung für v0.1 |
|---|---|---|
| O1 | Wirkt `/reload-skills` in einer interaktiven Session auf Skills, die nach dem Start angelegt wurden? | Getestet (Memo 16): Ein beim Session-Start angelegter Skill ist erst im nächsten Chat verfügbar; die Registrierung ist darauf ausgelegt (Spec 03). Offen ist nur `/reload-skills` |
| O2 | Detailregeln der Klassen | siehe Spec 02, *Vorläufige Regeln der Klassen* |
| O3 | neutraler Memo-Skill ohne AIbex-Pfade | Voraussetzung dafür, dass `memo` in die Bibliothek kommt |
