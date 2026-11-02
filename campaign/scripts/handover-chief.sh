#!/bin/sh
# Start a new Chief of Staff for a running Campaign (Chief handover).
# Usage:
#   handover-chief.sh --campaign-dir <dir> --from <outgoing-chief-name> --name <new-chief-name> \
#     [--model opus] [--effort high] [--cwd <repo-root>] [--no-remote-control]
# The new Chief runs in bypass permission mode (same class as its Threads) with Remote Control on,
# so the user can talk to it from the desktop app, claude.ai/code or the phone.
# It reads <dir>/handover.md, takes over the Threads and tells the outgoing Chief when it has.
# Prints the background session's short id on the last line.
set -eu

model=opus effort=high cwd= dir= from= name= rc=1
while [ $# -gt 0 ]; do
  case "$1" in
    --campaign-dir) dir=$2; shift 2;;
    --from) from=$2; shift 2;;
    --name) name=$2; shift 2;;
    --model) model=$2; shift 2;;
    --effort) effort=$2; shift 2;;
    --cwd) cwd=$2; shift 2;;
    --no-remote-control) rc=0; shift;;
    *) echo "unknown option: $1" >&2; exit 2;;
  esac
done
for v in dir from name; do
  eval "val=\${$v}"
  [ -n "$val" ] || { echo "missing --$v (see usage in $0)" >&2; exit 2; }
done

dir=$(CDPATH= cd -- "$dir" && pwd)
[ -f "$dir/handover.md" ] || { echo "write $dir/handover.md first (references/handover-template.md)" >&2; exit 2; }
[ -n "$cwd" ] && cd "$cwd"

slug=$(basename "$dir")
prompt="/campaign Take over Campaign \"$slug\" as its new Chief of Staff (Chief handover, incoming side). The outgoing Chief is the session named \"$from\"; your session name is \"$name\". Campaign dir: $dir. Register yourself first: sh ~/.claude/skills/campaign/scripts/chief-register.sh \"$dir\". Read $dir/handover.md and $dir/resume.md, then campaign.md, board.md, asks.md and the tail of decisions.md, and follow the skill's \"Chief handover → Incoming Chief\" steps: confirm the live Threads with ListAgents, message each one \"Chief is now $name\", re-subscribe notify_when_idle, rewrite resume.md, update the Chief line in campaign.md, tell the outgoing Chief \"TOOK OVER\", then greet the user with a short status and the next step."

set -- --bg --name "$name" --model "$model" --effort "$effort" --permission-mode bypassPermissions
[ "$rc" = 1 ] && set -- "$@" --remote-control "$name"

out=$(claude "$@" "$prompt" 2>&1) || { echo "$out" >&2; exit 1; }
echo "$out"
id=$(printf '%s\n' "$out" | sed -n 's/^backgrounded · \([0-9a-f]*\).*/\1/p' | head -n 1)
[ -n "$id" ] || { echo "could not parse session id from claude output" >&2; exit 1; }

mkdir -p "$dir/chiefs"
printf '{"name":"%s","id":"%s","from":"%s","model":"%s","effort":"%s","cwd":"%s","started":"%s"}\n' \
  "$name" "$id" "$from" "$model" "$effort" "$(pwd)" "$(date '+%Y-%m-%d %H:%M')" > "$dir/chiefs/$name.json"
echo "$id"
