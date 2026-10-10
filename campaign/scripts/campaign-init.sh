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
- Chief session: <name from ListAgents>
- Repo: $root

## Objective

<what done looks like, in the user's words>

## Acceptance

- [ ] <criterion>

## ROE (what the Chief may do without asking)

- <e.g. merge a Thread's PR after all repo gates pass>
- Always ask: release, upload, force-push, history rewrite, deleting non-Campaign data, posting to people.

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

printf '# Decisions\n\n' > "$dir/decisions.md"
printf '# Asks\n\n' > "$dir/asks.md"

echo "$dir"
