---
title: "AIbex AIOS v0.4 — Überblick"
date: 2026-10-21
author: iHux
status: Entwurf
tags: [spec, aios, v0.4]
number: 01
related:
  - "Spec 02 Master-Kontext"
  - "Spec 03 Skills und Assistenten"
  - "Spec 04 Installation und Konfiguration"
  - "Spec 05 Projekte"
  - "Spec 06 Pakete und Workspaces"
  - "Memo 12 Umfang von AIOS v0.1.0 — Entscheidungen vor der Spec (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memo 13 Umfang von v0.2, Memos 01–12 nach V0.3 (AA-AIbex-AIOS, @Memo/V0.2)"
  - "Memo 13 Herkunft der Memos und Begriffe von v0.2 (AA-AIbex-AIOS, @Memo/V0.3)"
  - "Memos 22–28 (AA-AIbex-AIOS, @Memo/V0.3)"
  - "Memos 01–15 (AA-AIbex-AIOS, @Memo/V0.4)"
---

# AIbex AIOS v0.4 — Überblick

## Definition

**AIbex AIOS ist ein Betriebssystem für den Kontext von KI-Assistenten.** Es verwaltet, welches Wissen ein Chat lädt, bei Bedarf liest oder nicht sieht, und stellt dafür Dateisystem-Konventionen, Assistenten und Skills bereit. Die Ausführung übernimmt ein Host (in v0.4: Claude Code).

AIOS hat keinen Kernel, kein Scheduling und keine Prozessisolation. Sessions, Modellaufrufe und Werkzeuge stellt der Host bereit. AIOS setzt darauf auf, mit Konventionen im Dateisystem, Hooks, Skills und einem Installer.

| Betriebssystem | AIOS |
|---|---|
| Dateisystem | Vault mit `§`-Wurzel und Verzeichnisbaum |
| Speicherverwaltung | Klassen *Laden* (resident), *Verfügbar* (bei Bedarf eingelesen), *Verborgen* (nicht eingeblendet) |
| Adressraum eines Prozesses | Master-Space-Kette: der Kontext, den ein Chat sieht |
| Programm starten | Chat mit dem Assistenten des Projekts beginnen |
| Treiber | Registrierung der Skills beim Host |
| Paketverwaltung | Pakete und Module aus dem Hub, `aios --deploy` (Spec 06) |
| Boot | SessionStart-Hook |
| Dateisystemprüfung (`fsck`) | Konsistenzprüfung beim Start, `/aios-integrity` |

## Diese Spec

Die Spec v0.4 besteht aus sechs Dokumenten, die sich nicht wiederholen:

| Spec | Inhalt |
|---|---|
| **01 Überblick** (dieses Dokument) | Definition, Begriffe, Umfang, Vorabversionen, Invarianten, Abnahmetest, offene Punkte |
| **02 Master-Kontext** | Projekt und Kette, Klassen, `aios-context`, Hooks (mit Assistent und Konsistenzprüfung), `/aios-context`, Legacy-Modus |
| **03 Skills und Assistenten** | Arten von Skills, Versionen, `/aios-register`, Assistenten und ihre Zuordnung, `/aios-assistant`, Oberflächen (`/aios-gui`, `/gui`), `/aios-memo` |
| **04 Installation und Konfiguration** | Dateistrukturen, Formate, CLI `aios`, Versionen und Aktivierung, Weiterleiter |
| **05 Projekte** | Struktur und Name eines Projekts, `/aios-init`, Konsistenzprüfung, `/aios-integrity`, `/aios-status` |
| **06 Pakete und Workspaces** | Paket-Manifest, Versionen und Bereiche, Hub, Resolver, `/aios-deploy`, Lock, Arbeitspferde, `@Data/`, Workspaces, Rückfluss, Demo-App Taschenrechner |

Die Begründungen stehen in den Memos der Konzeptprojekte unter `§AIOS/A-AIOS/AA-AIbex-AIOS/`: `@Memo/V0.1/` für die Grundlage, `@Memo/V0.2/` (Memos 13–18) für die Änderungen in v0.2, `@Memo/V0.3/` (Memos 01–28) für die Änderungen in v0.3, `@Memo/V0.4/` (Memos 01–15) für die Änderungen in v0.4. In den Memos 01–11 von V0.3 heißt der Assistent noch *Agent* (V0.3, Memo 13). Die Spec beschreibt nur den Soll-Stand. Sie wird im Repo `aibex-aios` unter `spec/` gepflegt und mit jeder Version nach `doc/spec/` ausgeliefert.

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
| **Alias** | globale, versionsneutrale Hülle mit kurzem Namen, die AIOS ausliefert (in v0.4 nur `/gui`, Spec 03) |
| **Projekt-Skill** | Skill aus `@!Skill` der Kette, projektlokal registriert |
| **Assistent** | eine Rolle, die AIOS dem KI-Assistenten des Hosts gibt: Bündel aus Rollentext, Prompt, Skills, Oberfläche, Wünschen an Modell und Werkzeuge und eigenem Wissen in `@!Assistant/<name>/`. Wie der Host ihn umsetzt, regelt die Abbildung je Host (Spec 03) |
| **Zuordnung** | der Assistent eines Projekts: `assistant:` in `.aios/config.yaml` mit dem Wert `<name>`, `none` oder `inherit` (Spec 03) |
| **Assistent der Session** | der Assistent, mit dem eine Session begonnen hat oder auf den sie mit `/aios-assistant` gewechselt hat; gilt bis zum Ende der Session (Spec 02) |
| **Oberfläche** | Startseite eines Assistenten (`/gui`) bzw. von AIOS (`/aios-gui`): Kacheln mit Text und Prompt, in der Desktop-App als HTML, in der CLI als Menü (Spec 03) |
| **Paket** | versionierte Einheit mit `manifest.yaml`, in einem eigenen Repo, Versionen als Tags `v<version>` (Spec 06) |
| **Modul** | Paket, nach dessen Installation AIOS etwas Neues kann (Kernel, App, Assistent, Skill) |
| **App** | Modul, das der Anwender direkt benutzt (Oberfläche, Befehle, Skills) |
| **Distribution** | Paket, das nur andere Pakete mit Versionen auflistet |
| **Hub** | GitHub-Organisation `aibex-aios`: ein Repo je Paket, Index-Repo `aios-index` (`aios --library`) |
| **Anwender-Site** | Vault mit Paketen als Kopie in `@!Package/` |
| **Entwickler-Site** | Workspace mit Paketen als Git-Checkout |
| **Workspace** | Projekt mit `.aios/workspace.yaml`, das Projekte mit Repo, Revision und Pfad nennt (Spec 06) |
| **Lock** | `.aios/lock.yaml`: aufgelöste Pakete und eingefrorener Stand eines Workspace |
| **Demo-Assistent** | Assistent als Paket zum Ausprobieren und für Tutorials (`gaertner`, `astronom`) |
| **installierter Skill** | Skill aus einem installierten Paket in `@!Package/` |
| **lokaler Skill** | Skill, der im Projekt selbst geschrieben wurde (`@!Skill/`) und aus keinem Paket stammt |
| **Struktur eines Projekts** | was ein Projekt nach `aios --init` hat: `@/`, eigenes Repo, `.gitignore`, Ausschluss im Repo darüber (Spec 05) |
| **integer** | ein Projekt, dessen Struktur vollständig und dessen Repo vollständig committet ist (Spec 05) |
| **Host** | das Programm, das die Session ausführt; in v0.4 nur Claude Code |
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
7. **Jedes Paket, jeder Skill und jeder Assistent hat eine Version** (Semver `MAJOR.MINOR.PATCH`, Spec 03, 06).
8. **Der Assistent ist eine Eigenschaft des Projekts**: Er gilt für alle User gleich; es gibt keine persönliche Zuordnung und keine Aktivierung nur für einen Chat (Spec 03).
9. **Jedes Projekt hat ein eigenes Git-Repo**, auch das Root-Projekt und jedes Unterprojekt; das Repo darüber schließt es aus (Spec 05).

## Umfang von v0.4

v0.4 baut auf v0.3 auf und macht AIOS **modular** (Spec 06): Pakete und Module mit Manifest, Versionsbereichen und Resolver, Installation als Kopie aus dem Hub, Workspaces mit Checkouts, ein einfacher Rückfluss zum Hub und die Demo-App Taschenrechner. Dazu kommen die Befunde der Abnahme von v0.3.1 (A4, A5, A10, A11, A13–A16; V0.3, Memos 57–62). Alles aus v0.3, das hier nicht geändert wird, gilt weiter.

| in v0.4 | nicht in v0.4 |
|---|---|
| Pakete mit `manifest.yaml`, Typen, Module, Apps, Distributionen | Wissen als Klassenobjekt, Konsolidieren von Rückflüssen |
| SemVer-Bereiche wie pip, Resolver ohne Backtracking, `lock.yaml` | Backtracking, mehrere Lösungen, Lizenzprüfung |
| Hub `aibex-aios` mit Index `aios-index`, Versionen aus Tags | eigene Registry, Suche, Rechteverwaltung über GitHub hinaus |
| `aios --deploy` als Installer nach `@!Package/`, `--upgrade`, `--remove`, `aios --library` | Hooks aus Paketen (nur gemeldet) |
| Arbeitspferde mit Skripten, nur nach Bestätigung | deklarative Paketmanager (pip, brew) im Manifest |
| Workspaces: `.aios/workspace.yaml`, `aios --workspace init`, `update`, `freeze`, `status`, Gruppen | `import` von Manifesten (nur im Format), `diff`, `forall`, Blobs |
| Rückfluss `aios --contribute` als Pull Request | Workflows (v0.6), `@Chat/` (v0.5) |
| `@Data/` für Daten von Apps, Demo-App Taschenrechner | `camp` statt `stup`, Antwort-Prefix der Demo-Assistenten, `memo` mit Unterordnern |
| `skills:` und `assistants:` gehen in `packages:` auf; `memo`, `gaertner`, `astronom` als Pakete | Bibliothek in der Installation |
| `.aios/registry` statt `.aios/manifest` | Windows, weitere Hosts |
| Befunde A4, A5, A10, A11, A13–A16 aus v0.3.1 | |

## Vorabversionen

Alle Versionen unter 1.0 sind Alpha- und Beta-Versionen; an Kunden wird erst ab v1.0 ausgeliefert. Das gilt für AIOS selbst und für die Pakete der Grundausstattung, die deshalb mit `0.1.0` beginnen (Ausnahme: `memo` behält seine Versionsfolge, 6.0.0).

Vor v1.0 wird keine Migration zwischen Versionen verlangt: Eine neue Version darf Begriffe, Ordnernamen und Formate ändern, ohne Migrationspfad und ohne Kompatibilitätsmodus. Die Versionsbindung (`aios:` in `.aios/config.yaml`) hält einen Vault auf seiner Version lauffähig. Ein mit v0.3 aktivierter Vault läuft mit v0.3 weiter, bis er mit `aios --activate v0.4.<n>` umgestellt wird; die Aktivierung bietet dann an, `skills:` und `assistants:` in `packages:` umzuschreiben (Spec 06, *Umstellung von v0.3*). Migrierbarkeit wird ab v1.0 angestrebt.

## Invarianten

AIOS v0.4 hält diese Regeln in jedem Befehl ein (für Pakete zusätzlich P1–P6, Spec 06):

| # | Regel |
|---|---|
| I1 | AIOS ändert nie ein bestehendes Memo in `@Memo/`. `/aios-memo` legt nur neue Memos an. |
| I2 | AIOS schreibt in einen Masterspace `@/` nur über `/aios-deploy`, und nur nach `@!Package/<name>/`; bei der Umstellung von v0.3 entfernt es dabei Blueprints mit Marke aus `@!Skill/` und `@!Assistant/`. Ausnahme: `aios --activate` und `aios --init` legen ein fehlendes `@/` mit `.gitkeep` an. |
| I3 | AIOS registriert nie einen Skill aus einem Masterspace global; global liegen nur AIOS-Skills und der Alias `gui`. |
| I4 | AIOS fasst in Vaults ohne Aktivierung nichts an und verhält sich dort wie `ai-brain`. Einzige Ausnahme ist `aios --activate`, das die Aktivierung schreibt; `aios --deploy`, `aios --init`, `aios --assistant` und die Registrierung brechen ab bzw. tun nichts. |
| I5 | AIOS verändert nie eine installierte Version in `/opt/aios/v<version>/`. |
| I6 | AIOS fasst in `.claude/skills/` nur Ordner an, die in `.aios/registry` stehen oder die es beim Registrieren neu anlegt; Ordner, die schon da sind und nicht in der Registry stehen, nie. |
| I7 | Jeder schreibende Befehl zeigt vorher, was er tut, und wartet auf Bestätigung. Ausnahmen sind beim Session-Start die Registrierung und der Merker der Session (`~/.aios/sessions/`). Ein Skill holt den Plan mit `--plan`, fragt im Chat und ruft erst nach Ja mit `--yes` auf (Spec 04). Prüfungen (Konsistenzprüfung, `/aios-integrity`) schreiben nie; sie bieten eine Ergänzung nur an. |
| I8 | Jeder Befehl ist idempotent: Ein zweiter Aufruf ohne Änderung ändert nichts. |
| I9 | AIOS committet nur, was es selbst angelegt oder geändert hat: den ersten Commit eines Projekts und den Ausschluss eines Unterprojekts im Repo darüber (Spec 05, Spec 06 *Workspaces*), dazu mit `aios --contribute` die genannten Dateien in einem eigenen Zweig eines Paket-Repos (Spec 06). Arbeitsstände des Users committet es nie. |

## Abnahmetest

Der Abnahmetest von v0.4 wird mit dem Implementierungsplan festgelegt (V0.4, Memo 05). Er deckt mindestens ab: Installation eines Pakets mit Abhängigkeit aus einem Test-Hub (`AIOS_HUB`), Abgleich auf einem zweiten Projekt nach `git pull`, `--upgrade` und `--remove`, Umstellung eines v0.3-Vaults, Taschenrechner mit Kachel, Speichern und Rückfluss, Workspace mit `init`, `update`, `freeze`, `status` und `aios --integrity`, die Befunde aus v0.3.1. Der Abnahmetest von v0.3 steht in dieser Spec im Tag `v0.3.1`.

## Offen

| # | Punkt | vorläufige Festlegung für v0.4 |
|---|---|---|
| O1 | Wirkt `/reload-skills` in einer interaktiven Session auf Skills, die nach dem Start angelegt wurden? | Getestet (V0.1, Memo 16): Ein beim Session-Start angelegter Skill ist erst im nächsten Chat verfügbar; die Registrierung ist darauf ausgelegt (Spec 03). Offen ist nur `/reload-skills` |
| O2 | Detailregeln der Klassen | siehe Spec 02, *Vorläufige Regeln der Klassen* |
| O4 | Stehen HTML-Oberflächen im Chat in jeder Installation der Desktop-App bereit? (V0.3, Memo 10, 25, 31) | Geprüft: in der Desktop-App vorhanden, in Headless-Sessions und der CLI nicht. Ohne HTML-Oberfläche zeigen `/gui` und `/aios-gui` das Menü der CLI |
| O5 | Abnahmetest von v0.4 | wird mit dem Implementierungsplan festgelegt |
