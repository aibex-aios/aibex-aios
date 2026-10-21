---
name: aios-package
description: Paketmanager von AIbex AIOS für Anwender - installiert (holt), entfernt und aktualisiert Pakete, Apps, Assistenten und Wissenspakete aus den Hubs, sucht Pakete, zeigt, was installiert ist, und pflegt die Hub-Liste. Verwenden bei "/aios-package", "installiere ...", "hole ...", "entferne ...", "deinstalliere ...", "aktualisiere ...", "welche Pakete gibt es?", "welche Apps gibt es?", "was ist installiert?", "Hub hinzufügen", "install ...", "remove ...", "update ...", "list packages".
allowed-tools: Bash(aios --fetch *), Bash(aios --deploy *), Bash(aios --library *), Bash(aios --hubs *)
---

# Pakete

Ein AIOS-Skill von AIbex AIOS (Spec 03, *Pakete*; Spec 06). Er versteht Wünsche in Umgangssprache und bedient sich der Hilfs-Skills `/aios-fetch` (holen, abgleichen, aktualisieren, entfernen) und `/aios-deploy` (Elemente ausrollen). *Installieren* heißt hier: ein Paket holen; der Kernel selbst wird mit `aios --install` installiert, nicht mit diesem Skill.

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`. Andere Orte nur als ausdrücklichen Pfad angeben.

## Wunsch bestimmen

| Wunsch | Vorgehen |
|---|---|
| „installiere …", „hole …", *install* | Paket finden (unten), dann wie `/aios-fetch` holen |
| „entferne …", „deinstalliere …", *remove* | wie `/aios-fetch --remove <paket>` |
| „aktualisiere …", *update* | wie `/aios-fetch --upgrade [<paket>]` |
| „welche Pakete bzw. Apps gibt es?", Suche | `aios --library [<suchwort>]` zeigen |
| „was ist installiert?" | `aios --deploy` ausführen und die Pakete mit ihren ausgerollten Elementen zeigen |
| „füge den Hub … hinzu", „entferne den Hub …" | `aios --hubs add <name> [<url>]` bzw. `remove <name>` mit `--plan`, Rückfrage, `--yes`; mit `--vault`, wenn der Hub für den ganzen Vault gelten soll (fragen) |
| nur einen Teil eines Pakets nutzen | `/aios-deploy` |

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
