---
name: init-obsidian-tasks
description: Initialize the Obsidian (TaskNotes) task-management workflow in a repository. Use when the user wants to set up Obsidian-based task tracking, the task/changelog/time-tracking flow, or the obsidian-tasks guidance files in a new project repo. Creates PROJECT.md and .agents/tools/obsidian-tasks.md wired to the user's Obsidian vault.
---

# Initialize Obsidian Tasks workflow

Sets up the Obsidian / TaskNotes task flow in the current repository: creates
`.agents/tools/obsidian-tasks.md` (universal reference) and the `## Tasks` section of
`PROJECT.md` (project-specific), wired to an existing Obsidian project page.

Templates live in this skill's `assets/` directory.

## Step 1 — Gather inputs

Ask the user for both, then proceed:

1. **Project name** — must match an existing project page `<vault>/PROJECTS/<name>.md`, and is
   the `[[name]]` wikilink used in each task's `projects:` field.
2. **Vault root** — the absolute path to the Obsidian vault on this machine. Ask the user for it;
   there is no default. If a sibling repo already has `.agents/tools/obsidian-tasks.md`, its
   "Machine configuration" table holds the value to reuse.

## Step 2 — Verify prerequisites (do not skip)

Run these checks. If any fails, STOP and report clearly rather than creating broken files.

1. Vault root exists: `test -d <vault>`
2. Plugin config exists: `test -f <vault>/.obsidian/plugins/tasknotes/data.json`.
   Read it and extract the real `tasksFolder` and `archiveFolder` values — use these, don't assume.
3. Tasks folder exists: `test -d <vault>/<tasksFolder>`
4. Project page exists: `test -f <vault>/PROJECTS/<name>.md`.
   - If missing, tell the user; ask whether to use a different name or create a minimal page.
5. Project page contains a `## Changelog` section. If absent, offer to append one (the changelog
   flow writes there).

## Step 3 — Create the files

1. **`.agents/tools/obsidian-tasks.md`**
   - Copy `assets/obsidian-tasks.md`.
   - Replace every `<VAULT>` with the confirmed vault root.
   - If the plugin config's `tasksFolder` / `archiveFolder` differ from the template's
     `META/planning/Tasks` / `META/planning/Archive`, update those occurrences too.
   - Leave `<PROJECT>` untouched — it is resolved per task by reading `PROJECT.md`.

2. **`PROJECT.md`**
   - If it does not exist: create from `assets/PROJECT.md`, replacing `<PROJECT>` with the project name.
   - If it exists: insert or replace only its `## Tasks` section with the rendered template;
     leave all other sections untouched.

## Step 4 — Confirm

Report which files were created or updated, plus the project name and vault root used. Remind the
user the result is reusable: copying to another repo on this machine only requires changing the
project name in `PROJECT.md`.
