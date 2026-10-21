# Projekte und Integrität

Dieses Tutorial zeigt in etwa 15 Minuten, was zu einem Projekt gehört, wie AIOS beim Start eines Chats Lücken erkennt und wie `/aios-integrity` ein Projekt mit allen Unterprojekten prüft. Es baut auf dem Vault `~/tmp/§Demo` aus Tutorial 01 auf; ein frisch aktivierter Vault genügt aber auch.

Voraussetzung: AIOS v0.4 ist installiert, der Vault ist mit `aios --activate v0.4.0 ~/tmp/§Demo` aktiviert.

## 1. Was zu einem Projekt gehört

Ein Projekt ist ein Ordner mit `@/`. Seine **Struktur** ist vollständig, wenn vier Punkte erfüllt sind:

| # | Punkt | Bedeutung |
|---|---|---|
| S1 | lokaler Masterspace | `@/` existiert |
| S2 | eigenes Repo | das Projekt ist die Wurzel eines eigenen Git-Repos |
| S3 | `.gitignore` | enthält `.DS_Store`, `.claude/skills/` und `.aios/registry` |
| S4 | Ausschluss darüber | das nächste Repo darüber ignoriert das Projekt und versioniert keine Datei darin |

Jedes Projekt hat also ein eigenes Repo, auch jedes Unterprojekt. Der Ausschluss darüber darf breiter sein, z. B. `/P-Projekte/` für alle Projekte darunter. `@Memo/` gehört nicht zur Struktur; ihn legt der Memo-Skill beim ersten Memo an.

## 2. Ein Unterprojekt anlegen

Öffne einen Chat in einem neuen Ordner unter dem Garten:

```bash
mkdir ~/tmp/§Demo/G-Garten/beet
```

AIOS zeigt den Dialog *Projekt initialisieren*. Der Name `beet` verstößt gegen die Namensregel, deshalb fragt `/aios-init` nach: (1) mit dem Vorschlag `GB-Beet` fortfahren, (2) beim eigenen Namen bleiben oder (3) abbrechen. Wähle den Vorschlag. Weil der Chat im umbenannten Ordner liegt, musst du danach in `GB-Beet` wechseln (Desktop-App: Arbeitsverzeichnis wechseln; CLI: neu starten).

Auf der Kommandozeile geht dasselbe in zwei Schritten:

```bash
aios --init ~/tmp/§Demo/G-Garten/beet --plan
aios --init ~/tmp/§Demo/G-Garten/beet --name GB-Beet --yes
```

Der Plan nennt den Verstoß und den Vorschlag; mit `--yes` ohne `--name` oder `--accept-name` bricht `aios --init` mit Exit 2 ab, ohne zu schreiben. Danach hat `GB-Beet` `@/`, ein Repo, eine `.gitignore`, und im Repo von `G-Garten` steht `/GB-Beet/` in der `.gitignore`, mit einem eigenen Commit dort.

## 3. Die Konsistenzprüfung beim Start

Beschädige die Struktur absichtlich:

```bash
rm ~/tmp/§Demo/S-Sternwarte/.gitignore
```

Öffne einen **neuen** Chat in `S-Sternwarte`. Vor der ersten Antwort meldet AIOS `PROJECT-INCOMPLETE` mit der Lücke (`.gitignore lines: .DS_Store, .claude/skills/, .aios/registry`) und bietet an, das Projekt mit `aios --init` zu ergänzen. Sagst du nein, arbeitet der Chat normal weiter und fragt nicht noch einmal.

Die Prüfung läuft nur beim ersten Start eines Chats, nicht beim Fortsetzen oder nach einer Compaction, und nur für das Projekt des Chats. Sie schreibt nie selbst.

## 4. Integrität über alle Projekte

Ändere zusätzlich eine Datei im Garten:

```bash
printf '# Notiz\n' > ~/tmp/§Demo/G-Garten/@/notiz.md
```

Öffne einen Chat in `§Demo` und rufe auf:

```
/aios-integrity
```

Der Bericht prüft die Vault-Root und alle Projekte darunter, beliebig tief und auch durch Ordner ohne `@/` hindurch:

```
Integrity §Demo — 2026-10-21

Project         Init             Commit
§Demo           ok               ok
  G-Garten      ok               0 changed, 1 new
    GB-Beet     ok               ok
  S-Sternwarte  missing: 1 part  1 changed, 0 new

Notes
- S-Sternwarte: missing .gitignore lines: .DS_Store, .claude/skills/, .aios/registry

Result: 2 of 4 projects integer
```

| Spalte | erfüllt, wenn |
|---|---|
| Init | S1–S4 erfüllt; sonst die Zahl der fehlenden Teile, die Teile selbst stehen unter `Notes` |
| Commit | `git status` des eigenen Repos ist leer; neue Dateien zählen mit |

Ein Projekt ist **integer**, wenn beides erfüllt ist. **Hinweise** (`Notes`) ändern daran nichts: Commits, die noch nicht gepusht sind oder lokal fehlen (aus dem lokalen Stand, ohne Netz), und Namen, die gegen die Namensregel verstoßen.

Für `S-Sternwarte` bietet der Skill an, die fehlenden Teile mit `aios --init` zu ergänzen: Er zeigt den Plan, fragt einmal und prüft danach erneut. Die neue Datei im Garten nennt er nur; committen musst du selbst, denn die Commit-Nachricht gehört dir.

Auf der Kommandozeile:

```bash
aios --integrity ~/tmp/§Demo
```

endet mit Exit 0, wenn alle Projekte integer sind, sonst mit Exit 1, und eignet sich so auch für Skripte.

## 5. Was du gesehen hast

| Begriff | im Tutorial |
|---|---|
| Struktur S1–S4 | `@/`, eigenes Repo, `.gitignore`, Ausschluss im Repo darüber |
| Namensregel | `beet` → `GB-Beet`, Prefix des übergeordneten Projekts plus ein Buchstabe |
| Konsistenzprüfung | `PROJECT-INCOMPLETE` beim ersten Start eines Chats |
| Integrität | `/aios-integrity`: Init und Commit für alle Projekte, Hinweise zu Push und Namen |
| Ergänzen | `aios --init` ergänzt nur, was fehlt, und committet nur die Dateien von AIOS |

Die vollständigen Regeln stehen in Spec 05 *Projekte*, installiert unter `/opt/aios/v0.4.0/doc/spec/`.
