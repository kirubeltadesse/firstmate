#!/usr/bin/env bash
# fm-graphify-refresh.sh - Standardized Graphify build/update helper.
# Usage: fm-graphify-refresh.sh <project-dir> [--full] [--scope <path>]
#   --full    Build/refresh the entire knowledge graph (nightly/weekly cadence)
#   --scope   Build/refresh only a specific subpath (on-demand, scoped cadence)
#   If no flag is provided, defaults to --full.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_DIR=${1:-}
[ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ] || { echo "error: valid project directory required" >&2; exit 1; }

GRAPHIFY_BIN=$(command -v graphify || echo "$HOME/.local/bin/graphify")
if [ ! -x "$GRAPHIFY_BIN" ]; then
  echo "error: graphify CLI not found" >&2
  exit 1
fi

MODE="full"
SCOPE=""
shift
while [ $# -gt 0 ]; do
  case "$1" in
    --full) MODE="full" ;;
    --scope) MODE="scope"; SCOPE=${2:-}; shift ;;
    *) echo "error: unknown flag $1" >&2; exit 1 ;;
  esac
  shift
done

cd "$PROJECT_DIR"
if [ "$MODE" = "scope" ]; then
  [ -n "$SCOPE" ] || { echo "error: --scope requires a path argument" >&2; exit 1; }
  echo "Refreshing scoped knowledge graph for $PROJECT_DIR/$SCOPE..."
  "$GRAPHIFY_BIN" update "$SCOPE"
else
  echo "Refreshing full knowledge graph for $PROJECT_DIR..."
  "$GRAPHIFY_BIN" update "$PROJECT_DIR" --force
fi
