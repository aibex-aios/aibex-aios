---
name: aios-package
description: Paketmanager von AIbex AIOS für Anwender - installiert (holt), entfernt und aktualisiert Pakete, Apps, Assistenten und Wissenspakete aus den Hubs, sucht Pakete, zeigt, was installiert ist, und pflegt die Hub-Liste. Verwenden bei "/aios-package", "installiere ...", "hole ...", "entferne ...", "deinstalliere ...", "aktualisiere ...", "welche Pakete gibt es?", "welche Apps gibt es?", "was ist installiert?", "Hub hinzufügen", "install ...", "remove ...", "update ...", "list packages".
allowed-tools: Bash(aios --fetch *), Bash(aios --deploy *), Bash(aios --library *), Bash(aios --hubs *), Bash(aios --install distribution-*)
---

# Pakete

Ein AIOS-Skill von AIbex AIOS (Spec 03, *Pakete*; Spec 06). Er versteht Wünsche in Umgangssprache und bedient sich der Hilfs-Skills `/aios-fetch` (holen, abgleichen, aktualisieren, entfernen) und `/aios-deploy` (Elemente ausrollen). *Installieren* heißt hier: ein Paket holen, bei einer Distribution (`distribution-<name>`) mit `aios --install distribution-<name>` installieren (unten); der Kernel allein wird mit `aios --install v<version>` installiert, nicht mit diesem Skill.

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`. Andere Orte nur als ausdrücklichen Pfad angeben.

## Wunsch bestimmen

| Wunsch | Vorgehen |
|---|---|
| „installiere …", „hole …", *install* | Paket finden (unten), dann wie `/aios-fetch` holen; ist es eine Distribution, *Distribution installieren* (unten) |
| „entferne …", „deinstalliere …", *remove* | wie `/aios-fetch --remove <paket>` |
| „aktualisiere …", *update* | wie `/aios-fetch --upgrade [<paket>]` |
| „welche Pakete bzw. Apps gibt es?", Suche | `aios --library [<suchwort>]` zeigen |
| „was ist installiert?" | `aios --deploy` ausführen und die Pakete mit ihren ausgerollten Elementen zeigen |
| „füge den Hub … hinzu", „entferne den Hub …" | `aios --hubs add <name> [<url>]` bzw. `remove <name>` mit `--plan`, Rückfrage, `--yes`; mit `--vault`, wenn der Hub für den ganzen Vault gelten soll (fragen) |
| nur einen Teil eines Pakets nutzen | `/aios-deploy` |
| „stelle eine Distribution zusammen" | `/aios-distribution` |

## Paket finden

1. Nennt der User einen vollen Paketnamen `<hub>/<paket>`, gib ihn unverändert weiter.
2. Sonst `aios --library <name>` ausführen. Nennt die Ausgabe Versionen (`<hub>/<name>  0.1.0 …`), ist das Paket gefunden; stehen dort mehrere Hubs, frage, welcher gemeint ist.
3. Sonst ist der Name unscharf („der Rechner", *calculator*): `aios --library <suchwort>` mit einem passenden Wort ausführen. Ein Treffer: nimm ihn und nenne ihn. Mehrere Treffer: frage mit dem Auswahlwerkzeug (`AskUserQuestion`). Kein Treffer: sag das und zeige `aios --library`.

**Version:** Einen Versionswunsch hängst du als Bereich an den Namen, ohne Leerzeichen und nie mit `@` (V0.4, Memo 67, B3):

| Wunsch | Bereich |
|---|---|
| „Version 0.4.0" | `app-taschenrechner==0.4.0` |
| „mindestens 0.4" | `app-taschenrechner>=0.4` |
| „irgendeine 0.4.x" | `app-taschenrechner~=0.4.0` |
| „nicht 0.4.1" | `app-taschenrechner!=0.4.1` |

Danach weiter wie im Skill `/aios-fetch` (Ziel klären, Plan, Rückfrage, `--yes`, Abschluss). Den Plan zeigst du immer und fragst; der Wunsch „installiere …" ist keine Bestätigung. Pakete holt nur der User; schlage das Holen nicht von dir aus vor.

## Distribution installieren

Eine Distribution erkennst du am Namen `distribution-<name>` bzw. am Typ `distribution` in `aios --library`. Sie kommt immer in die **Vault-Root** und kann den Rechner ändern (Kernel, Arbeitspferde; Spec 06, *Distributionen*).

1. **Plan:** `aios --install distribution-<name>[<bereich>] --plan` (ohne Vault-Angabe gilt der Vault der Session; einen anderen Vault als Pfad zur Vault-Root angeben).
2. **Rückfrage:** Zeige beide Teile: den **Rechnerteil** (Kernel installieren, Arbeitspferde einrichten, mit den Paketen `paket==version`) und den **Vaultteil** (Bindung, z. B. `aios: 0.5.0 … (was 0.4.0)`, Pakete `new`, `upgrade`). Weise auf eine Umstellung des Vaults ausdrücklich hin und frage **immer** eigens.
3. **Ausführen:** Nach Ja denselben Befehl mit `--yes`. Braucht die Installation des Kernels `sudo` mit Passwort (steht im Plan), führe sie nicht aus, sondern nenne dem User den Befehl ohne `--plan` für sein Terminal.
4. **Fehler:** Meldungen wie `one distribution with kernel: per vault`, `overridden only with only:` oder `the machine part failed` dem User nennen und beenden. „distributions need AIOS 0.5 or later" heißt: erst `aios --install v0.5.<n>`.

Aktualisieren ist derselbe Befehl ohne Version (`upgrade a -> b`); entfernen wie `/aios-fetch --remove distribution-<name> --to <vault-root>`.
