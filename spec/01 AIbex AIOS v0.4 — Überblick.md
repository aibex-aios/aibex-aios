---
title: "AIbex AIOS v0.4 — Überblick"
date: 2026-10-21
author: iHux
status: Spec
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
  - "Memos 01–29 (AA-AIbex-AIOS, @Memo/V0.4)"
---

# AIbex AIOS v0.4 — Überblick

## Definition

**AIbex AIOS ist ein Betriebssystem für den Kontext von KI-Assistenten.** Es verwaltet, welches Wissen ein Chat lädt, bei Bedarf liest oder nicht sieht, und stellt dafür Dateisystem-Konventionen, Assistenten und Skills bereit. Die Ausführung übernimmt ein Host (in v0.4: Claude Code).

AIOS hat keinen Kernel im Sinne eines Betriebssystems, kein Scheduling und keine Prozessisolation. Sessions, Modellaufrufe und Werkzeuge stellt der Host bereit. AIOS setzt darauf auf, mit Konventionen im Dateisystem, Hooks, Skills und einem Installer. *Kernel* heißt in AIOS das Grundpaket `aios` mit CLI, Hooks und AIOS-Skills (Spec 04, 06).

| Betriebssystem | AIOS |
|---|---|
| Dateisystem | Vault mit `§`-Wurzel und Verzeichnisbaum |
| Speicherverwaltung | Klassen *Laden* (resident), *Verfügbar* (bei Bedarf eingelesen), *Verborgen* (nicht eingeblendet) |
| Adressraum eines Prozesses | Master-Space-Kette: der Kontext, den ein Chat sieht |
| Programm starten | Chat mit dem Assistenten des Projekts beginnen |
| Treiber | Registrierung der Skills beim Host |
| Paketverwaltung | Pakete aus Hubs holen und ausrollen, `/aios-package` (Spec 06) |
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
| **06 Pakete und Workspaces** | Paket-Manifest, Versionen und Bereiche, Hubs und Hub-Liste, Resolver, holen (`aios --fetch`), ausrollen (`aios --deploy`), Lock, Arbeitspferde, `@Data/`, Workspaces, Rückfluss, Demo-App Taschenrechner |

Die Begründungen stehen in den Memos der Konzeptprojekte unter `§AIOS/A-AIOS/AA-AIbex-AIOS/`: `@Memo/V0.1/` für die Grundlage, `@Memo/V0.2/` (Memos 13–18) für die Änderungen in v0.2, `@Memo/V0.3/` (Memos 01–28) für die Änderungen in v0.3, `@Memo/V0.4/` (Memos 01–29) für die Änderungen in v0.4. In den Memos 01–11 von V0.3 heißt der Assistent noch *Agent* (V0.3, Memo 13). Die Spec beschreibt nur den Soll-Stand. Sie wird im Repo `aibex-aios` unter `spec/` gepflegt und mit jeder Version nach `doc/spec/` ausgeliefert.

## Begriffe

| Begriff | Bedeutung |
|---|---|
| **Vault** | Verzeichnisbaum, dessen Wurzel mit `§` beginnt (z. B. `§Demo`); in der Regel ein Obsidian-Vault |
| **Vault-Root** | das `§`-Verzeichnis selbst |
| **Masterspace** | ein Verzeichnis namens `@`; Container von Unterverzeichnissen je einer Klasse |
| **Projekt** | jeder Ordner mit `@/`, auch die Vault-Root; die Vault-Root mit `@/` ist das **Root-Projekt** |
| **Unterprojekt** | ein Projekt unterhalb eines anderen Projekts, auch durch Container hindurch |
| **Container** | Ordner ohne `@/`; gliedert nur, trägt keinen Kontext bei und hat kein eigenes Repo; eine Vault-Root ohne `@/` ist ebenfalls ein Container. Ausnahme ist ein Fremd-Repo |
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
| **Paket** | versionierte Einheit mit `manifest.yaml`, in einem eigenen Repo eines Hubs, Versionen als Tags `v<version>` (Spec 06) |
| **Element** | Teil eines Pakets, der in einem Projekt wirkt: Skill, Assistent, Wissen, Befehl |
| **Kernel** | das Grundpaket `aios` mit CLI, Hooks und AIOS-Skills; wird installiert, nicht geholt (Spec 04) |
| **Modul** | Paket, nach dessen Holen AIOS etwas Neues kann (Kernel, App, Assistent, Skill) |
| **App** | Modul, das der Anwender direkt benutzt (Oberfläche, Befehle, Skills) |
| **Distribution** | Paket, das nur andere Pakete mit Versionen auflistet |
| **Hub** | Ort mit Paket-Repos: Name und Basis-URL; bei GitHub ist der Name der Owner (z. B. `aibex-aios`). Ein Paket liegt dort als Repo `<basis>/<paket>`, voller Paketname `<hub>/<paket>` (Spec 06) |
| **Hub-Liste** | die Hubs, in denen AIOS einen Paketnamen ohne Hub sucht, in Suchreihenfolge (`hubs:`, Spec 04, 06) |
| **holen** (fetch) | eine Version eines Pakets ganz vom Hub nach `@!Package/` eines Projekts bringen (`aios --fetch`) |
| **ausrollen** (deploy) | festlegen, welche Elemente eines geholten Pakets im Projekt wirken (`aios --deploy`) |
| **registrieren** | ausgerollte Skills dem Host bekannt machen (`.claude/skills/`, Spec 03) |
| **Anwender-Site** | Vault mit Paketen als Kopie in `@!Package/` |
| **Entwickler-Site** | Workspace mit Paketen als Git-Checkout |
| **Workspace** | Projekt mit `.aios/workspace.yaml`, das Repos mit Revision und Pfad nennt (Spec 06) |
| **Fremd-Repo** | Repo eines Workspace ohne `@/`, z. B. ein Paket-Repo; kein Projekt und kein Container (Spec 06) |
| **Lock** | `.aios/lock.yaml`: aufgelöste Pakete und eingefrorener Stand eines Workspace |
| **Demo-Assistent** | Assistent als Paket zum Ausprobieren und für Tutorials (`assistent-gaertner`, `assistent-astronom`) |
| **Paket-Skill** | ausgerollter Skill aus einem geholten Paket in `@!Package/` |
| **lokaler Skill** | Skill, der im Projekt selbst geschrieben wurde (`@!Skill/`) und aus keinem Paket stammt |
| **Struktur eines Projekts** | was ein Projekt nach `aios --init` hat: `@/`, eigenes Repo, `.gitignore`, Ausschluss im Repo darüber (Spec 05) |
| **integer** | ein Projekt, dessen Struktur vollständig und dessen Repo vollständig committet ist (Spec 05) |
| **Host** | das Programm, das die Session ausführt; in v0.4 nur Claude Code |
| **Installation** | eine AIOS-Version (Kernel) auf dem Rechner, `/opt/aios/v<version>/`; *installieren* gilt nur für den Kernel |
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

v0.4 baut auf v0.3 auf und macht AIOS **modular** (Spec 06): Pakete und Module mit Manifest, Versionsbereichen und Resolver, Holen aus Hubs und Ausrollen ihrer Elemente, Workspaces mit Checkouts, ein einfacher Rückfluss zum Hub und die Demo-App Taschenrechner. Dazu kommen die Befunde der Abnahme von v0.3.1 (A4, A5, A10, A11, A13–A16; V0.3, Memos 57–62). Alles aus v0.3, das hier nicht geändert wird, gilt weiter.

| in v0.4 | nicht in v0.4 |
|---|---|
| Pakete mit `manifest.yaml`, Typen, Module, Apps, Distributionen | Wissen als Klassenobjekt, Konsolidieren von Rückflüssen |
| SemVer-Bereiche wie pip, Resolver ohne Backtracking, `lock.yaml` | Backtracking, mehrere Lösungen, Lizenzprüfung |
| Hubs und Hub-Liste (`hubs:`, `aios --hubs`), Standard-Hub `aibex-aios`, optionaler Index, Versionen aus Tags | eigene Registry, Signaturen, Rechteverwaltung über GitHub hinaus |
| `aios --fetch` nach `@!Package/` mit `--upgrade`, `--remove`, `--from`; `aios --deploy` mit `only`; `aios --library`; Skills `/aios-package`, `/aios-fetch`, `/aios-deploy` | Hooks aus Paketen (nur gemeldet) |
| Arbeitspferde mit Skripten, nur nach Bestätigung | deklarative Paketmanager (pip, brew) im Manifest |
| Workspaces: `.aios/workspace.yaml`, `aios --workspace init`, `update`, `freeze`, `status`, Gruppen | `import` von Manifesten (nur im Format), `diff`, `forall`, Blobs |
| Rückfluss `aios --contribute` als Pull Request | Workflows (v0.6), `@Chat/` (v0.5) |
| `@Data/` für Daten von Apps, Demo-App Taschenrechner, Kachel *Apps* in `/aios-gui` | `camp` statt `stup`, Antwort-Prefix der Demo-Assistenten, `memo` mit Unterordnern |
| `skills:` und `assistants:` gehen in `packages:` auf; `skill-memo`, `assistent-gaertner`, `assistent-astronom`, `app-taschenrechner` als Pakete (Namen `<art>-<name>`, V0.4, Memo 43); Testpakete `knowledge-orion`, `knowledge-scorpio` | Bibliothek in der Installation, Paket `toolbox` (v0.4.1) |
| `.aios/registry` statt `.aios/manifest` | Windows, weitere Hosts |
| Befunde A4, A5, A10, A11, A13–A16 aus v0.3.1 | |

## Vorabversionen

Alle Versionen unter 1.0 sind Alpha- und Beta-Versionen; an Kunden wird erst ab v1.0 ausgeliefert. Das gilt für AIOS selbst und für die Pakete der Grundausstattung, die deshalb mit `0.1.0` beginnen (Ausnahme: `memo` behält seine Versionsfolge, 6.0.0).

Vor v1.0 wird keine Migration zwischen Versionen verlangt: Eine neue Version darf Begriffe, Ordnernamen und Formate ändern, ohne Migrationspfad und ohne Kompatibilitätsmodus. Die Versionsbindung (`aios:` in `.aios/config.yaml`) hält einen Vault auf seiner Version lauffähig. Ein mit v0.3 aktivierter Vault läuft mit v0.3 weiter, bis er mit `aios --activate v0.4.<n>` umgestellt wird; die Aktivierung bietet dann an, `skills:` und `assistants:` in `packages:` umzuschreiben (Spec 06, *Umstellung von v0.3*). Migrierbarkeit wird ab v1.0 angestrebt.

## Invarianten

AIOS v0.4 hält diese Regeln in jedem Befehl ein (für Pakete zusätzlich P1–P7, Spec 06):

| # | Regel |
|---|---|
| I1 | AIOS ändert nie ein bestehendes Memo in `@Memo/`. `/aios-memo` legt nur neue Memos an. |
| I2 | AIOS schreibt in einen Masterspace `@/` nur mit `aios --fetch`, und nur nach `@!Package/<name>/`. Ausnahmen: `aios --activate` und `aios --init` legen ein fehlendes `@/` mit `.gitkeep` an; `aios --activate v0.4.<n>` ersetzt bei der Umstellung von v0.3 Blueprints mit Marke in `@!Skill/` und `@!Assistant/` durch geholte Pakete (Spec 06). |
| I3 | AIOS registriert nie einen Skill aus einem Masterspace global; global liegen nur AIOS-Skills und der Alias `gui`. |
| I4 | AIOS fasst in Vaults ohne Aktivierung nichts an und verhält sich dort wie `ai-brain`. Einzige Ausnahme ist `aios --activate`, das die Aktivierung schreibt; `aios --fetch`, `aios --deploy`, `aios --workspace`, `aios --init`, `aios --assistant` und die Registrierung brechen ab bzw. tun nichts. |
| I5 | AIOS verändert nie eine installierte Version in `/opt/aios/v<version>/`. |
| I6 | AIOS fasst in `.claude/skills/` nur Ordner an, die in `.aios/registry` stehen oder die es beim Registrieren neu anlegt; Ordner, die schon da sind und nicht in der Registry stehen, nie. |
| I7 | Jeder schreibende Befehl zeigt vorher, was er tut, und wartet auf Bestätigung. Ausnahmen sind beim Session-Start die Registrierung und der Merker der Session (`~/.aios/sessions/`). Ein Skill holt den Plan mit `--plan`, fragt im Chat und ruft erst nach Ja mit `--yes` auf (Spec 04). Prüfungen (Konsistenzprüfung, `/aios-integrity`) schreiben nie; sie bieten eine Ergänzung nur an. |
| I8 | Jeder Befehl ist idempotent: Ein zweiter Aufruf ohne Änderung ändert nichts. |
| I9 | AIOS committet nur, was es selbst angelegt oder geändert hat: den ersten Commit eines Projekts (mit den Dateien, die es dabei aus dem Repo darüber übernimmt, Spec 05) und den Ausschluss eines Unterprojekts im Repo darüber (Spec 05, Spec 06 *Workspaces*), dazu mit `aios --contribute` die genannten Dateien in einem eigenen Zweig eines Paket-Repos (Spec 06). Arbeitsstände des Users committet es nie. |

## Abnahmetest

Der Abnahmetest von v0.4 läuft auf dem Arbeitsrechner mit v0.4.0 in einem neuen Demo-Vault `~/tmp/§Demo` (V0.4, Memos 18, 19, 27). Grundlage sind zwei Test-Hubs `aibex-aios` und `aibex-hub`, die das Skript `tests/hub/build <ziel>` unter `file://` baut und `AIOS_HUBS` einbindet. Der Schritt mit dem Rückfluss und die letzte Probe nutzen die echten Hubs auf GitHub. Der Abnahmetest von v0.3 steht in dieser Spec im Tag `v0.3.1`.

| # | Schritt | erwartet |
|---|---|---|
| 1 | v0.4.0 installieren, `§Demo` anlegen und aktivieren | `aios: 0.4.0`, Struktur vollständig |
| 2 | `aios --hubs`, `aios --library`, `aios --library app-taschenrechner` | Hub-Liste mit Herkunft; Pakete beider Hubs; Versionen 0.3.0–0.3.2, 0.4.0, 0.4.1 und die Testversion 0.4.2 (im echten Hub zusätzlich 0.1.x und 0.2.x, ohne 0.4.2) |
| 3 | im Code-Tab: „Installiere mir den Taschenrechner", Version 0.4.0, Ziel Root-Projekt | `/aios-package` findet das Paket, zeigt den Plan mit `skill-memo` als Abhängigkeit; `@!Package/` mit Marken, `packages:`, `lock.yaml` mit `hub` und `required_by` |
| 4 | im nächsten Chat `/taschenrechner-gui` bzw. Kachel *Apps* in `/aios-gui`: rechnen, mit *LEARN* eine Funktionstaste belegen, speichern | `@Data/app-taschenrechner/funktionstasten.yaml`; die Funktionstaste spielt die Folge ab |
| 5 | Vault committen, an anderen Ort klonen, `aios --fetch` ohne Argument, dann ohne Netz | gleicher Stand aus `lock.yaml`; ohne Netz aus dem Cache |
| 6 | `aios --fetch --upgrade app-taschenrechner`, mitgelieferte Funktionstaste übernehmen | 0.4.0 → 0.4.2 (Testversion) mit Plan; der Skill bietet die Funktionstaste *doppelt* aus `knowledge/@!Funktionstasten/` an |
| 7 | `aios --fetch --remove app-taschenrechner` | Paket und `skill-memo` entfernt, `@Data/` bleibt |
| 8 | in `S-Sternwarte`: `aios --fetch assistent-astronom`, `/aios-assistant Astronom`, dann `aios --fetch knowledge-orion` und `aios --fetch aibex-hub/knowledge-scorpio` | Astronom aus dem Paket; Orion aus der Hub-Liste, Skorpion aus dem genannten Hub ohne Hinweis; `lock.yaml` mit beiden Hubs |
| 9 | im nächsten Chat: „Daten des Sterns Rigel", „die drei hellsten Orion-Sterne", „der hellste Stern im Skorpion" | Werte aus den Tabellen der Wissenspakete mit Quelle |
| 10 | Paket mit mehreren Skills: `aios --deploy <paket> --only <skill>`, dann `--all` | nur der gewählte Skill registriert, `/aios-context` nennt die übrigen „fetched, not deployed" |
| 11 | lokaler `@!Skill/memo` neben dem Skill `memo` des Pakets `skill-memo` | lokaler Skill gilt, `/aios-context` meldet die Verdeckung |
| 12 | gleicher Paketname in beiden Test-Hubs | Abbruch der CLI mit der Liste, Rückfrage im Skill, danach `hub` in `lock.yaml` |
| 13 | Paket mit Arbeitspferd holen, starten, stoppen, entfernen | jedes Skript nur nach eigener Bestätigung |
| 14 | Vault mit `aios: 0.3.1`, `skills:` und `assistants:` auf v0.4.0 umstellen | Angebot zum Umschreiben; Blueprints mit Marke ersetzt, lokale bleiben |
| 15 | `aios --contribute @Data/app-taschenrechner/funktionstasten.yaml --to app-taschenrechner` gegen `aibex-aios/app-taschenrechner` | Plan, Zweig `contrib/…`, echter Pull Request |
| 16 | Workspace: `aios --workspace init` aus einem Test-Wurzelrepo, `update --group`, `freeze`, `status`, `aios --integrity` | Klone verschachtelt mit Ausschluss, `ws/<tag>`, `lock.yaml` mit SHAs, Fremd-Repo geprüft, fehlender Klon gemeldet |
| 17 | Befunde A4, A11, A13–A16 nachstellen | Bitte um Umbenennen des Chats; `B-Beet` → `GB-Beet`; Umbenennen nur in der Schreibweise; übernommene Dateien committet; keine falsche Warnung; kurze Spalte *Init* |
| 18 | Probe gegen die echten Hubs (`AIOS_HUBS` leer): `aios --library`, `aios --fetch skill-memo` | Pakete aus `aibex-aios`, Topic bzw. Index |

## Offen

| # | Punkt | vorläufige Festlegung für v0.4 |
|---|---|---|
| O1 | Wirkt `/reload-skills` in einer interaktiven Session auf Skills, die nach dem Start angelegt wurden? | Getestet (V0.1, Memo 16): Ein beim Session-Start angelegter Skill ist erst im nächsten Chat verfügbar; die Registrierung ist darauf ausgelegt (Spec 03). Offen ist nur `/reload-skills` |
| O2 | Detailregeln der Klassen | siehe Spec 02, *Vorläufige Regeln der Klassen* |
| O4 | Stehen HTML-Oberflächen im Chat in jeder Installation der Desktop-App bereit? (V0.3, Memo 10, 25, 31) | Geprüft: in der Desktop-App vorhanden, in Headless-Sessions und der CLI nicht. Ohne HTML-Oberfläche zeigen `/gui` und `/aios-gui` das Menü der CLI |
