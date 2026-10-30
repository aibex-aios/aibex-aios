# Erste Schritte mit den Demo-Assistenten

Dieses Tutorial führt in etwa 20 Minuten durch einen kleinen Vault mit zwei Projekten und den beiden Demo-Assistenten von AIbex AIOS: dem **Gärtner**, der nur mit Äpfeln und Birnen rechnet, und dem **Astronomen**, der nur mit Sonne und Mond rechnet. Am Ende weißt du, wie ein Chat sein Wissen bekommt, wie Assistenten als Pakete geholt und einem Projekt zugeordnet werden, warum ein Assistent nur in seinem Teil des Vaults sichtbar ist und wie du seine Oberfläche öffnest.

Voraussetzung: AIBOS v0.6 ist installiert (`aios --install v0.6.0`, siehe README) und Claude Code läuft als Desktop-App oder CLI. Die Beispiele schreiben `aios`; steht `~/.aios/bin` nicht in deinem `PATH`, rufe `~/.aios/bin/aios` auf.

Starte jeden Chat direkt im Ordner des Projekts. Legt die Desktop-App für den Chat eine Arbeitskopie an (`.claude/worktrees/<name>/` auf einem eigenen Branch), landen die Ergebnisse auf diesem Branch und erscheinen erst nach dem Übernehmen (Merge) im Ordner. AIOS erkennt das beim Start: Claude sagt es dir vor der ersten Arbeit und bietet danach das Übernehmen an.

## 1. Vault anlegen und aktivieren

Ein Vault ist ein Verzeichnis, dessen Name mit `§` beginnt. Lege ihn an und binde ihn an AIBOS; damit wird er ein **AIBOS-Workspace** (A/W):

```bash
mkdir -p ~/tmp/§Demo
aios --activate v0.6.0 ~/tmp/§Demo
```

```
=> activate AIOS v0.6.0 for ~/tmp/§Demo
=> ~/tmp/§Demo runs with AIOS 0.6.0 (~/tmp/§Demo/.aios/config.yaml)
   the master context and the skill registration apply from the next chat
```

`aios --activate` zeigt einen Plan und fragt nach. Danach gibt es `§Demo/.aios/config.yaml` mit `aios: 0.6.0`, den **Root-Masterspace** `§Demo/@/` und ein Git-Repo mit einem ersten Commit: Die Vault-Root ist das Root-Projekt. Gebunden wird nur an der Vault-Root; ein `aios:` in einem Projekt übergeht AIBOS mit einer Warnung.

Die Aktivierung registriert auch die **Kernel-Skills** (`/aios-init`, `/aios-context`, …) und `/gui` als dünne Hüllen in `.claude/skills/` der Vault-Root und jedes Projekts; der Master-Kontext jedes Chats im Vault nennt sie im Block `<aios-kernel-skills>`. Außerhalb eines A/W gibt es sie nicht, und ein Aufruf von Hand sagt nur:

```bash
cd ~/tmp && aios --skill aios-status
```

```
Kein AIBOS-Workspace: ~/tmp
```

Außerhalb eines A/W verhält sich Claude, als wäre AIBOS nicht installiert.

Lege eine Regel an, die jeder Chat im Vault laden soll:

```bash
mkdir -p ~/tmp/§Demo/@/@Rule
printf '# Stil\nAntworte kurz und auf Deutsch.\n' > ~/tmp/§Demo/@/@Rule/stil.md
```

Ordner mit `@` werden **geladen**, Ordner mit `@@` sind **verfügbar** (nur ein Inhaltsverzeichnis wird geladen, der Rest bei Bedarf gelesen), Ordner mit `@!` sind **verborgen** (Blueprints von Skills und Assistenten).

## 2. Zwei Projekte

Ein Projekt ist ein Ordner mit `@/` und einem eigenen Git-Repo. Lege den Ordner `G-Garten` an und öffne darin einen Chat:

```bash
mkdir ~/tmp/§Demo/G-Garten
```

AIOS meldet, dass `G-Garten` noch kein Projekt ist, und zeigt den Dialog *Projekt initialisieren* mit Titel, Assistent und Anlegen. Wähle beim Assistenten `inherit` und dann **initialisieren**: `/aios-init` legt `@/`, `.gitignore` und ein Git-Repo an und trägt `/G-Garten/` in die `.gitignore` des Root-Projekts ein. Mach dasselbe mit `~/tmp/§Demo/S-Sternwarte`.

Der Name folgt einer Regel: ein **Prefix** aus Großbuchstaben, dann Namensteile mit `-`. Direkt unter der Vault-Root ist der Prefix ein Großbuchstabe (`G`, `S`), darunter der Prefix des übergeordneten Projekts plus ein Buchstabe oder eine Zahl (`GB-Beet`, `G1-…`). Für `garten` würde `/aios-init` `G-Garten` vorschlagen.

Ein Chat sieht immer die **Master-Space-Kette**: die Masterspaces von der Vault-Root bis zu seinem Projekt. Ein Chat in `G-Garten` sieht also `§Demo/@/` und `G-Garten/@/`, aber nicht `S-Sternwarte/@/`. Prüfe das in einem neuen Chat in `G-Garten`:

```
/aios-context
```

Die Aufstellung zeigt die Kette `§Demo → G-Garten`, die Zeile *Assistant* `none (no assignment)` und `stil.md` als geladene Datei:

```
Master context id ab6e7ddf, AIOS 0.6.0 — G-Garten

Chain                      §Demo → G-Garten
Assistant                  none (no assignment)

Master context (loaded)    1 file, 2,179 characters
  §Demo/@/@Rule/stil.md
Available knowledge        0 files
Hidden                     Blueprints: 0 skills, 1 assistant, 0 prompts
  Assistants   gaertner 0.3.1 (§Demo, package assistant-gaertner)
Packages                   1 package
  assistant-gaertner 0.3.1 (aibex-aios, §Demo) — assistants gaertner
```

(Die Aufstellung oben stammt aus einem Vault, in dem der Gärtner schon geholt ist, Abschnitt 4; die id hängt vom Pfad ab.)

## 3. Pakete im Hub

Skills, Assistenten, Wissen und Apps kommen als **Pakete** aus einem **Hub**, einer GitHub-Organisation. Der Standard-Hub ist `aibex-aios`. Suche darin nach Assistenten:

```bash
aios --library assistant
```

```
aibex-aios/assistant-anja      assistant     Assistentin Anja, Spezialistin für die Entwicklung von AIOS-Paketen aller Typen
aibex-aios/assistant-astronom  assistant     Demo-Assistent Astronom, rechnet nur mit Sonne und Mond, nennt Sterndaten aus verfügbarem Wissen
aibex-aios/assistant-gaertner  assistant     Demo-Assistent Gärtner, rechnet nur mit Äpfeln und Birnen, mit Oberfläche
```

Der Name eines Pakets nennt seine Art: `assistant-…`, `skill-…`, `knowledge-…`, `app-…`, `worker-…`, `distribution-…`. Bis v0.4 hießen die Assistenten `assistent-…`; `aios --activate v0.6.0` stellt einen älteren Vault um. Ein Paket wird nicht automatisch verwendet; du **holst** es in ein Projekt. Mehr über Pakete und Hubs zeigt Tutorial *03 Pakete und Taschenrechner*.

## 4. Den Gärtner holen

Den Gärtner sollen alle Projekte des Vaults nutzen können, deshalb kommt er in das Root-Projekt. Im Chat:

```
/aios-fetch assistant-gaertner
```

Der Skill fragt nach dem Ziel und schlägt das Root-Projekt vor, zeigt den Plan und holt nach deinem Ja. Dasselbe auf der Kommandozeile, zuerst nur der Plan:

```bash
aios --fetch assistant-gaertner --to ~/tmp/§Demo --plan
```

```
=> fetch assistant-gaertner into ~/tmp/§Demo
   plan:
      back up what the plan changes -> ~/tmp/§Demo/.aios/backup
      new        assistant-gaertner 0.3.1 (aibex-aios) -> ~/tmp/§Demo/@/@!Package/assistant-gaertner
      ~/tmp/§Demo/.aios/config.yaml: packages: assistant-gaertner: "~=0.3.1"
      ~/tmp/§Demo/.aios/lock.yaml: 1 packages
      register the skills of ~/tmp/§Demo
      remove the backup
   (plan only, nothing written)
```

Jeder Plan sichert zuerst, was er ändert, und entfernt die Sicherung erst nach Erfolg: Scheitert ein Schritt, ist der Stand wie vorher (alles oder nichts).

Ohne `--plan` fragt `aios` einmal nach und meldet dann:

```
=> packages of ~/tmp/§Demo: assistant-gaertner 0.3.1
   assign the assistant to a project of the chain with /aios-assistant Gärtner
   new skills are available from the next chat (or after /reload-skills)
```

Danach liegt das Paket in `§Demo/@/@!Package/assistant-gaertner/`, und `§Demo/.aios/config.yaml` enthält:

```yaml
aios: 0.6.0
packages:
  assistant-gaertner: "~=0.3.1"
```

`~=0.3.1` heißt: 0.3.1 oder eine neuere 0.3.x. Welche Version und welcher Commit genau geholt wurden, steht in `.aios/lock.yaml`; `aios --fetch` ohne Argument stellt diesen Stand wieder her, auch auf einem anderen Rechner.

Schau dir den Ordner `assistants/gaertner/` im Paket an: `ASSISTANT.md` mit Rollentext und Grenzen, die privaten Skills `@!Skill/apfel-birnen-algebra/` und `@!Skill/gaertner-gui/` (seine Oberfläche), das Wissen `@Wissen/` mit den Grundlagen (geladen) sowie Sortenkunde und Veredelung (verfügbar). Die Datei `.aios-deploy` merkt sich Version und Prüfsumme; änderst du das Paket direkt, meldet `aios --fetch` das beim nächsten Abgleich.

Geholt heißt noch nicht zugeordnet: Der Gärtner steht bereit, antwortet aber erst, wenn ein Projekt ihn als Assistenten hat.

## 5. Den Gärtner dem Garten zuordnen

In einem Chat in `G-Garten`:

```
/aios-assistant Gärtner: Erste Schritte
```

Der Skill zeigt den Plan `project G-Garten: no assistant → Gärtner` und fragt einmal nach. Nach deinem Ja steht in `G-Garten/.aios/config.yaml` die Zeile `assistant: gaertner`, der Gärtner meldet sich („👩‍🌾 Gärtner aktiv"; jede seiner Antworten beginnt mit 👩‍🌾, die des Astronomen mit 💫), und bittet dich, den Chat in „Erste Schritte" umzubenennen (den Titel setzt nur die App). Probiere:

| Frage | Was du sehen solltest |
|---|---|
| Was ist Apfel * Birne? | **Apfel**, mit Rechenweg (Dominanz) — sein Skill `apfel-birnen-algebra` |
| Was ist ¬Apfel * Birne? | **Birne** |
| Was ist Mond * Mond? | eine freundliche Absage: Mond gibt es in seinem Garten nicht |
| Wann ist der Elstar genussreif? | September bis Januar, mit Verweis auf die Sortenkunde, die er dafür erst liest |

Die letzte Frage zeigt verfügbares Wissen: Die Sortenkunde stand nicht im Kontext, nur ihr Eintrag im Inhaltsverzeichnis. Der Gärtner hat sie bei Bedarf gelesen.

Die Zuordnung ist eine **Eigenschaft des Projekts**: Öffne einen neuen Chat in `G-Garten`, und der Gärtner ist ohne weiteren Aufruf da. Auch nach einer Compaction oder beim Fortsetzen eines Chats bleibt er. Unterprojekte von `G-Garten` erben ihn, solange sie nichts anderes festlegen (`inherit`).

## 6. Die Oberfläche des Gärtners

In einem Chat mit dem Gärtner:

```
/gui
```

In der Desktop-App erscheint die Oberfläche des Gärtners im Chat: der **Apfel-Birnen-Rechner**, der ohne Claude rechnet, und Kacheln für „Aufgabe rechnen", „Sorte bestimmen" und „Sortenkunde". In der CLI zeigt Claude dieselben Kacheln als Menü; der Rechner fehlt dort, weil er eine HTML-Oberfläche braucht.

`/aios-gui` zeigt die Oberfläche von AIOS selbst: Projekt initialisieren, Kontext und Konfiguration, Assistent zuordnen, Pakete, Apps, Pakete abgleichen und Skills registrieren, Integrität prüfen, Projektstatus und Memo schreiben.

## 7. Den Astronomen in die Sternwarte

Der Astronom soll nur in der Sternwarte arbeiten, deshalb kommt er in dieses Projekt:

```bash
aios --fetch assistant-astronom --to ~/tmp/§Demo/S-Sternwarte
```

In einem Chat in `S-Sternwarte`:

```
/aios-assistant Astronom
```

Frage ihn nach **Mond · Mond** (Antwort: **−Sonne**), nach **Apfel * Birne** (freundliche Absage) und nach der Helligkeit von Beteigeuze: Er schlägt im Wissen nach und sagt, dass er dazu nichts findet, statt Werte zu erfinden. Die Sterndaten bringt das Paket `knowledge-orion` (Tutorial 03). `/gui` meldet: `The assistant Astronom has no surface.` Auch der Gärtner ist hier verfügbar, denn er liegt im Root-Projekt und damit in der Kette jedes Projekts.

Öffne nun einen Chat in `G-Garten` und versuche `/aios-assistant Astronom`: AIOS findet keinen Astronomen und listet nur den Gärtner. Die Sternwarte gehört nicht zur Kette des Gartens.

Willst du einen Assistenten nur ausprobieren, ohne die Zuordnung eines Projekts zu ändern, leg dafür ein Unterprojekt an, z. B. `G-Garten/GT-Test`, und ordne ihn dort zu. `/aios-assistant --none` legt die Rolle ab, `/aios-assistant --inherit` übernimmt wieder den Assistenten des übergeordneten Projekts.

## 8. Was du gesehen hast

| Begriff | im Tutorial |
|---|---|
| Vault, A/W, Aktivierung | `§Demo`, `aios --activate v0.6.0`; außerhalb eines A/W kein AIBOS |
| Projekt, Kette, Name | `G-Garten`, `S-Sternwarte`; ein Chat sieht von der Vault-Root bis zu seinem Projekt |
| Klassen | `@Rule` geladen, `@@Sortenkunde` verfügbar, `@!Assistant` verborgen |
| Paket, Hub, Holen | `aios --library assistant`, `/aios-fetch assistant-gaertner`, `packages:` und `lock.yaml` |
| Zuordnung | `/aios-assistant Gärtner` schreibt `assistant: gaertner`; neue Chats laden ihn, Unterprojekte erben ihn |
| Oberfläche | `/gui` (Gärtner), `/aios-gui` (AIOS) |
| Version | jeder Skill und Assistent trägt `version:`; ohne Version wird er nicht verwendet und gemeldet |

## Weiter

- Tutorial *02 Projekte und Integrität*: Unterprojekte, Konsistenzprüfung und `/aios-integrity`.
- Schreib einen eigenen Skill in `§Demo/@/@!Skill/<name>/SKILL.md` mit `name`, `version: 0.1.0` und `description`. Er wird beim nächsten Chat-Start registriert und ist in jedem Projekt des Vaults aufrufbar. Fehlt `version`, meldet der Start ein `AIOS-WARNING`.
- Tutorial *03 Pakete und Taschenrechner*: Hubs, Versionen, Ausrollen einzelner Elemente, die Demo-App und der Rückfluss.
- Tutorial *04 Workspaces*: mehrere Repos als Projekte eines Wurzelprojekts.
- Tutorial *05 Arbeitspferde und Distributionen*: Programme wie `yt-dlp` als Arbeitspferde und die Distribution Rothirsch.
- Zum Aufräumen: `aios --deactivate ~/tmp/§Demo` löst die Bindung; der Vault ist dann ohne Wirkung, die Dateien bleiben.

Die vollständigen Regeln stehen in der Spec, installiert unter `~/.aios/versions/v0.6.0/doc/spec/`.
