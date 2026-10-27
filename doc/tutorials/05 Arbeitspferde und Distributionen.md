# Arbeitspferde und Distributionen

Dieses Tutorial führt in etwa 20 Minuten durch **Arbeitspferde** und **Distributionen** von AIbex AIOS. Du installierst die Distribution **Rothirsch** mit der Video-Analyse und der Assistentin Anja, siehst, wie AIOS das Programm `yt-dlp` einrichtet, ohne dass du etwas installierst, und wie ein zweiter Rechner, ein Update und das Entfernen damit umgehen.

Voraussetzung: AIOS v0.5 ist installiert (`aios --install v0.5.1`, siehe README) mit der Grundausstattung aus `aios --prepare` (`python3` ab 3.11 mit `venv` und `pip`, `git`; auf macOS z. B. `brew install python`). Für das Einrichten der Arbeitspferde braucht der Rechner Zugang zu PyPI.

## 1. Was ein Arbeitspferd ist

Ein **Arbeitspferd** ist ein Programm, das Skills aufrufen, das aber nicht im Paket liegen kann: Es muss für den Rechner gebaut werden, ist groß und wird oft aktualisiert, etwa `yt-dlp` oder `deno`. In AIOS ist es ein Paket vom Typ `worker` mit dem Namen `worker-<name>`. Andere Pakete nennen es in `depends`, so wie die Video-Analyse `worker-yt-dlp`.

| | Paket | Arbeitspferd |
|---|---|---|
| liegt | als Kopie im Projekt (`@/@!Package/`) | einmal je Version auf dem Rechner (`/opt/aios/workers/<paket>/v<version>/`, sonst `~/.aios/workers/`) |
| wird | geholt | beim Holen **eingerichtet** (setup), danach schreibgeschützt |
| welche Version gilt | die des Projekts | die, die `lock.yaml` des nächsten Projekts sperrt |
| aufgerufen über | Skill | Weiterleiter `~/.aios/bin/<programm>` |

## 2. Rothirsch installieren

Eine **Distribution** stellt einen Kernel und Pakete in exakten Versionen zusammen. Rothirsch 1.0.0 bringt den Kernel 0.5.0, `skill-video-analyse` 0.2.0 und `assistant-anja` 0.2.0; ihre Abhängigkeiten holt der Resolver. Lege einen neuen Vault an und schau dir den Plan an:

```bash
mkdir -p ~/tmp/§Rothirsch
aios --install distribution-rothirsch ~/tmp/§Rothirsch --plan
```

```
=> install distribution-rothirsch 1.0.0 into ~/tmp/§Rothirsch (kernel 0.5.0)
   plan:
      (machine part: kernel and workhorses)
      (AIOS v0.5.0 is already installed in /opt/aios/v0.5.0)
      setup      worker-deno 0.1.0 -> /opt/aios/workers/worker-deno/v0.1.0
             python /opt/homebrew/opt/python@3.11/bin/python3.11, 1 packages from worker/requirements.lock:
             | deno==2.9.8
             check: deno --version
      setup      worker-yt-dlp 0.1.0 -> /opt/aios/workers/worker-yt-dlp/v0.1.0
             python /opt/homebrew/opt/python@3.11/bin/python3.11, 11 packages from worker/requirements.lock:
             | brotli==1.2.1
             | certifi==2026.10.23
             | charset-normalizer==3.5.2
             | idna==3.20
             | mutagen==1.48.1
             | pycryptodomex==3.24.1
             | requests==2.34.2
             | urllib3==2.8.0
             | websockets==17.3
             | yt-dlp==2026.10.21
             | yt-dlp-ejs==0.8.0
             check: yt-dlp --version
      (vault part: ~/tmp/§Rothirsch)
      back up what the plan changes -> ~/tmp/§Rothirsch/.aios/backup
      create @/ (with .gitkeep)
      git init (branch main)
      .gitignore: .DS_Store, .claude/skills/, .claude/worktrees/, .agents/, .aios/registry, .aios/backup/
      create ~/tmp/§Rothirsch/.aios/config.yaml with aios: 0.5.0
      commit "AIOS: Projekt initialisiert" with the files AIOS wrote
      new        assistant-anja 0.2.0 (aibex-aios) -> ~/tmp/§Rothirsch/@/@!Package/assistant-anja
      new        distribution-rothirsch 1.0.0 (aibex-aios) -> ~/tmp/§Rothirsch/@/@!Package/distribution-rothirsch
      new        skill-5-8-zusammenfassung 1.2.1 (aibex-aios) -> ~/tmp/§Rothirsch/@/@!Package/skill-5-8-zusammenfassung
      new        skill-memo 6.0.1 (aibex-aios) -> ~/tmp/§Rothirsch/@/@!Package/skill-memo
      new        skill-video-analyse 0.2.0 (aibex-aios) -> ~/tmp/§Rothirsch/@/@!Package/skill-video-analyse
      new        worker-deno 0.1.0 (aibex-aios) -> ~/tmp/§Rothirsch/@/@!Package/worker-deno
      new        worker-yt-dlp 0.1.0 (aibex-aios) -> ~/tmp/§Rothirsch/@/@!Package/worker-yt-dlp
      ~/tmp/§Rothirsch/.aios/config.yaml: packages: distribution-rothirsch: "==1.0.0"
      ~/tmp/§Rothirsch/.aios/lock.yaml: 7 packages
      register the project skills of ~/tmp/§Rothirsch
      /opt/aios/workers.yaml: ~/tmp/§Rothirsch uses worker-deno 0.1.0, worker-yt-dlp 0.1.0
      remove the backup
   (plan only, nothing written)
```

Der Plan hat zwei Teile. Der **Rechnerteil** installiert den Kernel, falls er fehlt, und richtet die Arbeitspferde ein, `worker-deno` zuerst, weil `worker-yt-dlp` davon abhängt. Jedes Arbeitspferd nennt die Python-Pakete mit Version, die `pip` mit geprüften Hashes installiert, und den `check`, der danach laufen muss. Der **Vaultteil** bindet die Vault-Root an den Kernel (hier mit Anlegen des Root-Projekts), holt die Pakete und registriert die Skills, mit Sicherung wie bei jedem `aios --fetch`. Ein Plan, ein Ja. Scheitert der Rechnerteil, bleibt der Vault unberührt; was schon eingerichtet ist, bleibt liegen.

Ohne `--plan` fragt `aios` einmal und meldet nach den Ausgaben von `check`:

```
   registered in ~/tmp/§Rothirsch: new 5-8-zusammenfassung, memo, video-analyse
=> packages of ~/tmp/§Rothirsch: assistant-anja 0.2.0, distribution-rothirsch 1.0.0, skill-5-8-zusammenfassung 1.2.1, skill-memo 6.0.1, skill-video-analyse 0.2.0, worker-deno 0.1.0, worker-yt-dlp 0.1.0
   assign the assistant to a project of the chain with /aios-assistant Anja
   new skills are available from the next chat (or after /reload-skills)
```

In `.aios/config.yaml` der Vault-Root steht nur die Distribution, mit ihrer exakten Version:

```yaml
aios: 0.5.0
packages:
  distribution-rothirsch: "==1.0.0"
```

Im Chat geht dasselbe mit „installiere distribution-rothirsch": `/aios-package` zeigt beide Teile des Plans und fragt eigens nach.

## 3. Die Video-Analyse

Öffne einen Chat direkt in `~/tmp/§Rothirsch`, nicht in einer Arbeitskopie (die Skills gelten ab dem nächsten Chat) und schick einen YouTube-Link mit dem Wort „Video-Analyse":

```
https://www.youtube.com/watch?v=<video-id> Video-Analyse
```

Der Skill ruft `yt-dlp` über `~/.aios/bin/yt-dlp` auf, legt das Transkript in `@Video/` und eine 5-8-Zusammenfassung in `@Summary/` ab und committet beides. Installiert hast du dafür nichts: `yt-dlp` kam mit dem Paket. Läuft der Chat doch in einer Arbeitskopie der Desktop-App, sagt Claude das vor der Analyse und bietet danach an, den Branch in `~/tmp/§Rothirsch` zu übernehmen; erst dann siehst du die Dateien in Obsidian.

## 4. Weiterleiter und Stand

`aios --worker` zeigt die eingerichteten Arbeitspferde und die Projekte, die sie nutzen:

```bash
aios --worker
```

```
=> workhorses (/opt/aios/workers.yaml)
   worker-deno 0.1.0  /opt/aios/workers/worker-deno/v0.1.0  programs deno  check ok
      used by ~/tmp/§Rothirsch
   worker-yt-dlp 0.1.0  /opt/aios/workers/worker-yt-dlp/v0.1.0  programs yt-dlp  check ok
      used by ~/tmp/§Rothirsch
```

`~/.aios/bin/yt-dlp` ist ein **Weiterleiter**: Er sucht vom aktuellen Ordner aufwärts das nächste `.aios/lock.yaml`, das `worker-yt-dlp` sperrt, und ruft dessen Version auf. Lege ein Projekt `P-Projekt` an (Tutorial 02) und frag ihn dort, wofür er sich entscheidet:

```bash
cd ~/tmp/§Rothirsch/P-Projekt
~/.aios/bin/yt-dlp ---which
~/.aios/bin/yt-dlp --version
```

```
program=yt-dlp package=worker-yt-dlp version=0.1.0 target=/opt/aios/workers/worker-yt-dlp/v0.1.0/bin/yt-dlp why=worker-yt-dlp 0.1.0 in ~/tmp/§Rothirsch/.aios/lock.yaml
2026.10.21
```

Außerhalb eines Projekts, das `worker-yt-dlp` sperrt, endet er mit Exit 127, statt irgendein `yt-dlp` zu nehmen:

```
*** yt-dlp: no project of the chain from ~ has worker-yt-dlp in lock.yaml
```

Zwei Projekte können verschiedene Versionen desselben Arbeitspferds sperren; beide liegen nebeneinander auf dem Rechner, und jedes Projekt bekommt seine. Das Verzeichnis der Installationen ist `workers.yaml`:

```yaml
# written by AIOS (worker setup), do not edit
schema: 1
programs:
  deno: [worker-deno]
  yt-dlp: [worker-yt-dlp]
workers:
  worker-deno:
    0.1.0:
      kind: python
      programs: [deno]
      check: ok
      projects: ["~/tmp/§Rothirsch"]
  worker-yt-dlp:
    0.1.0:
      kind: python
      programs: [yt-dlp]
      check: ok
      projects: ["~/tmp/§Rothirsch"]
```

Ein Weiterleiter richtet nie selbst etwas ein. Ist eine Installation beschädigt, baut `aios --worker <paket> setup` sie mit Plan und Rückfrage neu.

## 5. Ein zweiter Rechner

Klonst du den Vault auf einen anderen Rechner, fehlen dort die Arbeitspferde. Vor jeder Antwort im Chat weist AIOS darauf hin:

```
AIOS-WORKERS: missing worker-yt-dlp 0.1.0 — run aios --fetch
```

`aios --fetch` ohne Argument gleicht ab und nimmt die fehlenden Arbeitspferde in den Plan:

```bash
aios --fetch --plan
```

```
=> reconcile the packages of ~/tmp/§Rothirsch with lock.yaml
   unchanged  assistant-anja 0.2.0 (aibex-aios)
   unchanged  distribution-rothirsch 1.0.0 (aibex-aios)
   unchanged  skill-5-8-zusammenfassung 1.2.1 (aibex-aios)
   unchanged  skill-memo 6.0.1 (aibex-aios)
   unchanged  skill-video-analyse 0.2.0 (aibex-aios)
   unchanged  worker-deno 0.1.0 (aibex-aios)
   unchanged  worker-yt-dlp 0.1.0 (aibex-aios)
   plan:
      back up what the plan changes -> ~/tmp/§Rothirsch/.aios/backup
      setup      worker-yt-dlp 0.1.0 -> /opt/aios/workers/worker-yt-dlp/v0.1.0
             python /opt/homebrew/opt/python@3.11/bin/python3.11, 11 packages from worker/requirements.lock:
             | brotli==1.2.1
             | certifi==2026.10.23
             | charset-normalizer==3.5.2
             | idna==3.20
             | mutagen==1.48.1
             | pycryptodomex==3.24.1
             | requests==2.34.2
             | urllib3==2.8.0
             | websockets==17.3
             | yt-dlp==2026.10.21
             | yt-dlp-ejs==0.8.0
             check: yt-dlp --version
      register the project skills of ~/tmp/§Rothirsch
      remove the backup
   (plan only, nothing written)
```

## 6. Aktualisieren und entfernen

Eine neue Version von Rothirsch installierst du mit demselben Befehl, ohne Version: `aios --install distribution-rothirsch` zeigt `upgrade 1.0.0 -> 1.1.0` mit allem, was sich am Kernel, an den Arbeitspferden und an den Paketen ändert. Eine Version eines Arbeitspferds, die kein Projekt mehr nutzt, entfernt derselbe Plan.

Entfernen geht wie bei jedem Paket:

```bash
aios --fetch --remove distribution-rothirsch --plan
```

```
=> remove distribution-rothirsch from ~/tmp/§Rothirsch
   plan:
      back up what the plan changes -> ~/tmp/§Rothirsch/.aios/backup
      remove     assistant-anja -> ~/tmp/§Rothirsch/@/@!Package/assistant-anja
      remove     distribution-rothirsch -> ~/tmp/§Rothirsch/@/@!Package/distribution-rothirsch
      remove     skill-5-8-zusammenfassung -> ~/tmp/§Rothirsch/@/@!Package/skill-5-8-zusammenfassung
      remove     skill-memo -> ~/tmp/§Rothirsch/@/@!Package/skill-memo
      remove     skill-video-analyse -> ~/tmp/§Rothirsch/@/@!Package/skill-video-analyse
      remove     worker-deno -> ~/tmp/§Rothirsch/@/@!Package/worker-deno
      remove     worker-yt-dlp -> ~/tmp/§Rothirsch/@/@!Package/worker-yt-dlp
      ~/tmp/§Rothirsch/.aios/config.yaml: packages: remove distribution-rothirsch
      ~/tmp/§Rothirsch/.aios/lock.yaml: 0 packages
      register the project skills of ~/tmp/§Rothirsch
      /opt/aios/workers.yaml: ~/tmp/§Rothirsch uses no workhorse
      remove     worker-deno 0.1.0 -> /opt/aios/workers/worker-deno/v0.1.0 (no project uses it)
      remove     worker-yt-dlp 0.1.0 -> /opt/aios/workers/worker-yt-dlp/v0.1.0 (no project uses it)
      remove the backup
   (plan only, nothing written)
```

Die Bindung an den Kernel bleibt; Daten in `@Data/` bleiben stehen.

## 7. Was du gesehen hast

| Begriff | im Tutorial |
|---|---|
| Arbeitspferd | `worker-yt-dlp`, `worker-deno`: einmal je Version auf dem Rechner, schreibgeschützt |
| Einrichten (setup) | im Plan von `aios --fetch` bzw. `aios --install`, mit `paket==version`, Hashes und `check` |
| Weiterleiter | `~/.aios/bin/yt-dlp`, Version aus dem nächsten `lock.yaml`, `---which`, Exit 127 |
| Distribution | `distribution-rothirsch`: Kernel und Pakete in exakten Versionen, Rechnerteil vor Vaultteil |
| zweiter Rechner | `AIOS-WORKERS`, Abgleich mit `aios --fetch` |
| Stand | `aios --worker`, `workers.yaml`, Reparatur mit `aios --worker <paket> setup` |

## Weiter

- Ein eigenes Arbeitspferd oder eine eigene Distribution bauen: Die Assistentin **Anja** (`/aios-assistant Anja`) begleitet dich vom Konzept bis zur Veröffentlichung; eine Distribution aus einem erprobten Projekt stellt `/aios-distribution` zusammen.
- Zum Aufräumen: `aios --fetch --remove distribution-rothirsch --to ~/tmp/§Rothirsch` und danach `aios --deactivate ~/tmp/§Rothirsch`.

Die vollständigen Regeln stehen in Spec 07 *Arbeitspferde* und Spec 06 *Distributionen*, installiert unter `/opt/aios/v0.5.0/doc/spec/`.
