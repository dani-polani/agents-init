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

- Launch every subagent in its **interactive TUI**, as the pane's **foreground process**, via `herdr agent start` (this registers it as an agent *target* herdr tracks by name).
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
- Cursor: dashboard only (usage is **monthly**); no clean CLI.

If you can't determine usage automatically, **ask the human** for current headroom/priorities. Do not guess silently.

### Selection rules (from the owner's preferences)

- **Claude → use Opus.** Launch with `--model opus`. **Never use Sonnet** for this flow (too weak).
- **Codex → use when there's plenty of free usage.** Good default workhorse otherwise.
- **Cursor → conservative. Backup, not primary.** Its usage is **monthly**, so a burst here costs more proportionally. Prefer it only when others are low or the task specifically fits. (Note: `cursor-agent` may not be installed — check first.)
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

Then each subagent gets a herdr **workspace** rooted at its worktree so herdr rolls its state up per project:

```bash
WS=$(herdr workspace create --cwd /path/to/repo.feat-auth --label "feat/auth" --no-focus \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["workspace"]["workspace_id"])')
```

(For a single shared feature, put multiple subagent panes as tabs/splits inside one workspace instead of many workspaces.)

Note: `cursor-agent` has native `-w/--worktree`, but prefer explicit `git worktree` so the flow is uniform across agents and you control branch names.

## Phase 4 — Launch subagents (the correct recipe)

Per subagent: (1) write its brief to a file in its worktree, (2) `herdr agent start` it in interactive TUI seeded with "read the brief and do it", (3) confirm herdr sees it.

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

# Launch as a tracked agent target, interactive TUI, in the worktree, without stealing focus.
herdr agent start feat-auth --cwd "$WT" --workspace "$WS" --split down --no-focus -- \
  claude --model opus --permission-mode acceptEdits \
  "Read ./.herdr-task.md and complete it. Work only in this worktree. Stop when done."
```

Swap the part after `--` for the chosen agent (see Quick reference). Then **verify detection**:

```bash
herdr agent list                 # feat-auth should appear and move to `working`
herdr agent read feat-auth --source recent --lines 30
herdr agent explain feat-auth    # if it looks idle but shouldn't be
```

If it shows `idle`/`unknown` while clearly running, you almost certainly violated THE ONE RULE (headless mode, backgrounding, redirect, or non-foreground launch). Fix the launch, don't paper over it.

### Auto-mode per agent (no dumb permission prompts, but not reckless)

| Agent | Interactive auto-mode launch | Notes |
| --- | --- | --- |
| Claude | `claude --model opus --permission-mode acceptEdits` | Auto-accepts edits, still gates genuinely risky actions. For fully unattended in an isolated worktree: `--permission-mode bypassPermissions` (== `--dangerously-skip-permissions`). Never Sonnet. |
| Codex | `codex --sandbox workspace-write --ask-for-approval on-request` | The "Auto"/"approve-for-me" preset: reads/edits/runs in the workspace, only escalates to leave workspace or use network. Full bypass (isolated only): `--dangerously-bypass-approvals-and-sandbox` (`--yolo`). |
| OMP | `omp` | Default approval mode is already `yolo` (auto-approves all). Safer middle ground: `omp --approval-mode write` (auto read+write, prompts for exec) or set `tools.approval.bash: prompt` in config. |
| Cursor | `cursor-agent --force` | Interactive TUI, auto-approves; still hands you `sudo`. Do NOT use `-p` (that's headless). Backup agent; check it's installed. |

Because subagents run in isolated worktrees and you review everything, `acceptEdits`/`workspace-write`/`yolo`-in-worktree is an acceptable risk. Dial down (allow/deny lists, `--approval-mode write`) if the human wants tighter control. If an agent does get `blocked` on a prompt, that's fine — herdr shows it and you handle it in Phase 5.

## Phase 5 — Supervise

Watch the fleet; act on state transitions. Poll `herdr agent list` (JSON) and block on specific transitions:

```bash
herdr agent list                                   # rollup of all agents + statuses
herdr agent wait feat-auth --status blocked --timeout 600000   # or poll in a loop
herdr agent read feat-auth --source recent --lines 60          # see what it's doing
```

Handle states:

- **working** — leave it. Periodically read the pane to confirm real progress (not a stuck loop). If a pane is `working` in herdr but the transcript hasn't advanced in a long time, treat it as stuck: read it, nudge with `herdr agent send`, or restart the subtask.
- **blocked** — read the pane and **judge**:
  - If you can resolve it yourself (a decision within the agreed task, a clarification you already know, an obvious fix), answer it: `herdr agent send feat-auth "<answer>"` then `herdr pane send-keys <pane> Enter`.
  - If it genuinely needs the **product owner / architect / admin** (scope change, product decision, credentials, destructive/irreversible action, ambiguous requirement), **escalate to the human** and wait.
- **done** — the subagent finished. Read its full output, then move to review (Phase 6). `done` stays flagged until you view it.
- **idle/unknown while active** — detection problem. `herdr agent explain`, then relaunch correctly.

Keep the human's attention budget low: surface only real decisions, batch status into concise updates.

## Phase 6 — Review, consolidate, deliver

Once subtasks are done:

1. **Review** each branch's diff yourself (you're the reviewer). Look for correctness, missing tests, security issues, and whether it actually meets acceptance criteria. Prefer running the tests / a smoke check to confirm the feature works, especially if the subagent didn't make that obvious.
2. **Bounce back** serious problems: send the subagent a focused fix task (`herdr agent send`), or spawn a fresh fixer subagent for that specific issue (Phase 4). Don't accumulate tiny throwaway branches — reuse the existing branch/worktree when reasonable.
3. **Consolidate** into a small number of **deployable** PRs. A PR = one thing you can deploy as a whole. Merge sibling branches of one feature together, **resolve conflicts yourself**, and open 1-2 big PRs rather than many fragments — unless splitting is genuinely necessary for deploy independence.
4. **Deliver**: the outcome is one or a few PRs + your review notes + a short report (what each agent did, what you changed, what's tested, any follow-ups or escalations). Add `Co-authored-by:` trailers for every contributing subagent (see "Attribution"), and **update the project's task management** — statuses, work summaries, and PR links — per `AGENTS.md`/`PROJECT.md`.

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
- Using Sonnet for Claude in this flow. Use **Opus**.
- Draining two agents that share the same underlying account/quota at once.
- Letting Codex/OMP commit under the human's identity with **no `Co-authored-by:` trailer** — you lose track of who did what. Instruct them in the brief and verify.
- Ignoring `AGENTS.md`/`PROJECT.md` task conventions, or forgetting to update task statuses/summaries as the fleet progresses.

## Quick reference — launch commands

```bash
# Claude (Opus, auto-accept)
herdr agent start <name> --cwd "$WT" --split down --no-focus -- \
  claude --model opus --permission-mode acceptEdits \
  "Read ./.herdr-task.md and complete it. Stop when done."

# Codex (Auto preset)
herdr agent start <name> --cwd "$WT" --split down --no-focus -- \
  codex --sandbox workspace-write --ask-for-approval on-request \
  "Read ./.herdr-task.md and complete it. Stop when done."

# OMP (yolo default; use --approval-mode write to be safer)
herdr agent start <name> --cwd "$WT" --split down --no-focus -- \
  omp "Read ./.herdr-task.md and complete it. Stop when done."

# Cursor (backup; interactive TUI, auto-approve). Check it's installed first.
herdr agent start <name> --cwd "$WT" --split down --no-focus -- \
  cursor-agent --force \
  "Read ./.herdr-task.md and complete it. Stop when done."
```

Supervise:

```bash
herdr agent list
herdr agent read <name> --source recent --lines 60
herdr agent wait <name> --status blocked --timeout 600000
herdr agent send <name> "<answer or follow-up>"; herdr pane send-keys <pane> Enter
herdr agent explain <name>   # when state looks wrong
```
