---
name: aios-init
description: Macht einen Ordner in einem aktivierten AIbex-AIOS-Vault zum Projekt oder ergänzt ein Projekt um die fehlenden Teile der Struktur (@/, eigenes Git-Repo, .gitignore, Ausschluss im Repo darüber, Registrierung der Skills, Commit), mit Prüfung der Namensregel. Verwenden bei "/aios-init", "Projekt initialisieren", "Projekt ergänzen", nach PROJECT-UNINITIALIZED oder PROJECT-INCOMPLETE und nach /aios-integrity.
allowed-tools: Bash(aios --init *), Bash(aios-context --assistants*)
---

# Projekt initialisieren

Ein AIOS-Skill von AIbex AIOS (Spec 05, *Initialisieren*).

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt das Projekt der Session aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben.

## Ablauf

1. **Vorschau:** Führe `aios --init "<pfad>" --plan` über das Bash-Werkzeug aus, mit dem absoluten Pfad des Ordners (Standard: das Arbeitsverzeichnis der Session). Der Befehl zeigt den Plan, ohne etwas zu schreiben. Er nennt nur die fehlenden Schritte.
   - Endet er mit einer Fehlermeldung (`*** aios --init: …`), nenne sie dem User mit dem Hinweis daraus und beende.
   - Meldet er „is a complete project, nothing to do", sag das und beende.
2. **Rückfrage:**
   - Stand `PROJECT-UNINITIALIZED` im Kontext: Zeige mit dem Auswahlwerkzeug (`AskUserQuestion`) den Dialog *Projekt initialisieren* mit drei Fragen: **Titel** des Chats (Ordnername ohne Prefix, ein Vorschlag), **Assistent** (`inherit` mit dem Assistenten, der geerbt würde, `none` und bis zu zwei Assistenten aus `aios-context --assistants`) und **Anlegen** (initialisieren oder ins Projekt darüber wechseln). Ohne Auswahlwerkzeug stellst du die Fragen als nummerierte Liste.
   - Sonst: Zeige den Plan und frage einmal, ob du ihn ausführen sollst. Hat der User das in seiner Anfrage schon ausdrücklich bestätigt, entfällt die Frage.
   - Bei Nein: abbrechen, nichts anlegen.
3. **Namensregel:** Enthält der Plan Zeilen `name …:` und `proposal: …`, verstößt der Name gegen die Namensregel. Frag den User mit drei Antworten: (1) mit dem Vorschlag fortfahren (empfohlen) → Option `--name <vorschlag>`, (2) mit dem eigenen Namen fortfahren → Option `--accept-name`, (3) abbrechen. Liegt die Session im Ordner, der umbenannt würde, sag vorher, dass der Chat danach ins umbenannte Projekt wechseln muss (Desktop-App: Werkzeug zum Wechsel des Arbeitsverzeichnisses; CLI: neu starten).
4. **Anlegen:** `aios --init "<pfad>" --yes` mit den gewählten Optionen ausführen: `--name <name>` bzw. `--accept-name`, und `--assistant <wert>`, wenn im Dialog `none` oder ein Assistent gewählt wurde (bei `inherit` keine Option). Der Befehl gibt nur das Ergebnis aus. Endet er mit Exit 2, fehlt die Entscheidung zur Namensregel: zurück zu Schritt 3.
5. **Titel:** Wurde im Dialog ein Titel gewählt, setze ihn nicht selbst, sondern bitte den User, den Chat so umzubenennen: „Bitte benenne den Chat in *<Titel>* um (Desktop-App: in der Seitenleiste; CLI: `/rename <Titel>`).“ AIOS kennt die Session der App nicht (A4).
6. **Abschluss:** Melde kurz, was angelegt oder ergänzt wurde (auch einen Commit im Repo darüber), und sag: „Das Projekt ist initialisiert. Der Master-Kontext des neuen Projekts gilt ab dem nächsten Chat vollständig; registrierte Skills sind ab dem nächsten Chat verfügbar (oder nach `/reload-skills`)."

`aios --init` legt kein `@Memo/` an; das macht der Memo-Skill beim ersten Memo. Stand vorher `PROJECT-UNINITIALIZED` im Kontext, ist die Wahl damit getroffen; danach darfst du die ursprüngliche Frage des Users beantworten.
