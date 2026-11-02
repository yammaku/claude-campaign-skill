#!/bin/sh
# Registers the calling session as the Chief of a Campaign. The chief-guard PreToolUse hook sees this
# command (it knows the session id) and records ~/.claude/campaign-chiefs/<session_id>.
# Usage: sh chief-register.sh <campaign-dir>   |   sh chief-register.sh --release  (outgoing Chief, after TOOK OVER)
[ "${1-}" = --release ] && { echo "chief registration released"; exit 0; }
[ -d "$1" ] || { echo "no such campaign dir: $1" >&2; exit 2; }
[ -f "$1/resume.md" ] || echo "note: $1/resume.md does not exist yet; write it now" >&2
echo "chief registered for $1 (if the chief-guard hook is installed)"
