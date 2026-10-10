#!/bin/sh
# Spawn a Campaign Thread as a background Claude Code session.
# Usage:
#   spawn-thread.sh --campaign-dir <dir> --chief <chief-session-name> --name <thread-name> \
#     --brief <brief.md> [--model opus] [--effort medium] [--worktree <name>] [--cwd <repo-root>] [--no-remote-control]
# Threads get Remote Control by default, so they show in the Claude desktop app sidebar, claude.ai/code and the phone app.
# Prints the background session's short id on the last line.
set -eu

model=opus effort=medium worktree= cwd= dir= chief= name= brief= rc=1
while [ $# -gt 0 ]; do
  case "$1" in
    --campaign-dir) dir=$2; shift 2;;
    --chief) chief=$2; shift 2;;
    --name) name=$2; shift 2;;
    --brief) brief=$2; shift 2;;
    --model) model=$2; shift 2;;
    --effort) effort=$2; shift 2;;
    --worktree) worktree=$2; shift 2;;
    --cwd) cwd=$2; shift 2;;
    --no-remote-control) rc=0; shift;;
    *) echo "unknown option: $1" >&2; exit 2;;
  esac
done
for v in dir chief name brief; do
  eval "val=\${$v}"
  [ -n "$val" ] || { echo "missing --$v (see usage in $0)" >&2; exit 2; }
done
[ -f "$brief" ] || { echo "brief not found: $brief" >&2; exit 2; }

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
protocol="$here/../references/thread-protocol.md"
[ -f "$protocol" ] || { echo "thread protocol not found: $protocol" >&2; exit 2; }

dir=$(CDPATH= cd -- "$dir" && pwd)
brief=$(CDPATH= cd -- "$(dirname -- "$brief")" && pwd)/$(basename -- "$brief")
[ -n "$cwd" ] && cd "$cwd"

mkdir -p "$dir/threads/$name"

slug=$(basename "$dir")
prompt="You are Thread \"$name\" in Campaign \"$slug\". Your Chief is the Claude Code session named \"$chief\": report to it only with SendMessage, following the Campaign Thread protocol in your system prompt. Campaign dir: $dir. Your report file: $dir/threads/$name/report.md. Read your Brief now: $brief. Then send STARTED to the Chief and begin."

set -- --bg --name "$name" --model "$model" --effort "$effort" \
  --permission-mode bypassPermissions \
  --append-system-prompt "$(cat "$protocol")"
[ -n "$worktree" ] && set -- "$@" --worktree "$worktree"
[ "$rc" = 1 ] && set -- "$@" --remote-control "$name"

out=$(claude "$@" "$prompt" 2>&1) || { echo "$out" >&2; exit 1; }
echo "$out"
id=$(printf '%s\n' "$out" | sed -n 's/^backgrounded · \([0-9a-f]*\).*/\1/p' | head -n 1)
[ -n "$id" ] || { echo "could not parse session id from claude output" >&2; exit 1; }

printf '{"name":"%s","id":"%s","model":"%s","effort":"%s","worktree":"%s","cwd":"%s","brief":"%s","spawned":"%s"}\n' \
  "$name" "$id" "$model" "$effort" "$worktree" "$(pwd)" "$brief" "$(date '+%Y-%m-%d %H:%M')" \
  > "$dir/threads/$name/spawn.json"
echo "$id"
