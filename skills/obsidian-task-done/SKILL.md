---
name: obsidian-task-done
description: Close out an Obsidian (TaskNotes) task after work is complete. Use when finishing a task, marking it review, adding a time entry, writing a summary, or updating the project Changelog. Triggers on phrases like "отправь задачу в ревью", "закрой задачу", "задача готова", "mark task review", "task done", "send to review", "finish task".
---

# Close out an Obsidian task

Use after completing work on a task. Performs every step in the correct order.

## Steps

### 0. Resolve vault and project

Both values come from files that `init-obsidian-tasks` created in the current repo — do not hardcode them:

- **Vault root** — read `.agents/tools/obsidian-tasks.local.md`, "Machine configuration" table (this
  is the gitignored, per-machine file). The tasks folder is `<vault>/META/planning/Tasks/` unless
  that file says otherwise.
- **Project name** — read `PROJECT.md`, the `**Project name:**` field. It is the `PROJECTS/<name>.md`
  page and the `[[<name>]]` wikilink in each task's `projects:` field.

If `obsidian-tasks.local.md` is missing (e.g. a fresh checkout on a new machine), STOP and tell the
user to run `init-obsidian-tasks` to (re)create it. If `PROJECT.md` is missing, run
`init-obsidian-tasks` as well.

### 1. Read the task file

Find and read the task file from the vault's tasks folder (resolved in step 0).

### 2. Update frontmatter

Rewrite the frontmatter fields in this exact order, keeping all existing fields that are not listed here:

```
title / status / priority / contexts / projects / agent-identity /
dateCreated / dateModified / tags / timeEstimate /
linear-issue / linear-team / linear-synced-at /
completedDate / timeEntries
```

Key changes:
- `status: review`
- `dateModified`: current timestamp
- `completedDate`: today's date (`YYYY-MM-DD`)
- Append a new entry to `timeEntries` (see YAML rules below)

**`completedDate` must always come BEFORE `timeEntries`.** Never put root-level fields after the `timeEntries` block — some parsers treat everything after an indented list as part of it.

### 3. YAML safety rules for `timeEntries.description`

The `description` value is free text — it will break YAML unless you follow these rules every time:

- **Always wrap in double quotes:** `description: "text here"`
- **Never include `: ` (colon + space) inside the string.** Replace with ` - ` or rewrite the phrase.
- **Never include `"` inside the string.** Use single quotes `'` or rephrase instead.
- Em dashes `—`, slashes `/`, parentheses, and Cyrillic are all safe.

Good example:
```yaml
timeEntries:
  - startTime: 2026-06-28T20:00:00.000Z
    description: "Реализовал split-кнопку экспорта. Дефолт JPEG 1x. Смёрджено в main."
    endTime: 2026-06-28T21:00:00.000Z
```

Bad (breaks YAML):
```yaml
    description: Добавил: новый флоу  # colon + space — breaks parsing
    description: "Он сказал "да""     # unescaped quotes — breaks parsing
```

### 4. Write a body summary

Below the frontmatter, add or update a brief summary of what was done — decisions made, caveats, follow-ups. This is for the human reviewer, not a commit log.

### 5. Update the project Changelog

Read the project page at `<vault>/PROJECTS/<project>.md` (both resolved in step 0). Add a one-line entry under today's date in `## Changelog`, most recent first. Focus on user-visible outcome, not implementation details.

### 6. Tag the PR with the Linear issue

If you open a PR for this task, read `linear-issue` from the task frontmatter, take the identifier
after `/issue/` in the URL (e.g. `BLD-67`), and put it in the PR title (in parentheses at the end)
and once in the body. Linear links the PR to the issue and syncs the rest on its own. If the task
has no `linear-issue`, open the PR normally. See the Linear section in
`.agents/tools/obsidian-tasks.md` for details.
