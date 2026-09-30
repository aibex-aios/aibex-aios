---
name: bash-script-structure
description: >
  Konvention für Bash-Skripte im Bluccino-/~/bin-Stil. Beschreibt den
  einheitlichen Aufbau: Shebang, Top-Kommentar, Help-Block, Version-Block,
  Dispatch-Blöcke mit #===-Separatoren, ec-basierte Colored-Echo-Konvention,
  und Fallback am Ende. Wende diese Regel an, sobald der User ein neues
  Bash-Skript erstellt oder ein bestehendes Skript erweitert, das diesem
  Stil folgen soll. Abgeleitet aus dem dominanten Muster in ~/bin
  (chk, gib, gic, gid, gih, gil, gip, gir, gis, giu, prq, tag, hlp, ec,
  cl, run, sc, pimp, stup, …).
type: reference
---

# Bash-Skript-Struktur (Bluccino-Konvention)

## Zweck

Diese Regel beschreibt die strukturelle Konvention für Bash-Skripte im ~/bin-Stil. Sie wird angewandt, sobald ein neues Skript erstellt oder ein bestehendes substanziell erweitert wird. Das Ziel: ein **vorhersagbarer Aufbau**, der Help-, Version- und Dispatch-Verhalten einheitlich macht — sodass jedes Skript ohne weitere Erklärung benutzbar und wartbar ist.

## Wann anwenden

| Situation | Anwenden? |
|---|---|
| Neues CLI-Tool im Bluccino-Stil | ✅ |
| Erweiterung eines Skripts, das die Konvention bereits nutzt (z. B. `chk`, `pimp`, `gic`) | ✅ |
| Einfacher Wrapper (`#!/bin/bash` + ein einziger Befehl, z. B. `atom.sh`) | ❌ nicht erforderlich |
| Skripte, die ausschließlich gesourct werden sollen (`profile.sh`, `zenv.sh`) | ❌ andere Konventionen |
| One-Liner-Aliase | ❌ |

## Pflicht-Struktur

Ein konventionsgemäßes Skript besteht aus **fünf Blöcken in fester Reihenfolge**:

1. Shebang + Top-Kommentar
2. Help-Block (`-?`, `--help`)
3. Version-Block (`--version`)
4. Einer oder mehrere Dispatch-Blöcke
5. Fallback am Ende

Zwischen den Blöcken stehen Separator-Linien aus `#===…`.

### 1. Shebang und Top-Kommentar

```bash
#!/bin/bash
# scriptname: Einzeilige Kurzbeschreibung
```

- **Shebang** immer `#!/bin/bash` (nicht `/bin/sh`, weil die Konvention Bash-Features nutzt — Arrays, `[[`, Parameter-Expansion).
- **Top-Kommentar** mit dem Skriptnamen, Doppelpunkt, einer prägnanten Funktionsbeschreibung.

### 2. Help-Block

```bash
   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: scriptname <args>     # Was es tut'
      echo '          scriptname -x         # Variante mit Flag'
      echo '          scriptname --version  # print version'
      echo '   see also: chk, gib, gic, gid, gih, gil, gip, gir, gis, giu, prq, tag'
      exit 1
   fi
```

- **Pflicht** als allererster funktionaler Block (nach dem Top-Kommentar).
- Vorgerückt um **3 Leerzeichen** (nicht 4 oder Tab).
- `echo`-Zeilen formatiert mit ausgerichtetem Spalten-Layout, jedes Beispiel mit `# Erklärung` am Ende.
- `see also:`-Zeile listet verwandte Tools — typischerweise die ganze Git-Familie oder die unmittelbare Gruppe.
- `exit 1` am Ende (nicht 0) — Help-Aufruf ist ein User-Eingriff, der den normalen Workflow unterbricht.

### 3. Version-Block

```bash
#===============================================================================
# print version: scriptname --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "1.0.2"; exit 0
   fi
```

- **Pflicht** direkt nach dem Help-Block.
- Versionsnummer im Semver-Stil (`MAJOR.MINOR.PATCH`).
- Manche Skripte unterstützen auch `--v` als Kurzform — optional.

### 4. Dispatch-Blöcke

Pro funktionaler Variante des Skripts ein eigener Block:

```bash
#===============================================================================
# Variante A: scriptname  # Standard-Aufruf ohne Argumente
#===============================================================================

   if [ "$*" == "" ]; then
      ec -y "=> mache etwas"
      tatsächlicher-befehl || exit 1
      exit 0
   fi

#===============================================================================
# Variante B: scriptname -x <arg>  # Beschreibung
#===============================================================================

   if [ "$1" == "-x" ] && [ "$2" != "" ] && [ "$3" == "" ]; then
      ec -y "=> mache etwas anderes mit $2"
      command-mit-arg "$2" || exit 1
      exit 0
   fi
```

**Regeln für Dispatch-Blöcke:**

- Separator-Kommentar `#===…` (79 `=`-Zeichen, gefolgt von einer Beschreibungs- und einer Schluss-Linie).
- Im Kommentar steht der **Beispiel-Aufruf** (`scriptname -x <arg>`) und die Funktion.
- Die `if`-Bedingung prüft **alle** relevanten Argument-Positionen mit `$1`, `$2`, `$*` etc. — auch dass nicht zu viele Argumente da sind (`"$3" == ""`).
- Im Body: ggf. `ec -y` (oder andere Farbe) zur **Echo-Diagnose** dessen, was als Nächstes passiert.
- Tatsächlicher Befehl mit `|| exit 1` — bei Fehler sofort aussteigen.
- Erfolgreiches Ende mit explizitem `exit 0`.

### 5. Fallback am Ende

```bash
#===============================================================================
# cannot deal with anything else ...
#===============================================================================

   scriptname -?
   exit 1
```

- **Pflicht** als letzter Block.
- Ruft die Help-Anzeige auf und beendet mit `exit 1`.
- Damit landet jeder unbekannte Aufruf bei der Usage-Anleitung — kein stilles Scheitern.

## Hilfsregeln

### Einrückung

- **3 Leerzeichen** pro Ebene (nicht 4, nicht Tab).
- Diese Konvention ist im gesamten ~/bin durchgehalten — Mischung würde sofort auffallen.

### Separator-Kommentare

```
#===============================================================================
# Sektions-Titel oder Beispiel-Aufruf
#===============================================================================
```

- 79 `=`-Zeichen (Standard-Terminal-Breite minus 1).
- Direkt vor jedem Dispatch-Block sowie vor dem Version-Block und dem Fallback.

### Farbige Ausgabe via `ec`

Statt direkter ANSI-Escapes wird das `ec`-Hilfsprogramm verwendet:

| Aufruf | Wirkung |
|---|---|
| `ec -y "Text"` | gelb (typisch für "ich tue jetzt: …") |
| `ec -g "Text"` | grün (Erfolg, OK) |
| `ec -r "Text"` | rot (Fehler) |
| `ec -c "Text"` | cyan (Hinweis, Kategorie) |
| `ec -m "Text"` | magenta (Sekundär-Info) |
| `ec -b "Text"` | blau |
| `ec -0 "Text"` | kein Color-Reset zwischen Aufrufen |

Beispiel:

```bash
ec -y "=> git status"
git status || exit 1
```

### Exit-Code-Konventionen

| Code | Bedeutung |
|---|---|
| `exit 0` | Erfolg |
| `exit 1` | Fehler oder Help-Trigger |
| `\|\| exit 1` | nach jedem fehlbaren Befehl angehängt |

### Kommentar-Stil

- Top-Kommentar: `# scriptname: Funktion`
- Separator-Kommentare: in den `#===…`-Block direkt darüber
- Inline-Kommentare im Befehl: rechtsbündig oder direkt anschließend mit `# Erklärung`

### Recursive Self-Calls

Viele Skripte rufen sich selbst rekursiv auf, z. B. um in das übergeordnete Verzeichnis zu wandern:

```bash
   if [ "$*" == "" ]; then
      if [ -d ".git" ]; then
         echo `pwd`
      else
         if [ "`pwd`" == "/" ]; then
            exit 1
         else
            cd ..
            scriptname
         fi
      fi
      exit 0
   fi
```

Das ist ein etabliertes Muster (`gih` für git-home, `pimp --path` etc.) — bevorzuge Selbst-Aufruf vor expliziter `while`-Schleife, wenn die Logik natürlich rekursiv ist.

## Vollständige Vorlage

Hier ein minimal-konventionsgemäßes Skript, das als Vorlage dient:

```bash
#!/bin/bash
# foo: Kurzbeschreibung was foo macht

   if [ "$*" == "-?" ] || [ "$*" == "--help" ]; then
      echo '   usage: foo             # Standard-Aufruf'
      echo '          foo -x <arg>    # Variante mit Flag'
      echo '          foo --version   # print version'
      echo '   see also: chk, gib, gic, gid, gih, gil, gip, gir, gis, giu, prq, tag'
      exit 1
   fi

#===============================================================================
# print version: foo --version
#===============================================================================

   if [ "$*" == "--version" ]; then
      echo "1.0.0"; exit 0
   fi

#===============================================================================
# Standard-Aufruf: foo
#===============================================================================

   if [ "$*" == "" ]; then
      ec -y "=> doing the standard thing"
      echo "Hello from foo"
      exit 0
   fi

#===============================================================================
# Variante: foo -x <arg>
#===============================================================================

   if [ "$1" == "-x" ] && [ "$2" != "" ] && [ "$3" == "" ]; then
      ec -y "=> doing the x-thing with $2"
      echo "x-mode arg: $2"
      exit 0
   fi

#===============================================================================
# cannot deal with anything else ...
#===============================================================================

   foo -?
   exit 1
```

## Beispiele in der Praxis

Folgende Skripte folgen dieser Konvention besonders sauber und können als Referenz dienen:

| Skript | Typischer Lernzweck |
|---|---|
| `~/bin/gic` | Minimales Help+Version+Standard+Fallback |
| `~/bin/gis` | Help+Version+Variante+Standard+Fallback |
| `~/bin/gip` | Mehrere Dispatch-Varianten, inklusive `--branch-name` als interner Helfer |
| `~/bin/tag` | Drei Operationen (`-!`, `-d`, `-r`) mit gemeinsamer Argument-Validierung |
| `~/bin/prq` | Saubere Variable-Verwendung mit `_BRANCH`, `_URL`, am Ende `unset` |
| `~/bin/gir` | Erweiterter Help-Block mit ausführlichem `--help` (mehrstufig) |
| `~/bin/pimp` | Sehr großes Skript (1200+ Zeilen) mit demselben Muster |
| `~/bin/ec` | Trotz Sonderrolle (selbst der Color-Helper) folgt es derselben Struktur |

## Wann von der Konvention abweichen?

| Abweichung | Begründung |
|---|---|
| **`.sh`-Endung** statt erweiterungsloser Name | Datei ist zum Sourcen gedacht (`profile.sh`, `zenv.sh`) — andere Aufruf-Semantik |
| **Kein Help-Block** | Trivialer One-Liner-Wrapper (`atom.sh`) — Hilfe wäre Overhead |
| **Eingebettetes Sub-Kommando-System** | Skript ist so groß, dass es eine eigene Sub-Befehl-Struktur braucht (`pimp`, `stup` machen das partiell) |

In allen anderen Fällen sollte die Konvention eingehalten werden — Konsistenz ist hier wertvoller als Originalität.

## Quoting-Hinweis

Pfade mit Sonderzeichen und Leerzeichen sind in vielen Umgebungen Realität (etwa Google-Drive-Mounts mit "Geteilte Ablagen"). Die Konvention berücksichtigt das **nicht ausreichend** — viele ältere Skripte (`pimp` vor Quoting-Fix) versagen bei solchen Pfaden. Bei neuen Skripten daher konsequent **alle Variablen-Expansionen quoten**:

```bash
[ -f "$ROOT/manifest/west.yml" ]          # gut
source "$VENV/bin/activate"                # gut
bash "$ROOT/.pimp/init.sh"                 # gut
```

Dies ist eine *Verfeinerung* der bestehenden Konvention, keine Abweichung — und sollte für neuen Code zur Pflicht werden.
