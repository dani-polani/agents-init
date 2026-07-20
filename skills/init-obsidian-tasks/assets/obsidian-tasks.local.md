# Obsidian Tasks — machine configuration (local, gitignored)

This file holds the machine-specific paths for the Obsidian task workflow. It is **gitignored** on
purpose: the vault root differs per machine, so committing it would conflict across machines.

- Do not commit this file. `init-obsidian-tasks` adds it to `.gitignore`.
- Recreate it on each machine by running `init-obsidian-tasks` (it finds the vault and fills the
  table below). Nothing else in the repo needs to change.
- The workflow itself lives in the committed sibling `obsidian-tasks.md`. That file resolves
  `<VAULT>` by reading the table here.

---

## Machine configuration

| Location | Path |
|---|---|
| Vault root | `<VAULT>` |
| Active tasks | `<VAULT>/META/planning/Tasks/` |
| Archived tasks | `<VAULT>/META/planning/Archive/` |
| Project pages | `<VAULT>/PROJECTS/` |
| Plugin config | `<VAULT>/.obsidian/plugins/tasknotes/data.json` |
