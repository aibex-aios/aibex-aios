# Dokumentation von AIbex AIOS

Inhaltsverzeichnis der Dokumentation, die mit jeder Version installiert wird, unter `~/.aios/versions/v<version>/doc/` (mit `aios --install --system` unter `/opt/aios/v<version>/doc/`). Im A/W gibt der Hook `Read` unter `doc/` der gebundenen Version ohne Rückfrage frei (Spec 02, *Freigabe*, R2). Den Ordner selbst kann eine Session nicht auflisten; deshalb stehen hier die genauen Dateinamen.

## Spec — `doc/spec/`

| Datei | Inhalt |
|---|---|
| `01 AIbex AIOS v0.6 — Überblick.md` | Definition, Begriffe, Grundregeln, Umfang, Vorabversionen, Invarianten, Abnahmetest |
| `02 Master-Kontext.md` | Vault, Projekt und Kette, Arten von Vaults, Klassen, Block der Kernel-Skills, `aios --context`, Hooks mit Freigabe, Legacy-Modus |
| `03 Skills und Assistenten.md` | Arten von Skills, Versionen, Ausführungsmodell, Kernel-Skills, Assistenten und ihre Zuordnung, Oberflächen |
| `04 Installation und Konfiguration.md` | Dateistrukturen, Formate, CLI `aios`, Versionen und Aktivierung, Weiterleiter, Distributionen, Umstieg |
| `05 Projekte.md` | Struktur und Name eines Projekts, `/aios-init`, Konsistenzprüfung, `/aios-integrity`, `/aios-status` |
| `06 Pakete und Workspaces.md` | Paket-Manifest, Versionen und Bereiche, Hubs, Resolver, Holen, Ausrollen, Distributionen, Lock, `@Data/`, Workspaces, Rückfluss |
| `07 Arbeitspferde.md` | Pakete `worker-<name>`, Installation je Version, Weiterleiter, Abläufe, `aios --worker` |

## Tutorials — `doc/tutorials/`

| Datei | Inhalt |
|---|---|
| `01 Erste Schritte mit den Demo-Assistenten.md` | Installieren, Vault binden, Demo-Assistenten |
| `02 Projekte und Integrität.md` | Projekte anlegen und prüfen |
| `03 Pakete und Taschenrechner.md` | Pakete holen, die Demo-App Taschenrechner |
| `04 Workspaces.md` | Workspaces auf mehreren Rechnern: `attach`, `sync`, `detach`, Namensschema, `sync:` |
| `05 Arbeitspferde und Distributionen.md` | Arbeitspferde und die Distribution Rothirsch |
