#!/usr/bin/env bash
# fm-coderabbit-background.sh - Run local CodeRabbit review against a task diff in the background
# and save findings to state/<task-id>.coderabbit.md for agent ingestion.
# Usage: fm-coderabbit-background.sh <task-id>
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"

ID=${1:-}
[ -n "$ID" ] || { echo "error: task ID required" >&2; exit 1; }

META="$STATE/$ID.meta"
[ -f "$META" ] || { echo "error: no meta for task $ID at $META" >&2; exit 1; }

WT=$(grep '^worktree=' "$META" | cut -d= -f2-)
[ -n "$WT" ] && [ -d "$WT" ] || { echo "error: valid worktree required for task $ID" >&2; exit 1; }

CODERABBIT_BIN=$(command -v coderabbit || echo "$HOME/.local/bin/coderabbit")
if [ ! -x "$CODERABBIT_BIN" ]; then
  echo "error: coderabbit CLI not found" >&2
  exit 1
fi

REPORT="$STATE/$ID.coderabbit.md"
echo "Running local CodeRabbit review for task $ID..." > "$REPORT"

# Determine base branch or commit
DEFAULT_BRANCH=$(git -C "$WT" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo "main")
DEFAULT_BRANCH=${DEFAULT_BRANCH#origin/}

# Run coderabbit review scoped to diff vs default branch
if (cd "$WT" && "$CODERABBIT_BIN" review --agent --base "$DEFAULT_BRANCH") > "$REPORT" 2>&1; then
  echo "CodeRabbit review completed successfully." >> "$REPORT"
else
  echo "warning: CodeRabbit review encountered an error or rate limit (429)." >> "$REPORT"
fi
