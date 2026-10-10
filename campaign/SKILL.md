---
name: campaign
description: Run a local multi-session Campaign in Claude Code. This session becomes the Chief of Staff — the user's stand-in who grills the user, scouts the code, writes Briefs, spawns background Thread sessions (`claude --bg`), answers their escalations, lands their work and debriefs. Use when the user says "/campaign <goal>", "start a campaign", "开一个战役", wants several pieces of work done in parallel by sub-sessions, or wants to resume an existing campaign. Not for a single quick fix (just do it) and not for in-process subagents (use the Agent tool).
argument-hint: "<goal>  |  resume <slug>"
---

# Campaign

A **Campaign** is one bounded objective (hours to a couple of days, usually 3–10 Threads). This session is its **Chief of Staff** ("Chief"). Background sessions doing execution are **Threads**. When the objective is met the Campaign ends with a **Debrief**; the next objective gets a new Campaign and a fresh Chief.

The design is a local take on the cloud-only Claude Code Projects, with two deliberate differences:

1. **The Chief is the user's stand-in, not a dispatcher.** The user discusses the *what* (intent, trade-offs, scope, acceptance) with the Chief. The Chief grills the user and scouts the code itself before dispatching. The user never has to go into a Thread to discuss anything.
2. **The Chief lives for one Campaign.** Long-term knowledge lives in the *Standing context* (repo `AGENTS.md`/`CLAUDE.md`, docs, memory). A fresh Chief per Campaign keeps enough context budget for deep discussion.

## Glossary

| Term | Meaning |
|---|---|
| Campaign | One objective, one Chief, several Threads; Kickoff → Debrief |
| Chief of Staff (Chief) | This session. Grill, Recon, Brief, answer escalations, Landing, Debrief |
| Thread | A `claude --bg` session with its own Brief, model and effort; reports only to the Chief |
| Grill | Proactively interrogating the user until problem, boundary and acceptance are unambiguous |
| Recon | The Chief reading code / reproducing the bug itself before dispatching |
| Brief | A Thread's written task: goal, writable paths, acceptance, verification, model/effort, worktree |
| Escalation | Thread → Chief message when blocked: question, options, recommendation, meanwhile |
| Asks | Decisions the Chief batches and digests for the user: context, options, recommendation |
| Show | Something the user must look at; the Chief opens it for them (`open`, screenshot, URL) |
| ROE | Rules of Engagement: what the user authorized for this Campaign (e.g. merge after gates) |
| Landing | Review diff, run gates serially in the main checkout, merge bottom-up per ROE |
| Debrief | Close-out: Threads resolved, decisions promoted to Standing context, Backlog written |
| Standing context | Repo instructions, docs, memory — outlives Campaigns |
| Campaign file | `.campaigns/<date>-<slug>/` — state that lets a restarted Chief carry on |

## Hard rules

- **You only talk to the user; Threads only talk to you.** A Thread never asks the user for a decision. If the user attaches to a Thread and works with it directly, that Thread must report the outcome back to you.
- **Repo rules win.** Read the repo's `AGENTS.md` / `CLAUDE.md` at Kickoff and put the rules that matter (branch/PR policy, signoff, gates, forbidden paths, package manager, image formats) into every Brief. This skill never overrides them.
- **Permission modes must match.** Threads are spawned with `--permission-mode bypassPermissions`. Cross-session messages between sessions of different permission classes are *held* for manual approval and may expire. If this Chief is not in bypass mode, tell the user at Kickoff (switch with shift+tab or restart with `--permission-mode bypassPermissions`), or the Threads' reports will be held.
- **Irreversible or outward actions always go to the user**, whatever the ROE says: release, upload, force-push, rewriting shared history, deleting branches/data that are not the Campaign's own, posting to other people.
- **Never poll.** Use `SendMessage` with `notify_when_idle: true` and wait for messages. Do not loop on `ListAgents`, `claude agents` or `sleep`.
- **Worktrees only when necessary**: two or more Threads write code at the same time, or the user asks for one. A single coding Thread, or a read-only investigation, works in the main checkout. Never let two writing Threads share a checkout.

## Kickoff

1. **Name and model.** Run `ListAgents`; the header says this session's name. Ask the user to `/rename <slug>-chief` so Threads have a readable address (re-check with `ListAgents` afterwards). Recommended Chief setup is Opus 5.5 with `high` effort; you cannot change your own model, so if it differs, say so once and let the user decide (`/model`, `/effort`).
2. **Read the Standing context**: repo instructions, relevant docs, memory. Note anything that constrains the Campaign. If this Campaign continues an earlier one, read that Campaign's `debrief.md` and `backlog.md` (its handoff) and carry the open decisions into this Campaign's `asks.md`.
3. **Create the Campaign file**:
   ```bash
   sh ~/.claude/skills/campaign/scripts/campaign-init.sh <slug> [<repo-root>]
   ```
   It creates `.campaigns/<YYYY-MM-DD>-<slug>/` from the templates and keeps it out of git via `.git/info/exclude` (no tracked file is touched).
4. **Agree the objective and ROE** with the user, plus the model lineup (below). Write them into `campaign.md`. The default ROE to propose: "merge a Thread's PR myself once all repo gates pass; ask before anything irreversible". Use the user's own words when they give an ROE.

## Grill and Recon (before any dispatch)

These alternate until you can write acceptance criteria the user agrees with.

- **Grill** the user proactively. For a bug: when does it happen, what was expected, what changed recently, how to reproduce, what counts as fixed. For a feature: who uses it, what the smallest valuable version is, what is out of scope, how it will be accepted (hands-on? screenshot? test?). Ask a few sharp questions at a time, each with your recommended answer, and stop when the answers stop changing the plan. If a `grilling` skill is available, use it.
- **Don't ask what Recon can answer.** Read the code, reproduce the bug, check git history first; then ask only what the code cannot tell you.
- **Recon yourself**, using `Explore` subagents for wide sweeps so file dumps stay out of your context.
- **Decide whether to dispatch at all.** Do it yourself when the work is small, sequential or needs the discussion context. Dispatch when it is parallelizable, long, or would bloat your context.

Record every decision the user makes in `decisions.md` as you go (date, decision, why, who decided).

## Brief and Dispatch

1. Write `briefs/<thread>.md` from `references/brief-template.md`. A good Brief is self-contained: a fresh session with no access to this conversation must be able to do the work. Include the repo rules that apply, the writable paths, acceptance criteria, exact verification commands and the branch name.
2. Pick model and effort (lineup below) and decide on a worktree.
3. Spawn:
   ```bash
   sh ~/.claude/skills/campaign/scripts/spawn-thread.sh \
     --campaign-dir <campaign-dir> --chief <your-session-name> \
     --name <slug>-<thread> --model opus --effort medium [--worktree <thread>] \
     --brief <campaign-dir>/briefs/<thread>.md [--cwd <repo-root>]
   ```
   The script runs `claude --bg` in bypass mode with Remote Control on (`--no-remote-control` to opt out) and the Thread protocol (`references/thread-protocol.md`) appended to the Thread's system prompt, and prints the short id.
4. `SendMessage` to the Thread name with `notify_when_idle: true` (no message body needed) so you hear when it stops.
5. Add a row to `board.md`.

Thread names: `<slug>-<short-task>`, lowercase, unique within the machine (duplicates are possible with `--bg`, so check `ListAgents` first).

### Model lineup (defaults)

| Role | Model | Effort |
|---|---|---|
| Chief | Opus 5.5 | high |
| Coding Thread | opus | medium |
| Hard bug / architecture investigation | opus | high |
| QA, gates, screenshot collection | sonnet | medium |
| Mechanical work (formatting, moving files) | haiku | low |

Override order: these defaults → the Campaign's lineup in `campaign.md` (agreed at Kickoff) → the Brief's `model`/`effort`. Show the chosen model/effort on the board.

## Run: handling Threads

Thread messages arrive as `<cross-session-message from="…">`; reply with `SendMessage` to that `from` address (or the Thread name). Thread message kinds are defined in `references/thread-protocol.md`: `STARTED`, `PROGRESS`, `ESCALATION`, `READY`, `DONE`.

Triage every `ESCALATION` three ways:

- **Answer**: the decision follows from the user's stated intent or `decisions.md`. Reply directly and log it. Most escalations should end here.
- **Ask**: the user must decide. Add it to `asks.md` as *context, options, your recommendation*. Bring non-blocking Asks to the user in a batch at a natural break; bring a blocking one now. Never forward the Thread's raw text.
- **Show**: the user must see or feel something (UI, motion, a page). Prepare it and open it for them (`open <file|app|url>`), with one line on what to look at.

When you need the user and they may be away, use a push notification if the `PushNotification` tool is available, or another notification channel the user asked for in this Campaign.

If a Thread goes idle without `READY`/`ESCALATION`, read its tail (`claude logs <id>`) before messaging it. Keep your context lean: Threads report in ≤3 lines and put details in `threads/<thread>/report.md` (worktree Threads that cannot write the Campaign dir put them in the PR description instead); read those only when you need them.

Update `board.md` on every state change. Statuses: `Working` → `Blocked on Chief` → `Ready for review` → `Landing` → `Resolved` (also `Stopped`). There is no "Waiting on user" status; anything that needs the user lives in `asks.md`.

### Changing a Thread's model or effort mid-flight

1. `claude stop <id>`.
2. Confirm it has stopped: `claude agents --json --all` no longer shows it running. If you resume while it is still running, Claude Code starts a *copy* under a new id instead of continuing the original.
3. `claude --bg --resume <full-session-id> --model <m> --effort <level> --permission-mode bypassPermissions`. The resumed session keeps its name and conversation but waits idle.
4. `SendMessage` it a one-line "continue" with any new instruction. Update the board.

Simpler when the user does it: `/effort high` typed into the Thread (attach, desktop sidebar, web or phone) applies from its next turn, no stop needed.

## Landing

1. Review the Thread's diff yourself (`git diff <base>...<branch>`, or the PR). Check scope against the Brief's writable paths.
2. Run the repo's gates **in the main checkout, one Landing at a time**. Parallel gate runs on one machine overload it and produce flaky timeouts. Check out the branch there; do not run app QA in a fresh worktree whose dependencies were never installed.
3. Merge according to the ROE, bottom-up for stacked branches. On conflicts or failing gates, send the Thread back with the exact failure. When a branch has fallen behind or conflicts, ask the Thread to **merge** the base branch in, never to rebase: a rebase forces a force-push, which most repos reserve for the user. Gate the merge result (base + branch) rather than the bare branch, and gate one PR at a time; if a test times out only under load, rerun it alone and then rerun the full gate before signing off. Limit review rounds to 2 per Thread, then escalate to the user.
4. Close the Thread: `claude stop <id>` then `claude rm <id>` (also removes its worktree when safe). Mark it `Resolved` on the board.

## Debrief

When the objective is met (or the user calls it):

1. Every Thread is `Resolved` or explicitly `Stopped`; no stray worktrees (`git worktree list`) or background sessions (`claude agents --json`).
2. Write `debrief.md`: what shipped (PRs/commits), what was decided, what was learned, what is left.
3. Promote durable decisions into the Standing context: repo docs through the repo's normal change process, or memory. Ask the user which ones.
4. Write `backlog.md`: the handoff to the next Campaign. Leftovers phrased as next-Campaign objectives, plus a short list of unresolved decisions (open `asks.md` entries) with the context needed to pick them up.
5. Give the user a short close-out and stop. The next Campaign starts in a new session; to continue this work, start it with `/campaign <goal>` and point it at this Campaign's `backlog.md`.

## Resuming after compaction or restart

Everything needed is on disk. Read `campaign.md` (objective, ROE, lineup, the **State** section), `board.md`, `asks.md`, the tail of `decisions.md`. Run `ListAgents` to see which Threads are alive; re-subscribe `notify_when_idle`. If this is a new Chief session, its name changed: message each live Thread "Chief is now <new-name>". Keep the **State** section of `campaign.md` current at every milestone so this always works.

## Known limits (Claude Code 2.1.294, 2026-10-08)

- Visibility: Threads are spawned with Remote Control, so they appear in the Claude desktop app sidebar, claude.ai/code and the phone app (verified 2026-10-08), where the user can read and type into them. They also show in `claude agents` (terminal agent view) and `claude attach <name>`.
- Effort: the user can change a running Thread's effort without stopping it (`/effort high` inside the Thread, from any of those surfaces); it applies from the Thread's next turn. Only the Chief's flag-based change needs stop + resume.
- A fresh worktree has no installed dependencies. Tell worktree Threads in the Brief what to install, and keep app-launching QA in the main checkout.
- Worktree isolation can stop a Thread from writing the Campaign dir in the main checkout; the protocol falls back to the PR description and `READY` message.
- Headless green is not acceptance for UI, input methods or native integration: plan a trial build and the user's hands-on check before calling a feature done.
- Session names are not guaranteed unique for `--bg`; always check `ListAgents`.
- Cross-harness orchestration (Codex, Gemini CLI and others) is out of scope for v1.
