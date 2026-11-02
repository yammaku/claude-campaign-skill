---
name: campaign
description: Run a local multi-session Campaign in Claude Code. This session becomes the Chief of Staff — the user's stand-in who grills the user, scouts the code, writes Briefs, spawns background Thread sessions (`claude --bg`), answers their escalations, lands their work and debriefs. Use when the user says "/campaign <goal>", "start a campaign", "开一个战役", wants several pieces of work done in parallel by sub-sessions, or wants to resume an existing campaign. Not for a single quick fix (just do it) and not for in-process subagents (use the Agent tool).
argument-hint: "<goal>  |  resume <slug>"
---

# Campaign

A **Campaign** is a bounded set of objectives (hours to a couple of days, usually 3–10 Threads). This session is its **Chief of Staff** ("Chief"). Background sessions doing execution are **Threads**. When its objectives are met the Campaign ends with a **Debrief**; the next set of objectives gets a new Campaign and a fresh Chief.

The design is a local take on the cloud-only Claude Code Projects, with two deliberate differences:

1. **The Chief is the user's stand-in, not a dispatcher.** The user discusses the *what* (intent, trade-offs, scope, acceptance) with the Chief. The Chief grills the user and scouts the code itself before dispatching. The user never has to go into a Thread to discuss anything.
2. **The Chief lives for one Campaign.** Long-term knowledge lives in the *Standing context* (repo `AGENTS.md`/`CLAUDE.md`, docs, memory). A fresh Chief per Campaign keeps enough context budget for deep discussion.

This skill starts Threads with `claude --bg` and works from a terminal or the Claude desktop app. Its sibling `campaign-native` does the same with the desktop app's own linked sub-sessions. Both use the same Campaign file (`references/campaign-file.md`), so either kind of Chief can take over a Campaign the other started.

## Glossary

| Term | Meaning |
|---|---|
| Campaign | One set of objectives, one Chief, several Threads; Kickoff → Debrief |
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
| Handover | Outgoing Chief writes `handover.md` and starts a fresh Chief that takes over the Threads |
| Standing context | Repo instructions, docs, memory — outlives Campaigns |
| Campaign file | `.campaigns/<date>-<slug>/` — state that lets a restarted Chief carry on |
| Resume card | `resume.md`: Now / Next / In flight / Waiting on user / Constraints, rewritten before every heavy step and every turn end; enforced by the optional chief-guard hook |

## Hard rules

- **You only talk to the user; Threads only talk to you.** A Thread never asks the user for a decision. If the user attaches to a Thread and works with it directly, that Thread must report the outcome back to you.
- **Repo rules win.** Read the repo's `AGENTS.md` / `CLAUDE.md` at Kickoff and put the rules that matter (branch/PR policy, signoff, gates, forbidden paths, package manager, image formats) into every Brief. This skill never overrides them.
- **Permission modes must match.** Threads are spawned with `--permission-mode bypassPermissions`. Cross-session messages between sessions of different permission classes are *held* for manual approval and may expire. If this Chief is not in bypass mode, tell the user at Kickoff (switch with shift+tab or restart with `--permission-mode bypassPermissions`), or the Threads' reports will be held.
- **Irreversible or outward actions always go to the user**, whatever the ROE says: release, upload, force-push, rewriting shared history, deleting branches/data that are not the Campaign's own, posting to other people.
- **Never poll Threads.** Use `SendMessage` with `notify_when_idle: true` and wait for messages. Do not loop on `ListAgents`, `claude agents` or `sleep`.
- **External state is the exception: watch it in the background and keep watching.** A colleague's replies (a chat thread, a PR review) or a long gate run can't send you a message. Watch them with one background job that exits on the first new event, for example a `gh pr view` loop with a 5-minute interval, or your chat tool's wait command. Read **everything** new since the last event, not just the event that woke you, then re-arm before you report to the user. Stop only when the user says so; when the discussion looks finished, ask whether to stop. A one-shot watch misses follow-ups that change the plan.
- **Disk is the memory; write before you act.** `resume.md` is rewritten (not appended) before every heavy or outward step and before every turn ends, so a compacted or brand-new Chief can continue from the files alone. The `chief-guard` hook enforces this when it is installed (`references/chief-guard.md`); never work around a denial, fix the card.
- **Worktrees only when necessary**: two or more Threads write code at the same time, or the user asks for one. A single coding Thread, or a read-only investigation, works in the main checkout. Never let two writing Threads share a checkout.

## Kickoff

1. **Name and model.** Run `ListAgents`; the header says this session's name. Ask the user to `/rename <slug>-chief` so Threads have a readable address (re-check with `ListAgents` afterwards). Recommended Chief setup is Opus 5.5 with `high` effort; you cannot change your own model, so if it differs, say so once and let the user decide (`/model`, `/effort`).
2. **Read the Standing context**: repo instructions, relevant docs, memory. Note anything that constrains the Campaign. If this Campaign continues an earlier one, read that Campaign's `debrief.md` and `backlog.md` (its handoff) and carry the open decisions into this Campaign's `asks.md`.
3. **Create the Campaign file**:
   ```bash
   sh ~/.claude/skills/campaign/scripts/campaign-init.sh <slug> [<repo-root>]
   ```
   It creates `.campaigns/<YYYY-MM-DD>-<slug>/` from the templates (including `resume.md`) and keeps it out of git via `.git/info/exclude` (no tracked file is touched). Then register this session as the Chief:
   ```bash
   sh ~/.claude/skills/campaign/scripts/chief-register.sh <campaign-dir>
   ```
   If the chief-guard hooks are not in `~/.claude/settings.json` yet, install them once (`references/chief-guard.md`; it is a user-settings change, so tell the user).
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

1. Review the Thread's diff yourself (`git diff <base>...<branch>`, or the PR). Check scope against the Brief's writable paths. For changes the user can see or touch, the `READY` must carry **real-app evidence** from the repo's verification skill: captures, plus a measurement where one exists. **Look at the captures yourself before merging.** A Thread's "PASS" is not evidence.
2. Run the repo's gates **in the main checkout, one Landing at a time**. Parallel gate runs on one machine overload it and produce flaky timeouts. Check out the branch there; do not run app QA in a fresh worktree whose dependencies were never installed.
3. Merge according to the ROE, bottom-up for stacked branches. On conflicts or failing gates, send the Thread back with the exact failure. When a branch has fallen behind or conflicts, ask the Thread to **merge** the base branch in, never to rebase: a rebase forces a force-push, which most repos reserve for the user. Gate the merge result (base + branch) rather than the bare branch, and gate one PR at a time; if a test times out only under load, rerun it alone and then rerun the full gate before signing off. **If the base moved after the gate ran**, list the new commits' files (`git log <head>..origin/<base> --name-only`). If they overlap the PR's files, merge the base in and re-gate before merging. If they don't overlap, note it in `decisions.md` and merge. If you merged and then noticed an overlap, run the affected tests on the base right away. Limit review rounds to 2 per Thread, then escalate to the user.
4. Run the **resume drill** after each batch lands: a fresh read-only subagent that may read only the Campaign dir answers "what is next, what is in flight, what waits on the user"; every difference from your own answer is a gap in the files, fix it now (`references/chief-guard.md`).
5. Close the Thread: `claude stop <id>` then `claude rm <id>` (also removes its worktree when safe). Mark it `Resolved` on the board.

### Several Chiefs on one machine

Other Campaigns may run on the same checkout and machine at the same time.
- Before dispatching, send each overlapping Chief your Threads' writable paths.
- Before running gates or heavy builds, send them a message, and say when you are done; the main checkout is shared.
- When two PRs touch the same generated files or baselines, agree who lands first. Whoever lands second merges the base and regenerates.
- Hand findings that belong to another Campaign's area to its Chief with a precise repro, instead of fixing them yourself.

### External coding agents (e.g. Codex)

Run them in their own worktree created from the base, with the Brief as the prompt. Tell them to leave changes uncommitted. Then the Chief reviews, commits with the repo's attribution, opens the PR and lands it like any Thread's work.

## Debrief

When the objectives are met (or the user calls it):

1. Every Thread is `Resolved` or explicitly `Stopped`; no stray worktrees (`git worktree list`) or background sessions (`claude agents --json`).
2. Write `debrief.md`: what shipped (PRs/commits), what was decided, what was learned, what is left.
3. Promote durable decisions into the Standing context: repo docs through the repo's normal change process, or memory. Ask the user which ones.
4. Write `backlog.md`: the handoff to the next Campaign. Leftovers phrased as next-Campaign objectives, plus a short list of unresolved decisions (open `asks.md` entries) with the context needed to pick them up.
5. Give the user a short close-out and stop. The next Campaign starts in a new session; to continue this work, start it with `/campaign <goal>` and point it at this Campaign's `backlog.md`.

## Chief handover

**Hand over only when the user explicitly asks for it.** Never hand over on your own initiative: not after a compaction, not after some number of landed batches, not before a long discussion. A Chief cannot see its own context usage and a self-triggered handover tends to come far too early (2026-10-11: at about 57% context). Continuity does not depend on a handover — it depends on `resume.md` being current, which the hook enforces — so after a compaction you simply continue from `resume.md`. When the user asks, hand over at the next stable point (nothing running, nothing half-answered); never mid-Landing, because background jobs and watches only notify the session that started them.

**Outgoing Chief**
1. Reach a stable point: no gate or build of yours running; every open escalation answered or written down with your intended answer.
2. Rewrite `resume.md`, then write `handover.md` from `references/handover-template.md` (it adds what the card does not carry): where things stand, the rules the next Chief inherits (ROE in the user's words, lineup, permission mode, user preferences), every live Thread (short id, branch, worktree, PR, state, owned files, what it is waiting for), peer Chiefs and standing agreements, next steps in order, pending user decisions, lessons. Bring the **State** section of `campaign.md` up to date.
3. Start the new Chief with the same model, effort and permission mode as yours:
   ```bash
   sh ~/.claude/skills/campaign/scripts/handover-chief.sh \
     --campaign-dir <campaign-dir> --from <your-session-name> --name <slug>-chief-<n> \
     --model opus --effort high [--cwd <repo-root>]
   ```
   It runs `claude --bg` in bypass mode with Remote Control (the user can talk to it from the desktop app, web or phone) and opens with `/campaign`, pointing it at `handover.md`.
4. Tell every live Thread, yourself: "Your Chief is now <new-name>; send everything to it from now on." Threads only switch Chief on their current Chief's word (or the user's), so this message is the authorization.
5. Wait for the new Chief's `TOOK OVER`. Release your registration (`sh ~/.claude/skills/campaign/scripts/chief-register.sh --release`), then tell the user the new Chief's name and where to find it, stop answering Threads, and end your turn. Do not stop Threads or delete anything: the new Chief owns them.

**Incoming Chief**
1. Register (`chief-register.sh <campaign-dir>`). Read `handover.md` and `resume.md`, then `campaign.md`, `board.md`, `asks.md`, the tail of `decisions.md`.
2. `ListAgents`: confirm every Thread in the handover is alive (and look for ones it missed). The board's Note column says each Thread's kind (`bg` or `native`, see `references/campaign-file.md`); a `native` Thread from a `campaign-native` Chief reports to you with `SendMessage` once you tell it you are its Chief.
3. Message each live Thread "Chief is now <your-name>" and re-subscribe `notify_when_idle`.
4. Message peer Chiefs the new address.
5. Rewrite `resume.md`, update the Chief line in `campaign.md`; log the handover in `decisions.md`. Re-arm every background watch the old Chief owned (its background jobs do not notify you).
6. Send the outgoing Chief `TOOK OVER`, then greet the user: what is in flight, what you do next, anything waiting on them.

## Resuming after compaction or restart

Everything needed is on disk. After a compaction the chief-guard SessionStart hook injects `resume.md`; read it first, then `campaign.md` (objective, ROE, lineup), `board.md`, `asks.md`, the tail of `decisions.md`. Run `ListAgents` to see which Threads are alive; re-subscribe `notify_when_idle`. If this is a new Chief session, its name changed: message each live Thread "Chief is now <new-name>". `resume.md` is what makes this work; the hook keeps it current.

## Known limits (Claude Code 2.1.294, 2026-10-08)

- Visibility: Threads are spawned with Remote Control, so they appear in the Claude desktop app sidebar, claude.ai/code and the phone app (verified 2026-10-08), where the user can read and type into them. They also show in `claude agents` (terminal agent view) and `claude attach <name>`.
- Effort: the user can change a running Thread's effort without stopping it (`/effort high` inside the Thread, from any of those surfaces); it applies from the Thread's next turn. Only the Chief's flag-based change needs stop + resume.
- A fresh worktree has no installed dependencies. Tell worktree Threads in the Brief what to install, and keep app-launching QA in the main checkout.
- Worktree isolation can stop a Thread from writing the Campaign dir in the main checkout; the protocol falls back to the PR description and `READY` message.
- Headless green is not acceptance for UI, input methods or native integration: plan a trial build and the user's hands-on check before calling a feature done.
- Session names are not guaranteed unique for `--bg`; always check `ListAgents`.
- Cross-harness orchestration (Codex, Gemini CLI and others) is out of scope for v1.
