---
name: aios-context
description: Prüft, ob der Master-Kontext von AIbex AIOS (das geladene Wissen der Masterspace-Kette) in diesem Chat vollständig geladen ist, lädt ihn bei Bedarf nach und zeigt Kette, geladene Dateien, verfügbares Wissen und Blueprints. Nachfolger von /masterspace. Verwenden bei "/aios-context", "Master-Kontext", "was ist geladen?", "Kontext prüfen".
allowed-tools: Bash(aios-context *), Read
---

# Master-Kontext

Ein AIOS-Skill von AIbex AIOS (Spec 02, *Skill `/aios-context`*). Er ändert nichts außer dem Nachladen.

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt das Projekt der Session aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben.

## Ablauf

1. **Soll-Stand ermitteln:** Führe `aios-context --id` über das Bash-Werkzeug aus. Die Ausgabe hat die Form `id=<id> files=<n> cwd=<cwd> mode=<mode>`.

2. **Kein Vault:** Bei `mode=none` antworte nur: „Kein Vault — kein Master-Kontext." und beende.

3. **Legacy-Modus:** Bei `mode=legacy` antworte nur: „Dieser Vault läuft im Legacy-Modus (ai-brain). Prüfe den Masterspace mit `/masterspace`." und beende.

4. **Prüfen:** Der Master-Kontext gilt nur dann als geladen, wenn **beide** exakten Marken mit genau dieser id in deinem Kontext stehen:
   - `<aios-context id="<id>"` (Anfang)
   - `</aios-context id="<id>">` (Ende)

   Eine Erinnerung, eine Zusammenfassung oder die Marken in einer Hook-Meldung (`AIOS-CONTEXT-CHECK`) zählen **nicht**. Es zählt nur Inhalt, den du tatsächlich aus einem SessionStart-Hook oder aus Part-Dateien gelesen hast.

5. **Nachladen**, wenn die Marken fehlen oder eine andere id im Kontext steht:
   - Steht eine andere id im Kontext, sag „Master-Kontext veraltet (`<alt>` → `<neu>`)", sonst „Lade Master-Kontext".
   - Führe `aios-context --load "<cwd>"` aus (mit dem `cwd` aus Schritt 1).
   - Lies **jede** aufgelistete Part-Datei vollständig mit dem Read-Tool, in der angegebenen Reihenfolge.
   - Prüfe, dass die Endmarke `</aios-context id="<id>">` gelesen wurde.

6. **Aufstellung zeigen:** Führe `aios-context --list "<cwd>"` aus. Zeige die Ausgabe unverändert in einem Codeblock, ersetze nur die erste Zeile `Master context id <id>, AIOS <version> — <Projekt>` durch „Master-Kontext geladen (id `<id>`, AIOS `<version>`) — `<Projekt>`".

7. **Assistent der Session:** Führe `aios-context --assignment "<cwd>" --session <session-id>` aus; `<session-id>` ist die Session-ID aus der Zeile *Session-ID dieses Chats* am Ende dieser Anweisung. Steht dort `from=session` und ein anderer Assistent als in der Zeile *Assistant* der Aufstellung (die Zuordnung des Projekts), nenne beide: „Assistent dieses Chats: <name> (Zuordnung des Projekts: <wert>)".

Steht in der Aufstellung ein Hinweis auf `/aios-register` (`Note: …`), nenne ihn. Die Aufstellung ist englisch; erkläre sie bei Bedarf in der Sprache des Users. Keine weiteren Kommentare, keine Zusammenfassung des Inhalts.
