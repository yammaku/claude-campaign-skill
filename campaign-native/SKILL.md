---
name: campaign-native
description: Run a multi-session Campaign with Claude desktop's native sub-sessions (start_session). This session becomes the Chief of Staff — the user's stand-in who grills the user, scouts the code, writes Briefs, starts linked sub-sessions (Threads) that show up grouped under it in the sidebar, answers their reports, lands their work and debriefs. Shares the Campaign file with the `campaign` skill, so either skill can take over a Campaign the other started. Use when the user says "/campaign-native <goal>", wants several pieces of work done in parallel by visible sub-sessions, or wants to resume a Campaign with it. Not for a single quick fix (just do it) and not for in-process subagents (use the Agent tool).
argument-hint: "<goal>  |  resume <campaign-dir>"
---

# Campaign (native sessions)

A **Campaign** is a bounded set of objectives, usually 3–10 Threads over hours to a couple of days. This session is the **Chief**. The user talks to the Chief about intent, trade-offs, scope and acceptance; the Chief grills, scouts, briefs, dispatches, verifies and lands. **Threads** are linked sub-sessions started with `start_session`; they appear under the Chief in the Claude desktop sidebar.

This is the lean sibling of the `campaign` skill. The app now does what that skill's scripts did (spawning, idle notices, the board view), so only the ideas stay here. Both skills read and write **the same Campaign file** (`references/campaign-file.md`); never change its layout on your own.

## Hard rules

- **The user talks to you; Threads report to you.** A Thread never asks the user for a decision. If the user works with a Thread directly, it still reports the outcome to you.
- **Repo rules win.** Read the repo's `AGENTS.md`/`CLAUDE.md` and memory at Kickoff and copy the rules that matter (branch/PR policy, gates, forbidden paths, package manager, image formats) into every Brief.
- **Irreversible or outward actions go to the user** whatever the ROE says: release, upload, force-push, rewriting shared history, deleting data that is not the Campaign's own, posting to people, archiving or deleting sessions.
- **Outward posts are the Chief's job.** Posting to a room or person (a team chat, a PR comment to a colleague) needs the user's own words in the posting session, and a Thread only has yours. So when the user wants something asked or sent, post it yourself with their words, then have the Thread watch for the answer.
- **Never poll.** Thread reports arrive by themselves. Don't loop on `list_sessions`, `ListAgents` or `sleep`.
- **External state is watched in the background and kept watched** (a colleague's thread, a PR review, a long build): one background job that exits on the first new event; read everything new, re-arm, then report. Stop only when the user says so.
- **Disk is the memory.** Record every user decision in `decisions.md` as it happens, in the user's words. Rewrite `resume.md` at every milestone and before ending a turn in which the state changed. A small hook (`scripts/resume-inject.py`, installed once per machine, see the end of this file) re-reads it to you after a compaction; nothing forces you, so keep the habit.
- **Worktrees only when needed**: two or more Threads writing code at once, or the user asks. Two writers never share a checkout.

## Kickoff

1. Name this session `<slug>-chief` (`set_session_title` on yourself, or ask the user to rename it).
2. Create or resume the Campaign file and register as its Chief:
   `sh ~/.claude/skills/campaign-native/scripts/chief.sh <slug | campaign-dir> [<repo-root>]`
   It creates `.campaigns/<YYYY-MM-DD>-<slug>/` with the shared templates if missing (kept out of git via `.git/info/exclude`) and prints a registration line that the compaction hook looks for. Run it again after every handover to you.
3. Read the Standing context (repo instructions, relevant docs, memory; if this Campaign continues an earlier one, that Campaign's `debrief.md` and `backlog.md`, carrying its open decisions into `asks.md`), and the app settings that shape Threads (`get_settings`: Remote Control default, worktree location, default permission mode).
4. Agree the objective, acceptance, ROE and model lineup with the user; write them into `campaign.md` with the user's own words. Default ROE to propose: "land a Thread's work myself once all repo gates pass; ask before anything irreversible". Default lineup: Threads opus at medium effort unless the user or memory says otherwise.

## Grill and Recon (before dispatch)

Alternate until you can write acceptance criteria the user agrees with. Ask a few sharp questions at a time, each with your recommended answer. Don't ask what the code can answer: read it, reproduce the bug, check history; use `Explore` subagents for wide sweeps. Decide whether to dispatch at all: do small, sequential or discussion-heavy work yourself.

## Dispatch

1. Write `briefs/<thread>.md` from `references/brief-template.md`. It must stand alone for a session that never saw this conversation.
2. Start the Thread with `start_session`:
   - `initiation`: `"user_asked"` when the user approved this work or the plan containing it; `"own_initiative"` for work you merely propose (it becomes a card the user starts).
   - `context: "fresh"`; `prompt` = the Brief (or "Read and follow <absolute brief path>" plus its key lines); `background` = objective, decisions so far, how this piece fits (≥ 80 chars).
   - `name: "<slug>-<task>"` (lowercase, ≤ 24); `title` in the user's language.
   - `use_worktree: true` and `branch_name` for code Threads that run in parallel; otherwise share the checkout.
   - `effort` and `permission_mode` from the lineup (both at most yours; a bypass Chief can start bypass Threads); `model` only to go cheaper.
   - `wake_when_done: true` when the Brief might never reach the Thread some other way (it also wakes you if the start fails).
3. Remote Control comes from the app: with Settings → Claude Code → "Connect new sessions to Remote Control" on, every Thread connects by itself and the user can follow it from the phone. Check that setting once at Kickoff (`get_settings`, key `connect_new_sessions_to_remote_control`); if it is off, tell the user it is the switch that makes Threads reachable from the phone (changing it is the user's call). `list_sessions` shows `remoteControlActive` per Thread; use `set_remote_control` only for a Thread the user names.
4. Add its row to `board.md` with `native · <local_ id>` in the Note column, and log the dispatch in `decisions.md`.

## Run

- Each time a Thread ends a turn, its report (first ~400 characters) reaches you and the app continues you if you were idle. That is why every Brief asks for a short report that starts with `READY`, `ESCALATION` or `PROGRESS` and keeps details in a report file or the PR.
- **Auto-continue has a cap**: after many such wake-ups in a row with no message from the user, further reports wait for the user's next message. So Threads report only at milestones (done, blocked, evidence to look at), not on every step. Before a long unattended stretch, tell the user that a single word from them resumes you if you go quiet.
- Reply with `SendMessage` to the Thread's `local_` id (or its name within your family). `list_sessions {"linked": true}` shows your family and their state; use it only when a decision needs it, not to poll.
- Triage every escalation: **Answer** it when it follows from the user's intent or `decisions.md`; **Ask** the user (context, options, your recommendation; batch non-blocking ones in `asks.md`); **Show** the user what they must see or feel (open the page, file or app for them, with one line on what to look at).
- Change a running Thread's model or effort with `set_session_model` / `set_session_effort`.
- Keep `board.md` statuses current: `Working` → `Blocked on Chief` → `Ready for review` → `Landing` → `Resolved` (or `Stopped`).

## Landing

1. Review the diff against the Brief's writable paths. For anything the user can see or touch, the report must carry real-app evidence (captures, measurements). **Look at the captures yourself**; a Thread's "pass" is not evidence.
2. Run repo gates one Landing at a time. Merge per the ROE; when a branch is behind, have the Thread **merge** the base in, never rebase. Re-gate the merge result if the base moved over the same files.
3. Close the Thread: mark it `Resolved` on the board. Offer to archive finished sessions; archive only on the user's yes.

## Handover and the other skill

Hand over only when the user asks. Both skills share the Campaign file, so either kind of Chief can continue a Campaign.
- **Taking over** (from a `campaign` Chief or another native Chief): run `chief.sh <campaign-dir>`, read `resume.md`, `campaign.md`, `board.md`, `asks.md` and the tail of `decisions.md`, then message every live Thread: "Your Chief is now <your session name>; send everything to it from now on." Old-style Threads (`claude --bg`) already report through `SendMessage`; native Threads switch to `SendMessage` because their Brief tells them to. Re-arm every background watch the old Chief owned.
- **Handing over**: bring `resume.md` and `campaign.md` up to date, write `handover.md` (live Threads with kind and id, owned files, pending user decisions, standing agreements), tell the Threads who the new Chief is, and stop answering them.

## Debrief

When the objectives are met or the user calls it: every Thread `Resolved` or `Stopped`; no stray worktrees; write `debrief.md` (shipped, decided, learned, left) and `backlog.md` (the handoff to the next Campaign: leftovers as next objectives, plus open decisions with the context to pick them up); promote durable decisions to the Standing context with the user's approval; give a short close-out.

## Known limits (Claude desktop, 2026-11-02)

- `start_session` exists only in Claude desktop sessions. This skill does not support terminal Chiefs; use the `campaign` skill there.
- `start_session` starts a session only in a turn the user's own message started, or in a side-session wake-up that directly follows one (and only for a step the user asked to have in its own session, in this project). In any other turn woken by a Thread's report or another session's message it is refused, and only an `own_initiative` card is allowed, which waits for the user. For overnight or unattended work, start the Threads you will need while the user is still there, and hand follow-up work to a live Thread with `SendMessage`.
- A Thread's effort and permission mode cannot exceed the Chief's; `model` can only go cheaper.
- Only the first ~400 characters of a Thread's turn-end report (its wrap-up recap, then its final message) reach you automatically. A cloud session sends no report at all.
- A fresh worktree has no installed dependencies: the Brief says what to install.
- Worktree Threads may be unable to write the Campaign dir; they put details in the PR description or their final report instead.

## Resume hook (once per machine)

`scripts/resume-inject.py` is a SessionStart hook: after a compaction or a resume it reads `resume.md` back to a session that registered with `chief.sh`, and does nothing for any other session. It is a user-settings change, so ask the user before adding it to `~/.claude/settings.json` → `hooks` (merge into an existing `SessionStart` array):

```json
"SessionStart": [{ "matcher": "compact|resume", "hooks": [{ "type": "command", "command": "python3 -I ~/.claude/skills/campaign-native/scripts/resume-inject.py", "timeout": 10 }] }]
```
