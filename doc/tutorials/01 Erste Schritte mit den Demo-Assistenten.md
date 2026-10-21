# Erste Schritte mit den Demo-Assistenten

Dieses Tutorial führt in etwa 20 Minuten durch einen kleinen Vault mit zwei Projekten und den beiden Demo-Assistenten von AIbex AIOS: dem **Gärtner**, der nur mit Äpfeln und Birnen rechnet, und dem **Astronomen**, der nur mit Sonne und Mond rechnet. Am Ende weißt du, wie ein Chat sein Wissen bekommt, wie Assistenten als Pakete geholt und einem Projekt zugeordnet werden, warum ein Assistent nur in seinem Teil des Vaults sichtbar ist und wie du seine Oberfläche öffnest.

Voraussetzung: AIOS v0.4 ist installiert (`aios --install v0.4.0`, siehe README) und Claude Code läuft als Desktop-App oder CLI.

## 1. Vault anlegen und aktivieren

Ein Vault ist ein Verzeichnis, dessen Name mit `§` beginnt. Lege ihn an und binde ihn an AIOS:

```bash
mkdir -p ~/tmp/§Demo
aios --activate v0.4.0 ~/tmp/§Demo
```

`aios --activate` zeigt einen Plan und fragt nach. Danach gibt es `§Demo/.aios/config.yaml` mit `aios: 0.4.0`, den **Root-Masterspace** `§Demo/@/` und ein Git-Repo mit einem ersten Commit: Die Vault-Root ist das Root-Projekt.

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

Die Aufstellung zeigt die Kette `§Demo → G-Garten`, die Zeile *Assistant* `none (no assignment)` und `stil.md` als geladene Datei.

## 3. Pakete im Hub

Skills, Assistenten, Wissen und Apps kommen als **Pakete** aus einem **Hub**, einer GitHub-Organisation. Der Standard-Hub ist `aibex-aios`. Suche darin nach Assistenten:

```bash
aios --library assistent
```

```
aibex-aios/assistent-astronom  assistant     Demo-Assistent Astronom, rechnet nur mit Sonne und Mond, nennt Sterndaten
aibex-aios/assistent-gaertner  assistant     Demo-Assistent Gärtner, rechnet nur mit Äpfeln und Birnen
```

Der Name eines Pakets nennt seine Art: `assistent-…`, `skill-…`, `knowledge-…`, `app-…`. Ein Paket wird nicht automatisch verwendet; du **holst** es in ein Projekt. Mehr über Pakete und Hubs zeigt Tutorial *03 Pakete und Taschenrechner*.

## 4. Den Gärtner holen

Den Gärtner sollen alle Projekte des Vaults nutzen können, deshalb kommt er in das Root-Projekt. Im Chat:

```
/aios-fetch assistent-gaertner
```

Der Skill fragt nach dem Ziel und schlägt das Root-Projekt vor, zeigt den Plan und holt nach deinem Ja. Dasselbe auf der Kommandozeile, zuerst nur der Plan:

```bash
aios --fetch assistent-gaertner --to ~/tmp/§Demo --plan
```

```
=> fetch assistent-gaertner into ~/tmp/§Demo
   plan:
      new        assistent-gaertner 0.2.0 (aibex-aios) -> ~/tmp/§Demo/@/@!Package/assistent-gaertner
      ~/tmp/§Demo/.aios/config.yaml: packages: assistent-gaertner: "~=0.2.0"
      ~/tmp/§Demo/.aios/lock.yaml: 1 packages
      register the project skills of ~/tmp/§Demo
   (plan only, nothing written)
```

Ohne `--plan` fragt `aios` einmal nach und meldet dann:

```
=> packages of ~/tmp/§Demo: assistent-gaertner 0.2.0
   assign the assistant to a project of the chain with /aios-assistant Gärtner
   new skills are available from the next chat (or after /reload-skills)
```

Danach liegt das Paket in `§Demo/@/@!Package/assistent-gaertner/`, und `§Demo/.aios/config.yaml` enthält:

```yaml
aios: 0.4.0
packages:
  assistent-gaertner: "~=0.2.0"
```

`~=0.2.0` heißt: 0.2.0 oder eine neuere 0.2.x. Welche Version und welcher Commit genau geholt wurden, steht in `.aios/lock.yaml`; `aios --fetch` ohne Argument stellt diesen Stand wieder her, auch auf einem anderen Rechner.

Schau dir den Ordner `assistants/gaertner/` im Paket an: `ASSISTANT.md` mit Rollentext und Grenzen, die privaten Skills `@!Skill/apfel-birnen-algebra/` und `@!Skill/gaertner-gui/` (seine Oberfläche), das Wissen `@Wissen/` mit den Grundlagen (geladen) sowie Sortenkunde und Veredelung (verfügbar). Die Datei `.aios-deploy` merkt sich Version und Prüfsumme; änderst du das Paket direkt, meldet `aios --fetch` das beim nächsten Abgleich.

Geholt heißt noch nicht zugeordnet: Der Gärtner steht bereit, antwortet aber erst, wenn ein Projekt ihn als Assistenten hat.

## 5. Den Gärtner dem Garten zuordnen

In einem Chat in `G-Garten`:

```
/aios-assistant Gärtner: Erste Schritte
```

Der Skill zeigt den Plan `project G-Garten: no assistant → Gärtner` und fragt einmal nach. Nach deinem Ja steht in `G-Garten/.aios/config.yaml` die Zeile `assistant: gaertner`, der Gärtner meldet sich („Gärtner aktiv"), und der Chat bekommt den Titel „Erste Schritte". Probiere:

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
aios --fetch assistent-astronom --to ~/tmp/§Demo/S-Sternwarte
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
| Vault, Aktivierung | `§Demo`, `aios --activate v0.4.0` |
| Projekt, Kette, Name | `G-Garten`, `S-Sternwarte`; ein Chat sieht von der Vault-Root bis zu seinem Projekt |
| Klassen | `@Rule` geladen, `@@Sortenkunde` verfügbar, `@!Assistant` verborgen |
| Paket, Hub, Holen | `aios --library assistent`, `/aios-fetch assistent-gaertner`, `packages:` und `lock.yaml` |
| Zuordnung | `/aios-assistant Gärtner` schreibt `assistant: gaertner`; neue Chats laden ihn, Unterprojekte erben ihn |
| Oberfläche | `/gui` (Gärtner), `/aios-gui` (AIOS) |
| Version | jeder Skill und Assistent trägt `version:`; ohne Version wird er nicht verwendet und gemeldet |

## Weiter

- Tutorial *02 Projekte und Integrität*: Unterprojekte, Konsistenzprüfung und `/aios-integrity`.
- Schreib einen eigenen Skill in `§Demo/@/@!Skill/<name>/SKILL.md` mit `name`, `version: 0.1.0` und `description`. Er wird beim nächsten Chat-Start registriert und ist in jedem Projekt des Vaults aufrufbar. Fehlt `version`, meldet der Start ein `AIOS-WARNING`.
- Tutorial *03 Pakete und Taschenrechner*: Hubs, Versionen, Ausrollen einzelner Elemente, die Demo-App und der Rückfluss.
- Tutorial *04 Workspaces*: mehrere Repos als Projekte eines Wurzelprojekts.
- Zum Aufräumen: `aios --deactivate ~/tmp/§Demo` schaltet AIOS für den Vault wieder aus; die Dateien bleiben.

Die vollständigen Regeln stehen in der Spec, installiert unter `/opt/aios/v0.4.0/doc/spec/`.
