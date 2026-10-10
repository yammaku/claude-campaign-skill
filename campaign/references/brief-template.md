# Brief: <thread-name>

- Campaign: <slug> (`<campaign-dir>`)
- Chief: <chief-session-name>
- Model / effort: <opus|sonnet|haiku> / <low|medium|high|xhigh>
- Checkout: <main checkout | worktree `<name>`>
- Branch: `<branch>` from `<base>`

## Goal

<One paragraph on what done looks like, written from the user's side.>

## Context

<What the Chief learned in Grill and Recon that this Thread needs:
- the root cause, or the hypotheses;
- the relevant files with paths;
- the decisions already made (or a pointer to `decisions.md` entries).
Self-contained: assume no access to the Chief's conversation.>

## Scope

- Writable paths: `<path/…>`
- Out of scope: <…>

## Repo rules that apply

<Copied or summarized from the repo's AGENTS.md / CLAUDE.md:
- branch/PR policy, commit attribution, signoff;
- package manager, gates;
- forbidden paths, file-format rules.>

- Catching up with the base branch: merge it into your branch; no rebase or force-push unless the user authorized it.
- A fresh worktree has no installed dependencies or built packages: list the exact setup commands.

## Acceptance

- [ ] <observable criterion>
- [ ] <test or check that proves it>

## Verification

```bash
<exact commands to run before READY>
```

## Escalate when

- <specific triggers, e.g. "the fix needs an API change", "tests outside scope fail">
- Anything that changes product or UX behaviour beyond the Goal.

## Report

Write details to `<campaign-dir>/threads/<thread-name>/report.md`; from a worktree that cannot write the Campaign dir, put them in the PR description and the `READY` message instead. Send `STARTED`, `ESCALATION`, `READY` per the Thread protocol.
