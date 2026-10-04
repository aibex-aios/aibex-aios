---
title: "AIbex AIOS v0.3 — Überblick"
date: 2026-10-03
author: iHux
status: Spec
tags: [spec, aios, v0.3]
number: 01
related:
  - "Spec 02 Master-Kontext"
  - "Spec 03 Skills und Assistenten"
  - "Spec 04 Installation und Konfiguration"
  - "Spec 05 Projekte"
  - "Memo 12 Umfang von AIOS v0.1.0 — Entscheidungen vor der Spec (Konzeptprojekt AAA-AIbex-AIOS-V0.1)"
  - "Memo 13 Umfang von v0.2, Memos 01–12 nach V0.3 (Konzeptprojekt AAA-AIbex-AIOS-V0.2)"
  - "Memo 13 Herkunft der Memos und Begriffe von v0.2 (Konzeptprojekt AAA-AIbex-AIOS-V0.3)"
  - "Memos 22–28 (Konzeptprojekt AAA-AIbex-AIOS-V0.3)"
---

# AIbex AIOS v0.3 — Überblick

## Definition

**AIbex AIOS ist ein Betriebssystem für den Kontext von KI-Assistenten.** Es verwaltet, welches Wissen ein Chat lädt, bei Bedarf liest oder nicht sieht, und stellt dafür Dateisystem-Konventionen, Assistenten und Skills bereit. Die Ausführung übernimmt ein Host (in v0.3: Claude Code).

AIOS hat keinen Kernel, kein Scheduling und keine Prozessisolation. Sessions, Modellaufrufe und Werkzeuge stellt der Host bereit. AIOS setzt darauf auf, mit Konventionen im Dateisystem, Hooks, Skills und einem Installer.

| Betriebssystem | AIOS |
|---|---|
| Dateisystem | Vault mit `§`-Wurzel und Verzeichnisbaum |
| Speicherverwaltung | Klassen *Laden* (resident), *Verfügbar* (bei Bedarf eingelesen), *Verborgen* (nicht eingeblendet) |
| Adressraum eines Prozesses | Master-Space-Kette: der Kontext, den ein Chat sieht |
| Programm starten | Chat mit dem Assistenten des Projekts beginnen |
| Treiber, Pakete | Registrierung der Skills beim Host |
| Boot | SessionStart-Hook |
| Dateisystemprüfung (`fsck`) | Konsistenzprüfung beim Start, `/aios-integrity` |

## Diese Spec

Die Spec v0.3 besteht aus fünf Dokumenten, die sich nicht wiederholen:

| Spec | Inhalt |
|---|---|
| **01 Überblick** (dieses Dokument) | Definition, Begriffe, Umfang, Vorabversionen, Invarianten, Abnahmetest, offene Punkte |
| **02 Master-Kontext** | Projekt und Kette, Klassen, `aios-context`, Hooks (mit Assistent und Konsistenzprüfung), `/aios-context`, Legacy-Modus |
| **03 Skills und Assistenten** | Arten von Skills, Versionen, `/aios-deploy`, `/aios-register`, Assistenten und ihre Zuordnung, `/aios-assistant`, Oberflächen (`/aios-gui`, `/gui`), `/aios-memo` |
| **04 Installation und Konfiguration** | Dateistrukturen, Formate, CLI `aios`, Versionen und Aktivierung, Weiterleiter |
| **05 Projekte** | Struktur und Name eines Projekts, `/aios-init`, Konsistenzprüfung, `/aios-integrity`, `/aios-status` |

Die Begründungen stehen in den Memos der Konzeptprojekte unter `§AIOS/A-AIOS/AA-AIbex-AIOS/`: `AAA-AIbex-AIOS-V0.1/@Memo/` für die Grundlage, `AAA-AIbex-AIOS-V0.2/@Memo/` (Memos 13–18) für die Änderungen in v0.2, `AAA-AIbex-AIOS-V0.3/@Memo/` (Memos 01–28) für die Änderungen in v0.3. In den Memos 01–11 von V0.3 heißt der Assistent noch *Agent* (V0.3, Memo 13). Die Spec beschreibt nur den Soll-Stand. Sie wird im Repo `aibex-aios` unter `spec/` gepflegt und mit jeder Version nach `doc/spec/` ausgeliefert.

## Begriffe

| Begriff | Bedeutung |
|---|---|
| **Vault** | Verzeichnisbaum, dessen Wurzel mit `§` beginnt (z. B. `§Demo`); in der Regel ein Obsidian-Vault |
| **Vault-Root** | das `§`-Verzeichnis selbst |
| **Masterspace** | ein Verzeichnis namens `@`; Container von Unterverzeichnissen je einer Klasse |
| **Projekt** | jeder Ordner mit `@/`, auch die Vault-Root; die Vault-Root mit `@/` ist das **Root-Projekt** |
| **Unterprojekt** | ein Projekt unterhalb eines anderen Projekts, auch durch Container hindurch |
| **Container** | Ordner ohne `@/`; gliedert nur, trägt keinen Kontext bei und hat kein eigenes Repo; eine Vault-Root ohne `@/` ist ebenfalls ein Container |
| **Root-Masterspace** | `@/` der Vault-Root |
| **lokaler Masterspace** | `@/` des Projekts, in dem ein Chat läuft |
| **Master-Space-Kette** | die Masterspaces aller Projekte vom Projekt des Chats aufwärts bis zum Root-Projekt |
| **Master-Kontext** | der geladene Teil der Master-Space-Kette: alles, was beim Chatbeginn in den Kontext des Hosts gelangt, einschließlich des Inhaltsverzeichnisses des verfügbaren Wissens |
| **verfügbares Wissen** | die Dateien der Klasse *Verfügbar* in der Kette; gehört nicht zum Master-Kontext, das Modell liest sie bei Bedarf |
| **Klasse** | *Laden* (`@…`), *Verfügbar* (`@@…`), *Verborgen* (`@!…`); steht im Namen eines Unterverzeichnisses eines Masterspace |
| **Blueprint** | Beschreibung eines Skills, Prompts oder Assistenten in einem verborgenen Verzeichnis (`@!Skill`, `@!Prompt`, `@!Assistant`) |
| **Build-Output** | aus Blueprints erzeugte Dateien für den Host (z. B. `.claude/skills/`); nie Quelle, jederzeit neu erzeugbar |
| **AIOS-Skill** | Skill, der zu AIOS selbst gehört (Präfix `aios-`); global registriert |
| **Alias** | globale, versionsneutrale Hülle mit kurzem Namen, die AIOS ausliefert (in v0.3 nur `/gui`, Spec 03) |
| **Projekt-Skill** | Skill aus `@!Skill` der Kette, projektlokal registriert |
| **Assistent** | eine Rolle, die AIOS dem KI-Assistenten des Hosts gibt: Bündel aus Rollentext, Prompt, Skills, Oberfläche, Wünschen an Modell und Werkzeuge und eigenem Wissen in `@!Assistant/<name>/`. Wie der Host ihn umsetzt, regelt die Abbildung je Host (Spec 03) |
| **Zuordnung** | der Assistent eines Projekts: `assistant:` in `.aios/config.yaml` mit dem Wert `<name>`, `none` oder `inherit` (Spec 03) |
| **Assistent der Session** | der Assistent, mit dem eine Session begonnen hat oder auf den sie mit `/aios-assistant` gewechselt hat; gilt bis zum Ende der Session (Spec 02) |
| **Oberfläche** | Startseite eines Assistenten (`/gui`) bzw. von AIOS (`/aios-gui`): Kacheln mit Text und Prompt, in der Desktop-App als HTML, in der CLI als Menü (Spec 03) |
| **Bibliothek** | was eine AIOS-Version zum Ausrollen bereitstellt: Skills in `skills/<gruppe>/` außer der Gruppe `aios` und Assistenten in `assistants/<gruppe>/` (`aios --library`) |
| **mitgelieferter Skill** | normaler Skill der Bibliothek (in v0.3: `memo`) |
| **Demo-Assistent** | Assistent der Bibliothek zum Ausprobieren und für Tutorials (in v0.3: `gaertner`, `astronom`) |
| **installierter Skill** | Skill, der über ein Manifest mit Version ausgerollt wurde |
| **lokaler Skill** | Skill, der im Projekt selbst geschrieben wurde und in keinem Manifest steht |
| **Struktur eines Projekts** | was ein Projekt nach `aios --init` hat: `@/`, eigenes Repo, `.gitignore`, Ausschluss im Repo darüber (Spec 05) |
| **integer** | ein Projekt, dessen Struktur vollständig und dessen Repo vollständig committet ist (Spec 05) |
| **Host** | das Programm, das die Session ausführt; in v0.3 nur Claude Code |
| **Installation** | eine AIOS-Version auf dem Rechner, `/opt/aios/v<version>/` |
| **Aktivierung** | Bindung eines Vaults oder Projekts an eine installierte Version (`.aios/config.yaml`) |
| **Legacy-Modus** | Verhalten ohne Aktivierung: wie `ai-brain` |
| **Weiterleiter** | Programm in `~/bin` ohne eigene Logik, das die gültige Version bestimmt und deren Programm aufruft |

## Grundregeln

1. **Der Pfad liefert den Projektkontext, der Assistent die Persönlichkeit und die Auswahl von Skills und Wissen.**
2. **Chat-Verzeichnis = Projektverzeichnis.** Innerhalb eines Vaults läuft ein Chat immer in einem Projekt; ein Ordner ohne `@/` wird initialisiert oder verlassen (Spec 02).
3. **Der nächstgelegene Eintrag gewinnt**: bei Blueprints entlang der Kette und bei Schlüsseln der Konfiguration, auch bei der Zuordnung des Assistenten.
4. **Blueprint ist Quelle, Build-Output ist abgeleitet.**
5. **Installieren und Aktivieren sind getrennt**: Installieren betrifft keinen Vault, Aktivieren bindet einen Vault oder ein Projekt.
6. **AIOS ist pro Vault eingeschaltet**: ohne Aktivierung in der Kette gilt der Legacy-Modus.
7. **Jeder Skill und jeder Assistent hat eine Version** (Semver `MAJOR.MINOR.PATCH`, Spec 03).
8. **Der Assistent ist eine Eigenschaft des Projekts**: Er gilt für alle User gleich; es gibt keine persönliche Zuordnung und keine Aktivierung nur für einen Chat (Spec 03).
9. **Jedes Projekt hat ein eigenes Git-Repo**, auch das Root-Projekt und jedes Unterprojekt; das Repo darüber schließt es aus (Spec 05).

## Umfang von v0.3

v0.3 baut auf v0.2 auf und bringt vier Themen: Der Assistent wird dem Projekt **dauerhaft zugeordnet** und vererbt; Projekte werden nach einer festen **Struktur** initialisiert, beim Start auf Lücken geprüft und mit `/aios-integrity` auf Integrität; Assistenten und AIOS bekommen **Oberflächen**; der AIOS-Skill **`/aios-memo`** stellt immer einen Memo-Stil bereit.

| in v0.3 | nicht in v0.3 |
|---|---|
| Master-Kontext mit drei Klassen, `aios-context`, Legacy-Modus | Module, Distributionen, Modulkatalog |
| AIOS-Skills `/aios-context`, `/aios-init`, `/aios-status`, `/aios-assistant`, `/aios-deploy`, `/aios-register`, `/aios-integrity`, `/aios-memo`, `/aios-gui` und der Alias `/gui` | `/aios-config`, weitere Aliase |
| dauerhafte Zuordnung eines Assistenten zum Projekt (`assistant:` mit `<name>`, `none`, `inherit`), Vererbung, Assistent der Session über Compaction und Resume | persönliche Zuordnung, Aktivierung nur für einen Chat, CLI-Launcher, Werkzeugbeschränkung |
| Dialog *Projekt initialisieren*, Namensregel, `aios --init` ergänzt bestehende Projekte, Ausschluss im Repo darüber | Abhängigkeiten zwischen Skills, Update-Hinweise für Skills |
| Konsistenzprüfung beim ersten Start einer Session, `/aios-integrity` über alle Unterprojekte | automatische Reparatur ohne Rückfrage, automatische Commits von Arbeitsständen |
| Oberflächen als Beschreibung mit Kacheln, optional mit HTML-Teilen; eine Startseite je Assistent | mehrere Oberflächen je Assistent, eigene App außerhalb von Claude Code |
| Versionen für jeden Skill und Assistenten, Manifeste `skills:` und `assistants:`; Ausrollen nur getaggter Versionen | Ausrollen von Assistenten aus Pflegeprojekten |
| Bibliothek mit `memo` und den Demo-Assistenten `gaertner` (mit Oberfläche), `astronom` | weitere mitgelieferte Skills |
| mehrere installierte Versionen, Aktivierung pro Vault oder Projekt | Mehrbenutzer-Gruppe `aios` |
| `.aios/config.yaml` mit `aios`, `skills`, `assistants`, `assistant`, `hosts` | `distribution`, `mandant`, `beitrag`, `capabilities` |
| macOS und Linux | Windows |
| Host Claude Code | Codex, Hybrid-Betrieb |
| — | Migration von Vaults aus v0.2, Nebeneinander mit v0.2 im selben Vault; Versionen und Tags der Pflegeprojekte beim Umstieg von `§AIbex` (V0.3, Memo 26) |

## Vorabversionen

Alle Versionen unter 1.0 sind Alpha- und Beta-Versionen; an Kunden wird erst ab v1.0 ausgeliefert. Das gilt für AIOS selbst und für die Skills und Assistenten der Bibliothek, die deshalb mit `0.1.0` beginnen (Ausnahme: `memo` behält seine Versionsfolge, 6.0.0).

Vor v1.0 wird keine Migration zwischen Versionen verlangt: Eine neue Version darf Begriffe, Ordnernamen und Formate ändern, ohne Migrationspfad und ohne Kompatibilitätsmodus. Die Versionsbindung (`aios:` in `.aios/config.yaml`) hält einen Vault auf seiner Version lauffähig. Ein mit v0.2 aktivierter Vault läuft mit v0.2 weiter, bis er mit `aios --activate v0.3.0` umgestellt wird; v0.2 ignoriert den Schlüssel `assistant:` mit Warnung. Migrierbarkeit wird ab v1.0 angestrebt.

## Invarianten

AIOS v0.3 hält diese Regeln in jedem Befehl ein:

| # | Regel |
|---|---|
| I1 | AIOS ändert nie ein bestehendes Memo in `@Memo/`. `/aios-memo` legt nur neue Memos an. |
| I2 | AIOS schreibt in einen Masterspace `@/` nur über `/aios-deploy`, und nur nach `@!Skill/<name>/`, `@!Assistant/<name>/` bzw. `@!Assistant/<name>/@!Skill/<name>/`. Ausnahme: `aios --activate` und `aios --init` legen ein fehlendes `@/` mit `.gitkeep` an. |
| I3 | AIOS registriert nie einen Skill aus einem Masterspace global; global liegen nur AIOS-Skills und der Alias `gui`. |
| I4 | AIOS fasst in Vaults ohne Aktivierung nichts an und verhält sich dort wie `ai-brain`. Einzige Ausnahme ist `aios --activate`, das die Aktivierung schreibt; `aios --deploy`, `aios --init`, `aios --assistant` und die Registrierung brechen ab bzw. tun nichts. |
| I5 | AIOS verändert nie eine installierte Version in `/opt/aios/v<version>/`. |
| I6 | AIOS fasst in `.claude/skills/` nur Ordner an, die in `.aios/manifest` stehen oder die es beim Registrieren neu anlegt; Ordner, die schon da sind und nicht im Manifest stehen, nie. |
| I7 | Jeder schreibende Befehl zeigt vorher, was er tut, und wartet auf Bestätigung. Ausnahmen sind beim Session-Start die Registrierung und der Merker der Session (`~/.aios/sessions/`). Ein Skill holt den Plan mit `--plan`, fragt im Chat und ruft erst nach Ja mit `--yes` auf (Spec 04). Prüfungen (Konsistenzprüfung, `/aios-integrity`) schreiben nie; sie bieten eine Ergänzung nur an. |
| I8 | Jeder Befehl ist idempotent: Ein zweiter Aufruf ohne Änderung ändert nichts. |
| I9 | AIOS committet nur, was es selbst angelegt oder geändert hat: den ersten Commit eines Projekts und den Ausschluss eines Unterprojekts im Repo darüber (Spec 05). Arbeitsstände des Users committet es nie. |

## Abnahmetest

v0.3 ist fertig, wenn dieser Ablauf auf einem Rechner gelingt, auf dem v0.3.1 noch nicht installiert ist. Jeder Schritt nennt das erwartete Ergebnis. Chats laufen in der Desktop-App; wo ein Dialog erwartet wird, gilt in Sessions ohne Fenster die Textform (Spec 02).

| # | Schritt | erwartet |
|---|---|---|
| 1 | Repo `aibex-aios` klonen, `./bin/aios --install v0.3.1` | Plan; nach Ja: `/opt/aios/v0.3.1/`, Weiterleiter in `~/bin`, Hooks und AIOS-Skills in `~/.claude/` (darunter `aios-integrity`, `aios-memo`, `aios-gui`) und der Alias `~/.claude/skills/gui/` |
| 2 | Chat in einem bestehenden Vault ohne Aktivierung (z. B. `§AIbex`) | Master-Kontext wie mit `ai-brain` (Legacy-Modus) |
| 3 | leeres Verzeichnis `§Demo` anlegen, `aios --activate v0.3.1 <§Demo>` | Plan, nach Ja: `§Demo/.aios/config.yaml` mit `aios: 0.3.1`, `§Demo/@/`, `.gitignore`, `git init`, erster Commit; `§Demo` ist das Root-Projekt |
| 4 | `§Demo/@/@Rule/stil.md`, `§Demo/@/@Wissen/@Content/inhalt.md` und `§Demo/@/@Wissen/@@Kapitel/kapitel.md` anlegen und committen | — |
| 5 | Ordner `§Demo/G-Garten` anlegen, Chat darin öffnen, „hi" | Dialog *Projekt initialisieren* mit Titel, Assistent (`inherit`, `none`, …) und den Antworten initialisieren oder ins Projekt `§Demo` wechseln |
| 6 | Titel „Garten", Assistent `inherit`, initialisieren | `G-Garten/@/`, `.gitignore`, eigenes Repo, erster Commit, kein `@Memo/`; in `§Demo/.gitignore` die Zeile `/G-Garten/`, im Repo `§Demo` committet; Chat-Titel „Garten" |
| 7 | neuen Chat in `§Demo/G-Garten` öffnen, `/aios-context` | Master-Kontext mit `stil.md` und `inhalt.md`; `kapitel.md` als verfügbares Wissen; Assistent: keiner (`inherit` ohne Eintrag darüber) |
| 8 | „Halte im Memo fest: Garten angelegt" | `/aios-memo` legt `G-Garten/@Memo/` und `01 Garten angelegt.md` im Stil von `memo==6.0.0` an |
| 9 | `aios --library`; `/aios-deploy memo==6.0.0` mit Ziel `§Demo` | `memo`, `gaertner` und `astronom` mit Versionen gelistet; `§Demo/@/@!Skill/memo/`, `skills: {memo: 6.0.0}`; in einem neuen Chat in `G-Garten` antwortet `/aios-memo` nur mit dem Hinweis, `/memo` zu verwenden |
| 10 | `/aios-deploy gaertner==0.2.0` mit Ziel `§Demo`; im Chat in `§Demo` `/aios-assistant Gärtner: Test` | Plan „project §Demo: no assistant → Gärtner", nach Ja `assistant: gaertner` in `§Demo/.aios/config.yaml`; der Chat ist sofort der Gärtner, Titel „Test" |
| 11 | neuen Chat in `G-Garten`; dann `/compact` | der Chat beginnt als Gärtner („Gärtner aktiv") ohne Aufruf; nach der Compaction ist er weiter der Gärtner |
| 12 | `/gui` in `G-Garten`; `/aios-gui` | Startseite des Gärtners mit Kacheln und dem Apfel-Birnen-Rechner (HTML); AIOS-Oberfläche mit den Kacheln von Spec 03 |
| 13 | Projekt `§Demo/S-Sternwarte` mit `/aios-init` und Assistent `none` anlegen; eigener Skill `@/@!Skill/sterne/` (mit `version: 0.1.0`) und `@/@!Skill/ohne-version/` ohne `version`; `/aios-deploy astronom==0.1.0` mit Ziel `§Demo`; `/aios-assistant Astronom` in `S-Sternwarte` | in `S-Sternwarte`: kein Assistent bis zum Wechsel, danach Astronom; `sterne` registriert (in `G-Garten` nicht), `ohne-version` nicht registriert und als `AIOS-WARNING` gemeldet; `/gui` meldet „The assistant Astronom has no surface" mit Verweis auf `/aios-gui` |
| 14 | Chat A in `G-Garten` offen lassen; in `§Demo` `/aios-assistant Astronom`; in Chat A eine Frage; neuer Chat B in `G-Garten` | Chat A bleibt der Gärtner; Chat B beginnt als Astronom (geerbt); `S-Sternwarte` bleibt beim Astronomen (eigener Eintrag) |
| 15 | `/aios-init` für den Ordner `§Demo/labor neu` | Plan meldet Verstoß gegen die Namensregel; Namensdialog mit Vorschlag `L-Labor-Neu`, eigenem Namen und Abbrechen; mit dem Vorschlag wird `§Demo/L-Labor-Neu` angelegt |
| 16 | in `S-Sternwarte` `.gitignore` löschen und eine Datei ändern; `/aios-integrity` in `§Demo` | Bericht über `§Demo`, `G-Garten`, `S-Sternwarte` und `L-Labor-Neu`, eingerückt; `S-Sternwarte` Init „missing: .gitignore lines: …", Commit mit geänderten und neuen Dateien getrennt; Ergebnis „Result: <n> of 4 projects integer"; Angebot `aios --init` für `S-Sternwarte`; nach Ja ist die Struktur vollständig, die Änderung wird nur genannt |
| 17 | Ordner `§Demo/G-Garten/B-Beet` mit `@/` von Hand anlegen und im Repo `G-Garten` committen; Chat in `B-Beet` öffnen | Konsistenzprüfung meldet `PROJECT-INCOMPLETE` (kein eigenes Repo, kein Ausschluss); nach Ja: eigenes Repo, in `G-Garten` `git rm --cached` und `/B-Beet/` in der `.gitignore`, dort committet |
| 18 | `/aios-status` | Status mit *Erledigt*, *Offen*, *Zuletzt* |
| 19 | `aios --deactivate <§Demo>` | Chat in `§Demo` wieder im Legacy-Modus |

## Offen

| # | Punkt | vorläufige Festlegung für v0.3 |
|---|---|---|
| O1 | Wirkt `/reload-skills` in einer interaktiven Session auf Skills, die nach dem Start angelegt wurden? | Getestet (V0.1, Memo 16): Ein beim Session-Start angelegter Skill ist erst im nächsten Chat verfügbar; die Registrierung ist darauf ausgelegt (Spec 03). Offen ist nur `/reload-skills` |
| O2 | Detailregeln der Klassen | siehe Spec 02, *Vorläufige Regeln der Klassen* |
| O4 | Stehen HTML-Oberflächen im Chat in jeder Installation der Desktop-App bereit? (V0.3, Memo 10, 25, 31) | Geprüft: in der Desktop-App vorhanden, in Headless-Sessions und der CLI nicht. Ohne HTML-Oberfläche zeigen `/gui` und `/aios-gui` das Menü der CLI |
