# agents-init

Shared instructions for AI coding agents.

From the root of any target repository, run:

```sh
curl -fsSL https://raw.githubusercontent.com/dani-polani/agents-init/main/install.sh | sh
```

The command downloads the current `AGENTS.md`, `CLAUDE.md` and `COPYRIGHT.md` from this repository and replaces files with the same names in the target repository.

It also adds an `agentsmd` target to the target repository's `Makefile` (creating the file if needed, skipping if the target already exists). Run it to pull the latest instructions later:

```sh
make agentsmd
```

## Skills

The `skills/` directory holds reusable [Agent Skills](https://skills.sh) shared across agents. These are **not** touched by `install.sh` / `make agentsmd`; they are installed separately with the [`skills` CLI](https://skills.sh), which creates one canonical copy and symlinks it into each agent (Claude Code, Codex, Cursor, …). OMP discovers skills from those agent directories automatically.

- `herdr-orchestrate` — orchestrate a fleet of coding subagents inside [herdr](https://herdr.dev): pick agents by usage, give each a worktree/pane, launch them so herdr sees their state (no false idle), supervise, review, and deliver deployable PRs.
- `init-obsidian-tasks` — set up the Obsidian (TaskNotes) task-management workflow in a repo: create `.agents/tools/obsidian-tasks.md` and the `## Tasks` section of `PROJECT.md`, wired to an existing vault and project page. Vault root and project name are runtime inputs, not baked into the skill.
- `obsidian-task-done` — close out a task once work is finished: move it to `review`, append a time entry, write a body summary, and add a Changelog line on the project page. Resolves the vault and project from the files `init-obsidian-tasks` created, so it stays machine-agnostic.
- `set-tools-color-schemes` — methodology to sync Ghostty / herdr / yazi / micro to a VS Code or Cursor theme via **per-tool** configs (not “inherit terminal”): shared palette, semantic ANSI, hex chrome, and micro’s `MICRO_TRUECOLOR` requirement.

Install all skills from this repo globally (available in every project):

```sh
npx skills add dani-polani/agents-init -g
```

Install a specific skill, or target specific agents:

```sh
# one skill
npx skills add dani-polani/agents-init -g --skill herdr-orchestrate

# choose agents explicitly (default: all detected)
npx skills add dani-polani/agents-init -g --skill herdr-orchestrate -a claude-code -a codex -a cursor
```

To **update** later, re-run the same `npx skills add` command — it refreshes the canonical copy from this repo.
