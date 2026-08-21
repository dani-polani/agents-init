---
name: init-linear-tasks
description: Initialize the Linear task-management workflow in a repository. Use when the user wants to set up Linear-based task tracking, bind a repo to a Linear project, or create the linear-tasks guidance files in a new project repo. Creates PROJECT.md and .agents/tools/linear-tasks.md wired to a Linear project through Orca's Linear CLI.
---

# Initialize Linear Tasks workflow

Binds the current repository to one Linear project and writes two committed files:

- **`.agents/tools/linear-tasks.md`** — universal workflow reference. Generic, no project values;
  committed verbatim.
- **`PROJECT.md` → `## Tasks` section** — the five project-specific values (project name, project
  id, project label, default team key, workspace id); committed.

Templates live in this skill's `assets/` directory.

Nothing in this setup is machine-specific, so there is no gitignored local file. A fresh checkout on
another machine works as-is, provided Orca there is connected to the same Linear workspace.

## Step 1 — Resolve the CLI

Pick the executable once and reuse it. Below, `ORCA` stands for what you resolved.

- `ORCA_CLI_COMMAND` set → its value. `ORCA_DEV_REPO_ROOT` set → `orca-dev`.
- Linux outside an Orca-managed terminal → `orca-ide`. Never bare `orca` there: it resolves to the
  GNOME Orca screen reader and starts speech on the user's machine.
- Otherwise → `orca`.

Confirm Orca is up before anything else; start it if not:

```bash
ORCA status --json
ORCA open --json
```

## Step 2 — Find the project (don't ask for raw ids)

List the projects and let the user pick by name. Project the output, don't dump it:

```bash
ORCA linear project list --limit 50 --workspace all --json \
  | jq -r '.result.projects[] | "\(.id)  \(.name)  teams=\([.teams[].key] | join(","))"'
```

- One obvious match to the repository → propose it and ask the user to confirm.
- Several → list names and let the user choose.
- None → the CLI cannot create projects. Ask the user to create it in the Linear UI, then re-run
  this skill. If the Linear MCP connector is authorized in the session, its project-creation tool is
  an alternative; ask before using it. Do not invent any other workaround.

Take `id` as `<PROJECT_ID>` and `name` as `<PROJECT>` from the chosen row.

## Step 3 — Resolve workspace and default team

The workspace id comes back with the teams:

```bash
ORCA linear team list --workspace all --json \
  | jq -r '.result.teams[] | "\(.key)  \(.name)  workspace=\(.workspace.id)"'
```

`<WORKSPACE>` is the workspace id of the chosen project's teams.

`<TEAM>` is the team key used when the agent **creates** an issue — Linear requires one. Pick the
engineering team of that project by default (in this workspace, `BLD`), and confirm with the user.
It does not narrow which issues the agent may read or work; selection is project-scoped.

## Step 3b — Resolve the project label

Orca's issue list does not group by Linear project, so a label carries that grouping. Find an
existing label matching the project:

```bash
ORCA linear team labels --team <TEAM> --workspace <WORKSPACE> --json | jq -r '.result.labels[].name'
```

- A matching label exists → use its name as `<PROJECT_LABEL>`.
- None exists → the CLI cannot create labels. Ask the user to add it in the Linear UI, or to let you
  create it through the Linear MCP connector if that is authorized in the session. Labels here are
  workspace-level, so one label serves every team.

Keep the project and scope dimensions in separate labels. Do not propose fused names like
`cards:frontend`: they multiply with every new scope and make cross-project scope queries
impossible, since label matching is exact-name.

## Step 4 — Verify prerequisites (do not skip)

If any check fails, STOP and report rather than writing broken files.

1. The project id resolves and belongs to the chosen workspace.
2. The team key resolves in that workspace.
3. The project's states include a review state:

   ```bash
   ORCA linear team states --team <TEAM> --workspace <WORKSPACE> --json \
     | jq -r '.result.states[] | "\(.name)  \(.type)"'
   ```

   Exactly one state whose name contains `review` (case-insensitive) and whose type is `started`.
   If zero or several qualify, ask the user which state the agent should treat as terminal, and
   record it in the `## Tasks` section instead of the default `In Review`.
4. A project-scoped listing returns without error:

   ```bash
   ORCA linear list-issues --project <PROJECT_ID> --workspace <WORKSPACE> --limit 3 --json \
     | jq -r '.result.issues[] | "\(.identifier) [\(.state.name)] \(.title)"'
   ```

## Step 5 — Create the files

1. **`.agents/tools/linear-tasks.md`** (committed, generic)
   - Copy `assets/linear-tasks.md` **verbatim**. Do not substitute the placeholders here; they are
     resolved at read time from `PROJECT.md`.
   - If it already exists, overwrite it. The file is generic, so an older copy is just a stale copy.

2. **`PROJECT.md`** (committed)
   - If it does not exist: create from `assets/PROJECT.md`, replacing `<PROJECT>`, `<PROJECT_ID>`,
     `<PROJECT_LABEL>`, `<TEAM>` and `<WORKSPACE>` with the resolved values.
   - If it exists: insert or replace only its `## Tasks` section with the rendered template; leave
     every other section untouched.

3. **Retiring an Obsidian setup in the same repo**
   - If `.agents/tools/obsidian-tasks.md` is present, the repo was on the Obsidian workflow. Ask
     before removing anything. On confirmation, delete `.agents/tools/obsidian-tasks.md` and
     `.agents/tools/obsidian-tasks.local.md`, and drop the `.agents/tools/*.local.md` line from
     `.gitignore` if nothing else needs it.
   - Never delete anything inside the Obsidian vault. Existing task notes are the user's history.

## Updating an already initialized repo

Do not re-run this skill just to pick up template changes. Both files are generated, so `install.sh`
refreshes them:

```sh
make agentsmd    # or: curl -fsSL https://raw.githubusercontent.com/dani-polani/agents-init/main/install.sh | sh
```

It rewrites `.agents/tools/linear-tasks.md` and the `## Tasks` section of `PROJECT.md`, reading the
five values back from the existing `**Linear project:**`, `**Project id:**`, `**Project label:**`,
`**Default team:**` and `**Workspace id:**` lines and leaving every other section alone. Repos without the workflow file are
not affected.

Since the sections are regenerated, edit the templates in this skill's `assets/`, never a repo's
copy.

## Step 6 — Confirm

Report which files were created or updated, plus the project name, project id, project label,
default team and workspace used. Note that everything is committed and machine-agnostic, so a checkout on another
machine needs no setup beyond Orca being connected to the same Linear workspace.
