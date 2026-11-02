# Campaign file layout

`campaign-init.sh` (campaign) and `chief.sh` (campaign-native) create `.campaigns/<YYYY-MM-DD>-<slug>/` at the repo root (or in the current directory outside a repo). They also add `.campaigns/` to `.git/info/exclude`, so nothing is tracked and no tracked file changes.

```
.campaigns/2026-10-08-window-polish/
  resume.md        resume card: Now / Next / In flight / Waiting on user / Constraints (rewritten, never appended)
  campaign.md      objective, ROE, lineup, acceptance, State history
  board.md         one row per Thread
  decisions.md     append-only decision log
  asks.md          open questions for the user (Chief → user)
  briefs/<thread>.md
  threads/<thread>/report.md   written by the Thread
  handover.md      written by an outgoing Chief (only when the user asks for a handover)
  debrief.md       written at close
  backlog.md       the handoff to the next Campaign: leftovers as objectives, open decisions
  chiefs/<name>.json   written by campaign's handover-chief.sh (a Chief it started)
  .guard-state.json    written by campaign's chief-guard hook (time of the last heavy step)
```

## board.md row format

```
| Thread | Status | Model/effort | Checkout · branch | PR | Updated | Note |
|---|---|---|---|---|---|---|
| wp-titlebar | Working | opus/medium | worktree · feat/titlebar-drag | — | 10-08 14:20 | bg · 3f9a2c1d · started |
```

Statuses: `Working`, `Blocked on Chief`, `Ready for review`, `Landing`, `Resolved`, `Stopped`.

## decisions.md entry format

```
- 2026-10-08 14:32 · <decision> · why: <reason> · by: <user|Chief> · affects: <threads>
```

## asks.md entry format

```
## A3 · <short title> · blocking: <yes|no> · from: <thread>
Context: …
Options: 1) … 2) …
Recommendation: … because …
Answer: <filled in after the user decides; then log in decisions.md>
```

## Shared by both skills (`campaign` and `campaign-native`)

This layout is the contract between the two skills: either kind of Chief must be able to take over a Campaign the other started, from these files alone. Neither skill adds, renames or drops a file or a section on its own; a change to the layout is made in both skills' copies of this file at once (`tools/check-shared.sh` in the source repo checks that the copies and the generated templates match).

- `campaign-init.sh` (campaign) and `chief.sh` (campaign-native) create the same files with the same templates.
- **Thread kind in `board.md`**: the Note column starts with how to reach the Thread:
  - `bg · <short-id>`: a `claude --bg` Thread (campaign skill); it reports with `SendMessage` to the Chief's session name.
  - `native · <local_ id>`: a linked sub-session started with `start_session` (campaign-native); it reports at the end of each turn to the session that started it, and with `SendMessage` to a new Chief once told "Your Chief is now <name>".
- `campaign.md` names the current Chief session and which skill it runs.
- `handover.md` lists every live Thread with its kind and id.
