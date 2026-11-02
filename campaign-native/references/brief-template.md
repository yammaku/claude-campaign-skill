# Brief: <thread-name>

- Campaign: <slug> (`<campaign-dir>`)
- Chief: <chief session name> (started you; you report to it)
- Model / effort: <model> / <effort>
- Checkout: <shared checkout | own worktree> · branch `<branch>` from `<base>`

## Goal

<One paragraph on what done looks like, from the user's side. Quote the user where it matters.>

## Context

<What the Chief learned in Grill and Recon: root cause or hypotheses, relevant files with paths, decisions already made (or pointers to `decisions.md`). Self-contained: you have no access to the Chief's conversation.>

## Scope

- Writable paths: `<path/…>`
- Out of scope: <…>

## Repo rules that apply

<Branch/PR policy, commit attribution, package manager, gates, forbidden paths, file formats — copied from the repo's AGENTS.md / CLAUDE.md and memory.>

- Catching up with the base branch: merge it in; never rebase or force-push unless the user authorized it.
- A fresh worktree has no installed dependencies: <exact setup commands>.

## Acceptance

- [ ] <observable criterion>
- [ ] <test or check that proves it; real-app captures for anything visible>

## Verification

```bash
<exact commands to run before READY>
```

## Escalate when

- <specific triggers>
- Anything that changes product or UX behaviour beyond the Goal.

## Reporting (how you talk to the Chief)

- The Chief sees the first ~400 characters of what you say when you end a turn, so end a turn only at a milestone and open with one word:
  - `READY` — done and verified: what changed (commits/PR), where the evidence is, risks;
  - `ESCALATION` — blocked: the question, the options, your recommendation, what you do meanwhile;
  - `PROGRESS` — a batch landed or something the Chief must look at now.
- Put the details in `<campaign-dir>/threads/<thread-name>/report.md`, or in the PR description when your checkout cannot write the Campaign dir.
- Don't stop to ask what you can decide inside the Goal and Scope. Never ask the user for a decision; ask the Chief.
- If the user talks to you directly, follow them, and tell the Chief what was decided in your next report.
- If you are told "Your Chief is now <name>", send every later report to that session with `SendMessage` as well as ending your turn as usual.
