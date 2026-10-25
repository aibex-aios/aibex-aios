---
title: "AIbex AIOS v0.5 — Überblick"
date: 2026-10-25
author: iHux
status: Spec
tags: [spec, aios, v0.5]
number: 01
related:
  - "Spec 02 Master-Kontext"
  - "Spec 03 Skills und Assistenten"
  - "Spec 04 Installation und Konfiguration"
  - "Spec 05 Projekte"
  - "Spec 06 Pakete und Workspaces"
  - "Spec 07 Arbeitspferde"
  - "Memo 12 Umfang von AIOS v0.1.0 — Entscheidungen vor der Spec (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memo 13 Umfang von v0.2, Memos 01–12 nach V0.3 (AA-AIbex-AIOS, @Memo/V0.2)"
  - "Memo 13 Herkunft der Memos und Begriffe von v0.2 (AA-AIbex-AIOS, @Memo/V0.3)"
  - "Memos 22–28 (AA-AIbex-AIOS, @Memo/V0.3)"
  - "Memos 01–29 (AA-AIbex-AIOS, @Memo/V0.4)"
  - "Memos 01–41 (AA-AIbex-AIOS, @Memo/V0.5), Soll-Bild Memo 36, Skizze Memo 37"
---

# AIbex AIOS v0.5 — Überblick

## Definition

**AIbex AIOS ist ein Betriebssystem für den Kontext von KI-Assistenten.** Es verwaltet, welches Wissen ein Chat lädt, bei Bedarf liest oder nicht sieht, und stellt dafür Dateisystem-Konventionen, Assistenten und Skills bereit. Die Ausführung übernimmt ein Host (in v0.5: Claude Code).

AIOS hat keinen Kernel im Sinne eines Betriebssystems, kein Scheduling und keine Prozessisolation. Sessions, Modellaufrufe und Werkzeuge stellt der Host bereit. AIOS setzt darauf auf, mit Konventionen im Dateisystem, Hooks, Skills und einem Installer. *Kernel* heißt in AIOS das Grundpaket `aios` mit CLI, Hooks und AIOS-Skills (Spec 04, 06).

| Betriebssystem | AIOS |
|---|---|
| Dateisystem | Vault mit `§`-Wurzel und Verzeichnisbaum |
| Speicherverwaltung | Klassen *Laden* (resident), *Verfügbar* (bei Bedarf eingelesen), *Verborgen* (nicht eingeblendet) |
| Adressraum eines Prozesses | Master-Space-Kette: der Kontext, den ein Chat sieht |
| Programm starten | Chat mit dem Assistenten des Projekts beginnen |
| Treiber | Registrierung der Skills beim Host |
| Paketverwaltung | Pakete aus Hubs laden und ausrollen, `/aios-package` (Spec 06) |
| Systemprogramme | Arbeitspferde, je Version installiert, aktiviert über `lock.yaml` (Spec 07) |
| Distribution | Kernel und Pakete in einer geprüften Zusammenstellung, `aios --install` (Spec 06) |
| Boot | SessionStart-Hook |
| Dateisystemprüfung (`fsck`) | Konsistenzprüfung beim Start, `/aios-integrity` |

## Diese Spec

Die Spec v0.5 besteht aus sieben Dokumenten, die sich nicht wiederholen:

| Spec | Inhalt |
|---|---|
| **01 Überblick** (dieses Dokument) | Definition, Begriffe, Umfang, Vorabversionen, Invarianten, Abnahmetest, offene Punkte |
| **02 Master-Kontext** | Projekt und Kette, Klassen, `aios --context`, Hooks (mit Assistent und Konsistenzprüfung), `/aios-context`, Legacy-Modus |
| **03 Skills und Assistenten** | Arten von Skills, Versionen, Ausführungsmodell, `/aios-distribution`, `/aios-register`, Assistenten und ihre Zuordnung, `/aios-assistant`, Oberflächen (`/aios-gui`, `/gui`), `/aios-memo` |
| **04 Installation und Konfiguration** | Dateistrukturen, Formate, CLI `aios`, Versionen und Aktivierung, Weiterleiter, Installieren von Distributionen |
| **05 Projekte** | Struktur und Name eines Projekts, `/aios-init`, Konsistenzprüfung, `/aios-integrity`, `/aios-status` |
| **06 Pakete und Workspaces** | Paket-Manifest, Versionen und Bereiche, Hubs und Hub-Liste, Resolver, Paket laden (`aios --fetch`), ausrollen (`aios --deploy`), Distributionen, Lock, `@Data/`, Workspaces, Rückfluss, Demo-App Taschenrechner |
| **07 Arbeitspferde** | Definition, Pakete `worker-<name>`, Installation je Version, Aktivierung über `lock.yaml`, Weiterleiter, Abläufe, `aios --worker`, Tests |

Die Begründungen stehen in den Memos der Konzeptprojekte unter `§AIOS/A-AIOS/AA-AIbex-AIOS/`: `@Memo/V0.1/` für die Grundlage, `@Memo/V0.2/` (Memos 13–18) für die Änderungen in v0.2, `@Memo/V0.3/` (Memos 01–28) für die Änderungen in v0.3, `@Memo/V0.4/` (Memos 01–29) für die Änderungen in v0.4, `@Memo/V0.5/` (Memos 11–41, Soll-Bild Memo 36) für die Änderungen in v0.5. In den Memos 01–11 von V0.3 heißt der Assistent noch *Agent* (V0.3, Memo 13). Die Spec beschreibt nur den Soll-Stand. Sie wird im Repo `aibex-aios` unter `spec/` gepflegt und mit jeder Version nach `doc/spec/` ausgeliefert.

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
| **Alias** | globale, versionsneutrale Hülle mit kurzem Namen, die AIOS ausliefert (in v0.5 nur `/gui`, Spec 03) |
| **Projekt-Skill** | Skill aus `@!Skill` der Kette, projektlokal registriert |
| **Assistent** | eine Rolle, die AIOS dem KI-Assistenten des Hosts gibt: Bündel aus Rollentext, Prompt, Skills, Oberfläche, Wünschen an Modell und Werkzeuge und eigenem Wissen in `@!Assistant/<name>/`. Wie der Host ihn umsetzt, regelt die Abbildung je Host (Spec 03) |
| **Zuordnung** | der Assistent eines Projekts: `assistant:` in `.aios/config.yaml` mit dem Wert `<name>`, `none` oder `inherit` (Spec 03) |
| **Assistent der Session** | der Assistent, mit dem eine Session begonnen hat oder auf den sie mit `/aios-assistant` gewechselt hat; gilt bis zum Ende der Session (Spec 02) |
| **Oberfläche** | Startseite eines Assistenten (`/gui`) bzw. von AIOS (`/aios-gui`): Kacheln mit Text und Prompt, in der Desktop-App als HTML, in der CLI als Menü (Spec 03) |
| **Paket** | versionierte Einheit mit `manifest.yaml`, in einem eigenen Repo eines Hubs, Versionen als Tags `v<version>` (Spec 06) |
| **Element** | Teil eines Pakets, der in einem Projekt wirkt: Skill, Assistent, Wissen, Befehl |
| **Kernel** | das Grundpaket `aios` mit CLI, Hooks und AIOS-Skills; wird installiert, nicht geholt (Spec 04) |
| **Modul** | Paket, nach dessen Holen AIOS etwas Neues kann (Kernel, App, Assistent, Skill, Arbeitspferd) |
| **App** | Modul, das der Anwender direkt benutzt (Oberfläche, Befehle, Skills) |
| **Distribution** | Paket, das optional einen Kernel und Pakete in exakten Versionen zusammenstellt; wird installiert (Spec 06) |
| **Arbeitspferd** | Programm, das ausgeführt wird, auf dem Rechner wohnt und vor Ort gebaut wird (K1–K3); Paket vom Typ `worker` (Spec 07) |
| **Werkzeug**, **Dienst** | Arbeitspferd, das nur während eines Aufrufs läuft bzw. dauerhaft läuft; Dienste sind in v0.5 nicht umgesetzt (Spec 07) |
| **Paket laden** | für den User ein Vorgang mit einem Plan und einem Ja: holen, Arbeitspferde einrichten, registrieren (Spec 06) |
| **setup**, **remove** | eine Version eines Arbeitspferds einrichten bzw. abbauen (Spec 07) |
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
| **Demo-Assistent** | Assistent als Paket zum Ausprobieren und für Tutorials (`assistant-gaertner`, `assistant-astronom`) |
| **Paket-Skill** | ausgerollter Skill aus einem geholten Paket in `@!Package/` |
| **lokaler Skill** | Skill, der im Projekt selbst geschrieben wurde (`@!Skill/`) und aus keinem Paket stammt |
| **Struktur eines Projekts** | was ein Projekt nach `aios --init` hat: `@/`, eigenes Repo, `.gitignore`, Ausschluss im Repo darüber (Spec 05) |
| **integer** | ein Projekt, dessen Struktur vollständig und dessen Repo vollständig committet ist (Spec 05) |
| **Host** | das Programm, das die Session ausführt; in v0.5 nur Claude Code |
| **Installation** | eine Version des Kernels (`/opt/aios/v<version>/`) oder eines Arbeitspferds (`/opt/aios/workers/<paket>/v<version>/`) auf dem Rechner; Versionen liegen nebeneinander. *Installieren* gilt für Kernel, Arbeitspferde und Distributionen |
| **Aktivierung** | Bindung eines Vaults oder Projekts an eine installierte Version: Kernel über `aios:` in `.aios/config.yaml`, Arbeitspferd über `lock.yaml` |
| **Legacy-Modus** | Verhalten ohne Aktivierung: wie `ai-brain` |
| **Weiterleiter** | Programm ohne eigene Logik, das die gültige Version bestimmt und deren Programm aufruft: `~/bin/aios` für den Kernel, `~/.aios/bin/<programm>` für Arbeitspferde |

## Grundregeln

1. **Der Pfad liefert den Projektkontext, der Assistent die Persönlichkeit und die Auswahl von Skills und Wissen.**
2. **Chat-Verzeichnis = Projektverzeichnis.** Innerhalb eines Vaults läuft ein Chat immer in einem Projekt; ein Ordner ohne `@/` wird initialisiert oder verlassen (Spec 02).
3. **Der nächstgelegene Eintrag gewinnt**: bei Blueprints entlang der Kette und bei Schlüsseln der Konfiguration, auch bei der Zuordnung des Assistenten.
4. **Blueprint ist Quelle, Build-Output ist abgeleitet.**
5. **Installieren und Aktivieren sind getrennt**: Installieren bringt eine Version auf den Rechner, Aktivieren bindet einen Vault oder ein Projekt an sie. Eine Distribution tut beides in einem Plan.
6. **AIOS ist pro Vault eingeschaltet**: ohne Aktivierung in der Kette gilt der Legacy-Modus.
7. **Jedes Paket, jeder Skill und jeder Assistent hat eine Version** (Semver `MAJOR.MINOR.PATCH`, Spec 03, 06).
8. **Der Assistent ist eine Eigenschaft des Projekts**: Er gilt für alle User gleich; es gibt keine persönliche Zuordnung und keine Aktivierung nur für einen Chat (Spec 03).
9. **Jedes Projekt hat ein eigenes Git-Repo**, auch das Root-Projekt und jedes Unterprojekt; das Repo darüber schließt es aus (Spec 05).

## Umfang von v0.5

v0.5 baut auf v0.4 auf. Schwerpunkt sind **Arbeitspferde** (Spec 07) und das **Laden** von Paketen als ein Vorgang; dazu kommen eine Grundversion von **Distributionen**, `aios --context` statt `aios-context` und kleinere Themen (V0.5, Memos 24, 36). Alles aus v0.4, das hier nicht geändert wird, gilt weiter.

| in v0.5 | nicht in v0.5 |
|---|---|
| Arbeitspferde als Pakete `worker-<name>` mit `kind: python` (Hash-Datei) und `kind: script`; Installation je Version in `/opt/aios/workers/`, Aktivierung über `lock.yaml`, Weiterleiter `~/.aios/bin/<programm>` | Dienste (`start`, `stop`, Ports), `kind: binary` |
| Paket laden: holen, setup, registrieren in einem Plan, alles oder nichts mit Sicherung; Abgleich auf einem zweiten Rechner | mehrere User auf einem Rechner |
| Distributionen mit `kernel:` und exakten Versionen; `aios --install distribution-<name>`; Skill `/aios-distribution` | Schlüsselordner und Nomenklatur, `@Chat/`, `@Package/`, `export:` |
| `aios --context` als Gruppe von `aios`, ohne `aios-context` | Workflows (v0.6), Wissen mit Rohwissen und Fassung (v0.7) |
| `aios --prepare` in zwei Stufen (Grund- und Entwicklerausstattung) | `deno` als Voraussetzung des Kernels (es ist ein Arbeitspferd) |
| Ausführungsmodell der Skills (Spec 03) | |
| englische Paketnamen (`assistant-`, `worker-`, `distribution-`), Umbenennung beim Aktivieren | |
| `@Data/` für jedes schreibende Paket; `.agents/` gemeldet und in der `.gitignore`-Vorlage | |

## Vorabversionen

Alle Versionen unter 1.0 sind Alpha- und Beta-Versionen; an Kunden wird erst ab v1.0 ausgeliefert. Das gilt für AIOS selbst und für die Pakete der Grundausstattung, die deshalb mit `0.1.0` beginnen (Ausnahme: `memo` behält seine Versionsfolge, 6.0.0).

Vor v1.0 wird keine Migration zwischen Versionen verlangt: Eine neue Version darf Begriffe, Ordnernamen und Formate ändern, ohne Migrationspfad und ohne Kompatibilitätsmodus. Die Versionsbindung (`aios:` in `.aios/config.yaml`) hält einen Vault auf seiner Version lauffähig. Ein mit v0.3 oder v0.4 aktivierter Vault läuft weiter, solange seine Version installiert ist und ihre Hooks gelten; nach der Installation von v0.5 gibt es `aios-context` nicht mehr, deshalb wird er mit `aios --activate v0.5.<n>` umgestellt (Spec 06, *Umstellung von v0.3*, *Umstellung von v0.4*). Migrierbarkeit wird ab v1.0 angestrebt.

## Invarianten

AIOS v0.5 hält diese Regeln in jedem Befehl ein (für Pakete zusätzlich P1–P8, Spec 06, für Arbeitspferde A1–A4, Spec 07):

| # | Regel |
|---|---|
| I1 | AIOS ändert nie ein bestehendes Memo in `@Memo/`. `/aios-memo` legt nur neue Memos an. |
| I2 | AIOS schreibt in einen Masterspace `@/` nur mit `aios --fetch`, und nur nach `@!Package/<name>/`. Ausnahmen: `aios --activate` und `aios --init` legen ein fehlendes `@/` mit `.gitkeep` an; `aios --activate` ersetzt bei der Umstellung von v0.3 Blueprints mit Marke in `@!Skill/` und `@!Assistant/` durch geholte Pakete (Spec 06). |
| I3 | AIOS registriert nie einen Skill aus einem Masterspace global; global liegen nur AIOS-Skills und der Alias `gui`. |
| I4 | AIOS fasst in Vaults ohne Aktivierung nichts an und verhält sich dort wie `ai-brain`. Ausnahmen sind `aios --activate`, das die Aktivierung schreibt, und `aios --install distribution-<name>`, das den Vault an den Kernel der Distribution bindet; `aios --fetch`, `aios --deploy`, `aios --workspace`, `aios --init`, `aios --assistant` und die Registrierung brechen ab bzw. tun nichts. |
| I5 | AIOS verändert nie eine installierte Version in `/opt/aios/v<version>/` oder `/opt/aios/workers/<paket>/v<version>/`; es entfernt sie nur ganz. |
| I6 | AIOS fasst in `.claude/skills/` nur Ordner an, die in `.aios/registry` stehen oder die es beim Registrieren neu anlegt; Ordner, die schon da sind und nicht in der Registry stehen, nie. |
| I7 | Jeder schreibende Befehl zeigt vorher, was er tut, und wartet auf Bestätigung. Ausnahmen sind beim Session-Start die Registrierung und der Merker der Session (`~/.aios/sessions/`). Ein Skill holt den Plan mit `--plan`, fragt im Chat und ruft erst nach Ja mit `--yes` auf (Spec 04). Prüfungen (Konsistenzprüfung, `/aios-integrity`) schreiben nie; sie bieten eine Ergänzung nur an. |
| I8 | Jeder Befehl ist idempotent: Ein zweiter Aufruf ohne Änderung ändert nichts. |
| I9 | AIOS committet nur, was es selbst angelegt oder geändert hat: den ersten Commit eines Projekts (mit den Dateien, die es dabei aus dem Repo darüber übernimmt, Spec 05) und den Ausschluss eines Unterprojekts im Repo darüber (Spec 05, Spec 06 *Workspaces*), dazu mit `aios --contribute` die genannten Dateien in einem eigenen Zweig eines Paket-Repos (Spec 06). Arbeitsstände des Users committet es nie. |
| I10 | Ein Weiterleiter oder Skill löst nie ein setup aus; fehlt ein Arbeitspferd, meldet er das und nennt höchstens `aios --fetch` (Spec 07). |
| I11 | Ein Plan mit „alles oder nichts" (Paket laden, Distribution installieren) stellt bei einem Fehler den Stand vor dem Plan wieder her (Sicherung, Spec 06); registriert wird erst nach erfolgreichem setup. |

## Abnahmetest

Der Abnahmetest von v0.5 läuft auf dem Arbeitsrechner nach der Implementierung, mit der Distribution „Rothirsch 1.0" (V0.5, Memos 28, 37). Vor der Veröffentlichung der Begleitpakete kommen sie aus einem lokalen Hub `aibex-local` (`file://`, aus den lokal getaggten Repos unter `~/git/AIbex/`), eingebunden im Probe-Vault mit `aios --hubs --vault`. Probe-Vault: `~/vault/§Probe-Rothirsch`. Der Abnahmetest von v0.4 steht in dieser Spec im Tag `v0.4.0`.

| # | Schritt | erwartet |
|---|---|---|
| 1 | `aios --prepare`, `aios --prepare --dev` | Grundausstattung vorhanden (`python3` mit `venv` und `pip`, `git`); mit `--dev` zusätzlich `gh` |
| 2 | `aios --install v0.5.0` | Kernel in `/opt/aios/v0.5.0/`; Plan nennt das Umschreiben der Hooks auf `aios --context`, das Entfernen von `~/bin/aios-context` und die Vaults auf älteren Versionen |
| 3 | neuer Chat; `aios --context --list` | Master-Kontext wie bisher; `aios-context` gibt es nicht mehr |
| 4 | leeren Vault `§Probe-Rothirsch` anlegen, Hub `aibex-local` mit `aios --hubs --vault`; `aios --install distribution-rothirsch ~/vault/§Probe-Rothirsch --plan` | ein Plan: Rechnerteil (`worker-deno`, `worker-yt-dlp` mit Liste `paket==version`, Ziel, `check`, Weiterleiter), Vaultteil (Bindung an 0.5.0, Pakete, `packages:` mit der Distribution, `lock.yaml`, Registrierung) |
| 5 | dasselbe mit Ja | alles eingerichtet; `aios --worker` zeigt beide Arbeitspferde mit Version, Ort, Projekt, `check` ok |
| 6 | neuer Chat im Vault; Video-Analyse mit einer YouTube-URL | Video-Notiz mit Transkript; `yt-dlp` über `~/.aios/bin/yt-dlp` mit `deno`; keine Installationsanweisung |
| 7 | `/aios-assistant Anja`; „Wie lege ich ein Arbeitspferd an?" | Anja 0.2.0 aktiv, antwortet aus ihrer Praxis zu Arbeitspferden mit `worker-yt-dlp` als Vorlage |
| 8 | Testversion `distribution-rothirsch` 1.0.1 (nur im lokalen Hub, mit `worker-yt-dlp` 0.1.1); `aios --install distribution-rothirsch` | Plan `upgrade 1.0.0 → 1.0.1`, setup von `worker-yt-dlp` 0.1.1, remove von 0.1.0; danach Schritt 6 erneut erfolgreich |
| 9 | Unterprojekt `P-Probe-Alt` mit `aios --fetch worker-yt-dlp==0.1.0` | 0.1.0 neben 0.1.1 installiert; `~/.aios/bin/yt-dlp --version` liefert je Ordner die gesperrte Version |
| 10 | im Unterprojekt ein Paket mit scheiterndem setup laden (`worker-test-script` aus dem Test-Hub) | Abbruch; `config.yaml`, `lock.yaml`, `@/@!Package/` und Registrierung unverändert; keine Sicherung bleibt liegen |
| 11 | eine installierte Version löschen (zweiten Rechner nachstellen); neuer Chat im Vault | Hinweis beim Start nennt das fehlende Arbeitspferd und `aios --fetch`; der Weiterleiter meldet „not fully loaded"; `aios --fetch` richtet es wieder ein |
| 12 | `/aios-distribution` im Vault: neue Distribution aus dem Stand des Vaults | Plan, lokales Repo `distribution-<name>` mit exakten Versionen und `kernel:`; Probe-Vorschlag mit `--from` in einen Ordner außerhalb des Vaults |
| 13 | `aios --fetch --remove distribution-rothirsch` im Vault | Pakete entfernt; Arbeitspferde entfernt, soweit kein `lock.yaml` sie nennt (0.1.0 bleibt für `P-Probe-Alt`); `aios: 0.5.0` bleibt |
| 14 | `aios --activate v0.5.0 ~/vault/§AIOS --plan` | Umstellung des Arbeitsvaults mit Umbenennung `assistent-*`, falls vorhanden |
| 15 | `/aios-integrity` in einem Projekt mit veralteter Kopie in `.agents/skills/` | Meldung der Kopie; neue Projekte haben `.agents/` und `.aios/backup/` in der `.gitignore` |
| 16 | `tests/run`; `tests/live/workers.sh` | alle grün |
| 17 | Veröffentlichen, jeder Schritt mit eigener Rückfrage: Tag `v0.5.0` im Kernel, Begleitpakete, Index; Probe gegen den Hub `aibex-aios` in einem frischen Vault | Schritte 4–6 gegen den echten Hub erfolgreich |

## Offen

| # | Punkt | vorläufige Festlegung für v0.5 |
|---|---|---|
| O1 | Wirkt `/reload-skills` in einer interaktiven Session auf Skills, die nach dem Start angelegt wurden? | Getestet (V0.1, Memo 16): Ein beim Session-Start angelegter Skill ist erst im nächsten Chat verfügbar; die Registrierung ist darauf ausgelegt (Spec 03). Offen ist nur `/reload-skills` |
| O2 | Detailregeln der Klassen | siehe Spec 02, *Vorläufige Regeln der Klassen* |
| O4 | Stehen HTML-Oberflächen im Chat in jeder Installation der Desktop-App bereit? (V0.3, Memo 10, 25, 31) | Geprüft: in der Desktop-App vorhanden, in Headless-Sessions und der CLI nicht. Ohne HTML-Oberfläche zeigen `/gui` und `/aios-gui` das Menü der CLI |
