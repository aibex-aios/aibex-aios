---
name: aios-init
description: Macht das Arbeitsverzeichnis in einem aktivierten AIbex-AIOS-Vault zum Projekt (@/, @Memo/, .gitignore, git init, Registrierung der Skills, erster Commit). Verwenden bei "/aios-init", "Projekt initialisieren" und bei Wahl (1) nach PROJECT-UNINITIALIZED.
allowed-tools: Bash(aios --init *)
---

# Projekt initialisieren

Ein AIOS-Skill von AIbex AIOS (Spec 03, *Initialisieren*).

## Ablauf

1. **Vorschau:** Führe `aios --init --plan` über das Bash-Werkzeug aus. Der Befehl prüft den Ordner und zeigt den Plan, ohne etwas zu schreiben.
   - Endet er mit einer Fehlermeldung (`*** aios --init: …`), nenne sie dem User mit dem Hinweis daraus und beende.
2. **Rückfrage:** Zeige dem User den Plan und frage, ob du das Projekt so anlegen sollst. Steht im Plan eine Zeile `note: … lies inside the git repository …`, weise ausdrücklich darauf hin, dass ein eigenes Git-Repo innerhalb eines bestehenden angelegt wird.
   - Hat der User die Initialisierung in seiner Anfrage schon ausdrücklich bestätigt, ist keine weitere Rückfrage nötig.
   - Bei Nein: abbrechen, nichts anlegen.
3. **Anlegen:** Nach Ja `aios --init --yes` ausführen.
4. **Abschluss:** Melde kurz, was angelegt wurde, und sag: „Das Projekt ist initialisiert. Der Master-Kontext des neuen Projekts gilt ab dem nächsten Chat vollständig; registrierte Skills sind ab dem nächsten Chat verfügbar (oder nach `/reload-skills`)."

Stand vorher `PROJECT-UNINITIALIZED` im Kontext, ist die Wahl damit getroffen; danach darfst du die ursprüngliche Frage des Users beantworten.
