# agents-init

Shared instructions for AI coding agents.

From the root of any target repository, run:

```sh
curl -fsSL https://raw.githubusercontent.com/dani-polani/agents-init/main/install.sh | sh
```

The command downloads the current `AGENTS.md`, `CLAUDE.md` and `COPYRIGHT.md` from this repository and replaces files with the same names in the target repository.

If the target repository already uses a task workflow, the command also refreshes its workflow file and the `## Tasks` section of `PROJECT.md` from the matching templates, reading the project values back from the existing `**...:**` lines and leaving every other section of `PROJECT.md` alone.

- `.agents/tools/linear-tasks.md` exists → the Linear workflow is refreshed from `init-linear-tasks` templates (values: `**Linear project:**`, `**Project id:**`, `**Project label:**`, `**Default team:**`, `**Workspace id:**`).
- Otherwise `.agents/tools/obsidian-tasks.md` exists → the Obsidian workflow is refreshed from `init-obsidian-tasks` templates (value: `**Project name:**`); the gitignored `obsidian-tasks.local.md` is never touched.

If both files are present, only the Linear one is refreshed and a warning is printed. Repositories with neither are unaffected.

It also adds an `agentsmd` target to the target repository's `Makefile` (creating the file if needed, skipping if the target already exists). Run it to pull the latest instructions later:

```sh
make agentsmd
```

## Skills

The `skills/` directory holds reusable [Agent Skills](https://skills.sh) shared across agents. These are **not** touched by `install.sh` / `make agentsmd`; they are installed separately with the [`skills` CLI](https://skills.sh), which creates one canonical copy and symlinks it into each agent (Claude Code, Codex, Cursor, …). OMP discovers skills from those agent directories automatically.

- `herdr-orchestrate` — orchestrate a fleet of coding subagents inside [herdr](https://herdr.dev): pick agents by usage, give each a worktree/pane, launch them so herdr sees their state (no false idle), supervise, review, and deliver deployable PRs.
- `init-linear-tasks` — bind a repo to a Linear project and set up the Linear task workflow: create the committed `.agents/tools/linear-tasks.md` and the `## Tasks` section of `PROJECT.md` holding the project name, project id, project label, default team key and workspace id. Everything is committed and machine-agnostic, so a checkout on another machine needs no setup beyond Orca being connected to the same Linear workspace.
- `linear-task-done` — close out an issue once work is finished: read the PRs Linear's own GitHub/GitLab integration linked, post a completion comment for this round of work, and move the issue to `In Review`. `In Review` is the agent's terminal status; `Done` and `Canceled` stay the user's call.
- `init-obsidian-tasks` — **superseded by `init-linear-tasks`**; kept for repositories still on the vault workflow. Set up the Obsidian (TaskNotes) task-management workflow in a repo: create the committed `.agents/tools/obsidian-tasks.md` and `## Tasks` section of `PROJECT.md`, plus a **gitignored** `.agents/tools/obsidian-tasks.local.md` holding the machine-specific vault path. The vault path stays out of git, so the same repo works across machines without conflicts; on a new machine, re-running the skill just regenerates the local file.
- `obsidian-task-done` — **superseded by `linear-task-done`**; kept for repositories still on the vault workflow. Close out a task once work is finished: move it to `review`, append a time entry, write a body summary, and add a Changelog line on the project page. Resolves the vault and project from the files `init-obsidian-tasks` created, so it stays machine-agnostic.
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
