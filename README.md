# agents-init

Shared instructions for AI coding agents.

From the root of any target repository, run:

```sh
curl -fsSL https://raw.githubusercontent.com/dani-polani/agents-init/main/install.sh | sh
```

The command downloads the current `AGENTS.md`, `CLAUDE.md` and `COPYRIGHT.md` from this repository and replaces files with the same names in the target repository.

It also adds an `update-agentsmd` target to the target repository's `Makefile` (creating the file if needed, skipping if the target already exists). Run it to pull the latest instructions later:

```sh
make update-agentsmd
```
