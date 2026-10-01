---
name: aios-agent
description: Aktiviert einen Agenten von AIbex AIOS (Persönlichkeit, Skills, Wissen und Modell aus @!Agent/<name>/AGENT.md der Masterspace-Kette) für diesen Chat, ohne etwas zu schreiben. Aufruf "/aios-agent <Name>[: <Titel>]", z. B. "/aios-agent Obstgärtner: Teste Apfel-Birne". Verwenden bei "/aios-agent", "Agent aktivieren", "welche Agenten gibt es?".
allowed-tools: Bash(aios-context --agent *), Bash(aios-context --agents *), Read
---

# Agent aktivieren

Ein AIOS-Skill von AIbex AIOS (Spec 03, *Aktivieren*). Die Aktivierung ist ohne Zustand: Sie schreibt nichts nach `.claude/` oder `.aios/` und gilt bis zum Ende des Chats.

## Ablauf

1. **Argument lesen:** `<Name>[: <Titel>]`. Ohne Namen oder bei „welche Agenten gibt es?" `aios-context --agents` ausführen, die Liste zeigen und beenden.
2. **Kontext holen:** `aios-context --agent "<Name>"` über das Bash-Werkzeug ausführen.
   - Endet der Befehl mit `*** aios-context --agent: no agent …` oder `… more than one agent …`, zeige die mitgelieferte Liste der verfügbaren Agenten und frage, welcher gemeint ist. Beende danach.
   - Andere Fehler (Prompt oder Skill nicht gefunden) dem User nennen und beenden.
3. **Vollständig lesen:** Die Ausgabe steht zwischen `<aios-agent name="<name>" …>` und `</aios-agent name="<name>">`. Lies sie vollständig; fehlt die Endmarke in der Ausgabe des Werkzeugs, lies den Rest nach, bevor du weitermachst.
4. **Rolle übernehmen:** Ab jetzt antwortest du als dieser Agent:
   - `class="prompt"` ist deine Persönlichkeit, `class="agent"` dein Rollentext mit Handwerk, Wissen und Grenzen. Halte die Grenzen genau ein.
   - `class="load"` ist dein Wissen. Die Zeilen in `<aios-available>` sind Wissen, das du **bei Bedarf** mit dem Read-Tool liest, bevor du eine Frage dazu beantwortest; sag, aus welchem Dokument die Antwort stammt.
   - `class="skill"` sind deine Skills. Wende sie an, als wären sie aufgerufen, ohne das Skill-Werkzeug.
5. **Titel setzen:** Titel ist `<Titel>` aus dem Argument, sonst der `title` des Agenten. In der Desktop-App setze ihn mit dem App-Werkzeug zum Setzen des Session-Titels, falls es verfügbar ist; in der CLI bitte den User, `/rename <Titel>` einzugeben. Ohne beides den Schritt überspringen.
6. **Bestätigen:** kurz „<title> aktiv". Steht in `model:` ein Modell (z. B. `claude: sonnet`), nenne es als Hinweis: „Empfohlenes Modell: sonnet (Modellwahl der App bzw. `/model`)". Danach in der Rolle weiter; stand nach dem Namen schon eine Aufgabe oder Frage, beantworte sie jetzt in der Rolle.

Nach einer Compaction muss die Aktivierung mit `/aios-agent` wiederholt werden; weise darauf hin, wenn du merkst, dass die Marken `<aios-agent …>` fehlen.
