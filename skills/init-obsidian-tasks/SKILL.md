---
name: init-obsidian-tasks
description: Initialize the Obsidian (TaskNotes) task-management workflow in a repository. Use when the user wants to set up Obsidian-based task tracking, the task/changelog/time-tracking flow, or the obsidian-tasks guidance files in a new project repo. Creates PROJECT.md and .agents/tools/obsidian-tasks.md wired to the user's Obsidian vault.
---

# Initialize Obsidian Tasks workflow

Sets up the Obsidian / TaskNotes task flow in the current repository. It writes three files, split
by what is safe to commit:

- **`.agents/tools/obsidian-tasks.md`** — universal workflow reference. Generic, no absolute paths;
  committed.
- **`PROJECT.md` → `## Tasks` section** — project-specific (holds the project name); committed.
- **`.agents/tools/obsidian-tasks.local.md`** — machine-specific vault paths; **gitignored**, so it
  never conflicts when the same repo is checked out on another machine.

Templates live in this skill's `assets/` directory.

The vault root is the only machine-specific value, so it is the only thing kept out of git. On a
second machine the two committed files already arrive with the repo — only the local file and the
`.gitignore` line need to be (re)created. This skill is safe to re-run for exactly that.

## Step 1 — Find the vault (don't ask for a raw path first)

This workflow requires the TaskNotes plugin, so the vault always contains
`<vault>/.obsidian/plugins/tasknotes/`. Search for it before asking the user:

```sh
find ~ -maxdepth 6 -type d -path '*/.obsidian/plugins/tasknotes' 2>/dev/null
```

The vault root is the match with `/.obsidian/plugins/tasknotes` stripped off the end.

- One match → propose it and ask the user to confirm.
- Several → list them and let the user pick.
- None → raise `-maxdepth` or search other roots (e.g. `/mnt`, `/media`); only if that also finds
  nothing, ask the user for the absolute path.

Shortcut: if a sibling repo already has `.agents/tools/obsidian-tasks.md`, its "Machine
configuration" table already holds the vault root — reuse it instead of searching.

## Step 1b — Project name

Ask for the **project name** — it must match an existing project page `<vault>/PROJECTS/<name>.md`,
and is the `[[name]]` wikilink used in each task's `projects:` field.

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

1. **`.agents/tools/obsidian-tasks.md`** (committed, generic)
   - Copy `assets/obsidian-tasks.md` **verbatim**. It carries no absolute paths — do not substitute
     `<VAULT>` or `<PROJECT>` here; both are resolved at read time (from the local file and
     `PROJECT.md` respectively).
   - If it already exists (e.g. pulled in from git on another machine), leave it as is.

2. **`.agents/tools/obsidian-tasks.local.md`** (gitignored, machine-specific)
   - Copy `assets/obsidian-tasks.local.md`.
   - Replace every `<VAULT>` with the confirmed vault root.
   - If the plugin config's `tasksFolder` / `archiveFolder` differ from the template's
     `META/planning/Tasks` / `META/planning/Archive`, update those occurrences too.
   - Always (re)write this file — it is the per-machine config.

3. **`.gitignore`** (committed)
   - Ensure it ignores the local file. Add the line `.agents/tools/*.local.md` if no matching
     pattern is already present. Create `.gitignore` if it does not exist.

4. **`PROJECT.md`** (committed)
   - If it does not exist: create from `assets/PROJECT.md`, replacing `<PROJECT>` with the project name.
   - If it exists: insert or replace only its `## Tasks` section with the rendered template;
     leave all other sections untouched.

## Step 4 — Confirm

Report which files were created or updated, plus the project name and vault root used. Point out the
split: `obsidian-tasks.local.md` is gitignored (per-machine vault path), the rest is committed. On a
new machine, re-running this skill only regenerates the local file — the committed files come from
git.
