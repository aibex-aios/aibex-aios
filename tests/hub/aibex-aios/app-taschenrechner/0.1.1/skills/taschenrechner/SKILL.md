---
name: taschenrechner
version: 0.1.0
description: >
  Kacheln des programmierbaren Taschenrechners von AIbex AIOS speichern, anzeigen und
  übernehmen: Belegungen aus der Oberfläche in @Data/app-taschenrechner/kacheln.yaml
  speichern, eigene und mitgelieferte Kacheln zeigen, eine mitgelieferte übernehmen,
  Kacheln zurückspielen. Verwenden bei "/taschenrechner", "Kachel speichern",
  "meine Kacheln", "mitgelieferte Kacheln".
allowed-tools: Read, Write, Glob, Bash(aios --deploy *), Bash(aios --contribute *)
---

# Kacheln des Taschenrechners

Ein Skill der Demo-App `app-taschenrechner` von AIbex AIOS (Spec 06, *Demo-App*). Die Oberfläche öffnet `/taschenrechner-gui`.

**Arbeitsverzeichnis:** Arbeite im Projekt der Session und wechsle nie mit `cd`.

## Orte

| Was | Ort |
|---|---|
| eigene Kacheln | `@Data/app-taschenrechner/kacheln.yaml` im Projekt der Session; den Ordner legst du beim ersten Speichern an |
| mitgelieferte Kacheln | `@/@!Package/app-taschenrechner/knowledge/@!Kacheln/*.yaml` im Projekt, in dem das Paket geholt ist (das Projekt der Session oder eines darüber; `aios --deploy` zeigt die Pakete) |

`kacheln.yaml` hat je Kachel `K1` bis `K4` einen Eintrag mit `title` und `keys` (Liste der Tasten: `0`–`9`, `.`, `+`, `−`, `×`, `÷`, `=`, `C`):

```yaml
K1:
  title: Quadrat
  keys: ["×", "="]
```

## Kachel speichern

Kommt aus der Oberfläche „Speichere die Kachel K<n> mit den Tasten [...] und dem Titel ...":
1. Zeige, was gespeichert wird: Kachel, Titel, Tasten, Datei. Frage, ob der Titel so bleiben soll, und biete einen sprechenden Titel an (z. B. „Quadrat" für `× =`).
2. Nach Ja lies die Datei (falls vorhanden), setze oder ersetze den Eintrag der Kachel und schreibe die Datei. Andere Kacheln bleiben.
3. Sag, dass die Belegung beim nächsten Öffnen von `/taschenrechner-gui` geladen wird.

## Kacheln zeigen und übernehmen

- **Zeigen:** eigene Kacheln aus `kacheln.yaml` und mitgelieferte aus `knowledge/@!Kacheln/` als Tabelle (Kachel bzw. Datei, Titel, Tasten).
- **Übernehmen:** Will der User eine mitgelieferte Kachel, frage nach der Kachel `K1`–`K4`, zeige den Eintrag und schreibe ihn nach Ja in `kacheln.yaml`.

## Zurückspielen

Für einen Beitrag an das Paket: `aios --contribute @Data/app-taschenrechner/kacheln.yaml --to app-taschenrechner` mit `--plan`, Plan zeigen, nach Ja mit `--yes` (Spec 06, *Rückfluss*). Gibt es den Befehl in dieser Version noch nicht, sag das.
