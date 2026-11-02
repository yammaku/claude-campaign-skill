#!/usr/bin/env python3
"""campaign-native: after a compaction (or a resume), read the Campaign's resume card back to its Chief.

SessionStart hook (matcher compact|resume). It finds the last registration line that
scripts/chief.sh printed in this session's transcript ("CAMPAIGN-NATIVE-CHIEF <dir>" or
"... released") and, for a live registration, injects <dir>/resume.md as additional context.
It never blocks anything; sessions that never registered get no output.
"""
import json, os, re, sys

MARKER = 'CAMPAIGN-NATIVE-CHIEF'
LINE = re.compile(MARKER + r' (released|/[^\n"\\]*)')
CHUNK = 4 * 1024 * 1024


def last_registration(path):
    """The last registration in the transcript: an absolute campaign dir, 'released', or None."""
    try:
        size = os.path.getsize(path)
    except OSError:
        return None
    with open(path, 'rb') as f:
        end = size
        tail = b''
        while end > 0:
            start = max(0, end - CHUNK)
            f.seek(start)
            block = f.read(end - start) + tail
            lines = block.split(b'\n')
            # The first piece may be a partial line; keep it for the next (earlier) block.
            tail, lines = (lines[0], lines[1:]) if start > 0 else (b'', lines)
            for raw in reversed(lines):
                if MARKER.encode() not in raw:
                    continue
                try:
                    text = json.dumps(json.loads(raw), ensure_ascii=False)
                except ValueError:
                    text = raw.decode('utf-8', 'replace')
                # Only tool output counts (the script's own print), not prose that mentions the marker.
                if '"tool_result"' not in text and '"toolUseResult"' not in text:
                    continue
                found = LINE.findall(text.replace('\\n', '\n'))
                if found:
                    return found[-1].rstrip()
            end = start
    return None


def main():
    data = json.load(sys.stdin)
    if (data.get('source') or '') not in ('compact', 'resume'):
        return
    camp = last_registration(data.get('transcript_path') or '')
    if not camp or camp == 'released' or not os.path.isdir(camp):
        return
    resume = os.path.join(camp, 'resume.md')
    card = open(resume, encoding='utf-8').read() if os.path.exists(resume) else '(resume.md is missing — rebuild it first)'
    note = ''
    if data.get('source') == 'compact':
        note = ('\nContext was just compacted. Re-read campaign.md, board.md, asks.md and the tail of decisions.md '
                'before acting, then simply continue. Do not hand over unless the user asks for it.')
    print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': (
        f'You are the Chief (campaign-native) of the Campaign in {camp}. Its resume card:\n\n{card}{note}')}},
        ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
