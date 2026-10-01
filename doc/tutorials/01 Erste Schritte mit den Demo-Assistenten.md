# Erste Schritte mit den Demo-Assistenten

Dieses Tutorial führt in etwa 20 Minuten durch einen kleinen Vault mit zwei Projekten und den beiden Demo-Assistenten von AIbex AIOS: dem **Gärtner**, der nur mit Äpfeln und Birnen rechnet, und dem **Astronomen**, der nur mit Sonne und Mond rechnet. Am Ende weißt du, wie ein Chat sein Wissen bekommt, wie Assistenten ausgerollt und aktiviert werden und warum ein Assistent nur in seinem Teil des Vaults sichtbar ist.

Voraussetzung: AIOS v0.2 ist installiert (`aios --install v0.2.0`, siehe README) und Claude Code läuft als Desktop-App oder CLI.

## 1. Vault anlegen und aktivieren

Ein Vault ist ein Verzeichnis, dessen Name mit `§` beginnt. Lege ihn an und binde ihn an AIOS:

```bash
mkdir -p ~/tmp/§Demo
aios --activate v0.2.0 ~/tmp/§Demo
```

`aios --activate` zeigt einen Plan und fragt nach. Danach gibt es `§Demo/.aios/config.yaml` mit `aios: 0.2.0` und den **Root-Masterspace** `§Demo/@/`.

Lege eine Regel an, die jeder Chat im Vault laden soll:

```bash
mkdir -p ~/tmp/§Demo/@/@Rule
printf '# Stil\nAntworte kurz und auf Deutsch.\n' > ~/tmp/§Demo/@/@Rule/stil.md
```

Ordner mit `@` werden **geladen**, Ordner mit `@@` sind **verfügbar** (nur ein Inhaltsverzeichnis wird geladen, der Rest bei Bedarf gelesen), Ordner mit `@!` sind **verborgen** (Blueprints von Skills und Assistenten).

## 2. Zwei Projekte

Ein Projekt ist ein Ordner mit `@/`. Lege den Ordner `Garten` an und öffne darin einen Chat:

```bash
mkdir ~/tmp/§Demo/Garten
```

AIOS meldet, dass `Garten` noch kein Projekt ist, und bietet an, es zu initialisieren. Wähle **initialisieren**; `/aios-init` legt `@/`, `@Memo/`, `.gitignore` und ein Git-Repo an. Mach dasselbe mit `~/tmp/§Demo/Sternwarte`.

Ein Chat sieht immer die **Master-Space-Kette**: die Masterspaces von der Vault-Root bis zu seinem Projekt. Ein Chat in `Garten` sieht also `§Demo/@/` und `Garten/@/`, aber nicht `Sternwarte/@/`. Prüfe das in einem neuen Chat in `Garten`:

```
/aios-context
```

Die Aufstellung zeigt die Kette `§Demo → Garten` und `stil.md` als geladene Datei.

## 3. Die Bibliothek

Jede AIOS-Version bringt eine Bibliothek mit:

```bash
aios --library
```

```
memo                     skill      6.0.0
astronom                 assistant  0.1.0
gaertner                 assistant  0.1.0
```

Skills und Assistenten der Bibliothek werden nicht automatisch verwendet; du **rollst sie aus**, also kopierst eine bestimmte Version in einen Masterspace und trägst sie ins Manifest ein.

## 4. Den Gärtner ausrollen

Den Gärtner sollen alle Projekte des Vaults nutzen können, deshalb kommt er in das Root-Projekt. Im Chat:

```
/aios-deploy gaertner==0.1.0
```

Der Skill fragt nach dem Ziel und schlägt das Root-Projekt vor, zeigt den Plan und rollt nach deinem Ja aus. Dasselbe auf der Kommandozeile:

```bash
aios --deploy gaertner==0.1.0 --to ~/tmp/§Demo
```

Danach liegt der Gärtner in `§Demo/@/@!Assistant/gaertner/`, und `§Demo/.aios/config.yaml` enthält:

```yaml
aios: 0.2.0
assistants:
  gaertner: 0.1.0
```

Schau dir den Ordner an: `ASSISTANT.md` mit Rollentext und Grenzen, der private Skill `@!Skill/apfel-birnen-algebra/`, das Wissen `@Wissen/` mit den Grundlagen (geladen) sowie Sortenkunde und Veredelung (verfügbar). Die Datei `.aios-deploy` merkt sich Version und Prüfsumme; änderst du den Gärtner direkt, meldet `/aios-deploy` das beim nächsten Abgleich.

## 5. Mit dem Gärtner sprechen

In einem Chat in `Garten`:

```
/aios-assistant Gärtner: Erste Schritte
```

Der Gärtner meldet sich, und der Chat bekommt den Titel „Erste Schritte“. Probiere:

| Frage | Was du sehen solltest |
|---|---|
| Was ist Apfel * Birne? | **Apfel**, mit Rechenweg (Dominanz) — sein Skill `apfel-birnen-algebra` |
| Was ist ¬Apfel * Birne? | **Birne** |
| Was ist Mond * Mond? | eine freundliche Absage: Mond gibt es in seinem Garten nicht |
| Wann ist der Elstar genussreif? | September bis Januar, mit Verweis auf die Sortenkunde, die er dafür erst liest |

Die letzte Frage zeigt verfügbares Wissen: Die Sortenkunde stand nicht im Kontext, nur ihr Eintrag im Inhaltsverzeichnis. Der Gärtner hat sie bei Bedarf gelesen.

Die Aktivierung gilt bis zum Ende des Chats. Nach einer Compaction oder in einem neuen Chat aktivierst du ihn erneut.

## 6. Den Astronomen in die Sternwarte

Der Astronom soll nur in der Sternwarte arbeiten, deshalb kommt er in dieses Projekt:

```bash
aios --deploy astronom==0.1.0 --to ~/tmp/§Demo/Sternwarte
```

In einem Chat in `Sternwarte`:

```
/aios-assistant Astronom
```

Frage ihn nach **Mond · Mond** (Antwort: **−Sonne**) und nach **Apfel * Birne** (freundliche Absage). Auch der Gärtner ist hier verfügbar, denn er liegt im Root-Projekt und damit in der Kette jedes Projekts.

Öffne nun einen Chat in `Garten` und versuche `/aios-assistant Astronom`: AIOS findet keinen Astronomen und listet nur den Gärtner. Die Sternwarte gehört nicht zur Kette des Gartens.

## 7. Was du gesehen hast

| Begriff | im Tutorial |
|---|---|
| Vault, Aktivierung | `§Demo`, `aios --activate v0.2.0` |
| Projekt, Kette | `Garten`, `Sternwarte`; ein Chat sieht von der Vault-Root bis zu seinem Projekt |
| Klassen | `@Rule` geladen, `@@Sortenkunde` verfügbar, `@!Assistant` verborgen |
| Bibliothek, Ausrollen | `aios --library`, `/aios-deploy gaertner==0.1.0`, Manifest `assistants:` |
| Assistent | `/aios-assistant Gärtner`: Rollentext, Wissen und Skill im Chat, ohne Zustand |
| Version | jeder Skill und Assistent trägt `version:`; ohne Version wird er nicht verwendet und gemeldet |

## Weiter

- Schreib einen eigenen Skill in `§Demo/@/@!Skill/<name>/SKILL.md` mit `name`, `version: 0.1.0` und `description`. Er wird beim nächsten Chat-Start registriert und ist in jedem Projekt des Vaults aufrufbar. Fehlt `version`, meldet der Start ein `AIOS-WARNING`.
- Gib dem Gärtner einen weiteren Skill: `aios --deploy memo==6.0.0 --assistant gaertner --to ~/tmp/§Demo`.
- Zum Aufräumen: `aios --deactivate ~/tmp/§Demo` schaltet AIOS für den Vault wieder aus; die Dateien bleiben.

Die vollständigen Regeln stehen in der Spec, installiert unter `/opt/aios/v0.2.0/doc/spec/`.
