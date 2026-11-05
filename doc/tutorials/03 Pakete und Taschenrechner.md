# Pakete und Taschenrechner

Dieses Tutorial führt in etwa 20 Minuten durch Pakete und Hubs von AIbex AIOS. Du holst die Demo-App **Taschenrechner** mit ihrer Abhängigkeit, rechnest damit, belegst eine Funktionstaste, holst Wissenspakete aus zwei Hubs, wählst Versionen und Elemente und spielst eine Funktionstaste als Beitrag an das Paket zurück.

Voraussetzung: AIBOS v0.6 ist installiert, der Vault `~/tmp/§Demo` ist mit `aios --activate v0.6.4 ~/tmp/§Demo` ein AIBOS-Workspace (Tutorial 01). Für die Suche in Hubs ohne Index und für den Rückfluss brauchst du `gh` (GitHub CLI), angemeldet mit `gh auth login`.

## 1. Hub und Hub-Liste

Ein **Paket** ist ein Git-Repo mit `manifest.yaml` und Versions-Tags `v<x.y.z>`. Ein **Hub** ist ein Ort für Pakete, meist eine GitHub-Organisation. Die **Hub-Liste** sagt, wo AIOS einen Paketnamen sucht:

```bash
aios --hubs
```

```
aibex-aios          https://github.com/aibex-aios  (default)
```

Ohne eigene Liste gilt der Standard-Hub `aibex-aios`. Suche darin:

```bash
aios --library rechner
aios --library app-taschenrechner
```

```
aibex-aios/app-taschenrechner  app           Programmierbarer RPN-Taschenrechner nach dem Vorbild des HP-15C mit lernenden Funktionstasten (Demo-App von AIbex AIOS)

aibex-aios/app-taschenrechner  0.1.0 0.1.1 0.2.0 0.2.1 0.3.0 0.3.1 0.3.2 0.4.0 0.4.1 0.4.2 0.5.0 0.5.1
```

Mit einem Suchwort sucht `aios --library` in Namen und Beschreibungen, mit einem Paketnamen zeigt es dessen Versionen. Mit AIBOS v0.6 lässt sich davon nur 0.5.1 holen; die älteren verlangen v0.4 bzw. v0.5 (`requires.aios`, Abschnitt 5).

## 2. Den Taschenrechner holen

Im Chat genügt ein Satz: „hol mir den Taschenrechner". `/aios-package` versteht ihn und ruft `/aios-fetch`. Auf der Kommandozeile, zuerst der Plan:

```bash
cd ~/tmp/§Demo
aios --fetch app-taschenrechner --plan
```

```
=> fetch app-taschenrechner into ~/tmp/§Demo
   unchanged  assistant-gaertner 0.3.1 (aibex-aios)
   plan:
      back up what the plan changes -> ~/tmp/§Demo/.aios/backup
      new        app-taschenrechner 0.5.1 (aibex-aios) -> ~/tmp/§Demo/@/@!Package/app-taschenrechner
      new        skill-memo 6.0.2 (aibex-aios) -> ~/tmp/§Demo/@/@!Package/skill-memo
      ~/tmp/§Demo/.aios/config.yaml: packages: app-taschenrechner: "~=0.5.1"
      ~/tmp/§Demo/.aios/lock.yaml: 3 packages
      register the skills of ~/tmp/§Demo
      remove the backup
   (plan only, nothing written)
```

Der Taschenrechner hängt von `skill-memo` ab; AIOS holt die Abhängigkeit mit. `unchanged` nennt Pakete, die schon da sind, hier den Gärtner aus Tutorial 01. Ohne `--plan` fragt `aios` einmal und meldet:

```
   registered in ~/tmp/§Demo: new taschenrechner, taschenrechner-gui, memo
=> packages of ~/tmp/§Demo: app-taschenrechner 0.5.1, assistant-gaertner 0.3.1, skill-memo 6.0.2
   open the app app-taschenrechner with /taschenrechner-gui or the tile Apps of /aios-gui
   assign the assistant to a project of the chain with /aios-assistant Gärtner
   new skills are available from the next chat (or after /reload-skills)
```

**Holen** heißt drei Dinge in einem Schritt: das Paket ohne `.git` nach `@/@!Package/<name>/` kopieren, seine Elemente **ausrollen** (wirksam machen) und seine Skills **registrieren**. In `.aios/config.yaml` steht, was du verlangt hast:

```yaml
aios: 0.6.0
packages:
  assistant-gaertner: "~=0.3.1"
  app-taschenrechner: "~=0.5.1"
```

In `.aios/lock.yaml` steht, was AIOS daraus aufgelöst hat:

```yaml
# written by AIOS (fetch, workspace), do not edit
schema: 1
packages:
  app-taschenrechner:
    version: 0.5.1
    hub: aibex-aios
    repo: "https://github.com/aibex-aios/app-taschenrechner"
    tag: v0.5.1
    commit: 2729280676f80b0faeedfa021d9ba7ad0d68e70c
    requested: "~=0.5.1"
  assistant-gaertner:
    version: 0.3.1
    hub: aibex-aios
    repo: "https://github.com/aibex-aios/assistant-gaertner"
    tag: v0.3.1
    commit: 56401f133496ae77ca609b1996e97312cb1f5d43
    requested: "~=0.3.1"
  skill-memo:
    version: 6.0.2
    hub: aibex-aios
    repo: "https://github.com/aibex-aios/skill-memo"
    tag: v6.0.2
    commit: ab904be25988501c0eaa4280a87b1994d8220593
    required_by: [app-taschenrechner]
```

Committe beide Dateien. `aios --fetch` ohne Argument stellt genau diesen Stand wieder her, etwa nach einem Klon auf einem anderen Rechner; eine neuere Version holt es dabei nie still.

## 3. Rechnen und eine Funktionstaste belegen

Öffne einen **neuen** Chat in `§Demo` (die Skills gelten ab dem nächsten Chat) und rufe auf:

```
/taschenrechner-gui
```

In der Desktop-App erscheint der Rechner im Chat. Er rechnet mit **umgekehrter polnischer Notation** wie der HP-15C: Erst die Zahlen, dann die Operation.

| Tasten | Anzeige | |
|---|---|---|
| `3` `ENTER` `4` `+` | 7 | 3 + 4 |
| `5` `ENTER` `×` | 25 | das Quadrat von 5 |
| `2` `CHS` | −2 | Vorzeichen wechseln |

Die oberste Reihe hat die Funktionstasten **A** bis **D**. So legst du das Quadrat auf **A**:

1. **LEARN** drücken, die Taste leuchtet.
2. `ENTER` `×` drücken, die Anzeige zeigt „Aufnahme: ENTER ×".
3. **LEARN** noch einmal drücken, dann **A**.

Die Statuszeile zeigt „Belegt: A ENTER ×" und den Hinweis, dass im Chat gespeichert wird. Die Oberfläche schickt dafür eine Nachricht an Claude; steht sie nur im Eingabefeld, drück Enter. In manchen Chats kommt sie gar nicht an, dann tipp den Satz aus der Statuszeile ab. Claude fragt nach einem Titel und speichert die Funktionstaste mit dem Skill `taschenrechner` in `@Data/app-taschenrechner/funktionstasten.yaml`:

```yaml
A:
  title: Quadrat
  keys: ["ENTER", "×"]
```

Ab jetzt rechnet `7` **A** das Quadrat 49. Die Daten einer App liegen in `@Data/<paket>/`, nicht im Paket: Ein Update des Pakets lässt sie stehen. Das Paket bringt eigene Funktionstasten mit, `quadrat.yaml` und `plus-19.yaml` in `knowledge/@!Funktionstasten/`. „Zeige meine Funktionstasten" im Chat listet beide Arten, und eine mitgelieferte kannst du auf eine freie Taste übernehmen.

Die Oberfläche öffnest du auch über `/aios-gui`, Kachel **Apps**. Sie listet die Apps des Projekts:

```bash
aios --gui --apps
```

```
Apps (open with the skill of the surface):
- /taschenrechner-gui — app-taschenrechner 0.5.1: Programmierbarer RPN-Taschenrechner nach dem Vorbild des HP-15C mit lernenden Funktionstasten (Demo-App von AIbex AIOS)
```

## 4. Wissen aus zwei Hubs

Das Paket `knowledge-orion` bringt die hellsten Sterne des Orion, `knowledge-scorpio` die des Skorpions. Der Skorpion liegt in einem zweiten Hub, `aibex-hub`. Nimm ihn in die Hub-Liste des Vaults auf:

```bash
aios --hubs add aibex-hub --vault
```

```
=> hub list: aibex-aios, aibex-hub
```

Die erste eigene Liste übernimmt den Standard-Hub, damit `aibex-aios` weiter durchsucht wird:

```
aibex-aios          https://github.com/aibex-aios  (vault)
aibex-hub           https://github.com/aibex-hub  (vault)
```

`aibex-hub` hat keinen Index; `aios --library scorpio` meldet das (`hub aibex-hub cannot be searched: no aios-index, …`) und findet ein Paket dort nur mit vollem Namen:

```bash
aios --library aibex-hub/knowledge-scorpio
```

```
aibex-hub/knowledge-scorpio  0.1.0 0.1.1 0.1.2
```

Hole beide Pakete:

```bash
aios --fetch knowledge-orion
aios --fetch aibex-hub/knowledge-scorpio
```

```
=> packages of ~/tmp/§Demo: app-taschenrechner 0.5.1, assistant-gaertner 0.3.1, knowledge-orion 0.1.2, knowledge-scorpio 0.1.2, skill-memo 6.0.2
```

Ein voller Name bindet das Paket an seinen Hub; `config.yaml` merkt sich das:

```yaml
packages:
  assistant-gaertner: "~=0.3.1"
  app-taschenrechner: "~=0.5.1"
  knowledge-orion: "~=0.1.2"
  knowledge-scorpio: {range: "~=0.1.2", hub: aibex-hub}
hubs:
  - aibex-aios
  - aibex-hub
```

Wissen eines geholten Pakets zählt, als läge es in `@/`. Ordne in einem Chat in `S-Sternwarte` den Astronomen zu (Tutorial 01) und frag ihn nach Beteigeuze oder Antares. Er nennt jetzt die Werte aus den Tabellen mit ihrer Quelle.

## 5. Versionen und Elemente

**Version wählen:** Ein Bereich hinter dem Namen wählt eine bestimmte Version. Die älteren Versionen des Taschenrechners verlangen AIOS v0.4 oder v0.5 (`requires.aios: ">=0.4,<0.5"` bzw. `"<0.6"`); in einem AIBOS-Workspace lehnt AIBOS v0.6 sie ab, bevor etwas geschieht:

```bash
aios --fetch app-taschenrechner==0.3.2 --plan
```

```
*** aios --fetch: no versions fulfil all ranges:
- app-taschenrechner: no fitting version runs with AIOS 0.6.0 (requires.aios); ==0.3.2 (packages:)
```

In einem Vault, der noch an v0.4 gebunden ist, holt der Kernel dieser Version die 0.3.2. Die Bereiche folgen pip: `==`, `!=`, `>=`, `<=`, `>`, `<`, `~=` und Kombinationen mit Komma. `aios --fetch --upgrade` wählt alle Versionen neu im Rahmen der Bereiche.

**Elemente wählen:** Ohne Angabe ist ein Paket ganz ausgerollt. `aios --deploy` zeigt, was wirkt:

```bash
aios --deploy
```

```
=> packages of ~/tmp/§Demo
   app-taschenrechner 0.5.1 (aibex-aios) — all elements deployed
      deployed      skill taschenrechner
      deployed      skill taschenrechner-gui
      deployed      knowledge
   assistant-gaertner 0.3.1 (aibex-aios) — all elements deployed
      deployed      assistant gaertner
   knowledge-orion 0.1.2 (aibex-aios) — all elements deployed
      deployed      knowledge
   knowledge-scorpio 0.1.2 (aibex-hub) — all elements deployed
      deployed      knowledge
   skill-memo 6.0.2 (aibex-aios) — all elements deployed
      deployed      skill memo
```

Mit `aios --deploy <paket> --only <element>…` wirkt nur ein Teil, mit `--all` wieder alles. Die Kopie im Paket bleibt vollständig; nicht ausgerollte Elemente haben nur keine Wirkung.

**Entfernen:** `aios --fetch --remove knowledge-scorpio` entfernt das Paket aus `@!Package/`, `packages:` und `lock.yaml`. Daten in `@Data/` bleiben stehen.

## 6. Eine Funktionstaste zurückspielen

Gefällt dir deine Funktionstaste, schick sie an das Paket zurück. Im Chat: „Ich möchte meine Funktionstasten zurückspielen" oder die Kachel *Funktionstaste zurückspielen* der Oberfläche. Auf der Kommandozeile:

```bash
aios --contribute @Data/app-taschenrechner/funktionstasten.yaml --to app-taschenrechner --plan
```

```
=> contribute to app-taschenrechner
   plan:
      contribute:
         repo https://github.com/aibex-aios/app-taschenrechner (fork for du, no write access)
         branch contrib/du/2026-10-21-funktionstasten
         ~/tmp/§Demo/@Data/app-taschenrechner/funktionstasten.yaml -> contrib/du/funktionstasten.yaml
         pull request "Beitrag: funktionstasten.yaml von du" against the default branch
   (plan only, nothing written)
```

`du` steht hier für deinen GitHub-Namen. Ohne Schreibrechte legt AIOS einen Fork an. Der Beitrag kommt in einen eigenen Zweig und wird ein Pull Request; auf den Standardzweig pusht AIOS nie. Der Maintainer prüft ihn, übernimmt ihn nach `knowledge/@!Funktionstasten/` und taggt eine neue Version. Mit `aios --fetch --upgrade` kommt er zu allen anderen.

## 7. Was du gesehen hast

| Begriff | im Tutorial |
|---|---|
| Paket, Hub, Hub-Liste | `app-taschenrechner` im Hub `aibex-aios`; `aios --hubs`, `aios --hubs add aibex-hub --vault` |
| Suchen | `aios --library rechner`, `aios --library app-taschenrechner`, voller Name `aibex-hub/knowledge-scorpio` |
| Holen | `aios --fetch`: kopieren, ausrollen, registrieren; Abhängigkeit `skill-memo` |
| verlangt und aufgelöst | `packages:` in `config.yaml`, `lock.yaml` mit Version und Commit |
| App und Daten | `/taschenrechner-gui`, Funktionstasten in `@Data/app-taschenrechner/` |
| Version, Elemente | `==0.3.2` (abgelehnt: `requires.aios`), `--upgrade`, `aios --deploy … --only`, `--remove` |
| Rückfluss | `aios --contribute`: Zweig, Fork, Pull Request |

## Weiter

- Tutorial *04 Workspaces*: Paket-Repos und Projekte als Git-Checkouts eines Wurzelprojekts.
- Bau dein eigenes Paket: ein Git-Repo mit `manifest.yaml` (`name`, `version`, `type`, `description`, `requires.aios`, `contents`), ein Tag `v0.1.0`, und `aios --fetch <paket> --from <repo-url>` holt es ohne Hub.

Die vollständigen Regeln stehen in Spec 06 *Pakete und Workspaces*, installiert unter `~/.aios/versions/v0.6.4/doc/spec/`.
