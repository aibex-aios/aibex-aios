![AIbex AIOS](etc/image/banner.jpg)
--------------------------------------------------------------------------------

# AIbex AIOS — an Operating System for the Context of AI Assistants

**AIbex AIOS is an operating system for the context of AI assistants.** It
manages which knowledge a chat loads, reads on demand or does not see, and
provides file system conventions, agents and skills for this purpose.
Execution is left to a host (Claude Code, Codex).

AIOS works on an Obsidian vault: every chat runs in a project directory and
receives the knowledge that belongs to this project — no more, no less. An
agent can give the chat a personality with its own selection of skills and
knowledge.


## Installation

```sh
  git clone https://github.com/aibex-hub/aibex-aios ~/git/AIbex/aibex-aios
  cd ~/git/AIbex/aibex-aios
  ./bin/aios --prepare     # fresh machine only
  ./bin/aios --install     # install AIOS for this user
```

`aios --help` explains what both commands do. They show a plan and ask before
they write anything.


## Status

Version **0.1.0** — early work in progress, not yet tagged.
