![AIbex AIOS](etc/image/banner.jpg)
--------------------------------------------------------------------------------

# AIbex AIOS — an Operating System for the Context of AI Assistants

**AIbex AIOS is an operating system for the context of AI assistants.** It
manages which knowledge a chat loads, reads on demand or does not see, and
provides file system conventions, assistants and skills for this purpose.
Execution is left to a host (in v0.2: Claude Code).

AIOS works on an Obsidian vault: every chat runs in a project directory and
receives the knowledge that belongs to this project — no more, no less. An
assistant can give the chat a personality with its own selection of skills and
knowledge.


## Requirements

macOS or Linux with `bash`, `git`, `python3` (3.9 or newer) and
[Claude Code](https://claude.com/claude-code) as the host.


## Installation

Copy this line into a terminal:

```sh
R=~/git/AIbex/aibex-aios; ([ -d "$R/.git" ] || git clone https://github.com/aibex-hub/aibex-aios "$R") && "$R/bin/aios" --install v0.2.0
```

It clones the repository to `~/git/AIbex/aibex-aios` unless a clone is already
there (an existing clone is left as it is), then prepares the machine and
installs. The installed files always come from the tag `v0.2.0`, not from the
working tree of the clone; without a version, the highest release tag is
installed.

`aios --install` shows a plan and asks once before it writes anything. It
installs the version read-only to `/opt/aios/v0.2.0/` (without `sudo`:
`~/.aios/versions/`), puts the forwarders `aios` and `aios-context` into
`~/bin`, adds two hooks to `~/.claude/settings.json` and the AIOS skills to
`~/.claude/skills/`. Hooks of `ai-brain` are saved and restored by
`aios --uninstall`.

Installing does not touch any vault. A vault runs with AIOS only after it has
been **activated**; all other vaults keep working as before (legacy mode).


## Quick start

```sh
  mkdir ~/Vaults/§Demo
  aios --activate v0.2.0 ~/Vaults/§Demo      # writes §Demo/.aios/config.yaml, creates §Demo/@/
```

Put knowledge into the **masterspace** `@/` of a project. The prefix of a
folder decides what a chat sees:

| Folder | Class | Effect |
|---|---|---|
| `@Rule/`, `@Wissen/@Content/`, files directly in `@/` | load | loaded at the start of every chat (master context) |
| `@@Kapitel/` | available | not loaded; the master context lists it, the chat reads it on demand |
| `@!Skill/`, `@!Assistant/`, `@!Prompt/` | hidden | blueprints of skills, assistants and prompts |

A project is any folder with `@/`; the vault root is the root project. A chat
in a project sees the masterspaces from the vault root down to the project.
Open a chat in a new folder and AIOS offers to initialize it (`/aios-init`).

In a chat:

| Skill | Purpose |
|---|---|
| `/aios-context` | check and show the master context |
| `/aios-init` | make the folder a project (`@/`, `@Memo/`, git, first commit) |
| `/aios-deploy memo==6.0.0` | deploy a skill version into a project or an assistant |
| `/aios-deploy gaertner==0.1.0` | deploy a demo assistant of the library into a project |
| `/aios-register` | register the project skills for Claude Code |
| `/aios-assistant Gärtner` | activate an assistant for this chat |
| `/aios-status` | project status from memos and git |

Registered skills become available in the **next** chat; an assistant is
available as soon as it is deployed.

Every skill and every assistant has a version (`version: MAJOR.MINOR.PATCH` in
its frontmatter). A blueprint without a version is not registered and is
reported as `AIOS-WARNING` at the start of a session.


## Demo assistants

The library of every version contains two demo assistants to play with
(`aios --library`):

| Assistant | Character | Own skill |
|---|---|---|
| `gaertner` (Gärtner) | down-to-earth gardener, calculates only with apples and pears; knows varieties and grafting | `apfel-birnen-algebra` |
| `astronom` (Astronom) | poetic, precise astronomer, calculates only with sun and moon | `sonne-mond-zahlen` |

Each one politely refuses the other one's calculations, so the answer shows
which assistant and which skill are active. The tutorial
[`doc/tutorials/01 Erste Schritte mit den Demo-Assistenten.md`](doc/tutorials/01%20Erste%20Schritte%20mit%20den%20Demo-Assistenten.md)
walks through a vault with both of them (German).


## Command line

| Command | Purpose |
|---|---|
| `aios --install [v<version>]`, `--versions`, `--remove-version v<version>`, `--uninstall` | installations |
| `aios --activate v<version> [<path>]`, `--deactivate [<path>]`, `--config [<path>]` | bind a vault or project to a version, show the configuration |
| `aios --init`, `--register`, `--deploy`, `--library` | projects, skills and assistants |
| `aios-context --context`, `--load`, `--id`, `--list`, `--assistant <name>`, `--assistants` | master context and assistants |

Every writing command shows a plan first; `--plan` only shows it, `--yes`
skips the question. Several versions can be installed side by side; each vault
or project chooses its version with `aios: <version>` in `.aios/config.yaml`.


## Documentation

The specification of each version is part of it: `spec/` in this repository,
installed to `/opt/aios/v<version>/doc/spec/`; tutorials are installed from
`doc/tutorials/` to `/opt/aios/v<version>/doc/tutorials/`.

| Spec | Content |
|---|---|
| `01 AIbex AIOS v0.2 — Überblick` | definition, terms, scope, pre-releases, invariants, acceptance test |
| `02 Master-Kontext` | projects, chain, classes, `aios-context`, hooks |
| `03 Skills und Assistenten` | skills, versions, deploy, register, assistants, init, status |
| `04 Installation und Konfiguration` | files, formats, forwarders, the command `aios` |


## Development

```sh
  tests/run                  # all tests in a sandbox, never touch the machine
  tests/live/hooks.sh        # real headless Claude sessions (cost tokens)
  tests/live/skills.sh
  tests/live/assistants.sh
```

A clone can be used without installing: point `AIOS_HOME` to it, or add a
line `v0.2.0-dev: ~/git/AIbex/aibex-aios` to `~/.aios/installations.yaml`.
`CLAUDE.md` holds the rules for working on the repository, `STATUS.md` the
state of the implementation.


## Status

Version **0.2.0** in development (`STATUS.md`): assistant instead of agent,
a version for every skill, demo assistants. Version 0.1.0 is released (tag
`v0.1.0`). All versions below 1.0 are alpha and beta versions.
