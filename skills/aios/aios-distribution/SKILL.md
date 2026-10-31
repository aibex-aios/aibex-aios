---
name: aios-distribution
description: Stellt eine Distribution von AIbex AIOS zusammen - aus dem erprobten Stand eines Projekts (Pakete aus lock.yaml, Kernel aus aios:) mit Ergänzungen aus den Hubs, prüft sie mit dem Resolver und legt ein lokales Paket-Repo distribution-<name> an (Commit und lokaler Tag, nichts nach außen). Verwenden bei "/aios-distribution", "Distribution zusammenstellen", "Distribution anlegen".
allowed-tools: Bash(aios --library *), Bash(aios --install * --plan), Bash(aios --context *), Bash(git -C *), Bash(mkdir -p *), Write
---

# Distribution zusammenstellen

Ein AIOS-Skill von AIbex AIOS (Spec 03, *Distributionen*; Spec 06, *Distributionen*). Er legt ein Paket-Repo **lokal** an; veröffentlicht wird nicht (das macht der User oder die Assistentin Anja mit eigener Rückfrage je Schritt nach außen).

**Arbeitsverzeichnis:** Führe alle Befehle im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; Repos nur mit absoluten Pfaden und `git -C <repo>`. Rufe `aios …` immer als einzelnen Befehl auf, ohne `;`, `&&`, `|`, Umleitung oder vorangestelltes `cd`; nur so gibt AIBOS den Aufruf ohne Rückfrage frei.

## Ablauf

1. **Name und Zweck:** Frage nach dem Namen (`distribution-<name>`, englisch, Kleinbuchstaben und `-`) und nach einem Satz für `description`, falls sie fehlen. Version der neuen Distribution: `1.0.0`, sonst die nächste nach dem letzten Tag des Repos.
2. **Ausgangsprojekt:** Standard ist das Projekt der Session; ein anderes nur, wenn der User es nennt. Lies `<projekt>/.aios/lock.yaml` und `<projekt>/.aios/config.yaml` (Read-Werkzeug). In die Distribution kommen die Pakete aus `packages:` mit ihrer Version aus `lock.yaml`; Pakete mit `required_by` sind Abhängigkeiten und kommen **nicht** in `depends`, der Resolver holt sie. Der Kernel ist `aios:` der Kette (`aios --context --id` nennt die Version im Feld `mode=aios-<version>`). Zeige die Liste mit Versionen und den Kernel.
3. **Ergänzen oder streichen:** Frage, ob Pakete dazukommen oder wegfallen sollen und ob die Distribution einen Kernel bringt (Standard ja; ohne `kernel:` ist sie eine reine Sammlung). Neue Pakete suchst du mit `aios --library <wort>` und nimmst deren höchste Version, die zum Kernel passt.
4. **Entwurf schreiben:** Lege den Entwurf in einem Ordner des Scratchpads an (`<scratchpad>/distribution-<name>/`): `manifest.yaml`, `README.md`, Lizenz (unten). Dann `git -C <entwurf> init -b main`, `add -A`, `commit -m "distribution-<name> <version>: Entwurf"` und `git -C <entwurf> tag v<version>`.
5. **Prüfen:** Leg einen leeren Probe-Vault im Scratchpad an (`mkdir -p "<scratchpad>/§Probe-<name>"`, nie im Vault des Users) und führe `aios --install distribution-<name> "<scratchpad>/§Probe-<name>" --from "<entwurf>" --plan` aus. Der Plan zeigt Rechnerteil (Kernel, Arbeitspferde) und Vaultteil (Bindung, Pakete). Meldet er einen Fehler (`no versions fulfil all ranges`, `requires.aios`, fehlender Tag des Kernels), nenne ihn, schlage eine Korrektur vor und beginne nach der Antwort wieder bei Schritt 4.
6. **Plan zeigen und fragen:** Zielordner nach den Vorgaben des Users (Regel *AIOS-Pakete — Vorgaben*, `name: aios-pakete-vorgaben`), sonst `<projekt>/@Package/distribution-<name>/` mit `/@Package/` in der `.gitignore` des Projekts. Zeige Zielordner, `manifest.yaml` vollständig, die übrigen Dateien mit Kurzinhalt, Commit und lokalen Tag. Gibt es den Zielordner schon, brich ab und sag es. Frage einmal; der Wunsch „leg an" ist keine Bestätigung des Plans.
7. **Anlegen:** Nach Ja die Dateien in den Zielordner schreiben, `git -C <repo> init -b main`, `add -A`, `commit -m "distribution-<name> <version>: zusammengestellt aus <projekt>"`, `tag v<version>` (lokal, nicht gepusht). Beim Standardort zusätzlich die Zeile `/@Package/` in der `.gitignore` des Projekts.
8. **Melden:** Ort, Inhalt, Probe für den User: `aios --install distribution-<name> <leerer-vault> --from <repo>` (in einem leeren Vault, nie im Arbeitsvault); nächster Schritt: veröffentlichen mit Anja (`anja-veroeffentlichen`) oder von Hand. Solange der Tag nicht gepusht ist, darf er bei einer Korrektur neu gesetzt werden.

## Vorlagen

`manifest.yaml` (alle Versionen exakt mit `==`; `kernel:` nur mit Kernel):

```yaml
name: distribution-<name>
version: <version>
type: distribution
description: "<ein Satz>"
license: Apache-2.0
requires:
  aios: ">=<major>.<minor>,<<major>.<minor+1>"
kernel: "==<kernel>"
depends:
  <paket>: "==<version>"
```

`README.md`: Überschrift `# distribution-<name>`, Zweck, Tabelle der Pakete mit Versionen und Kernel, Installieren mit `aios --install distribution-<name>` (Rechnerteil, Vaultteil, ein Ja), Lizenz.

**Lizenz** nach den Vorgaben des Users; ohne Vorgaben frag. Bei Apache-2.0: `LICENSE` als unveränderte Kopie des Lizenztexts (z. B. aus einem geholten Paket mit Apache-2.0, `@/@!Package/<paket>/LICENSE`) und `NOTICE` mit Paketname und Copyright-Zeile.

Der Skill schreibt nur im Scratchpad und, nach Ja, im Zielordner; er holt nichts, installiert nichts und pusht nichts.
