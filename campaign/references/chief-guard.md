# chief-guard: the resume card, enforced

The Chief's memory is the Campaign file, not the conversation. Compaction or a new Chief loses nothing as long as `resume.md` is current. `scripts/chief-guard.py` makes that a rule the harness enforces instead of a habit.

## What it does (only for registered Chief sessions)

| Event | Rule |
|---|---|
| PreToolUse (Bash) | A heavy or outward step — `sh/bash/zsh …gate.sh`, `…spawn-thread.sh`, `…handover-chief.sh`, `gh pr merge`, `gh pr create`, `gh signoff`, `git push`, `claude stop`/`claude rm` — is **denied** unless `resume.md` was rewritten after the previous heavy step. Write what you are about to run, its task id / log path, and how to check the result; then run it. |
| Stop | Ending a turn is **blocked** while `resume.md` is older than `board.md`, `decisions.md`, `asks.md` or the last heavy step (1 s tolerance). One retry is allowed (`stop_hook_active`) so it never loops. |
| SessionStart (`compact`, `resume`) | Injects `resume.md`; after a compaction it tells the Chief to re-read the Campaign file and continue. It never suggests a handover: handovers happen only when the user asks. |
| PostToolUse (Bash, `gh pr merge`) | Reminds the Chief to rewrite `resume.md` and run the resume drill (below). |

Sessions that are not registered (Threads, unrelated sessions) are untouched.

The heavy-step list is the `HEAVY` pattern at the top of `scripts/chief-guard.py`. Add your repo's own gate, release and install commands to it (for example `bun run check`, a packaging script, a copy into `/Applications`).

## Registering

The hook knows the session id; the session does not need to. Run

```bash
sh ~/.claude/skills/campaign/scripts/chief-register.sh <campaign-dir>
```

and the PreToolUse hook records `~/.claude/campaign-chiefs/<session_id>` → `<campaign-dir>`. The outgoing Chief runs `chief-register.sh --release` after `TOOK OVER`.

## Installing (user settings, once per machine)

Add to `~/.claude/settings.json` → `hooks` (merge into existing arrays):

```json
"PreToolUse":  [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "python3 -I ~/.claude/skills/campaign/scripts/chief-guard.py", "timeout": 10 }] }],
"PostToolUse": [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "python3 -I ~/.claude/skills/campaign/scripts/chief-guard.py", "timeout": 10 }] }],
"Stop":        [{ "hooks": [{ "type": "command", "command": "python3 -I ~/.claude/skills/campaign/scripts/chief-guard.py", "timeout": 10 }] }],
"SessionStart":[{ "matcher": "compact|resume", "hooks": [{ "type": "command", "command": "python3 -I ~/.claude/skills/campaign/scripts/chief-guard.py", "timeout": 10 }] }]
```

Prove it fires: register, run two harmless commands that match a heavy pattern back to back (e.g. `true # gh signoff probe`); the second must be denied.

## Resume drill

At every batch landing, spawn a fresh read-only subagent (Agent tool, `Explore`) whose prompt only names the Campaign dir: "Read these files and tell me: what is the next action, what is in flight, what is waiting on the user." Compare with your own answer; every difference is a gap in the files — fix it now.

What the first drill (2026-10-11) found, so cards avoid it from the start: thread states copied from an older moment; background jobs recorded only by task id (useless to another session — record PID and log path); no note on how a new Chief registers; batch commits not logged; guessed timestamps drifting an hour or more from the clock.
