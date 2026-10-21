# Workspaces

Dieses Tutorial führt in etwa 15 Minuten durch Workspaces von AIbex AIOS. Ein **Workspace** ist ein Projekt, das in `.aios/workspace.yaml` weitere Repos nennt, mit Revision und Pfad. AIOS klont sie verschachtelt darunter, hält sie auf ihrer Revision und friert den Stand ein. So arbeitest du an Paketen als Git-Checkouts (Entwickler-Site), während ein Vault Pakete als Kopie in `@!Package/` hat (Anwender-Site).

Voraussetzung: AIOS v0.4 ist installiert, der Vault `~/tmp/§Demo` ist aktiviert (Tutorial 01). Die Repos des Beispiels sind die Paket-Repos des Hubs `aibex-aios`; zum Klonen genügt Lesezugriff.

## 1. Das Wurzelprojekt

Lege ein Projekt `W-Werkstatt` an:

```bash
mkdir ~/tmp/§Demo/W-Werkstatt
cd ~/tmp/§Demo/W-Werkstatt
aios --init
```

```
=> ~/tmp/§Demo/W-Werkstatt is a project
```

Schreib die Datei `.aios/workspace.yaml`:

```yaml
schema: 1
remotes:
  aibex: https://github.com/aibex-aios
projects:
  - name: app-taschenrechner
    remote: aibex
    revision: v0.4.0
    path: app-taschenrechner
  - name: skill-memo
    remote: aibex
    revision: main
    path: skill-memo
  - name: knowledge-orion
    remote: aibex
    revision: main
    path: wissen/knowledge-orion
    groups: [wissen]
```

| Feld | Bedeutung |
|---|---|
| `remotes` | Name und Basis-URL; die URL eines Projekts ist `<basis>/<name>` |
| `remote` oder `repo` | ein Remote aus `remotes` oder eine volle URL |
| `revision` | Zweig, Tag oder Commit |
| `path` | Ort unter dem Wurzelprojekt, ohne `..` |
| `groups` | Gruppen für `--group` |

Committe die Datei: `git add .aios/workspace.yaml` und `git commit -m "Workspace"`.

## 2. Klonen mit update

```bash
aios --workspace update --plan
```

```
=> update the workspace ~/tmp/§Demo/W-Werkstatt
   plan:
      clone https://github.com/aibex-aios/app-taschenrechner (v0.4.0) -> app-taschenrechner
      clone https://github.com/aibex-aios/skill-memo (main) -> skill-memo
      clone https://github.com/aibex-aios/knowledge-orion (main) -> wissen/knowledge-orion
   (plan only, nothing written)
```

Ohne `--plan` fragt `aios` einmal und klont:

```
   app-taschenrechner: cloned (v0.4.0)
   skill-memo: cloned (main)
   wissen/knowledge-orion: cloned (main)
=> workspace W-Werkstatt: 3 projects
```

Ein **Zweig** wie `main` wird ausgecheckt. Ein **Tag** oder Commit wie `v0.4.0` wird zum lokalen Zweig `ws/v0.4.0`. So gibt es nie ein *detached HEAD*, und eigene Commits haben einen Zweig. Jedes Projekt ist im Repo darüber ausgeschlossen. AIOS hat dafür je eine Zeile in `W-Werkstatt/.gitignore` eingetragen und nur diese committet:

```bash
git log --format=%s
```

```
AIOS: wissen/knowledge-orion als Projekt des Workspace ausgeschlossen
AIOS: skill-memo als Projekt des Workspace ausgeschlossen
AIOS: app-taschenrechner als Projekt des Workspace ausgeschlossen
Workspace
AIOS: Projekt initialisiert
```

Diese Commits pusht AIOS nicht; das bleibt bei dir.

## 3. Status und Integrität

```bash
aios --workspace status
```

```
Workspace W-Werkstatt — 2026-10-21

Project             Path                    Branch     Revision  Remote  Changes
app-taschenrechner  app-taschenrechner      ws/v0.4.0  ok        —       ok
skill-memo          skill-memo              main       ok        ok      ok
knowledge-orion     wissen/knowledge-orion  main       ok        ok      ok
```

| Spalte | Inhalt |
|---|---|
| Revision | `ok`, wenn der ausgecheckte Zweig die Revision enthält |
| Remote | voraus oder hinter dem Upstream; `—` ohne Upstream, wie bei `ws/v0.4.0` |
| Changes | nicht committete Änderungen |

Die Paket-Repos haben kein `@/`: Sie sind **Fremd-Repos**, keine AIOS-Projekte, und nicht Teil des Master-Kontexts. `aios --integrity` prüft sie über `workspace.yaml`, nur auf Klon und Commit-Stand:

```bash
aios --integrity
```

```
Integrity W-Werkstatt — 2026-10-21

Project               Init          Commit
W-Werkstatt           ok            ok
  app-taschenrechner  foreign repo  ok
  skill-memo          foreign repo  ok
  knowledge-orion     foreign repo  ok

Result: 4 of 4 projects integer
```

Fehlt ein Klon, steht dort `missing: clone`, und das Projekt ist nicht integer.

## 4. Abgleichen ohne Verlust

Leg im Taschenrechner eine Notiz an:

```bash
echo "# Notiz" > app-taschenrechner/NOTIZ.md
aios --workspace status
```

```
Project             Path                    Branch     Revision  Remote  Changes
app-taschenrechner  app-taschenrechner      ws/v0.4.0  ok        —       1 changed
```

`aios --workspace update` bringt die Projekte auf ihre Revision, aber **nur per fast-forward**. Ein Projekt mit offenen Änderungen, eigenen Commits, einem anderen ausgecheckten Zweig oder einem anderen `origin` lässt es unverändert und meldet den Grund, etwa:

```
   app-taschenrechner: kept (uncommitted changes)
```

Mit `--group wissen` gelten nur die Projekte dieser Gruppe und die Projekte ohne Gruppe. Ein `<pfad>` darf auch ein Ordner unter dem Wurzelprojekt sein; AIOS sucht die nächste `workspace.yaml` aufwärts.

## 5. Einfrieren

```bash
aios --workspace freeze
```

```
=> frozen: app-taschenrechner 6ad33b5b, skill-memo 9e007454, knowledge-orion 4fa0b258
```

`freeze` schreibt den Commit jedes geklonten Projekts in `.aios/lock.yaml` des Wurzelprojekts, Abschnitt `workspace:`:

```yaml
# written by AIOS (fetch, workspace), do not edit
schema: 1
workspace:
  app-taschenrechner: 6ad33b5b5ebc4e79e115b12eb7b52c40d4a75479
  skill-memo: 9e0074541541104db199837883add03d7b265cb4
  knowledge-orion: 4fa0b258f3eb45ce520fdd9db716c47b3a47a881
```

Hat das Wurzelprojekt auch Pakete, bleibt der Abschnitt `packages:` daneben stehen. Committe `lock.yaml`; der Stand des Workspace ist damit festgehalten.

## 6. Der Workspace auf einem zweiten Rechner

Push das Wurzelprojekt in ein eigenes Repo, z. B. `https://github.com/du/W-Werkstatt`. Auf einem anderen Rechner oder in einem anderen aktivierten Vault klont ein Befehl alles:

```bash
cd ~/tmp/§Zweit
aios --workspace init https://github.com/du/W-Werkstatt --plan
```

```
=> init the workspace ~/tmp/§Zweit/W-Werkstatt
   plan:
      clone https://github.com/du/W-Werkstatt -> ~/tmp/§Zweit/W-Werkstatt, then the projects of its .aios/workspace.yaml
   (plan only, nothing written)
```

```
   app-taschenrechner: cloned (v0.4.0)
   skill-memo: cloned (main)
   wissen/knowledge-orion: cloned (main)
=> workspace ~/tmp/§Zweit/W-Werkstatt ready
```

Das Wurzelprojekt wird behandelt wie ein Projekt des Workspace: Es landet im Ordner der Session und ist im Repo darüber ausgeschlossen, hier im Repo des Vaults. Ein zweiter Ordner wählt `aios --workspace init <repo> <ordner>`, eine Auswahl `--group <g>`. Gibt es den Ordner schon, bricht `init` ab; dann gilt `update`.

## 7. Was du gesehen hast

| Begriff | im Tutorial |
|---|---|
| Workspace, Wurzelprojekt | `W-Werkstatt` mit `.aios/workspace.yaml` |
| Klonen | `aios --workspace update`: Zweig `main`, Tag als `ws/v0.4.0`, Ausschluss mit eigenem Commit |
| Fremd-Repo | Paket-Repos ohne `@/`, in `aios --integrity` als `foreign repo` |
| Abgleich | nur fast-forward; Abweichungen werden gemeldet und bleiben |
| Einfrieren | `aios --workspace freeze`, Abschnitt `workspace:` in `lock.yaml` |
| zweiter Rechner | `aios --workspace init <repo>` |

Die vollständigen Regeln stehen in Spec 06 *Pakete und Workspaces*, Abschnitt *Workspaces*, und in Spec 05 *Projekte*, installiert unter `/opt/aios/v0.4.0/doc/spec/`.
