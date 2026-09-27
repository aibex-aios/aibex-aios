![AIbex AIOS](etc/image/banner.jpg)
--------------------------------------------------------------------------------

# AIbex AIOS — AI Operating System for Project Work

**AIbex AIOS** turns an Obsidian vault into a **project-aware chat environment**
for AI coding assistants — first [Claude Code](https://code.claude.com/docs),
later ChatGPT Codex. Every chat is opened in a project directory of the vault;
AIOS gives it exactly the context that belongs to this project, and the chat
keeps project status and information in the same directory.

AIOS combines two ideas:

| Idea | Contribution |
|---|---|
| **AI-Brain** — path-activated context | The context of a chat follows from *where* it runs: the masterspaces on the path from the project directory up to the vault root are inherited. Transparent, deterministic, versionable. |
| **Custom AIs** (as in roosi AIOS) | An **agent** bundles a system prompt, a selection of skills, a model and its own knowledge. A chat is assigned to an agent. |

In short: **the path supplies the project context, the agent supplies the
personality and the selection of skills and knowledge.**


## Core Concepts

| Term | Meaning |
|---|---|
| **Vault root** | Root of an Obsidian vault, its name starts with `§` (e.g. `§AIbex`) |
| **Masterspace** | A directory named `@`; a container of subdirectories, each of one of three classes |
| **Root / local masterspace** | `§…/@` at the vault root / the mandatory (possibly empty) `@` in the project directory |
| **Masterspace chain** | All masterspaces from the local one up to the root masterspace |

The class of a masterspace subdirectory is part of its name:

| Class | Name | Behaviour | Example |
|---|---|---|---|
| **load** | `@…` | loaded completely at chat start | `@/@Rule` |
| **available** | `@@…` | part of the context, but read only on demand | `@/@Wissen/@@Chapter1` |
| **hidden** | `@!…` | never context; blueprints for the tools | `@/@!Skill`, `@/@!Prompt`, `@/@!Agent` |

Skill blueprints in `@!Skill` are registered as Claude Code skills of the
project; agents in `@!Agent/<name>/AGENT.md` reference a prompt, skills and a
model by name and carry their own knowledge.


## Installation

Prerequisites: `bash`, `git`, `jq`, `curl`.

```sh
  git clone https://github.com/aibex-hub/aibex-aios ~/git/AIbex/aibex-aios
  cd ~/git/AIbex/aibex-aios
  ./bin/aios --prepare     # fresh machine only: stup, ~/bin, ~/etc, profile.sh
  ./bin/aios --install     # install AIOS for this user
```

`aios --prepare` installs or updates [stup](https://github.com/bluccino/tool-stup)
and creates `~/bin`, `~/etc`, `~/tmp`, `~/git`. An existing `~/bin/profile.sh`
is never overwritten.

`aios --install` copies the scripts to `~/bin` (or, if missing, to the first
writable directory in `PATH`), registers the AIOS skills in `~/.claude/skills`
and records version, repo and bin location in `~/etc/aios`. Both commands show
a plan and ask before they write anything; both are idempotent.

No virtual environment is needed at runtime — hooks and skills run in every
Claude session, including the desktop app.


## Development Environment (optional)

For working on AIOS itself the repo carries a [pimp](https://github.com/bluccino/tool-pimp)
blueprint for the virtual environment `@aios`:

```sh
  . pimp                   # create and activate @aios
  aios --install           # same installation as above
```


## Repository Layout

```
aibex-aios/
├── bin/aios          installer and maintenance utility
├── .pimp/            blueprint of the venv @aios (optional)
├── etc/image/        README images
└── §AIOS/            vault root of AIOS itself (planned)
    ├── @/            root masterspace for working on AIOS
    ├── skills/       AIOS skills  -> ~/.claude/skills/
    ├── bin/          scripts      -> ~/bin/
    └── etc/          configuration, hook templates -> ~/etc/aios/
```


## Status

Version **0.1.0** — early work in progress, not yet tagged.

| Available | Planned |
|---|---|
| `aios -?`, `--help`, `--version`, `--prepare`, `--install` | hooks, `--uninstall`, `--update`, AIOS skills, vault `§AIOS`, agent activation (`/agent`), Codex support |

```sh
  aios -?                  # brief usage
  aios --help              # comprehensive help
```
