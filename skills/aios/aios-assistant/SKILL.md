---
name: aios-assistant
description: Ordnet dem Projekt einen Assistenten von AIbex AIOS zu (Persönlichkeit, Skills, Wissen und Modell aus @!Assistant/<name>/ASSISTANT.md der Masterspace-Kette) und wechselt sofort in diese Rolle; --none legt die Rolle ab, --inherit übernimmt den Assistenten des übergeordneten Projekts. Aufruf "/aios-assistant <Name>[: <Titel>]", z. B. "/aios-assistant Gärtner: Teste Apfel-Birne". Verwenden bei "/aios-assistant", "Assistent zuordnen", "Assistent wechseln", "welche Assistenten gibt es?".
allowed-tools: Bash(aios --assistant *), Bash(aios --context --assistant *), Bash(aios --context --assistants *), Bash(aios --context --assignment *), Read
---

# Assistent zuordnen

Ein AIOS-Skill von AIbex AIOS (Spec 03, *Wechsel*). Jeder Aufruf ist eine **Zuordnung zum Projekt**: Er schreibt `assistant:` in `.aios/config.yaml` und gilt für alle neuen Chats im Projekt und in den Unterprojekten mit `inherit`. Eine Aktivierung nur für den laufenden Chat gibt es nicht; wer einen anderen Assistenten ausprobieren will, legt dafür ein Unterprojekt an.

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt das Projekt der Session aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben. Rufe `aios …` immer als einzelnen Befehl auf, ohne `;`, `&&`, `|`, Umleitung oder vorangestelltes `cd`; nur so gibt AIBOS den Aufruf ohne Rückfrage frei.

`<session-id>` steht im Folgenden für die Session-ID dieses Chats; sie steht in der Zeile *Session-ID dieses Chats* am Ende dieser Anweisung.

## Ablauf

1. **Argument lesen:** `<Name>[: <Titel>]`, `--none` oder `--inherit`, optional `--to <projekt>` (ein Projekt der Kette, z. B. die Vault-Root für den Standard des Vaults). Ohne Argument oder bei „welche Assistenten gibt es?" `aios --context --assistants` und `aios --context --assignment` ausführen, die Liste und die Zuordnung zeigen und beenden.
2. **Plan:** `aios --assistant <wert> [--to <projekt>] --plan` über das Bash-Werkzeug ausführen. `<wert>` ist der Name bzw. Titel (`aios --assistant` löst ihn ohne Rücksicht auf Groß-/Kleinschreibung und Umlaute auf), `none` bei `--none`, `inherit` bei `--inherit`.
   - Endet der Befehl mit `no assistant named …` oder `more than one assistant …`, zeige die mitgelieferte Liste und frage, welcher gemeint ist. Beende danach.
   - Meldet er „nothing to do", ist die Zuordnung schon gesetzt: weiter mit Schritt 3 ohne Rückfrage.
   - Sonst zeige den Plan (z. B. `project G-Garten: Gärtner → Astronom`) und frage einmal, ob du ihn ausführen sollst. Hat der User den Wechsel in seinem Aufruf schon ausdrücklich bestätigt, entfällt die Frage. Bei Nein: abbrechen.
3. **Zuordnen:** `aios --assistant <wert> [--to <projekt>] --yes --session <session-id>` ausführen. Die letzte Zeile `session …: <name>` nennt den neuen Assistenten dieses Chats; fehlt sie (bei `--to`, wenn sich für diesen Chat nichts ändert), bleibt der bisherige.
4. **Rolle:** Ist der neue Assistent dieses Chats nicht `none`: `aios --context --assistant <name>` ausführen und die Ausgabe zwischen `<aios-assistant name="<name>" …>` und `</aios-assistant name="<name>">` vollständig lesen; fehlt die Endmarke in der Ausgabe des Werkzeugs, lies den Rest nach. Ab jetzt antwortest du als dieser Assistent:
   - `class="prompt"` ist deine Persönlichkeit, `class="assistant"` dein Rollentext mit Handwerk, Wissen und Grenzen. Halte die Grenzen genau ein.
   - `class="load"` ist dein Wissen. Die Zeilen in `<aios-available>` sind Wissen, das du **bei Bedarf** mit dem Read-Tool liest, bevor du eine Frage dazu beantwortest; sag, aus welchem Dokument die Antwort stammt.
   - `class="skill"` sind deine Skills. Wende sie an, als wären sie aufgerufen, ohne das Skill-Werkzeug.

   Ist er `none`: Lege die bisherige Rolle ab und antworte wieder als gewöhnliches Claude Code.
5. **Titel:** Nur wenn `<Titel>` im Argument steht, setze ihn nicht selbst, sondern bitte den User, den Chat so umzubenennen: „Bitte benenne den Chat in *<Titel>* um (Desktop-App: in der Seitenleiste; CLI: `/rename <Titel>`).“ AIOS kennt die Session der App nicht (A4). Ohne Titel bleibt er unverändert.
6. **Bestätigen:** kurz „<title> aktiv" bzw. „kein Assistent". Steht in `model:` ein Modell (z. B. `claude: sonnet`), nenne es als Hinweis: „Empfohlenes Modell: sonnet (Modellwahl der App bzw. `/model`)". Danach in der Rolle weiter; stand nach dem Namen schon eine Aufgabe oder Frage, beantworte sie jetzt in der Rolle.

Neue Chats im Projekt laden den Assistenten automatisch; Compaction und Resume behalten ihn (Merker der Session). Andere laufende Chats behalten den Assistenten, mit dem sie begonnen haben.
