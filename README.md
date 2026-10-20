![AIbex AIOS](etc/image/banner.jpg)
--------------------------------------------------------------------------------

# AIbex AIOS — an Operating System for the Context of AI Assistants

**AIbex AIOS is an operating system for the context of AI assistants.** It
manages which knowledge a chat loads, reads on demand or does not see, and
provides file system conventions, assistants and skills for this purpose.
Execution is left to a host (in v0.3: Claude Code).

AIOS works on an Obsidian vault: every chat runs in a project directory and
receives the knowledge that belongs to this project — no more, no less. An
assistant, assigned to the project, gives every chat there a personality with
its own selection of skills, knowledge and a surface.


## Requirements

macOS or Linux with `bash`, `git`, `python3` (3.9 or newer) and
[Claude Code](https://claude.com/claude-code) as the host.


## Installation

Copy this line into a terminal:

```sh
R=~/git/AIbex/aibex-aios; ([ -d "$R/.git" ] || git clone https://github.com/aibex-aios/aibex-aios "$R") && "$R/bin/aios" --install v0.3.1
```

It clones the repository to `~/git/AIbex/aibex-aios` unless a clone is already
there (an existing clone is left as it is), then prepares the machine and
installs. The installed files always come from the tag `v0.3.1`, not from the
working tree of the clone; without a version, the highest release tag is
installed.

`aios --install` shows a plan and asks once before it writes anything. It
installs the version read-only to `/opt/aios/v0.3.1/` (without `sudo`:
`~/.aios/versions/`), puts the forwarders `aios` and `aios-context` into
`~/bin`, adds two hooks to `~/.claude/settings.json`, the AIOS skills and the
alias `/gui` to `~/.claude/skills/`. Hooks of `ai-brain` are saved and restored by
`aios --uninstall`.

Installing does not touch any vault. A vault runs with AIOS only after it has
been **activated**; all other vaults keep working as before (legacy mode).


## Quick start

```sh
  mkdir ~/Vaults/§Demo
  aios --activate v0.3.1 ~/Vaults/§Demo      # writes §Demo/.aios/config.yaml, creates §Demo/@/ and a git repo
```

Put knowledge into the **masterspace** `@/` of a project. The prefix of a
folder decides what a chat sees:

| Folder | Class | Effect |
|---|---|---|
| `@Rule/`, `@Wissen/@Content/`, files directly in `@/` | load | loaded at the start of every chat (master context) |
| `@@Kapitel/` | available | not loaded; the master context lists it, the chat reads it on demand |
| `@!Skill/`, `@!Assistant/`, `@!Prompt/` | hidden | blueprints of skills, assistants and prompts |

A project is any folder with `@/` and its own git repo; the vault root is the
root project. A chat in a project sees the masterspaces from the vault root down
to the project. Open a chat in a new folder and AIOS offers to initialize it
(`/aios-init`); at the first start of a chat it checks the structure of the
project and offers to complete it.

In a chat:

| Skill | Purpose |
|---|---|
| `/aios-context` | check and show the master context and the assistant |
| `/aios-init` | make the folder a project or complete it (`@/`, git, `.gitignore`, exclusion in the repo above) |
| `/aios-integrity` | check the structure and the commit state of a project and all its subprojects |
| `/aios-deploy memo==6.0.0` | deploy a skill version into a project or an assistant |
| `/aios-deploy gaertner==0.2.0` | deploy a demo assistant of the library into a project |
| `/aios-register` | register the project skills for Claude Code |
| `/aios-assistant Gärtner` | assign an assistant to the project (`--none`, `--inherit`) and switch to it |
| `/gui`, `/aios-gui` | surface of the assistant of the session, surface of AIOS |
| `/aios-memo` | memo style in every project (only when no skill `memo` is available) |
| `/aios-status` | project status from memos and git |

Registered skills become available in the **next** chat. The assistant is a
property of the project: `assistant: <name>`, `none` or `inherit` (the default)
in `.aios/config.yaml`. New chats load it automatically; compaction and resume
keep the assistant a chat started with.

Every skill and every assistant has a version (`version: MAJOR.MINOR.PATCH` in
its frontmatter). A blueprint without a version is not registered and is
reported as `AIOS-WARNING` at the start of a session.


## Demo assistants

The library of every version contains two demo assistants to play with
(`aios --library`):

| Assistant | Character | Own skill |
|---|---|---|
| `gaertner` (Gärtner) | down-to-earth gardener, calculates only with apples and pears; knows varieties and grafting; surface with an apple-pear calculator (`/gui`) | `apfel-birnen-algebra`, `gaertner-gui` |
| `astronom` (Astronom) | poetic, precise astronomer, calculates only with sun and moon | `sonne-mond-zahlen` |

Each one politely refuses the other one's calculations, so the answer shows
which assistant and which skill are active. The tutorials (German) walk through
a vault with both of them and through projects and their integrity:

- [`doc/tutorials/01 Erste Schritte mit den Demo-Assistenten.md`](doc/tutorials/01%20Erste%20Schritte%20mit%20den%20Demo-Assistenten.md)
- [`doc/tutorials/02 Projekte und Integrität.md`](doc/tutorials/02%20Projekte%20und%20Integrit%C3%A4t.md)


## Command line

| Command | Purpose |
|---|---|
| `aios --install [v<version>]`, `--versions`, `--remove-version v<version>`, `--uninstall` | installations |
| `aios --activate v<version> [<path>]`, `--deactivate [<path>]`, `--config [<path>]` | bind a vault or project to a version, show the configuration |
| `aios --init`, `--integrity`, `--register`, `--deploy`, `--library` | projects, skills and assistants |
| `aios --assistant <name\|none\|inherit> [--to <project>]`, `--gui [--html] [--aios]` | assignment of the assistant, surfaces |
| `aios-context --context`, `--load`, `--id`, `--list`, `--assistant <name> [--load]`, `--assistants`, `--assignment` | master context and assistants |

Every writing command shows a plan first; `--plan` only shows it, `--yes`
skips the question and prints only the result. Several versions can be installed side by side; each vault
or project chooses its version with `aios: <version>` in `.aios/config.yaml`.


## Documentation

The specification of each version is part of it: `spec/` in this repository,
installed to `/opt/aios/v<version>/doc/spec/`; tutorials are installed from
`doc/tutorials/` to `/opt/aios/v<version>/doc/tutorials/`.

| Spec | Content |
|---|---|
| `01 AIbex AIOS v0.4 — Überblick` | definition, terms, scope, pre-releases, invariants, acceptance test |
| `02 Master-Kontext` | projects, chain, classes, `aios-context`, hooks, assistant of the session, consistency check |
| `03 Skills und Assistenten` | skills, versions, deploy, register, assistants and their assignment, GUIs, `aios-memo` |
| `04 Installation und Konfiguration` | files, formats, forwarders, the command `aios` |
| `05 Projekte` | project structure and naming, init, integrity, status |
| `06 Pakete und Workspaces` | packages, manifest, versions, hub, deploy, lock, workers, workspaces, contribute (draft v0.4) |


## Development

```sh
  tests/run                  # all tests in a sandbox, never touch the machine
  tests/live/hooks.sh        # real headless Claude sessions (cost tokens)
  tests/live/skills.sh
  tests/live/assistants.sh
```

A clone can be used without installing: point `AIOS_HOME` to it, or add a
line `v0.3.2-dev: ~/git/AIbex/aibex-aios` to `~/.aios/installations.yaml`.
`CLAUDE.md` holds the rules for working on the repository, `STATUS.md` the
state of the implementation.


## Status

Version **0.3.1** (`STATUS.md`): all output of `aios` and `aios-context` is in English; the assistant is assigned to the
project and inherited, projects get a fixed structure with a consistency check
and `/aios-integrity`, assistants and AIOS get surfaces, `/aios-memo` always
provides a memo style. Versions 0.1.0 and 0.2.0 are released (tags `v0.1.0`,
`v0.2.0`); 0.3.0 was not released. All versions below 1.0 are alpha and beta versions.
