---
name: aios-assistant
description: Aktiviert einen Assistenten von AIbex AIOS (Persönlichkeit, Skills, Wissen und Modell aus @!Assistant/<name>/ASSISTANT.md der Masterspace-Kette) für diesen Chat, ohne etwas zu schreiben. Aufruf "/aios-assistant <Name>[: <Titel>]", z. B. "/aios-assistant Gärtner: Teste Apfel-Birne". Verwenden bei "/aios-assistant", "Assistent aktivieren", "welche Assistenten gibt es?".
allowed-tools: Bash(aios-context --assistant *), Bash(aios-context --assistants *), Read
---

# Assistent aktivieren

Ein AIOS-Skill von AIbex AIOS (Spec 03, *Aktivieren*). Die Aktivierung ist ohne Zustand: Sie schreibt nichts nach `.claude/` oder `.aios/` und gilt bis zum Ende des Chats.

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt das Projekt der Session aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben.

## Ablauf

1. **Argument lesen:** `<Name>[: <Titel>]`. Ohne Namen oder bei „welche Assistenten gibt es?" `aios-context --assistants` ausführen, die Liste zeigen und beenden.
2. **Kontext holen:** `aios-context --assistant "<Name>"` über das Bash-Werkzeug ausführen.
   - Endet der Befehl mit `*** aios-context --assistant: no assistant …` oder `… more than one assistant …`, zeige die mitgelieferte Liste der verfügbaren Assistenten und frage, welcher gemeint ist. Beende danach.
   - Andere Fehler (Prompt oder Skill nicht gefunden) dem User nennen und beenden.
3. **Vollständig lesen:** Die Ausgabe steht zwischen `<aios-assistant name="<name>" …>` und `</aios-assistant name="<name>">`. Lies sie vollständig; fehlt die Endmarke in der Ausgabe des Werkzeugs, lies den Rest nach, bevor du weitermachst.
4. **Rolle übernehmen:** Ab jetzt antwortest du als dieser Assistent:
   - `class="prompt"` ist deine Persönlichkeit, `class="assistant"` dein Rollentext mit Handwerk, Wissen und Grenzen. Halte die Grenzen genau ein.
   - `class="load"` ist dein Wissen. Die Zeilen in `<aios-available>` sind Wissen, das du **bei Bedarf** mit dem Read-Tool liest, bevor du eine Frage dazu beantwortest; sag, aus welchem Dokument die Antwort stammt.
   - `class="skill"` sind deine Skills. Wende sie an, als wären sie aufgerufen, ohne das Skill-Werkzeug.
5. **Titel setzen:** Titel ist `<Titel>` aus dem Argument, sonst der `title` des Assistenten. In der Desktop-App setze ihn mit dem App-Werkzeug zum Setzen des Session-Titels, falls es verfügbar ist; in der CLI bitte den User, `/rename <Titel>` einzugeben. Ohne beides den Schritt überspringen.
6. **Bestätigen:** kurz „<title> aktiv". Steht in `model:` ein Modell (z. B. `claude: sonnet`), nenne es als Hinweis: „Empfohlenes Modell: sonnet (Modellwahl der App bzw. `/model`)". Danach in der Rolle weiter; stand nach dem Namen schon eine Aufgabe oder Frage, beantworte sie jetzt in der Rolle.

Nach einer Compaction muss die Aktivierung mit `/aios-assistant` wiederholt werden; weise darauf hin, wenn du merkst, dass die Marken `<aios-assistant …>` fehlen.
