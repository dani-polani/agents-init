---
name: herdr-orchestrate
description: "Orchestrate a fleet of coding subagents inside herdr. Use when you (the main/orchestrator agent) are asked to take a task or a list of tasks, spin up several subagents (claude/codex/cursor/omp) in herdr panes, give each a worktree and a pane, keep them VISIBLE to herdr (correct state, no false idle), supervise them, review their work, and deliver 1-2 deployable PRs plus a report. Complements the base `herdr` skill (which teaches the herdr CLI itself)."
---

# herdr-orchestrate — running a fleet of subagents

You are the **orchestrator**. A human handed you one feature or a list of tasks and asked you to get it done by delegating to subagents running inside **herdr**. This skill is the workflow. The base `herdr` skill is the CLI reference — read it too if you are unsure of a `herdr` command.

Before anything else, confirm `HERDR_ENV=1`. If it is not `1`, you are not inside herdr; stop and tell the human to start you inside a herdr pane (`herdr`, then run your agent in a pane). Everything below assumes you are inside herdr.

Your job, end to end:

1. Understand the task(s) with the human.
2. Pick the right agents based on remaining usage and fit.
3. Create the right worktrees (isolation, but no more than needed).
4. Launch subagents **so herdr sees them working** (this is the part people get wrong).
5. Supervise: watch state, unblock, keep them productive.
6. Review, consolidate, resolve conflicts, and deliver a small number of deployable PRs + a report.

You do **not** write feature code yourself. You may do glue work: resolve merge conflicts, run tests/smoke-checks to confirm a feature works, and consolidate branches.

---

## THE ONE RULE: keep subagents visible to herdr

The most common failure is launching a subagent in a way that burns tokens while herdr shows it `idle`/`unknown` and the human can't see what it's doing. herdr detects agent state by reading the **live interactive TUI** at the bottom of a pane and matching it against detection manifests (plus lifecycle hooks for some agents). If there is no TUI to read, herdr sees a plain shell.

So, **always**:

- Launch every subagent in its **interactive TUI**, as the pane's **foreground process**, via `herdr agent start` (this registers it as an agent *target* herdr tracks by name). Then put the pane in the right place with `herdr pane move` — see the fixed layout in Phase 4. Never let a subagent split your orchestrator pane, and never give it its own workspace.
- **Never** launch subagents in print/headless/one-shot mode: no `claude -p`, no `codex exec`, no `cursor-agent -p`, no `omp -p`. Those produce no TUI → false idle.
- **Never** background it (`&`, `nohup`), wrap it in an extra subshell, or redirect its output to a file/pipe. All of these hide the TUI from herdr.
- Give the task as a **positional prompt** (interactive seed) or via `herdr agent send` *after* the TUI is ready — not through headless flags.
- Make sure the per-agent **herdr integration** is installed (better state + session restore).
- If a sandbox/VM wrapper hides the process, set `HERDR_AGENT=<agent>` on the launch command.

If a pane shows the wrong state, run `herdr agent explain <target>` to see why.

---

## Phase 0 — Intake (with the human)

Clarify before spawning anything:

- Is this **one feature** (subtasks that ship together) or **several independent tasks**? This decides worktrees and PRs.
- What is "done" for each? Acceptance criteria, tests, and what counts as deployable.
- Any constraints: which repo/branch, files to avoid, budget/usage limits, deadlines.
- PR shape: default is **one PR per deployable unit**. A big feature stays in one PR unless that's genuinely unwieldy. Prefer 1-2 large PRs over 10 tiny ones.
- **PR ownership:** *you* (the orchestrator) open every PR after review and consolidation. Subagents **never push and never open PRs** — they commit to their branch and stop. Open PRs **ready for review — never draft** (this team doesn't use drafts; they're just friction).
- **Read `AGENTS.md` and `PROJECT.md`** (and anything they link) before doing anything. The project usually defines a **task-management system** and conventions there. Follow them — see "Respect the project's task management" below.

Write a short brief per subtask. You will drop each brief into a file the subagent reads (see Phase 4).

## Phase 1 — Preflight

```bash
[ "${HERDR_ENV:-}" = "1" ] || { echo "not inside herdr"; exit 1; }
herdr agent list          # what's already running
herdr integration status  # confirm integrations are installed & current
```

Ensure integrations for the agents you'll use are present (they give herdr authoritative state and session restore):

```bash
herdr integration install claude   # codex / cursor / omp as needed
```

`omp` and `pi`-family agents report lifecycle state via hooks (most reliable). `claude`, `codex`, `cursor` are detected from their screen TUI + provide session identity — which is exactly why they must run in interactive TUI mode.

If you will use **Claude in auto mode**, verify its prereqs now (otherwise it silently runs in manual and blocks on everything): `CLAUDE_CODE_ENABLE_AUTO_MODE=1` present in `~/.claude/settings.json` `env` block, model is Opus 4.7/4.8, and Claude Code is v2.1.83+. For **Codex**, confirm `approvals_reviewer = "auto_review"` is in `~/.codex/config.toml` (or pass it per-launch). See "Auto-mode per agent".

## Phase 2 — Pick agents (usage-aware)

Candidates: **claude, codex, cursor, omp**. Choose per subtask by (a) remaining usage headroom, (b) fit for the task, (c) how soon the usage window resets.

### Check remaining usage

Preferred, unified check — `omp usage` shows every provider/account, each limit window, reset time, and plan in one shot:

```bash
omp usage            # snapshot of all signed-in providers/accounts
omp usage --history  # adds sparklines / trends
```

Fallbacks when a provider isn't visible to `omp usage`:

- Claude: `/usage` inside the Claude TUI, or `npx ccusage@latest blocks` (reads local `~/.claude` JSONL; approximate).
- Codex: `/status` inside the Codex TUI (shows rate-limit usage + reset).
- Cursor: **no programmatic usage readout at all** — `cursor-agent usage`/`about`/`status` show only activity/days, and `omp usage` can't fetch it even when Cursor is logged into omp. Headroom must be checked **manually** on the Cursor dashboard (monthly billing).

If you can't determine usage automatically, **ask the human** for current headroom/priorities. Do not guess silently.

### Selection rules (from the owner's preferences)

- **Claude → use Opus.** Launch with `--model opus`. **Never use Sonnet** for this flow (too weak).
- **Codex → use when there's plenty of free usage.** Good default workhorse otherwise.
- **Cursor → specialist for fast, well-scoped tasks.** Its **Composer 2.5** model (`--model composer-2.5`) is fast and strong on constrained technical tasks where the implementation path is already clear. Caveat: usage is **monthly** and there is **no way to read remaining budget programmatically** (neither `cursor-agent` nor `omp usage` reports it), so headroom is a **manual check** on the Cursor dashboard — judge it conservatively. Don't hand it large open-ended work; do reach for it for quick, clear-cut slices.
- **OMP → use when it has usage available.** Strong native tooling and first-class subagents.
- **Reset timing:** if an agent's window resets **soon**, prefer spending *that* agent now (headroom would otherwise reset unused) — but don't hand it a long task it can't finish before the reset.
- **Shared-quota caution:** agents can route to the same underlying account (e.g. `omp` may be configured to use the OpenAI Codex plan, sharing quota with `codex`). `omp usage` shows per-account limits — don't pick two agents that drain the *same* account unless it has headroom.
- Match capability to task: heavy reasoning/refactors → strongest model with headroom; broad parallel grunt work → spread across agents.

## Phase 3 — Worktrees (isolate, but minimally)

Strategy (owner's choice — "smart"):

- **One feature** (related subtasks): **one worktree + one branch**. Subagents collaborate in it, or take non-overlapping slices. This keeps the result to a single deployable PR.
- **Several independent tasks**: **one worktree/branch per task**. Each becomes its own PR.
- Only give a subagent its **own** worktree when its work would otherwise collide with a sibling. Over-splitting creates merge pain and PR sprawl.

Create worktrees explicitly (works for every agent):

```bash
cd /path/to/repo
git worktree add ../repo.feat-auth -b feat/auth        # new branch off HEAD
```

Subagents do **not** get their own herdr **workspace** — a workspace represents a *project*, not an agent. Keep every subagent as a **pane in your current workspace and main tab**; its per-worktree state still rolls up correctly because herdr reads it from the pane and its cwd. Exactly where each pane goes is fixed in Phase 4 → "Pane layout".

Note: `cursor-agent` has native `-w/--worktree`, but prefer explicit `git worktree` so the flow is uniform across agents and you control branch names.

## Phase 4 — Launch subagents (the correct recipe)

Per subagent: (1) write its brief to a file in its worktree, (2) `herdr agent start` it in interactive TUI seeded with "read the brief and do it", (3) confirm herdr sees it.

**Name every agent target after its harness, not its task.** Use `claude`, `codex`, `cursor`, `omp` so the human can tell who is who in the sidebar without opening panes. When you run more than one of the same harness, add a short task suffix: `codex-ui`, `codex-api`, `claude-auth`. Never use cryptic task-only names like `Bld65Autofit`. Fix a bad name with `herdr agent rename <target> <name>`.

### Pane layout — where agents go (fixed rules)

Agents must land in a **predictable** place. Follow this exactly; do not improvise splits, and do not create workspaces or tabs for agents.

- **Stay in your current workspace and main tab.** Never `herdr workspace create` for an agent (workspaces = projects), and don't spread agents across tabs by default.
- **Your orchestrator pane is the left column: ~half width, full height. Never split it again.** The human talks to you and needs it readable.
- **All agents live in the right column.** The first agent *becomes* that column; the rest fill it top → bottom.
- **Fixed fill order:** up to **3 stacked rows** first (top, middle, bottom). Only if you need a 4th–6th agent, split each row into **2 columns** (left, then right). That is the cap: **6 agent panes**. Prefer finishing or recycling an agent over exceeding it.
- **More than 6 at once** (rare for a small team): open **one new tab in the same workspace** for the overflow grid — you stay in the main tab. Still never a new workspace.

You build this with `herdr agent start` (keeps naming + tracking + integration state) and then `herdr pane move --target-pane` (drops the pane into the exact slot). `agent start` alone would split *your* pane, so always move the pane afterwards.

### Launch recipe

Write each agent's brief into its worktree, then start + move it into its slot. `$WT2`/`$WT3` are the other agents' worktrees — reuse the same `$WT` for every agent that shares one feature/worktree.

```bash
WT=/path/to/repo.feat-auth
cat > "$WT/.herdr-task.md" <<'EOF'
# Task: <title>
## Goal
<what to build, acceptance criteria>
## Constraints
<files to touch/avoid, tests to pass, do NOT push/merge — leave commits on the branch>
## Attribution (REQUIRED)
Add a `Co-authored-by:` trailer identifying YOURSELF (agent + model) to EVERY commit.
Identify yourself the same way in any PR description or GitHub comment you write.
Do NOT commit as if you were the human. Example trailer:
  Co-authored-by: <agent> (<model>) <email>
## Task management
Read AGENTS.md and PROJECT.md first and follow the project's task-management
system and conventions exactly. Do not invent your own workflow.
## When done
Commit your work on this branch (with the attribution trailer), print a short
summary, then stop. Do not push or open PRs unless told — the orchestrator does that.
EOF

# --- Find your own pane + tab once; never split your pane again ---
ORCH=$(herdr pane current | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
TAB=$(herdr pane current  | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["pane"]["tab_id"])')
pid(){ herdr agent get "$1" | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["pane"]["pane_id"])'; }

# --- Row 1: first agent takes the RIGHT half (you keep the left half, full height) ---
# Name = harness (add a task suffix only if several of the same harness). --tab keeps it
# in the current tab/workspace; NEVER pass --workspace and NEVER --split your own pane.
herdr agent start claude --cwd "$WT" --tab "$TAB" --no-focus -- \
  claude --model opus --permission-mode auto \
  "Read ./.herdr-task.md and complete it. Work only in this worktree. Stop when done."
ROW1=$(pid claude); herdr pane move "$ROW1" --tab "$TAB" --target-pane "$ORCH" --split right --ratio 0.5 --no-focus

# --- Row 2 stacks under row 1; Row 3 under row 2 (swap the argv per agent) ---
herdr agent start codex --cwd "$WT2" --tab "$TAB" --no-focus -- \
  codex --sandbox workspace-write --ask-for-approval on-request -c approvals_reviewer=auto_review \
  "Read ./.herdr-task.md and complete it. Work only in this worktree. Stop when done."
ROW2=$(pid codex); herdr pane move "$ROW2" --tab "$TAB" --target-pane "$ROW1" --split down --no-focus

herdr agent start omp --cwd "$WT3" --tab "$TAB" --no-focus -- \
  omp --approval-mode write \
  "Read ./.herdr-task.md and complete it. Work only in this worktree. Stop when done."
ROW3=$(pid omp); herdr pane move "$ROW3" --tab "$TAB" --target-pane "$ROW2" --split down --no-focus

# --- Agents 4-6 only if needed: split each row into two columns (left -> right) ---
# herdr agent start codex-api --cwd "$WT4" --tab "$TAB" --no-focus -- codex ... ; P4=$(pid codex-api)
# herdr pane move "$P4" --tab "$TAB" --target-pane "$ROW1" --split right --no-focus   # right of row 1
# ...repeat with --target-pane "$ROW2" / "$ROW3" for the 5th / 6th agent.
```

Swap the argv after `--` for the chosen agent (see "Auto-mode per agent" / Quick reference). Then **verify detection**:

```bash
herdr agent list                  # `claude` should appear and move to `working`
herdr agent read claude --source recent --lines 30
herdr agent explain claude        # if it looks idle but shouldn't be
```

If it shows `idle`/`unknown` while clearly running, you almost certainly violated THE ONE RULE (headless mode, backgrounding, redirect, or non-foreground launch). Fix the launch, don't paper over it.

### Auto-mode per agent — use the CLASSIFIER modes, not dangerous bypass

The target is "no dumb permission prompts, but never anything genuinely dangerous." Claude, Codex, and Cursor each have a **classifier/reviewer** that decides per-command whether to auto-approve — that is the correct mode for a subagent (only OMP lacks one). It usually works well: routine edits and commands run without prompts, and only genuinely risky actions (destructive + networked, production targets, secrets, exfiltration) get escalated.

**Do NOT use the dangerous full-bypass flags** (`--dangerously-skip-permissions`, `--yolo`, `--dangerously-bypass-approvals-and-sandbox`) for subagents. The risk is small but real, and worktree isolation is not a reason to strip the classifier. Occasional escalation on a truly risky action is *expected and desired* — you judge it in Phase 5. What you avoid is the *timid* presets (`acceptEdits`, plain `on-request` without a reviewer) that prompt on ordinary edits/commands.

| Agent | Classifier auto-mode launch | Notes |
| --- | --- | --- |
| Claude | `claude --model opus --permission-mode auto` | Real "auto" mode: a separate classifier reviews each action, blocks escalation/exfiltration/destructive ops, runs everything else without prompts. **Prereqs, or it silently falls back to manual:** (1) `CLAUDE_CODE_ENABLE_AUTO_MODE=1` on a signed-in Claude subscription — set it in `~/.claude/settings.json` `env` block (durable) or pass `--env CLAUDE_CODE_ENABLE_AUTO_MODE=1` to `herdr agent start`; (2) model must be Opus 4.7/4.8 (`opus`), never Sonnet 4.5 / Opus 4.5; (3) Claude Code v2.1.83+. "Auto mode unavailable" means a prereq is unmet — not transient. Docs: code.claude.com/docs/en/auto-mode-config |
| Codex | `codex --sandbox workspace-write --ask-for-approval on-request -c approvals_reviewer=auto_review` | This is "approve for me": a reviewer agent auto-approves low/medium-risk requests and only escalates high/critical ones. Drop `-c approvals_reviewer=auto_review` if it's already in `~/.codex/config.toml`. Network stays off in `workspace-write` unless enabled, so an install like `npm ci` will surface for approval — that escalation is correct, not a bug. Docs: learn.chatgpt.com/docs/agent-approvals-security |
| OMP | `omp --approval-mode write` | OMP has **no command classifier** — modes are `always-ask` / `write` / `yolo` plus per-tool policy. `write` auto-approves reads+edits and prompts before shell exec (a real guardrail; expect more `blocked` on bash). `--yolo` removes all gating (small but real risk) — avoid for subagents. Because it lacks a classifier, prefer Claude/Codex for unattended work. |
| Cursor | `cursor-agent --auto-review --model composer-2.5` | "Smart Auto": a server classifier auto-runs safe tool calls and prompts for the rest — the right mode. `--force`/`--yolo` = "Run Everything" (no classifier) — avoid. Never `-p` (headless). Best fit: fast, well-scoped technical tasks where the path is already clear, on Composer 2.5. |

If you genuinely cannot use a classifier mode and cannot isolate, drop to a guarded preset and service the extra prompts. Reserve the dangerous bypass flags for throwaway containers you own — not for the subagent fleet.

**Switching a running agent into auto mode (post-hoc).** Launching in the right mode from the start is the primary path and avoids all of this — do that first. If an agent is already up in the wrong mode, two options:

- *Hot-toggle* — works only while the agent is `idle`/`working`, **not** while it sits at a prompt. Send `shift+tab` and re-read the status bar until it shows `auto mode on`:

```bash
herdr pane send-keys <pane> shift+tab
herdr pane read <pane> --source visible --lines 3   # look for "auto mode on"; repeat if not there yet
```

  `shift+tab` cycles `default → acceptEdits → plan → (auto)`, so it may take a few presses, and `auto` only appears when the account meets the prereqs above. If the agent is **blocked at an approval prompt**, the keystroke only changes the prompt selection and does not change the session mode — use restart-in-place instead.

- *Restart in place* (reliable, keeps the work) — closing a pane kills only the agent process, not the files on disk. Note the slot's neighbour first, relaunch in the same worktree with the right flag, then move the new pane back into that slot and tell it to continue from the uncommitted changes:

```bash
herdr pane close <old_pane>
herdr agent start claude --cwd "$WT" --tab "$TAB" --no-focus -- \
  claude --model opus --permission-mode auto \
  "Continue ./.herdr-task.md from the current unstaged changes in this worktree. You are in auto mode. Work only in this worktree. Do not discard existing edits. Finish and commit, then stop."
# move it back into the freed slot (e.g. under ROW1): 
herdr pane move "$(pid claude)" --tab "$TAB" --target-pane "$ROW1" --split down --no-focus
```

  This restart-in-place pattern is also the general way to change an agent's mode, model, or even harness mid-task without losing uncommitted work — the worktree holds the state, so verify `git status` in the worktree looks right before and after.

**If a subagent keeps blocking, tell the two cases apart:** (a) it prompts on *routine* edits/commands → it is not actually in the classifier mode: check the prereqs (Claude env var + Opus model; Codex flags + `auto_review`) and relaunch. (b) it escalates a *genuinely risky* action → that is the classifier working; judge it in Phase 5 and either answer it or escalate to the human. Never "fix" case (b) by switching to a dangerous bypass mode. (Note: in auto mode Claude itself *blocks* spawning agents that run with isolation/approvals disabled like `--dangerously-skip-permissions`/`--yolo`, so mixing bypass subagents under an auto orchestrator gets blocked anyway.)

## Phase 5 — Supervise

Watch the fleet; act on state transitions. Poll `herdr agent list` (JSON) and block on specific transitions:

```bash
herdr agent list                                   # rollup of all agents + statuses
herdr agent wait codex-ui --status blocked --timeout 600000    # or poll in a loop
herdr agent read codex-ui --source recent --lines 60           # see what it's doing
```

Handle states:

- **working** — leave it. Periodically read the pane to confirm real progress (not a stuck loop). If a pane is `working` in herdr but the transcript hasn't advanced in a long time, treat it as stuck: read it, nudge with `herdr agent send`, or restart the subtask.
- **blocked** — read the pane and **judge**:
  - If you can resolve it yourself (a decision within the agreed task, a clarification you already know, an obvious fix), answer it: `herdr agent send <name> "<answer>"` then `herdr pane send-keys <pane> Enter`. If a subagent keeps blocking on *routine* approvals, it was launched without full auto — relaunch it with the flags in "Auto-mode per agent".
  - If it genuinely needs the **product owner / architect / admin** (scope change, product decision, credentials, destructive/irreversible action, ambiguous requirement), **escalate to the human** and wait.
- **done** — the subagent finished. Read its full output, then move to review (Phase 6). `done` stays flagged until you view it.
- **idle/unknown while active** — detection problem. `herdr agent explain`, then relaunch correctly.

Keep the human's attention budget low: surface only real decisions, batch status into concise updates.

## Phase 6 — Review, consolidate, deliver

Once subtasks are done:

1. **Review** each branch's diff yourself (you're the reviewer). Look for correctness, missing tests, security issues, and whether it actually meets acceptance criteria. Prefer running the tests / a smoke check to confirm the feature works, especially if the subagent didn't make that obvious.
2. **Bounce back** serious problems: send the subagent a focused fix task (`herdr agent send`), or spawn a fresh fixer subagent for that specific issue (Phase 4). Don't accumulate tiny throwaway branches — reuse the existing branch/worktree when reasonable.
3. **Consolidate** into a small number of **deployable** PRs. A PR = one thing you can deploy as a whole. Merge sibling branches of one feature together, **resolve conflicts yourself**, and open 1-2 big PRs rather than many fragments — unless splitting is genuinely necessary for deploy independence.
4. **Open the PRs yourself, ready for review — never draft.** You are the **sole PR author**: subagents commit to their branches and stop; they do not push or open PRs. Drafts just add friction for this team, so create every PR in the normal ready state (`gh pr create` without `--draft`).
5. **Deliver**: the outcome is one or a few PRs + your review notes + a short report (what each agent did, what you changed, what's tested, any follow-ups or escalations). Add `Co-authored-by:` trailers for every contributing subagent (see "Attribution"), and **update the project's task management** — statuses, work summaries, and PR links — per `AGENTS.md`/`PROJECT.md`.

## Cleanup

Remove worktrees and (optionally) panes/workspaces you no longer need:

```bash
git worktree remove ../repo.feat-auth      # after merge/close
herdr pane close <pane>                      # or leave for the human to inspect
```

Leave `done` panes visible if the human still wants to read them.

---

## Attribution: every agent signs its work

For monitoring, **every commit, PR, and GitHub comment must identify which agent produced it.** Commits must not look like the human wrote them.

- **Claude** and **Cursor** usually add a co-author trailer on their own. **Codex** and **OMP** often commit under the human's git identity with no trailer — you must **explicitly instruct them** (put it in `.herdr-task.md`, and re-check their commits).
- Every subagent adds a `Co-authored-by:` trailer to each commit it authors, naming itself and its model. Suggested identities (adjust emails to real bot accounts if you want GitHub to link them):

```
Co-authored-by: Claude (Opus) <noreply@anthropic.com>
Co-authored-by: Codex (gpt-5.5) <codex@openai.com>
Co-authored-by: Cursor Agent <cursoragent@cursor.com>
Co-authored-by: omp (<model>) <noreply@omp.sh>
```

- In **PR descriptions and GitHub comments**, each agent states which agent+model it is (a one-line header is enough).
- **You (the orchestrator)** attribute too: when you make consolidation/merge/conflict-resolution commits or open the final PRs, add `Co-authored-by:` trailers for **each subagent whose work is included**, so the PR shows every contributor.
- **Verify** before delivering: `git log --format='%an %ae%n%b' <base>..<branch>` and confirm each commit carries the right trailer. If Codex/OMP forgot, have them amend, or fix it during consolidation.
- Never touch `git config user.*` to impersonate anyone. Attribution goes through trailers and PR/comment text, not by rewriting the human's identity.

## Respect the project's task management

Projects define how work is tracked — usually in **`AGENTS.md`** and **`PROJECT.md`** (they may point to an issue tracker, a tasks file, a board, or a convention like Obsidian/TaskNotes). This is normally handled automatically, but make it explicit so nobody forgets:

- **Before starting:** read `AGENTS.md` and `PROJECT.md` and any task docs they reference. Follow the defined statuses, naming, branch/PR conventions, and where notes/summaries live. Do not invent a parallel system.
- **Subagents** follow the project's conventions for the slice they work on (referenced in their brief).
- **The orchestrator owns task bookkeeping:** move tasks through their statuses as work starts / completes / goes to review, write concise summaries of what was done into each task, link the resulting PR(s), and record follow-ups or escalations. Keep task state in sync with reality across the fleet.
- If the project has **no** task-management system documented, don't fabricate one — mirror whatever lightweight convention exists (commit/PR descriptions, a changelog) and ask the human if unclear.

## Anti-patterns (these cause the "invisible / false-idle" bug)

- `claude -p …`, `codex exec …`, `cursor-agent -p …`, `omp -p …` — headless, no TUI, herdr can't see state. **Don't.**
- Backgrounding (`agent … &`), `nohup`, or launching inside an extra wrapper subshell — agent isn't the pane foreground. **Don't.**
- Redirecting/piping agent output (`agent … > out.log`, `| tee`) — hides the TUI. **Don't.**
- Running the agent, then walking away without checking `herdr agent list` shows it `working`. **Always verify.**
- Not installing the herdr integration → weaker/erroneous state.
- Spawning one worktree/branch/PR per trivial slice → merge hell and PR sprawl. Isolate only where work collides.
- Creating a herdr **workspace** (or scattering tabs) per subagent → the sidebar fills with fake "projects". Agents are **panes in your current workspace/main tab**; place them with `pane move` per the fixed layout.
- Letting `agent start` split **your** orchestrator pane, or improvising split order → the human loses the readable half-width orchestrator pane and can't tell where the next agent appears. Keep your pane whole; fill the right column top→bottom, then 2 columns per row.
- Subagents pushing branches or opening their own PRs → **you** are the sole PR author. They commit and stop.
- Opening PRs as **drafts** → this team doesn't use them; ship them ready for review.
- Using dangerous bypass flags (`--dangerously-skip-permissions`, `--yolo`, `--dangerously-bypass-approvals-and-sandbox`) for subagents. Small but real risk. Use the classifier modes: Claude `--permission-mode auto`, Codex `--ask-for-approval on-request` + `approvals_reviewer=auto_review`.
- Launching Claude with `--permission-mode auto` without its prereqs (env var + Opus model) — it silently drops to manual and blocks on everything. Fix the prereqs, don't switch to bypass.
- Using Sonnet for Claude in this flow. Use **Opus** (also required for auto mode).
- Draining two agents that share the same underlying account/quota at once.
- Letting Codex/OMP commit under the human's identity with **no `Co-authored-by:` trailer** — you lose track of who did what. Instruct them in the brief and verify.
- Ignoring `AGENTS.md`/`PROJECT.md` task conventions, or forgetting to update task statuses/summaries as the fleet progresses.

## Quick reference — launch commands

```bash
# Agent-target name = the harness (claude / codex / omp / cursor); add a task suffix
# only when several of the same harness run at once (codex-ui, codex-api).
# Classifier-gated auto mode — NOT dangerous bypass (see "Auto-mode per agent").
# Start with --tab "$TAB" --no-focus (stay in the current tab/workspace, never --workspace),
# then `herdr pane move ... --target-pane` into its slot (see Phase 4 → Pane layout).

# Claude (Opus, auto mode — needs CLAUDE_CODE_ENABLE_AUTO_MODE=1 + Opus model)
herdr agent start claude --cwd "$WT" --tab "$TAB" --no-focus -- \
  claude --model opus --permission-mode auto \
  "Read ./.herdr-task.md and complete it. Stop when done."

# Codex ("approve for me" / auto-review)
herdr agent start codex --cwd "$WT" --tab "$TAB" --no-focus -- \
  codex --sandbox workspace-write --ask-for-approval on-request -c approvals_reviewer=auto_review \
  "Read ./.herdr-task.md and complete it. Stop when done."

# OMP (no classifier — 'write' gates shell exec; avoid --yolo for subagents)
herdr agent start omp --cwd "$WT" --tab "$TAB" --no-focus -- \
  omp --approval-mode write "Read ./.herdr-task.md and complete it. Stop when done."

# Cursor (Smart Auto classifier; Composer 2.5 for fast, well-scoped tasks)
herdr agent start cursor --cwd "$WT" --tab "$TAB" --no-focus -- \
  cursor-agent --auto-review --model composer-2.5 \
  "Read ./.herdr-task.md and complete it. Stop when done."

# Placement (after each start): first agent -> right half; then stack rows; then 2 cols/row.
herdr pane move "$(pid claude)" --tab "$TAB" --target-pane "$ORCH"  --split right --ratio 0.5 --no-focus
herdr pane move "$(pid codex)"  --tab "$TAB" --target-pane "$ROW1"  --split down  --no-focus
```

Supervise:

```bash
herdr agent list
herdr agent read <name> --source recent --lines 60
herdr agent wait <name> --status blocked --timeout 600000
herdr agent send <name> "<answer or follow-up>"; herdr pane send-keys <pane> Enter
herdr agent explain <name>   # when state looks wrong
```
