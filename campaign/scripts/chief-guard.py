#!/usr/bin/env python3
"""Campaign Chief guard: hooks that make the resume card a habit the harness enforces.

Only sessions registered as a Chief (~/.claude/campaign-chiefs/<session_id> holds the campaign dir)
are affected. A Chief registers by running `sh <skill>/scripts/chief-register.sh <campaign-dir>`;
this hook sees that command and records the session.

Events:
- PreToolUse(Bash): a heavy or outward step (gate, merge, PR, push, spawn, stop/rm, handover) is denied unless resume.md was rewritten after the previous heavy step (write-ahead).
- PostToolUse(Bash): after `gh pr merge`, remind the Chief to run the resume drill.
- Stop: block the end of a turn while resume.md is older than board.md / decisions.md / asks.md
  or the last heavy step.
- SessionStart(compact|resume): inject resume.md; after a compaction, tell the Chief to re-read and continue.
"""
import json, os, re, sys, time

REG = os.path.expanduser('~/.claude/campaign-chiefs')
# Heavy or outward steps. Add your repo's own gate, release and install commands to this pattern.
HEAVY = re.compile(
    r'(\b(sh|bash|zsh)\s+["\']?[^|;&\n]*?(gate|spawn-thread|handover-chief)\.sh'
    r'|^\s*(gh pr (merge|create)|gh signoff|git push|claude (stop|rm)\b)'
    r'|[;&|]\s*(gh pr (merge|create)|gh signoff|git push|claude (stop|rm)\b))', re.M)
REGISTER = re.compile(r'(?:^|[;&|]\s*)(?:sh|bash|zsh)\s+["\']?[^|;&\n]*?chief-register\.sh["\']?\s+(--release\b|"([^"]+)"|\'([^\']+)\'|(\S+))', re.M)


def out(obj):
    print(json.dumps(obj, ensure_ascii=False))
    sys.exit(0)


def mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return 0.0


def main():
    data = json.load(sys.stdin)
    sid = data.get('session_id') or ''
    event = data.get('hook_event_name') or ''
    command = (data.get('tool_input') or {}).get('command') or ''

    m = REGISTER.search(command) if event == 'PreToolUse' else None
    if m and sid:
        if m.group(1) == '--release':
            try:
                os.remove(os.path.join(REG, sid))
            except OSError:
                pass
        else:
            camp = os.path.abspath(os.path.expanduser(next(g for g in m.groups()[1:] if g)))
            os.makedirs(REG, exist_ok=True)
            with open(os.path.join(REG, sid), 'w') as f:
                f.write(camp + '\n')
        sys.exit(0)

    reg = os.path.join(REG, sid)
    if not sid or not os.path.exists(reg):
        sys.exit(0)
    camp = open(reg).read().strip()
    if not os.path.isdir(camp):
        sys.exit(0)
    resume = os.path.join(camp, 'resume.md')
    state_path = os.path.join(camp, '.guard-state.json')
    try:
        state = json.load(open(state_path))
    except (OSError, ValueError):
        state = {}
    last_heavy = float(state.get('last_heavy', 0))

    if event == 'PreToolUse':
        if not HEAVY.search(command):
            sys.exit(0)
        if mtime(resume) <= last_heavy:
            out({'hookSpecificOutput': {
                'hookEventName': 'PreToolUse', 'permissionDecision': 'deny',
                'permissionDecisionReason': (
                    f'Campaign write-ahead: before this step, rewrite {resume} (Now / Next / In flight: '
                    'what you are about to run, its log path or task id, and how to check the result). '
                    'Then run the command again.')}})
        state['last_heavy'] = time.time()
        json.dump(state, open(state_path, 'w'))
        sys.exit(0)

    if event == 'PostToolUse':
        if re.search(r'(?:^|[;&|]\s*)gh pr merge\b', command, re.M):
            out({'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': (
                'A PR was merged. Update resume.md, then run the resume drill: spawn a fresh read-only '
                f'subagent that may read only {camp} and ask it what the next action is and what is in '
                'flight; fix the campaign files wherever its answer differs from yours.')}})
        sys.exit(0)

    if event == 'Stop':
        if data.get('stop_hook_active'):
            sys.exit(0)
        newest = max([last_heavy] + [mtime(os.path.join(camp, n)) for n in ('board.md', 'decisions.md', 'asks.md')])
        if mtime(resume) + 1 < newest:
            out({'decision': 'block', 'reason': (
                f'Campaign resume card is stale: {resume} is older than the latest board/decisions/asks '
                'change or heavy step. Rewrite it (Now / Next / In flight / Waiting on user / Constraints) '
                'so a fresh session could continue from it, then finish.')})
        sys.exit(0)

    if event == 'SessionStart':
        source = data.get('source') or ''
        if source not in ('compact', 'resume'):
            sys.exit(0)
        card = open(resume).read() if os.path.exists(resume) else '(resume.md missing — rebuild it first)'
        policy = ''
        if source == 'compact':
            policy = ('\nContext was just compacted. Re-read campaign.md, board.md, asks.md and the tail of '
                      'decisions.md before acting, then simply continue the work. Do not hand over unless the user '
                      'explicitly asks for it.')
        out({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': (
            f'You are the Chief of Staff of the Campaign in {camp}. Its resume card:\n\n{card}{policy}')}})
    sys.exit(0)


if __name__ == '__main__':
    main()
