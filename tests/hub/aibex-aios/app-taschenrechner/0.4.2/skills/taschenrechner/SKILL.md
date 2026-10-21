---
name: taschenrechner
version: 0.4.2
description: >
  Funktionstasten des programmierbaren Taschenrechners von AIbex AIOS speichern, anzeigen und
  übernehmen: Belegungen aus der Oberfläche in @Data/app-taschenrechner/funktionstasten.yaml
  speichern, eigene und mitgelieferte Funktionstasten zeigen, eine mitgelieferte übernehmen,
  Funktionstasten zurückspielen. Verwenden bei "/taschenrechner", "Funktionstaste speichern",
  "meine Funktionstasten", "mitgelieferte Funktionstasten".
allowed-tools: Read, Write, Glob, Bash(aios --deploy *), Bash(aios --contribute *)
---

# Funktionstasten des Taschenrechners

Ein Skill der Demo-App `app-taschenrechner` von AIbex AIOS (Spec 06, *Demo-App*). Die Oberfläche öffnet `/taschenrechner-gui`.

**Arbeitsverzeichnis:** Arbeite im Projekt der Session und wechsle nie mit `cd`.

## Orte

| Was | Ort |
|---|---|
| eigene Funktionstasten | `@Data/app-taschenrechner/funktionstasten.yaml` im Projekt der Session; den Ordner legst du beim ersten Speichern an |
| mitgelieferte Funktionstasten | `@/@!Package/app-taschenrechner/knowledge/@!Funktionstasten/*.yaml` im Projekt, in dem das Paket geholt ist (das Projekt der Session oder eines darüber; `aios --deploy` zeigt die Pakete) |

`funktionstasten.yaml` hat je Funktionstaste `A` bis `D` einen Eintrag mit `title` und `keys` (Liste der Tasten: `0`–`9`, `.`, `+`, `−`, `×`, `÷`, `CHS`, `ENTER`). Der Rechner arbeitet mit umgekehrter polnischer Notation wie der HP-15C (Stack X, Y, Z, T):

```yaml
A:
  title: Quadrat
  keys: ["ENTER", "×"]
```

## Funktionstaste speichern

Kommt aus der Oberfläche „Speichere die Funktionstaste <A–D> mit den Tasten [...] und dem Titel ..." oder tippt der User den Satz aus der Statuszeile ab, wenn die Nachricht der Oberfläche nicht ankommt; dann stehen die Tasten durch Leerzeichen getrennt da (`ENTER ×`, auch `x` oder `*` für `×`, `-` für `−`, `/` für `÷`):
1. Zeige, was gespeichert wird: Funktionstaste, Titel, Tasten, Datei. Frage, ob der Titel so bleiben soll, und biete einen sprechenden Titel an (z. B. „Quadrat" für `ENTER ×`).
2. Nach Ja lies die Datei (falls vorhanden), setze oder ersetze den Eintrag der Funktionstaste und schreibe die Datei. Andere Funktionstasten bleiben.
3. Sag, dass die Belegung beim nächsten Öffnen von `/taschenrechner-gui` geladen wird.

## Funktionstasten zeigen und übernehmen

- **Zeigen:** eigene Funktionstasten aus `funktionstasten.yaml` und mitgelieferte aus `knowledge/@!Funktionstasten/` als Tabelle (Funktionstaste bzw. Datei, Titel, Tasten).
- **Übernehmen:** Will der User eine mitgelieferte Funktionstaste, frage nach der Funktionstaste `A`–`D`, zeige den Eintrag und schreibe ihn nach Ja in `funktionstasten.yaml`.

## Zurückspielen

Für einen Beitrag an das Paket: `aios --contribute @Data/app-taschenrechner/funktionstasten.yaml --to app-taschenrechner` mit `--plan`, Plan zeigen, nach Ja mit `--yes` (Spec 06, *Rückfluss*). Gibt es den Befehl in dieser Version noch nicht, sag das.
