# Workspaces

Dieses Tutorial führt in etwa 20 Minuten durch Workspaces von AIbex AIOS. Ein **Workspace** ist eine Vault-Root, die in `.aios/workspace.yaml` ihre Projekte nennt, jedes ein eigenes Git-Repo an seinem eigenen Remote. Damit kommt ein ganzer Vault auf einen zweiten Rechner und bleibt dort abgeglichen. Drei Handgriffe genügen, je für den ganzen Workspace oder mit Pfad für einen Teilbaum:

| Handgriff | Bedeutung |
|---|---|
| `attach` | den Workspace an diesen Rechner anbinden; mit Pfad: einen ausgelagerten Teilbaum zurückholen |
| `sync` | den Projektbaum mit den Remotes abgleichen |
| `detach` | den Workspace von diesem Rechner lösen; mit Pfad: einen Teilbaum auslagern |

Dazu kommt `remove`: ein Projekt aus dem Workspace entfernen, auf allen Rechnern (Abschnitt 7).

Voraussetzung: AIBOS v0.6.6 ist installiert, der Vault `~/tmp/§Demo` ist ein AIBOS-Workspace (Tutorial 01) und hat ein eigenes Git-Repo. Die Projekte des Beispiels sind Paket-Repos des Hubs `aibex-aios`; zum Klonen genügt Lesezugriff.

## 1. Das Manifest in der Vault-Root

Haben die Projekte deines Vaults schon Remotes, legt `aios --workspace sync` an der Vault-Root die Datei selbst an: mit allen Repos, die ein Remote haben, und einem Commit nur dieser Datei. Für dieses Beispiel schreibst du sie von Hand, weil die Projekte noch nicht da sind. Schreib die Datei `~/tmp/§Demo/.aios/workspace.yaml`:

```yaml
schema: 1
remotes:
  aibex: https://github.com/aibex-aios
projects:
  - name: app-taschenrechner
    remote: aibex
    revision: v0.4.0
    path: W-Werkstatt/app-taschenrechner
  - name: skill-memo
    remote: aibex
    revision: main
    path: W-Werkstatt/skill-memo
  - name: knowledge-orion
    remote: aibex
    revision: main
    path: W-Werkstatt/wissen/knowledge-orion
    groups: [wissen]
```

| Feld | Bedeutung |
|---|---|
| `remotes` | Name und Basis-URL; die URL eines Projekts ist `<basis>/<name>` |
| `remote` oder `repo` | ein Remote aus `remotes` oder eine volle URL |
| `revision` | Zweig, Tag oder Commit |
| `path` | Ort unter der Vault-Root, ohne `..`; die Reihenfolge der Einträge ist egal, Eltern werden vor Kindern geklont |
| `groups` | Gruppen für `--group` |

Committe die Datei im Repo der Vault-Root: `git add .aios/workspace.yaml` und `git commit -m "Workspace"`.

Die drei Projekte sind **Paket-Repos**: Sie haben ein `manifest.yaml` und kein `@/`. Ihre Namen sind klein geschrieben und bleiben, wie sie im Hub stehen. Eigene Projekte mit `@/` bekommen am Remote einen Namen nach dem Schema `<Workspace>-<Ordnername>`, hier etwa `Demo-W-Werkstatt`.

## 2. Klonen mit sync

```bash
cd ~/tmp/§Demo
aios --workspace sync --plan
```

```
=> sync the workspace ~/tmp/§Demo
   plan:
      clone https://github.com/aibex-aios/app-taschenrechner (v0.4.0) -> W-Werkstatt/app-taschenrechner
      clone https://github.com/aibex-aios/skill-memo (main) -> W-Werkstatt/skill-memo
      clone https://github.com/aibex-aios/knowledge-orion (main) -> W-Werkstatt/wissen/knowledge-orion
      make the newly cloned projects runnable (aios --fetch, registration)
   (plan only, nothing written)
```

Ohne `--plan` fragt `aios` einmal und klont:

```
   W-Werkstatt/app-taschenrechner: cloned (v0.4.0)
   W-Werkstatt/skill-memo: cloned (main)
   W-Werkstatt/wissen/knowledge-orion: cloned (main)
=> workspace §Demo synchronized
```

Ein Zweig wird ausgecheckt, ein Tag als lokaler Zweig `ws/v0.4.0`, nie als *detached HEAD*. Jedes Projekt wird im Repo darüber ausgeschlossen, mit einem eigenen Commit nur dieser Zeile. Neu geklonte Projekte mit `@/` macht sync gleich lauffähig: Pakete und Arbeitspferde aus `lock.yaml`, registrierte Skills.

Im Chat heißt derselbe Handgriff `/aios-sync`; Claude zeigt den Plan und fragt einmal.

## 3. Status und Integrität

```bash
aios --workspace status
```

```
Workspace §Demo — 2026-11-05 — sync: auto

Project             Path                                 Branch     Revision  Remote  Changes
app-taschenrechner  W-Werkstatt/app-taschenrechner       ws/v0.4.0  ok        —       ok
skill-memo          W-Werkstatt/skill-memo               main       ok        ok      ok
knowledge-orion     W-Werkstatt/wissen/knowledge-orion   main       ok        ok      ok
```

`aios --integrity` prüft die Projekte des Workspace mit; Paket-Repos ohne `@/` erscheinen als `foreign repo`, ein fehlender Klon als `missing: clone`.

## 4. Abgleichen ohne Verlust

Ein zweiter `aios --workspace sync` arbeitet wie ein Cloud-Laufwerk: Was du geändert, neu angelegt oder gelöscht hast, **sichert** er selbst (ohne dass du committest), neue Stände anderer Rechner **führt er zusammen**. Hast du dieselbe Datei geändert wie ein anderer Rechner, gilt dessen Fassung, und deine liegt als `… (Konflikt <Rechner> <Datum>).md` daneben. Geheimnisse wie `.env` bleiben lokal. Fehlen in einem Projekt viele Dateien (mehr als 10 oder ganz `@/`), fragt sync, ob das Löschen gewollt ist, und stellt sonst wieder her, etwa:

```
   W-Werkstatt: saved (1 new, 2 changed, 0 deleted)
   W-Werkstatt: moved (merged with origin/main)
```

Ohne Pfad gleicht sync das Projekt ab, in dem du stehst, an der Vault-Root den ganzen Workspace; mit Pfad nur diesen Teilbaum: `aios --workspace sync W-Werkstatt/skill-memo`. Mit `--only` nur das eine Projekt ohne seine Unterprojekte, etwa die Vault-Root allein: `aios --workspace sync ~/tmp/§Demo --only`. Frühere Fassungen zeigt `aios --workspace history <datei>`, gelöschte Dateien `history <projekt> --deleted`; zurück holt sie `aios --workspace restore <datei>` bzw. `restore <projekt> --at 2026-11-06` (im Chat `/aios-restore`).

## 5. Hinausbringen

sync pusht auch: je Repo mit Upstream und eigenen Commits den ausgecheckten Zweig, **nie Tags** und nie mit `--force`. Der Plan nennt die Commits, die hinausgehen:

```
      push W-Werkstatt/skill-memo: 1 commit(s)
      (3f2a1c9 Du: Notiz ergänzt)
```

Zwei Sicherungen gehören dazu:

- **Geheimnisse:** Berührt ein ausgehender Commit `@Secret/`, `.env`, `*.pem`, `*.key` oder einen SSH-Schlüssel, hält sync den Push dieses Repos an und nennt Datei und Commit. Geheimnisse gehören in den Ordner `@Secret/` eines Projekts; die `.gitignore`-Vorlage schließt ihn aus.
- **Manifest:** Liegt unter der Vault-Root ein neues Repo mit Remote, trägt sync es in `workspace.yaml` ein und committet nur diese Datei. Ein Repo ohne Remote nennt sync als Hinweis, mit einem Namen nach dem Schema und, wenn die Vault-Root bei GitHub liegt, dem Befehl `gh repo create … --push`, der das Repo anlegt und den ersten Stand hinausbringt. Hat ein Repo ein Remote, aber noch nie gepusht (kein Upstream), nennt sync `git -C <pfad> push -u origin main`. Repos am Remote anlegen tut sync nie selbst.

## 6. Der Workspace auf einem zweiten Rechner

Liegt das Repo der Vault-Root bei GitHub, z. B. `https://github.com/du/Demo`, bindet ein Befehl den ganzen Workspace an einen anderen Rechner. AIBOS muss dort installiert sein (README, *Install*); der Befehl läuft im Terminal, weil es noch keinen Vault gibt:

```bash
~/.aios/bin/aios --workspace attach https://github.com/du/Demo ~/tmp/§Demo --plan
```

```
=> attach the workspace https://github.com/du/Demo to this machine
   plan:
      clone https://github.com/du/Demo -> ~/tmp/§Demo (vault root)
      (install the bound kernel version if it is missing (aios --install))
      (then sync: clone the projects of workspace.yaml, parents before children; reconcile packages and workhorses; register the skills)
   (plan only, nothing written)
```

Danach ist der Rechner bereit, ohne `aios --activate`: Die Bindung reist in `config.yaml` mit. Im allerersten Chat dort ist `/aios-sync` noch kein Slash-Befehl, „sync den Workspace" in Worten wirkt aber schon; ab dem zweiten Chat geht auch der Slash-Befehl.

## 7. Platz sparen: Teilbäume auslagern

Ein Rechner muss nicht alles tragen. `detach` mit Pfad lagert einen Teilbaum aus, aber nur, wenn nichts verloren gehen kann:

```bash
aios --workspace detach W-Werkstatt/wissen/knowledge-orion --plan
```

```
=> detach W-Werkstatt/wissen/knowledge-orion on this machine
   plan:
      move W-Werkstatt/wissen/knowledge-orion with 1 repo(s) to the trash (~/.Trash), checked: nothing is lost
      (placeholder W-Werkstatt/wissen/knowledge-orion/DETACHED.md and W-Werkstatt/wissen/knowledge-orion/DETACHED.command; entry in .aios/workspace.local.yaml)
   (plan only, nothing written)
```

Geprüft wird jedes Repo im Teilbaum: Remote erreichbar, nichts offen, nichts ungepusht, kein Stash, keine ignorierten Dateien außer neu erzeugbaren. Sonst nennt `detach` die Hindernisse und ändert nichts. Der Ordner bleibt mit seinem Namen stehen und enthält `DETACHED.md` und `DETACHED.command`. Zurück geht es mit `aios --workspace attach W-Werkstatt/wissen/knowledge-orion`, im Chat mit `/aios-attach …` oder im Finder mit einem Doppelklick auf `DETACHED.command`. Die Auslagerung gilt nur für diesen Rechner; `sync` holt ausgelagerte Teilbäume nie von selbst zurück.

`detach` ohne Pfad löst den ganzen Workspace und legt den Vault-Ordner in den Papierkorb, nach derselben Prüfung für alle Repos.

Soll ein Projekt **ganz aus dem Workspace**, auf allen Rechnern, hilft `remove`:

```bash
aios --workspace remove W-Werkstatt/wissen/knowledge-orion --plan
```

Es prüft wie `detach`, legt den Teilbaum ohne Platzhalter in den Papierkorb, trägt ihn in `workspace.yaml` unter `removed:` ein und committet nur diese Datei. Das Repo am Remote bleibt. Der nächste sync bringt den Eintrag hinaus; auf einem anderen Rechner entfernt sync das Projekt dann ebenso, nach derselben Prüfung. Zurück geht es mit `aios --workspace attach W-Werkstatt/wissen/knowledge-orion`. Im Chat versteht `/aios-detach` „entferne … aus dem Workspace".

## 8. Laufender Abgleich: sync auto, manual, off

`sync:` in `.aios/config.yaml` der Vault-Root legt fest, wie der Workspace abgleicht; mit `workspace.yaml` gilt `auto`:

| Wert | Wirkung |
|---|---|
| `auto` | ein neuer Chat holt sein Projekt und führt es zusammen, wenn es dabei nichts zu sichern und keinen Konflikt gibt (`AIOS-SYNC: … updated from …`), und Claude bietet nach jedem Commit `/aios-sync` für das Projekt an |
| `manual` | abgeglichen wird nur auf Wunsch |
| `off` | `attach` und `sync` verweigern |

Ein Vault in einem Cloud-Ordner (Google Drive, OneDrive, iCloud Drive, Dropbox) gilt immer als `off`: Dort repliziert der Cloud-Dienst. Git bleibt erlaubt, nur der Abgleich von AIBOS ist aus.

Insgesamt gibt es vier Arten, einen Vault über Rechner zu führen:

- **Lokal-Drive:** Der Vault liegt nur auf diesem Rechner; kein Abgleich.
- **Cloud-Drive:** Die Vault-Root liegt in einem Cloud-Ordner. Der Cloud-Dienst repliziert den Vault; `sync` ist immer `off`.
- **AIBOS-Drive:** Der Vault hat eine `workspace.yaml`. AIBOS gleicht ihn über die Git-Remotes ab (`attach`, `sync`, `detach`, `remove`).
- **Netz-Drive:** Der Vault liegt auf einem Netzlaufwerk (NAS, Server). Es gibt nur eine Kopie, auf der alle Rechner arbeiten; setze dort `sync: off`.

## 9. Einfrieren

```bash
aios --workspace freeze
```

`freeze` schreibt den Commit jedes Projekts in den Abschnitt `workspace:` von `.aios/lock.yaml` der Vault-Root. So lässt sich ein Stand festhalten.

## 10. Was du gesehen hast

| Begriff | im Tutorial |
|---|---|
| Workspace, Vault-Root | `§Demo` mit `.aios/workspace.yaml` |
| Paket-Repo, Namensschema | Paket-Repos klein und unverändert; eigene Projekte `<Workspace>-<Ordnername>` |
| sync | klonen, sichern, zusammenführen (Konfliktkopie), lauffähig machen, Manifest nachführen, pushen ohne Tags; Geheimnisse bleiben lokal; große Löschung nur auf Wunsch |
| history, restore | frühere Fassungen und gelöschte Dateien zeigen und zurückholen; Papierkorb für nicht Gesichertes |
| attach | Workspace an einen zweiten Rechner; mit Pfad: Teilbaum zurück |
| detach | Teilbaum auslagern, Workspace lösen, nur ohne Verlust; Papierkorb |
| remove | Projekt aus dem Workspace entfernen, auf allen Rechnern; `removed:` in `workspace.yaml` |
| sync:, Arten | `auto`, `manual`, `off`; Lokal-, Cloud-, AIBOS- und Netz-Drive; Cloud-Ordner immer `off` |
| Einfrieren | `aios --workspace freeze`, Abschnitt `workspace:` in `lock.yaml` |

Die vollständigen Regeln stehen in Spec 06 *Pakete und Workspaces*, Abschnitt *Workspaces*, und in Spec 05 *Projekte*, installiert unter `~/.aios/versions/v0.6.6/doc/spec/`.
