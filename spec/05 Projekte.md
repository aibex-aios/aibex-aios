---
title: "Projekte"
date: 2026-10-25
author: iHux
status: Spec
tags: [spec, aios, v0.5, projekte]
number: 05
related:
  - "Spec 01 AIbex AIOS v0.6 — Überblick"
  - "Spec 02 Master-Kontext"
  - "Spec 03 Skills und Assistenten"
  - "Spec 04 Installation und Konfiguration"
  - "Spec 06 Pakete und Workspaces"
  - "Memo 06 Projekt, Root-Projekt und Projektstatus (AA-AIbex-AIOS, @Memo/V0.1)"
  - "Memos 08, 14–18, 21–24, 27, 28 (AA-AIbex-AIOS, @Memo/V0.3)"
  - "Memos 10, 24, 35 (AA-AIbex-AIOS, @Memo/V0.5)"
---

# Projekte

Diese Spec regelt, was zu einem Projekt gehört (Struktur und Name), wie `aios --init` ein Projekt anlegt oder ergänzt, was die Konsistenzprüfung beim Start und `/aios-integrity` prüfen, und wie `/aios-status` den Stand eines Projekts rekonstruiert. Der Dialog *Projekt initialisieren* und die Hook-Ausgaben `PROJECT-UNINITIALIZED` und `PROJECT-INCOMPLETE` stehen in Spec 02, Dateistrukturen und das CLI in Spec 04.

## Struktur eines Projekts

Ein Projekt ist ein Ordner mit `@/` (Spec 01). Seine **Struktur** ist vollständig, wenn alle vier Punkte erfüllt sind. Initialisieren, Konsistenzprüfung und `/aios-integrity` verwenden genau diese Prüfung, damit sie nicht auseinanderlaufen (V0.3, Memo 22, 27).

| # | Punkt | erfüllt, wenn | Name der Lücke |
|---|---|---|---|
| S1 | lokaler Masterspace | `<Projekt>/@/` existiert | `local masterspace @/` |
| S2 | eigenes Repo | `<Projekt>/.git` existiert, d. h. die Wurzel des Repos (`git rev-parse --show-toplevel`) ist das Projekt selbst | `own git repo` |
| S3 | `.gitignore` | `<Projekt>/.gitignore` enthält alle Zeilen der Vorlage (Spec 04) | `.gitignore lines: <fehlende Zeilen>` |
| S4 | Ausschluss darüber | Gibt es oberhalb des Projekts bis einschließlich zur Vault-Root ein Repo, ist das nächste davon das **Repo darüber**. Es ignoriert das Projekt (`git check-ignore` für `<relativer pfad>/` trifft) und versioniert keine Datei darin (`git ls-files <relativer pfad>` ist leer). Ohne Repo darüber ist S4 erfüllt | `exclusion in parent repo <pfad>` |

Jedes Projekt hat damit ein eigenes Repo, auch das Root-Projekt und jedes Unterprojekt eines Projekts mit Repo (Spec 01, Grundregel 9). Ein gemeinsames Repo für mehrere Projekte ist nicht vorgesehen. Ein Ausschluss darüber darf breiter sein als das Projekt, z. B. `/P-Projekte/` für alle Projekte darunter.

Nicht zur Struktur gehören `@Memo/` (legt der Memo-Skill an, Spec 03), `@Data/` (legen Apps an, Spec 06), der Name (Hinweis, siehe *Namensregel*) und der Abgleich der Pakete mit `lock.yaml` (`aios --fetch`, Spec 06).

## Namensregel

Projekte tragen einen Namen aus **Prefix** und **Namensteilen**, getrennt durch `-`, z. B. `PB1-Die-KI-Kann-Viel` oder `AAA-AIbex-AIOS-V0.3` (V0.3, Memo 16, 17, 24).

| Teil | Regel |
|---|---|
| Form | `<Prefix>-<Teil>[-<Teil>…]`, ohne Leerzeichen und ohne `/` |
| Prefix | Großbuchstaben und Ziffern, beginnt mit einem Großbuchstaben |
| Prefix und Pfad | Der Prefix ist der Prefix des übergeordneten Ordners plus **ein Großbuchstabe** (Standard, typisch der Anfangsbuchstabe: `PA` → `PAA`, `PAG`) oder wahlweise plus **eine Zahl** (`PB` → `PB1`, `PB12`; immer erlaubt, z. B. bei Blogs oder YouTube-Projekten). Der Vorschlag verwendet immer den Großbuchstaben. Das gilt auch über Container hinweg (`PA-AIbex-AIOS` ohne `@/` → `PAA-…`). Direkt unter der Vault-Root ist der Prefix des übergeordneten Ordners leer: ein Großbuchstabe (`P-Projekte`, `T-Test`). Hat der übergeordnete Ordner keinen regelkonformen Namen, wird nur die Form geprüft |
| Namensteil | beginnt mit einem Großbuchstaben oder einer Ziffer (`V0.3`, `KI`, `2026`); ein Teil, der mit einem Kleinbuchstaben beginnt, verstößt gegen die Regel |

Die Vault-Root ist von der Namensregel ausgenommen. Ob ein Prefix unter Geschwistern eindeutig ist, wird nicht geprüft.

**Vorschlag:** Bei einem Verstoß bildet `aios --init` einen regelkonformen Vorschlag: Leerzeichen und `_` werden zu `-`, jeder Namensteil beginnt groß, und vor den Namen tritt der Prefix des übergeordneten Ordners plus der Anfangsbuchstabe des ersten Teils (z. B. `§Demo/labor neu` → `L-Labor-Neu`). Beginnt der Name schon mit einem Prefix, also mit einem ersten Namensteil nur aus Großbuchstaben und Ziffern, der mit einem Großbuchstaben beginnt, wird nur dieser ersetzt: durch den Prefix des übergeordneten Ordners plus den ersten Buchstaben des alten Prefix (`G-Garten/B-Beet` → `GB-Beet`, `G-Garten/AT-Test` → `GA-Test`, `§Demo/KI-Tools` → `K-Tools`; V0.4, Memo 19, L6). Ein gültiger Prefix bleibt. Ein Wort in Großbuchstaben wie `KI` geht dabei im Vorschlag verloren; der User kann mit seinem eigenen Namen fortfahren (Wahl (2)).

**Verstoß beim Anlegen:** Entscheidungsdialog mit drei Wahlmöglichkeiten (V0.3, Memo 17): (1) mit dem Vorschlag fortfahren, (2) mit dem Namen des Users fortfahren, (3) abbrechen. **Verstoß bei bestehenden Projekten:** Konsistenzprüfung und `/aios-integrity` nennen ihn nur als Hinweis; das Projekt bleibt vollständig bzw. integer, weil der User mit seinem eigenen Namen fortfahren darf (V0.3, Memo 28).

## Initialisieren — `/aios-init`

Macht einen Ordner zum Projekt oder ergänzt ein bestehendes Projekt um die fehlenden Teile der Struktur. Auslöser: `/aios-init`, Wahl „initialisieren" im Dialog *Projekt initialisieren* (Spec 02), Ergänzung nach `PROJECT-INCOMPLETE` (Spec 02) oder nach `/aios-integrity`. Die Arbeit macht `aios --init [<pfad>] [--assistant <wert>] [--name <name>] [--accept-name]`.

| Option | Bedeutung |
|---|---|
| `<pfad>` | der Ordner; Standard `cwd`. Er muss in einem aktivierten Vault liegen (I4); er muss noch nicht existieren |
| `--assistant <wert>` | schreibt `assistant: <wert>` in `<pfad>/.aios/config.yaml` (Spec 03); `inherit` wird nicht geschrieben |
| `--name <name>` | legt den Ordner unter diesem Namen an bzw. benennt einen bestehenden Ordner um (Wahl (1) des Namensdialogs) |
| `--accept-name` | fährt trotz Verstoß gegen die Namensregel fort (Wahl (2)) |

**Schritte**, jeweils nur, was fehlt:

| # | Schritt | Wirkung |
|---|---|---|
| 1 | Ordner | anlegen, falls er fehlt (mit `--name` unter diesem Namen bzw. umbenennen). Unterscheidet sich `--name` nur in der Groß- und Kleinschreibung (auf macOS derselbe Ordner, erkannt mit `os.path.samefile`), wird über einen Zwischennamen umbenannt (A13) |
| 2 | Name | prüfen (*Namensregel*), außer an der Vault-Root. Bei einem Verstoß ohne `--name` oder `--accept-name` nennt der Plan den Verstoß und den Vorschlag, und `--yes` bricht mit Exit 2 ab, ohne zu schreiben |
| 3 | `@/` | anlegen, mit `.gitkeep` (S1) |
| 4 | Repo | `git init` mit dem Branch `main`, falls das Projekt kein eigenes Repo hat (S2); fehlende Zeilen der `.gitignore`-Vorlage ergänzen, vorhandene Zeilen bleiben (S3) |
| 5 | Repo darüber | falls es ein Repo darüber gibt und S4 nicht erfüllt ist: `/<relativer pfad>/` in dessen `.gitignore` eintragen, versionierte Dateien des Projekts mit `git rm -r --cached` aus der Versionierung nehmen (die Dateien bleiben liegen, die alte Historie bleibt dort) und nur diese Änderungen dort committen: „AIOS: <relativer pfad> als eigenes Projekt ausgeschlossen" (V0.3, Memo 23, 24). Die so herausgenommenen Dateien committet Schritt 8 im neuen Repo, damit sie versioniert bleiben (A14) |
| 6 | Zuordnung | mit `--assistant` den Schlüssel `assistant:` schreiben |
| 7 | Registrieren | Projekt-Skills registrieren (wie `aios --context --sync --yes`; V0.3, Memo 21) |
| 8 | Commit | im Projekt nur die Dateien committen, die AIOS angelegt oder geändert hat (`.gitignore`, `@/.gitkeep`, `.aios/config.yaml`), dazu die Dateien, die Schritt 5 aus dem Repo darüber übernommen hat (A14): bei einem neuen Repo „AIOS: Projekt initialisiert", sonst „AIOS: Projekt ergänzt". Ist nach dem Stagen nichts geändert (`git diff --cached --quiet`), entfällt der Commit ohne Meldung (A16). Scheitert ein Commit (z. B. ohne Git-Identität), nur eine Warnung |
| 9 | Abschluss | Hinweis, dass Master-Kontext und Skills für das Projekt ab dem nächsten Chat vollständig gelten |

`aios --init` legt **kein** `@Memo/` an (V0.3, Memo 18). Fehlt nichts, meldet es „nichts zu tun" ohne Rückfrage (I8). An der Vault-Root ist `aios --init` erlaubt; dort entfallen die Schritte 2 und 5 (V0.3, Memo 23). `--plan` zeigt den Plan und schreibt nichts; mit `--yes` gibt `aios --init` nur eine Ergebniszeile und Fehler aus (Spec 04).

**Ablauf des Skills:**

1. `aios --init "<pfad>" --plan` ausführen.
2. Kommt der Aufruf aus `PROJECT-UNINITIALIZED`, den Dialog *Projekt initialisieren* zeigen (Spec 02); sonst den Plan zeigen und einmal fragen. Nach `PROJECT-INCOMPLETE` oder `/aios-integrity` nennt der Plan nur die fehlenden Schritte.
3. Meldet der Plan einen Verstoß gegen die Namensregel: Namensdialog mit (1) Vorschlag, (2) eigener Name, (3) abbrechen. Liegt die Session im umzubenennenden Ordner, sagt der Skill vorher, dass der Chat danach ins umbenannte Projekt wechseln muss (Desktop-App: Werkzeug zum Wechsel des Arbeitsverzeichnisses; CLI: neu starten).
4. Nach Ja `aios --init "<pfad>" --yes` mit den gewählten Optionen ausführen und das Ergebnis kurz melden.

## Konsistenzprüfung

Beim ersten Start einer Session (`source` `startup`) prüft der SessionStart-Hook die Struktur des Projekts der Session nach S1–S4 und meldet Lücken mit `PROJECT-INCOMPLETE` (Spec 02; V0.3, Memo 14, 22). Die Prüfung schreibt nichts (I7); die Ergänzung bietet Claude an und führt sie nach Ja mit `aios --init` aus. Geprüft wird nur das Projekt der Session, nicht seine Unterprojekte, und nur die Struktur, nicht der Commit-Stand. Eine Vault-Root ohne `@/` ist ein Container und wird nicht geprüft (V0.3, Memo 15).

## Integrität — `/aios-integrity`

Prüft auf Anforderung des Users die **Integrität** eines Projekts und aller seiner Unterprojekte und berichtet die Ergebnisse (V0.3, Memo 27, 28). Auslöser: `/aios-integrity`, „Integrität". Die Arbeit macht `aios --integrity [<pfad>]`; es schreibt nie.

| | Konsistenzprüfung | `/aios-integrity` |
|---|---|---|
| Auslöser | automatisch, erster Start einer Session | nur auf Anforderung |
| Umfang | Projekt der Session | Projekt und alle Unterprojekte |
| Prüfungen | Struktur (S1–S4) | Struktur (S1–S4) und Commit-Stand |

**Projekte:** `<pfad>` (Standard `cwd`) und alle Ordner darunter mit `@/`, beliebig tief, auch durch Container hindurch und auch Unterprojekte von Unterprojekten. Nicht durchsucht werden Ordner, deren Name mit `.` beginnt (u. a. `.git`, `.claude`, `.aios`), Ordner, deren Name mit `@` beginnt (Masterspaces, `@Memo/`), und `node_modules`. Ist `<pfad>` selbst ein Container, werden nur die Projekte darunter geprüft.

| Prüfung | erfüllt, wenn | Bericht |
|---|---|---|
| **Init** | S1–S4 erfüllt | `ok` oder kurz `missing: <n> parts`; die Lücken stehen unter *Notes* (A15) |
| **Commit** | `git status --porcelain` des eigenen Repos ist leer; neue, nicht versionierte Dateien zählen mit | `ok`, `<n> changed, <m> new` oder `—` (kein eigenes Repo) |

**Workspace:** Hat `<pfad>`, ein Projekt darüber oder ein geprüftes Projekt darunter eine `.aios/workspace.yaml` (Spec 06), prüft `aios --integrity` zusätzlich jedes Projekt daraus, das unter `<pfad>` liegt (F2; V0.4, Memos 15, 73). Ein fehlender Klon erscheint als eigene Zeile mit Init `missing: clone` und gilt als nicht integer. Ein Fremd-Repo ohne `@/` (Spec 06) erscheint mit Init `foreign repo`; geprüft werden nur Klon und Commit, nicht S1–S4. Ist die Revision im ausgecheckten Zweig nicht enthalten oder zeigt `origin` auf ein anderes Repo als `workspace.yaml`, nennt der Bericht das unter *Notes*.

Ein Projekt ist **integer**, wenn Init und Commit erfüllt sind. **Hinweise** (`Notes`) ändern daran nichts:

- **Push-Stand:** Hat ein Repo einen Upstream, nennt der Bericht Commits, die noch nicht gepusht sind (voraus), und Commits, die lokal fehlen (hinter). Grundlage ist der lokale Stand ohne `git fetch`, also ohne Netz. Ein Repo ohne Remote ist zulässig.
- **Namensregel:** ein Verstoß nach *Namensregel*.
- **Kopien in `.agents/`:** Liegen in `<Projekt>/.agents/skills/<name>/` Kopien mit Marke `.aios-deploy`, deren Version nicht dem registrierten oder geholten Stand entspricht oder deren Skill es in der Kette nicht mehr gibt, nennt der Bericht sie als veraltet. AIOS ändert und entfernt sie nicht (V0.5, Memos 10, 24, Option C).

Registrierte Skills, geholte Pakete und Blueprints gehören nicht zur Integrität; den Abgleich macht `aios --fetch` (Spec 06).

**Bericht:**

```
Integrity §Demo — 2026-10-03

Project                 Init               Commit
§Demo                   ok                 ok
  G-Garten              ok                 2 changed, 1 new
    B-Beet              missing: 2 parts   —
  S-Sternwarte          ok                 ok

Notes
- B-Beet: missing own git repo, exclusion in /…/§Demo/G-Garten
- B-Beet: name violates the naming rule, proposal GB-Beet
- §Demo: 3 commits not pushed
- G-Garten: 1 commit behind origin

Result: 2 of 4 projects integer
```

Die Einrückung zeigt die Verschachtelung. `aios --integrity` endet mit Exit 0, wenn alle Projekte integer sind, sonst mit Exit 1.

**Ablauf des Skills:**

1. `aios --integrity "<pfad>"` ausführen und den Bericht zeigen.
2. Für Projekte mit Mängeln bei *Init* anbieten, sie mit `aios --init` zu ergänzen: die Pläne (`--plan`) zusammen zeigen, einmal fragen, nach Ja je Projekt `aios --init --yes` ausführen, danach die Prüfung wiederholen.
3. Nicht committete Änderungen nur nennen, nicht anbieten: Die Commit-Nachricht gehört dem User (I9).

## Projektstatus — `/aios-status`

Rekonstruiert eine kurze Übersicht, **was im Projekt erledigt wurde und was offen ist**. Der Status wird nicht gespeichert. Auslöser: `/aios-status`, „Projektstatus", „Wo stehen wir?". Er läuft nur auf Anforderung.

| Quelle | ausgewertet |
|---|---|
| `@Memo/` | Header (`Datum`, `Status`, `Ersetzt`), Abschnitte *Offen* und *Caveats* |
| Git-Log des Projekts | Umsetzungsschritte, jüngster Commit |

1. Memos in Nummernfolge lesen; Header und die Abschnitte *Offen* und *Caveats* genau, den Rest überfliegen. Fehlt `@Memo/`, stützt sich der Status nur auf das Git-Log und sagt das.
2. Abgleichen: Was ein späteres Memo entscheidet oder mit `Ersetzt` ablöst, gilt nicht mehr als offen. Bei Widerspruch gilt das spätere Memo.
3. Das Git-Log ergänzt Schritte, die in keinem Memo stehen.
4. Ausgabe im Chat:

```
Projektstatus <Projekt> — Stand <Datum>

Erledigt
- …
Offen
- …
Zuletzt: <hash> <Commit-Nachricht> (<Datum>)
```

Gespeichert wird der Status nur auf ausdrücklichen Wunsch, dann als gewöhnliches Memo nach `/memo` bzw. `/aios-memo`.
