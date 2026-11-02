#!/bin/sh
# Create a Campaign file: .campaigns/<YYYY-MM-DD>-<slug>/ with templates.
# Usage: campaign-init.sh <slug> [<repo-root>]
# Prints the campaign directory. Re-running for an existing directory prints it and exits 0.
set -eu

slug=${1:?usage: campaign-init.sh <slug> [<repo-root>]}
case "$slug" in *[!a-z0-9-]*) echo "slug must be lowercase letters, digits, hyphens" >&2; exit 2;; esac

if [ $# -ge 2 ]; then
  root=$2
elif root=$(git rev-parse --show-toplevel 2>/dev/null); then
  :
else
  root=$(pwd)
fi

dir="$root/.campaigns/$(date +%F)-$slug"
if [ -d "$dir" ]; then
  echo "$dir"
  echo "exists: resuming, nothing written" >&2
  exit 0
fi

mkdir -p "$dir/briefs" "$dir/threads"

# Keep the Campaign file out of git without touching tracked files.
if common=$(git -C "$root" rev-parse --git-common-dir 2>/dev/null); then
  case "$common" in /*) ;; *) common="$root/$common";; esac
  exclude="$common/info/exclude"
  mkdir -p "$(dirname "$exclude")"
  grep -qx '.campaigns/' "$exclude" 2>/dev/null || printf '.campaigns/\n' >> "$exclude"
fi

today=$(date '+%Y-%m-%d %H:%M')

cat > "$dir/campaign.md" <<MD
# Campaign: $slug

- Started: $today
- Chief session: <this session's name> · skill: <campaign | campaign-native>
- Repo: $root

## Objective

<what done looks like, in the user's words>

## Acceptance

- [ ] <criterion>

## ROE (what the Chief may do without asking)

- <e.g. land a Thread's work after all repo gates pass>
- Always ask: release, upload, force-push, history rewrite, deleting non-Campaign data, posting to people, archiving or deleting sessions.

## Model lineup

| Role | Model | Effort |
|---|---|---|
| Chief | Opus 5.5 | high |
| Coding Thread | opus | medium |
| Hard bug / architecture | opus | high |
| QA / gates | sonnet | medium |
| Mechanical | haiku | low |

## State

<Keep current at every milestone: phase (Kickoff/Grill/Recon/Run/Landing/Debrief), what is in flight, what is next.>
MD

cat > "$dir/board.md" <<'MD'
# Board

| Thread | Status | Model/effort | Checkout · branch | PR | Updated | Note |
|---|---|---|---|---|---|---|
MD

cat > "$dir/resume.md" <<'MD'
# Resume card — rewrite (do not append) before every heavy step and at the end of every turn

## Now
- <what is happening this minute; any running command with its task id / log path and how to check its result>

## Next (in order)
1. <next action, concrete enough for a fresh session>

## In flight
- Threads: <name · kind (bg | native) · id: state>
- Background jobs and watches: <what, PID, log path, how to check it; a task id only notifies the session that started it, so a new Chief needs the PID and log>

## Waiting on user
- <decision / acceptance>

## Constraints
- <ROE highlights, user preferences that must not be forgotten>
- Timestamps come from `date`, never from memory.
MD

printf '# Decisions\n\n' > "$dir/decisions.md"
printf '# Asks\n\n' > "$dir/asks.md"

echo "$dir"
