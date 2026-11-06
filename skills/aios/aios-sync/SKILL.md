---
name: aios-sync
description: Synchronisiert den Projektbaum eines AIbex-AIOS-Workspace mit seinen Remotes - fehlende Projekte klonen, neue Stände per fast-forward holen, neu Geklontes lauffähig machen, workspace.yaml nachführen, eigene Stände pushen (ohne Tags, Geheimnisse halten an). Verwenden bei "/aios-sync", "sync", "sync project", "synchronisiere das Projekt", "sync workspace", "sync vault", "synchronisiere den Workspace", "Workspace abgleichen", nach einem Commit bei sync auto.
allowed-tools: Bash(aios --workspace *)
---

# Workspace synchronisieren

Ein AIOS-Skill von AIbex AIOS (Spec 06, *sync*; Spec 03, *Workspaces*).

**Arbeitsverzeichnis:** Führe alle Befehle dieses Skills im Arbeitsverzeichnis der Session aus und wechsle nie mit `cd`; AIOS bestimmt den Workspace aus dem aktuellen Verzeichnis. Andere Orte nur als ausdrücklichen Pfad angeben. Rufe `aios …` immer als einzelnen Befehl auf, ohne `;`, `&&`, `|`, Umleitung oder vorangestelltes `cd`; nur so gibt AIBOS den Aufruf ohne Rückfrage frei.

## Ablauf

1. **Umfang** (V0.6, Memo 203: B33), nach den Worten des Users:
   - **Projekt** („sync project", „synchronisiere das Projekt") **oder kein Wort** („/aios-sync", „sync", das Angebot nach einem Commit): das Projekt der Session mit seinen Unterprojekten. Gib **keinen Pfad** an; AIOS nimmt das Projekt des Arbeitsverzeichnisses, an der Vault-Root den ganzen Workspace.
   - **Workspace** („sync workspace", „sync vault", „synchronisiere den Workspace"): der ganze Workspace; gib die Vault-Root als Pfad an.
   - **Ein Pfad** oder `--group <g>`: wie angegeben.
   Nenne den Umfang in einem Satz (welches Projekt bzw. „ganzer Workspace").
2. **Plan:** `aios --workspace sync ["<pfad>"] --plan`. Endet der Befehl mit `*** aios --workspace: …` (z. B. `sync is off`, kein Workspace), nenne die Meldung und beende.
3. **Zeigen:** Fasse den Plan **einmal** kurz zusammen (nicht im Text und in der Frage wiederholen): was geklont, geholt, eingetragen und gepusht wird. Nenne bei jedem Push die ausgehenden Commits aus dem Plan und, **mit einer eigenen Frage**, die Commits, die nicht aus dieser Session stammen (Regel *Weiter*). Nenne die Hinweise (`note: …`), etwa Repos ohne Remote mit dem vorgeschlagenen Befehl, ohne sie auszuführen.
4. **Fragen:** einmal, ob du ausführen sollst. Ohne Ja nichts ausführen.
5. **Ausführen:** `aios --workspace sync ["<pfad>"] --yes` und das Ergebnis kurz melden: geklont, geholt, gepusht; unverändert gelassene Repos mit Grund (`kept`, `not pushed`, `push stopped`).

## Grenzen

- sync committet nichts außer `workspace.yaml` und Ausschlüssen; nicht committete Arbeit nennst du, committest sie aber nicht ungefragt.
- Repos am Remote anlegen ist ein eigener Schritt nach außen mit eigener Rückfrage, nie Teil dieses Skills.
- Hält sync einen Push wegen Geheimnissen an (`push stopped`), schlage vor, die Datei aus der Geschichte zu nehmen und nach `@Secret/` zu legen; ändere die Geschichte nie ohne ausdrückliches Ja.
