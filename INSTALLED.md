# Installed skills and MCP servers

Reference snapshot of what is set up on the main machine. Built-in Claude Code skills are not listed.

## Skills from this repository

- `herdr-orchestrate` — run a fleet of coding subagents in herdr panes and worktrees, supervise them, deliver PRs.
- `init-linear-tasks` — bind a repo to a Linear project and set up the Linear task workflow through Orca's Linear CLI.
- `linear-task-done` — close out a Linear issue: read the linked PRs, post a completion comment, move it to In Review.
- `init-obsidian-tasks` — superseded by `init-linear-tasks`; kept for repos still on the vault workflow.
- `obsidian-task-done` — superseded by `linear-task-done`; kept for repos still on the vault workflow.
- `set-tools-color-schemes` — sync Ghostty, herdr, yazi and micro to a VS Code / Cursor theme through per-tool color configs.

## Skills from external sources

- `herdr` — drive the running herdr instance from inside it: workspaces, tabs, panes, agents. Bundled with the binary since 0.8.0, so it stays in step with the installed version: `herdr --skill > ~/.agents/skills/herdr/SKILL.md`.
- `improve` — read-only codebase audit that produces prioritized implementation plans for other agents.
- `find-skills` — discover and install agent skills on request.
- `ui-ux-pro-max` — UI/UX design intelligence: styles, palettes, font pairings, UX guidelines, chart types across 10 stacks.
- `ui-styling` — build interfaces with shadcn/ui, Tailwind and canvas-based visuals.
- `design` — umbrella design skill: brand identity, logos, corporate identity, presentations, banners, icons, social images.
- `design-system` — three-layer design tokens, component specs and slide generation.
- `brand` — brand voice, visual identity, messaging frameworks and brand consistency checks.
- `banner-design` — banners for social, ads, web heroes and print, with several art direction options.
- `slides` — strategic HTML presentations with Chart.js and design tokens.
- `shadcn` — add, search, fix and compose shadcn/ui components, registries and presets.
- `unslop-code` — strip the tells that make source code read as AI-generated.
- `unslop-text` — strip the cues that make prose read as AI-generated.
- `unslop-ui` — strip the cues that make a website look AI-generated, including the "tasteful default" look.
- `humanizer-ru` — Russian text editor that removes AI patterns, bureaucratese and filler. Manual invocation only.
- `keyword-research` — content planning with the 6 Circles Method, no paid tools required.
- `directory-submissions` — plan and track product submissions to startup, SaaS, AI and review directories.

## Plugin

- `claude-seo` (marketplace `AgriciDaniel/claude-seo`) — SEO suite: 25 skills (site audits, technical SEO, schema, content, local and maps, GEO for AI search) plus ~20 specialist subagents.

## MCP servers

- `claude.ai Linear` — remote connector at `https://mcp.linear.app/mcp`, bound to the Claude account rather than to this machine. Day-to-day task work goes through Orca's `orca linear` CLI instead; the connector covers what the CLI lacks, such as creating projects.
- `railway` — HTTP server at `https://mcp.railway.com`, scoped to a single project.
- `word-aligner` — HTTP server at `https://aligner.tinygods.dev/mcp`, scoped to a single project.

No MCP servers are configured globally.
