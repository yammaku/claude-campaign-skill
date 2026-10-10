# Campaign file layout

`campaign-init.sh` creates `.campaigns/<YYYY-MM-DD>-<slug>/` at the repo root (or in the current directory outside a repo). It also adds `.campaigns/` to `.git/info/exclude`, so nothing is tracked and no tracked file changes.

```
.campaigns/2026-10-08-window-polish/
  campaign.md      objective, ROE, lineup, acceptance, State (kept current)
  board.md         one row per Thread
  decisions.md     append-only decision log
  asks.md          open questions for the user (Chief → user)
  briefs/<thread>.md
  threads/<thread>/report.md   written by the Thread
  debrief.md       written at close
  backlog.md       leftovers as next-Campaign objectives
```

## board.md row format

```
| Thread | Status | Model/effort | Checkout · branch | PR | Updated | Note |
|---|---|---|---|---|---|---|
| wp-titlebar | Working | opus/medium | worktree · feat/titlebar-drag | — | 10-08 14:20 | started |
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
