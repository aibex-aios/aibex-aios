---
title: "AIbex AIOS v0.6 — Überblick"
date: 2026-11-03
author: iHux
status: Spec
tags: [spec, aios, v0.6]
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
  - "Memos 01–36 (AA-AIbex-AIOS, @Memo/V0.6), Soll-Bild Memo 34, Skizze Memo 35"
  - "Memos 79–84 (AA-AIbex-AIOS, @Memo/V0.6), v0.6.1, Skizze Memo 84"
---

# AIbex AIOS v0.6 — Überblick

## Definition

**AIbex AIOS ist ein Betriebssystem für den Kontext von KI-Assistenten.** Es verwaltet, welches Wissen ein Chat lädt, bei Bedarf liest oder nicht sieht, und stellt dafür Dateisystem-Konventionen, Assistenten und Skills bereit. Die Ausführung übernimmt ein Host (in v0.6: Claude Code).

**AIBOS** ist der Rufname für AIbex AIOS ab Version 0.6.0. Die technischen Namen bleiben: Befehl `aios`, Ordner `~/.aios`, Schlüssel `aios:` (V0.6, Memos 13, 14). Ältere Versionen heißen weiter AIOS.

AIOS hat keinen Kernel im Sinne eines Betriebssystems, kein Scheduling und keine Prozessisolation. Sessions, Modellaufrufe und Werkzeuge stellt der Host bereit. AIOS setzt darauf auf, mit Konventionen im Dateisystem, Hooks, Skills und einem Installer. *Kernel* heißt in AIOS das Grundpaket `aios` mit CLI, Hooks und Kernel-Skills (Spec 04, 06).

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

Die Spec v0.6 besteht aus sieben Dokumenten, die sich nicht wiederholen:

| Spec | Inhalt |
|---|---|
| **01 Überblick** (dieses Dokument) | Definition, Begriffe, Grundregeln, Umfang, Vorabversionen, Invarianten, Abnahmetest, offene Punkte |
| **02 Master-Kontext** | Vault, Projekt und Kette, Arten von Vaults, Klassen, Block der Kernel-Skills, `aios --context`, Hooks (mit Assistent, Konsistenzprüfung und Freigabe), `/aios-context`, Legacy-Modus |
| **03 Skills und Assistenten** | Arten von Skills, Versionen, Ausführungsmodell, Auslösen der Kernel-Skills, `/aios-distribution`, `/aios-register`, Assistenten und ihre Zuordnung, `/aios-assistant`, Oberflächen (`/aios-gui`, `/gui`), `/aios-memo` |
| **04 Installation und Konfiguration** | Dateistrukturen, Formate, CLI `aios`, Versionen und Aktivierung, Weiterleiter, Installieren von Distributionen, Umstieg |
| **05 Projekte** | Struktur und Name eines Projekts, `/aios-init`, Konsistenzprüfung, `/aios-integrity`, `/aios-status` |
| **06 Pakete und Workspaces** | Paket-Manifest, Versionen und Bereiche, Hubs und Hub-Liste, Resolver, Paket laden (`aios --fetch`), ausrollen (`aios --deploy`), Distributionen, Lock, `@Data/`, Workspaces, Rückfluss, Demo-App Taschenrechner |
| **07 Arbeitspferde** | Definition, Pakete `worker-<name>`, Installation je Version, Aktivierung über `lock.yaml`, Weiterleiter, Abläufe, `aios --worker`, Tests |

Die Begründungen stehen in den Memos der Konzeptprojekte unter `§AIOS/A-AIOS/AA-AIbex-AIOS/`: `@Memo/V0.1/` für die Grundlage, `@Memo/V0.2/` (Memos 13–18) für die Änderungen in v0.2, `@Memo/V0.3/` (Memos 01–28) für die Änderungen in v0.3, `@Memo/V0.4/` (Memos 01–29) für die Änderungen in v0.4, `@Memo/V0.5/` (Memos 11–41, Soll-Bild Memo 36) für die Änderungen in v0.5, dort auch die Memos 70–86 für v0.5.1, `@Memo/V0.6/` (Memos 01–36, Soll-Bild Memo 34, Skizze Memo 35) für die Änderungen in v0.6, dort auch die Memos 79–84 (Bewertung Memo 79, Skizze Memo 84) für v0.6.1 und die Memos 114–123 (Bewertung Memo 118, Soll-Bild und Skizze Memo 122) für v0.6.2. In den Memos 01–11 von V0.3 heißt der Assistent noch *Agent* (V0.3, Memo 13). Die Spec beschreibt nur den Soll-Stand. Sie wird im Repo `aibex-aios` unter `spec/` gepflegt und mit jeder Version nach `doc/spec/` ausgeliefert.

## Begriffe

| Begriff | Bedeutung |
|---|---|
| **AIBOS** | AIbex AIOS ab Version 0.6.0 |
| **Vault** | ein Ordner, dessen Name mit `§` beginnt (z. B. `§Demo`), mit allem darunter; in der Regel ein Obsidian-Vault. Ein Vault hat eine Bindung an AIBOS oder nicht |
| **Vault-Root** | das `§`-Verzeichnis selbst; der einzige Ort einer Bindung (`aios:`) oder Markierung (`legacy:`) |
| **AIBOS-Workspace (A/W)** | ein Vault, dessen `<vault>/.aios/config.yaml` eine Bindung `aios:` an eine Version ≥ 0.6.0 enthält (V0.6, Memo 14) |
| **Arbeitsverzeichnis** | das `cwd`, das der Host den Hooks bei jedem Prompt mitgibt (V0.6, Memos 13, 31) |
| **AIBOS-Verhalten** | AIBOS beeinflusst den Kontext der KI: Master-Kontext, Kernel-Skills, Assistent, Freigabe von Befehlen (Spec 02) |
| **Masterspace** | ein Verzeichnis namens `@`; Container von Unterverzeichnissen je einer Klasse |
| **Projekt** | jeder Ordner mit `@/`, auch die Vault-Root; die Vault-Root mit `@/` ist das **Root-Projekt** |
| **Unterprojekt** | ein Projekt unterhalb eines anderen Projekts, auch durch Container hindurch |
| **Container** | Ordner ohne `@/`; gliedert nur, trägt keinen Kontext bei und hat kein eigenes Repo; eine Vault-Root ohne `@/` ist ebenfalls ein Container. Ausnahme ist ein Fremd-Repo |
| **Root-Masterspace** | `@/` der Vault-Root |
| **lokaler Masterspace** | `@/` des Projekts, in dem ein Chat läuft |
| **Master-Space-Kette** | die Masterspaces aller Projekte vom Projekt des Chats aufwärts bis zum Root-Projekt |
| **Master-Kontext** | der geladene Teil der Master-Space-Kette: alles, was beim Chatbeginn in den Kontext des Hosts gelangt, einschließlich des Inhaltsverzeichnisses des verfügbaren Wissens und des Blocks der Kernel-Skills |
| **verfügbares Wissen** | die Dateien der Klasse *Verfügbar* in der Kette; gehört nicht zum Master-Kontext, das Modell liest sie bei Bedarf |
| **Klasse** | *Laden* (`@…`), *Verfügbar* (`@@…`), *Verborgen* (`@!…`); steht im Namen eines Unterverzeichnisses eines Masterspace |
| **Blueprint** | Beschreibung eines Skills, Prompts oder Assistenten in einem verborgenen Verzeichnis (`@!Skill`, `@!Prompt`, `@!Assistant`) |
| **Build-Output** | aus Blueprints erzeugte Dateien für den Host (z. B. `.claude/skills/`); nie Quelle, jederzeit neu erzeugbar |
| **Kernel-Skill** | Skill, der zum Kernel selbst gehört (Präfix `aios-`); im A/W an der Vault-Root und in jedem Projekt als dünne Hülle registriert und im Master-Kontext aufgeführt (Spec 03). Bis v0.5 hieß er *AIOS-Skill* und war global registriert |
| **Projekt-Skill** | Skill aus `@!Skill` der Kette, projektlokal registriert |
| **Assistent** | eine Rolle, die AIOS dem KI-Assistenten des Hosts gibt: Bündel aus Rollentext, Prompt, Skills, Oberfläche, Wünschen an Modell und Werkzeuge und eigenem Wissen in `@!Assistant/<name>/`. Wie der Host ihn umsetzt, regelt die Abbildung je Host (Spec 03) |
| **Zuordnung** | der Assistent eines Projekts: `assistant:` in `.aios/config.yaml` mit dem Wert `<name>`, `none` oder `inherit` (Spec 03) |
| **Assistent der Session** | der Assistent, mit dem eine Session begonnen hat oder auf den sie mit `/aios-assistant` gewechselt hat; gilt bis zum Ende der Session, solange ihr Arbeitsverzeichnis dasselbe ist wie bei der Zuordnung (Spec 02) |
| **Oberfläche** | Startseite eines Assistenten (`/gui`) bzw. von AIOS (`/aios-gui`): Kacheln mit Text und Prompt, in der Desktop-App als HTML, in der CLI als Menü (Spec 03) |
| **Paket** | versionierte Einheit mit `manifest.yaml`, in einem eigenen Repo eines Hubs, Versionen als Tags `v<version>` (Spec 06) |
| **Element** | Teil eines Pakets, der in einem Projekt wirkt: Skill, Assistent, Wissen, Befehl |
| **Kernel** | das Grundpaket `aios` mit CLI, Hooks und Kernel-Skills; wird installiert, nicht geholt (Spec 04) |
| **Modul** | Paket, nach dessen Holen AIOS etwas Neues kann (Kernel, App, Assistent, Skill, Arbeitspferd) |
| **App** | Modul, das der Anwender direkt benutzt (Oberfläche, Befehle, Skills) |
| **Distribution** | Paket, das optional einen Kernel und Pakete in exakten Versionen zusammenstellt; wird installiert (Spec 06) |
| **Arbeitspferd** | Programm, das ausgeführt wird, auf dem Rechner wohnt und vor Ort gebaut wird (K1–K3); Paket vom Typ `worker` (Spec 07) |
| **Werkzeug**, **Dienst** | Arbeitspferd, das nur während eines Aufrufs läuft bzw. dauerhaft läuft; Dienste sind in v0.6 nicht umgesetzt (Spec 07) |
| **Paket laden** | für den User ein Vorgang mit einem Plan und einem Ja: holen, Arbeitspferde einrichten, registrieren (Spec 06) |
| **setup**, **remove** | eine Version eines Arbeitspferds einrichten bzw. abbauen (Spec 07) |
| **Hub** | Ort mit Paket-Repos: Name und Basis-URL; bei GitHub ist der Name der Owner (z. B. `aibex-aios`). Ein Paket liegt dort als Repo `<basis>/<paket>`, voller Paketname `<hub>/<paket>` (Spec 06) |
| **Hub-Liste** | die Hubs, in denen AIOS einen Paketnamen ohne Hub sucht, in Suchreihenfolge (`hubs:`, Spec 04, 06) |
| **holen** (fetch) | eine Version eines Pakets ganz vom Hub nach `@!Package/` eines Projekts bringen (`aios --fetch`) |
| **ausrollen** (deploy) | festlegen, welche Elemente eines geholten Pakets im Projekt wirken (`aios --deploy`) |
| **registrieren** | Kernel-Skills und ausgerollte Skills dem Host bekannt machen (`.claude/skills/`, Spec 03) |
| **Anwender-Site** | Vault mit Paketen als Kopie in `@!Package/` |
| **Entwickler-Site** | Workspace mit Paketen als Git-Checkout |
| **Workspace** | Projekt mit `.aios/workspace.yaml`, das Repos mit Revision und Pfad nennt (Spec 06); nicht zu verwechseln mit dem AIBOS-Workspace |
| **Fremd-Repo** | Repo eines Workspace ohne `@/`, z. B. ein Paket-Repo; kein Projekt und kein Container (Spec 06) |
| **Lock** | `.aios/lock.yaml`: aufgelöste Pakete und eingefrorener Stand eines Workspace |
| **Demo-Assistent** | Assistent als Paket zum Ausprobieren und für Tutorials (`assistant-gaertner`, `assistant-astronom`) |
| **Paket-Skill** | ausgerollter Skill aus einem geholten Paket in `@!Package/` |
| **lokaler Skill** | Skill, der im Projekt selbst geschrieben wurde (`@!Skill/`) und aus keinem Paket stammt |
| **Struktur eines Projekts** | was ein Projekt nach `aios --init` hat: `@/`, eigenes Repo, `.gitignore`, Ausschluss im Repo darüber (Spec 05) |
| **integer** | ein Projekt, dessen Struktur vollständig und dessen Repo vollständig committet ist (Spec 05) |
| **Host** | das Programm, das die Session ausführt; in v0.6 nur Claude Code |
| **Installation** | eine Version des Kernels (`~/.aios/versions/v<version>/`, auf ausdrücklichen Wunsch `/opt/aios/v<version>/`) oder eines Arbeitspferds (`~/.aios/workers/<paket>/v<version>/` bzw. `/opt/aios/workers/…`) auf dem Rechner; Versionen liegen nebeneinander. *Installieren* gilt für Kernel, Arbeitspferde und Distributionen (Spec 04) |
| **Aktivierung** | Bindung eines Vaults an eine installierte Version: Kernel über `aios:` in `<vault>/.aios/config.yaml`, nur an der Vault-Root; Arbeitspferd über `lock.yaml` |
| **Altbindung** | Bindung eines Vaults an eine Version unter 0.6.0; der Vault läuft mit dem Kernel dieser Version weiter und ist kein A/W (Spec 02) |
| **Legacy-Modus** | Verhalten eines Vaults mit der Markierung `legacy: ai-brain`: Den Kontext liefert `ai-brain` wie vor AIOS; kein A/W (Spec 02) |
| **Weiterleiter** | Programm ohne eigene Logik, das die gültige Version bestimmt und deren Programm aufruft: `~/.aios/bin/aios` für den Kernel, `~/.aios/bin/<programm>` für Arbeitspferde |

## Grundregeln

1. **Der Pfad liefert den Projektkontext, der Assistent die Persönlichkeit und die Auswahl von Skills und Wissen.**
2. **Chat-Verzeichnis = Projektverzeichnis.** Innerhalb eines A/W läuft ein Chat immer in einem Projekt; ein Ordner ohne `@/` wird initialisiert oder verlassen (Spec 02).
3. **Der nächstgelegene Eintrag gewinnt**: bei Blueprints entlang der Kette und bei Schlüsseln der Konfiguration, auch bei der Zuordnung des Assistenten. Ausgenommen sind `aios:` und `legacy:`, die nur an der Vault-Root gelten.
4. **Blueprint ist Quelle, Build-Output ist abgeleitet.**
5. **Installieren und Aktivieren sind getrennt**: Installieren bringt eine Version auf den Rechner, Aktivieren bindet einen Vault an sie. Eine Distribution tut beides in einem Plan.
6. **AIBOS ist pro Vault eingeschaltet**: AIBOS-Verhalten gibt es genau dann, wenn das Arbeitsverzeichnis in einem A/W liegt. Außerhalb bekommt die KI denselben Kontext, als wäre AIBOS nicht installiert; die Hooks laufen und enden ohne Ausgabe (V0.6, Memos 12, 13).
7. **Jedes Paket, jeder Skill und jeder Assistent hat eine Version** (Semver `MAJOR.MINOR.PATCH`, Spec 03, 06).
8. **Der Assistent ist eine Eigenschaft des Projekts**: Er gilt für alle User gleich; es gibt keine persönliche Zuordnung und keine Aktivierung nur für einen Chat (Spec 03).
9. **Jedes Projekt hat ein eigenes Git-Repo**, auch das Root-Projekt und jedes Unterprojekt; das Repo darüber schließt es aus (Spec 05).
10. **Das Arbeitsverzeichnis entscheidet allein**, welche Bausteine aktiv sind (Master-Kontext, Kernel-Skills, Assistent, Freigabe), von Prompt zu Prompt. Bei einem Wechsel des Arbeitsverzeichnisses wandert nichts mit; was die Session vorher geladen hat, bleibt in ihrem Verlauf (V0.6, Memo 33).
11. **AIBOS schreibt nur in drei Bereiche**: a) `~/.aios`, b) das Innere von Vaults, c) die Hook-Einträge in der Einrichtung des Hosts (`~/.claude/settings.json`). Nach `/opt/aios` nur auf ausdrücklichen Wunsch (V0.6, Memo 14, K3, K4).

## Umfang von v0.6

v0.6.0 baut auf v0.5.1 auf. Schwerpunkt ist die **Grenze von AIBOS**: AIBOS-Verhalten nur im A/W, Kernel-Skills im Vault statt global, Orte nur unter `~/.aios` (V0.6, Memos 18, 19, 34). Alles aus v0.5, das hier nicht geändert wird, gilt weiter.

| in v0.6.0 | später |
|---|---|
| Begriffe AIBOS, Vault, A/W; Bindung nur an der Vault-Root; Altbindung und Legacy-Modus mit Markierung | Distributions-Installer mit Nutzungsvertrag und Dialog im Browser (eigenes Repo nach v0.6.1; V0.6, Memo 80) |
| Grundregel 6 und I12: keine Ausgabe außerhalb eines A/W, Fehler nur im Log | Codex als Host |
| Kernel-Skills als registrierte Hüllen im Vault und als Block im Master-Kontext; keine globalen Hüllen | Linux, Windows |
| Hook `PreToolUse` für die Freigabe der Befehle von AIBOS im A/W | Python über `uv`, Beheben fehlender Infrastruktur |
| Weiterleiter `~/.aios/bin/aios`, Hooks mit absolutem Pfad, Installationen unter `~/.aios`; `aios --prepare` als Altbestand | Migration `~/.aios` → `/opt/aios` |
| Zuordnung zur Session nur beim gespeicherten Arbeitsverzeichnis | Workflows (v0.7), Wissen mit Rohwissen und Fassung (v0.8) |
| Umstieg von v0.5 in vier Schritten (Spec 04) | |
| Cache von `--from` nach Quelle und Commit; `aios --install <distribution> <vault>` registriert im Ziel-Vault; Plan nennt offene Dateien des Ziels | |
| Begleitpakete in neuen Patch-Versionen mit `requires.aios` bis `<0.7` (V0.6, Memo 38) | |

v0.6.1 ist ein Korrektur-Patch auf v0.6.0 (V0.6, Memos 79–84):

| in v0.6.1 | Memos |
|---|---|
| Vor dem Entfernen einer Version eines Arbeitspferds zählen auch die Projekte der bekannten Vaults (Spec 07, *Nutzende Projekte*; B12) | Memos 71, 81 |
| Plan von `aios --activate` mit allen Unterschritten des Paketwechsels unter `packages for AIOS <version>` (Spec 06, *Paketwechsel bei der Aktivierung*; B13) | Memos 71, 81 |
| offene Dateien im Plan je Paketordner zusammengefasst (Spec 06, *Holen*; H3) | Memos 72, 81 |
| Distributionen mit Kernel 0.6: `distribution-capricorn` 0.3.0 und `distribution-rothirsch` 1.1.0 mit `kernel: "==0.6.1"` (Spec 06, *Distributionen*) | Memos 82, 83 |
| Release-Kandidaten `v0.6.1-rc<n>` für die Abnahme (*Abnahmetest*), bei einem Befund ein neuer | Memos 77, 82 |

v0.6.2 ist ein Patch auf v0.6.1, ein Release aus Kernel, `skill-cleanup` und `distribution-capricorn` (V0.6, Memos 118–123):

| in v0.6.2 | Memos |
|---|---|
| `aios --activate` nennt eine Distribution, deren `kernel:` die neue Bindung nicht erfüllt, als Hinweis mit Befehl (Spec 04; H5) | Memos 108, 120 |
| `aios --vaults` listet die gefundenen Vaults mit Art, Bindung und Quelle; `aios --remove-version` nennt die gebundenen Vaults aus derselben Suche (Spec 04; H6, H8) | Memos 110, 115, 120 |
| Die Registrierung beim Umbinden endet an jedem `§`-Ordner im Vault (Spec 04; H7) | Memos 111, 120 |
| Der Hook gibt `Read` auch unter `doc/` der Installation der Bindung frei (Spec 02, *Freigabe*, R2; H9) | Memos 116, 120 |
| `skill-cleanup` 0.1.1 mit `requires.aios: ">=0.6,<0.7"` als Begleitpaket; `distribution-capricorn` 0.4.0 mit `kernel: "==0.6.2"`, `assistant-anja` 0.3.0 und `skill-cleanup` 0.1.1; `distribution-rothirsch` bleibt 1.1.0 (H10, H11) | Memos 117, 121, 122 |
| `STATUS.md` im Paket-Repo (Spec 06, *Aufbau eines Paket-Repos*) | Memo 123 |
| Release-Kandidaten `v0.6.2-rc<n>`, Capricorn mit derselben Nummer, `skill-cleanup` mit eigenen (*Abnahmetest*) | Memos 121, 122 |
| aus der Abnahme: Zahl der Projekte im Plan von `--activate` auch für ein A/W (B20); `--remove-version` und `--vaults` über den Weiterleiter mit der höchsten installierten Version (B21); `doc/README.md` als Inhaltsverzeichnis von `doc/` (B22) | Memos 137–140 |

## Vorabversionen

Alle Versionen unter 1.0 sind Alpha- und Beta-Versionen; an Kunden wird erst ab v1.0 ausgeliefert. Das gilt für AIOS selbst und für die Pakete der Grundausstattung, die deshalb mit `0.1.0` beginnen (Ausnahme: `memo` behält seine Versionsfolge, 6.0.0).

Vor v1.0 wird keine Migration zwischen Versionen verlangt: Eine neue Version darf Begriffe, Ordnernamen und Formate ändern, ohne Migrationspfad und ohne Kompatibilitätsmodus. Die Versionsbindung (`aios:` in `.aios/config.yaml`) hält einen Vault auf seiner Version lauffähig. Ein Vault mit Altbindung an v0.5 läuft nach der Installation von v0.6.0 weiter, solange seine Version installiert ist; er wird mit `aios --activate v0.6.<n>` umgestellt (Spec 04, *Legacy und Umstieg*). Migrierbarkeit wird ab v1.0 angestrebt.

## Invarianten

AIBOS hält diese Regeln in jedem Befehl ein (für Pakete zusätzlich P1–P8, Spec 06, für Arbeitspferde A1–A4, Spec 07):

| # | Regel |
|---|---|
| I1 | AIOS ändert nie ein bestehendes Memo in `@Memo/`. `/aios-memo` legt nur neue Memos an. |
| I2 | AIOS schreibt in einen Masterspace `@/` nur mit `aios --fetch`, und nur nach `@!Package/<name>/`. Ausnahmen: `aios --activate` und `aios --init` legen ein fehlendes `@/` mit `.gitkeep` an; `aios --activate` ersetzt bei der Umstellung von v0.3 Blueprints mit Marke in `@!Skill/` und `@!Assistant/` durch geholte Pakete (Spec 06). |
| I3 | AIBOS registriert nie einen Skill global. Kernel-Skills und Projekt-Skills werden nur im Vault registriert, an der Vault-Root und in Projekten (Spec 03). Beim Umstieg entfernt AIBOS die globalen Hüllen früherer Versionen (Spec 04). |
| I4 | AIBOS fasst in Vaults ohne Bindung nichts an und liefert dort keinen Kontext. Ausnahmen sind `aios --activate`, das die Bindung schreibt, `aios --install distribution-<name>`, das den Vault an den Kernel der Distribution bindet, und der Umstieg, der nach Rückfrage `legacy: ai-brain` einträgt (Spec 04); `aios --fetch`, `aios --deploy`, `aios --workspace`, `aios --init`, `aios --assistant` und die Registrierung brechen ab bzw. tun nichts. In einem Legacy-Vault liefert `ai-brain` den Kontext. |
| I5 | AIOS verändert nie eine installierte Version (`v<version>/` oder `workers/<paket>/v<version>/` unter `~/.aios` bzw. `/opt/aios`); es entfernt sie nur ganz. |
| I6 | AIOS fasst in `.claude/skills/` nur Ordner an, die in `.aios/registry` stehen oder die es beim Registrieren neu anlegt; Ordner, die schon da sind und nicht in der Registry stehen, nie. In `~/.claude/skills/` entfernt der Umstieg nur die Hüllen früherer Versionen (Spec 04). |
| I7 | Jeder schreibende Befehl zeigt vorher, was er tut, und wartet auf Bestätigung. Ausnahmen sind beim Session-Start die Registrierung, der Merker der Session (`~/.aios/sessions/`) und das Log (`~/.aios/log/`). Ein Skill holt den Plan mit `--plan`, fragt im Chat und ruft erst nach Ja mit `--yes` auf (Spec 04). Prüfungen (Konsistenzprüfung, `/aios-integrity`) schreiben nie; sie bieten eine Ergänzung nur an. |
| I8 | Jeder Befehl ist idempotent: Ein zweiter Aufruf ohne Änderung ändert nichts. |
| I9 | AIOS committet nur, was es selbst angelegt oder geändert hat: den ersten Commit eines Projekts (mit den Dateien, die es dabei aus dem Repo darüber übernimmt, Spec 05) und den Ausschluss eines Unterprojekts im Repo darüber (Spec 05, Spec 06 *Workspaces*), dazu mit `aios --contribute` die genannten Dateien in einem eigenen Zweig eines Paket-Repos (Spec 06). Arbeitsstände des Users committet es nie. |
| I10 | Ein Weiterleiter oder Skill löst nie ein setup aus; fehlt ein Arbeitspferd, meldet er das und nennt höchstens `aios --fetch` (Spec 07). |
| I11 | Ein Plan mit „alles oder nichts" (Paket laden, Distribution installieren) stellt bei einem Fehler den Stand vor dem Plan wieder her (Sicherung, Spec 06); registriert wird erst nach erfolgreichem setup. |
| I12 | Liegt das Arbeitsverzeichnis außerhalb eines A/W, geben die Hooks von AIBOS nichts aus und geben keinen Befehl frei; Fehler stehen nur im Log `~/.aios/log/context.log` (Spec 02). |
| I13 | AIBOS schreibt außerhalb von `~/.aios` und Vaults nur die eigenen Hook-Einträge in `~/.claude/settings.json` und entfernt beim Umstieg die Hüllen früherer Versionen in `~/.claude/skills/`; es ändert keine Startdateien der Shell und keine Regeln in `permissions`. Nach `/opt/aios` schreibt es nur mit `aios --install --system` (Spec 04). |
| I14 | Eine Bindung `aios:` und eine Markierung `legacy:` gelten nur an der Vault-Root; in einem Projekt werden sie mit Warnung übergangen (Spec 04). |

## Abnahmetest

Der Abnahmetest von v0.6.2 läuft auf dem Arbeitsrechner nach der Implementierung, auf dem letzten Release-Kandidaten `v0.6.2-rc<n>` (V0.6, Memo 122); `distribution-capricorn` hat Kandidaten `0.4.0-rc<n>` mit derselben Nummer und `kernel: "==0.6.2-rc<n>"`, `skill-cleanup` eigene Kandidaten `0.1.1-rc<m>`, die Capricorn mit `==` nennt (F91). An den Kandidaten gebunden werden nur `~/vault/§Probe-AIBOS` (mit dem Probe-Projekt `P-Probe`) und `~/vault/§Probe-Capricorn`; die übrigen Vaults bleiben bis Schritt 13 auf 0.6.1. `/cleanup` wird im Testprojekt `MSC-Cleanup/MSCP-Probe-Cleanup` im Vault `§AIOS` auf 0.6.1 abgenommen (F96).

**Headless:** Die Schritte im Chat (7, 9, 10) laufen als Headless-Sessions: `claude -p "<prompt>" --setting-sources project --settings <nur die Hooks aus ~/.claude/settings.json> --output-format json`, über mehrere Züge mit `--resume`; Modus „Manuell" entspricht `--permission-mode default`. Abgelehnte Aufrufe stehen in `permission_denials`; geprüft wird im JSON und im Transkript (V0.6, Memos 139, 141). Was nur mit den Sitzungswerkzeugen der Desktop-App geht (Testsitzungen archivieren), bleibt headless ungeprüft.

Die Abnahmetests von v0.6.1, v0.6.0 und v0.5 stehen in dieser Spec in den Tags `v0.6.1`, `v0.6.0` bzw. `v0.5.1`.

| # | Schritt | erwartet |
|---|---|---|
| 1 | `~/git/AIbex/aibex-aios/bin/aios --install v0.6.2-rc<n> --plan`, dann mit Ja | Kernel nach `~/.aios/versions/v0.6.2-rc<n>/`; Weiterleiter und Hooks unverändert; nichts in `~/bin` |
| 2 | `aios --vaults` | alle Vault-Wurzeln unter `~/vault/` und `§Obsidian/`, an 0.6.1 gebunden, je mit Quelle; `§Obsidian` mit `above`, `§BrainLab`, `§KI-Kit`, `§Lisa` mit `beside`, auch ohne Merker (H8) |
| 3 | `aios --activate v0.6.2-rc<n> ~/vault/§Probe-AIBOS` mit Ja | Bindung `0.6.2-rc<n>`; Hüllen in `.aios/registry` mit `source` Kernel `0.6.2-rc<n>`; Pakete unverändert |
| 4 | `aios --activate v0.6.2-rc<n> "<Google Drive>/Meine Ablage/§Obsidian" --plan` (nur der Plan) | `register the wrappers of the kernel skills in 1 projects of …/§Obsidian`: nur die Vault-Root, nicht die Projekte der Vaults darin (H7, B20; vorher 104 Projekte, V0.6, Memo 111) |
| 5 | `aios --activate v0.6.2-rc<n> ~/vault/§Probe-Capricorn --plan`, dann mit Ja | der Plan nennt `distribution-capricorn` 0.3.0 mit `kernel: "==0.6.1"` und `aios --install distribution-capricorn` (H5); Bindung `0.6.2-rc<n>` (F95) |
| 6 | in `§Probe-AIBOS`: `aios --remove-version v0.6.1 --plan` (nur der Plan) | der Plan nennt die Vault-Wurzeln, die noch an 0.6.1 hängen (H6); der Weiterleiter wählt die höchste installierte Version (B21), auch aus einem Vault an 0.6.1 |
| 7 | headless in `P-Probe` (Anja zugeordnet): „Was sagt Spec 02 zur Freigabe von Read? Lies dazu die Spec der AIOS-Version, an die dieser Vault gebunden ist." | Anja findet den Dateinamen über `doc/README.md` (B22) und liest `~/.aios/versions/v0.6.2-rc<n>/doc/spec/02 Master-Kontext.md`; `permission_denials` ohne `Read` (H9) |
| 8 | in `§Probe-Capricorn`: `aios --hubs add aibex-local file://<MSC-Cleanup>/@Package --vault` mit Ja | Hub-Liste der Vault-Root `aibex-aios`, `aibex-local` (F94) |
| 9 | `aios --install "distribution-capricorn==0.4.0-rc<n>" ~/vault/§Probe-Capricorn --from ~/git/AIbex/distribution-capricorn --plan`, dann mit Ja; danach headless in `§Probe-Capricorn`: Skill `cleanup`, Assistenten, Version des Master-Kontexts | Upgrade auf `0.4.0-rc<n>`; `assistant-anja` 0.2.1 → 0.3.0; neu `skill-cleanup` `0.1.1-rc<m>` aus `aibex-local`; übrige Pakete unverändert; headless: `cleanup` verfügbar, `anja` 0.3.0, Master-Kontext `0.6.2-rc<n>` |
| 10 | in `MSCP-Probe-Cleanup`: `aios --fetch "skill-cleanup==0.1.1-rc<m>" --from <MSC-Cleanup>/@Package/skill-cleanup` im Testprojekt, Ausgangslage A1 der Paket-Spec, dann A1b–A9 headless | wie in der Paket-Spec `MSC-Cleanup/@Spec/01`; Archivieren der Testsitzung nur interaktiv |
| 11 | `tests/run`, `tests/live/fresh.sh`, `permit.sh`, `rothirsch.sh`, `changeover.sh` | alle grün |
| 12 | Bestandslauf: je Vault aus `aios --vaults` `aios --activate v0.6.2-rc<n> <vault> --plan`; Hooks, `~/.claude/skills/`, `workers.yaml`, `installations.yaml` | keine Konflikte; Tabelle im Abnahme-Memo |
| 13 | nach Freigabe: Tags `v0.6.2`, `skill-cleanup` `v0.1.1`, `distribution-capricorn` `v0.4.0`; `aios --install v0.6.2`; Probe-Vaults umbinden; mit eigener Frage die übrigen Vaults; `aios --remove-version v0.6.2-rc<n>` und, wenn kein Vault mehr daran hängt, `v0.6.1` | Bindung `0.6.2`; keine Hülle verweist auf einen Kandidaten |
| 14 | Veröffentlichen, jeder Schritt mit eigener Rückfrage: `skill-cleanup` im Hub, Kernel `v0.6.2` mit Konzept-Tag auf dem Abnahme-Memo, `distribution-capricorn` `v0.4.0`; dann `aios --hubs remove aibex-local --vault` in `§Probe-Capricorn` und Probe gegen den Hub | alles aus dem Hub holbar; `lock.yaml` ohne `aibex-local` |

## Offen

| # | Punkt | vorläufige Festlegung für v0.6 |
|---|---|---|
| O1 | Wirkt `/reload-skills` in einer interaktiven Session auf Skills, die nach dem Start angelegt wurden? | Getestet (V0.1, Memo 16): Ein beim Session-Start angelegter Skill ist erst im nächsten Chat verfügbar; die Registrierung ist darauf ausgelegt (Spec 03). Offen ist nur `/reload-skills` |
| O2 | Detailregeln der Klassen | siehe Spec 02, *Vorläufige Regeln der Klassen* |
| O4 | Stehen HTML-Oberflächen im Chat in jeder Installation der Desktop-App bereit? (V0.3, Memo 10, 25, 31) | Geprüft: in der Desktop-App vorhanden, in Headless-Sessions und der CLI nicht. Ohne HTML-Oberfläche zeigen `/gui` und `/aios-gui` das Menü der CLI |
| O5 | Löst der Host `~` in `allowed-tools` und im Rumpf einer Hülle auf? (V0.6, Memo 29) | Die Hülle trägt den absoluten Pfad des Weiterleiters, den AIBOS beim Registrieren einsetzt (Spec 03); der Abnahmetest (Schritt 9) prüft es |
| O6 | Wirkt ein Wechsel des Arbeitsverzeichnisses mit `/cd` wie der Wechsel über die Desktop-App, und wie stark wirkt der Verlauf nach dem Verlassen eines A/W nach? (V0.6, Memo 31) | AIBOS gibt nach dem Wechsel nach außen nichts mehr aus (I12); den Verlauf entfernt es nicht |
