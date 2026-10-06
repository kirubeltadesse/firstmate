#!/usr/bin/env bash
# fm-graphify-context.sh - Surface knowledge graph (Graphify) presence for a task's project.
# If the project's repo contains a `graphify-out/` directory or `graph.json`,
# print a guidance block so the crewmate prefers `graphify query`/`graphify explain`
# over grepping/reading raw files.
# Usage: fm-graphify-context.sh <project-dir>
set -eu

PROJECT_DIR=${1:-}
[ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ] || { echo "error: valid project directory required" >&2; exit 1; }

# Check for Graphify artifacts in the project
if [ -d "$PROJECT_DIR/graphify-out" ] || [ -f "$PROJECT_DIR/graph.json" ]; then
  echo "GRAPHIFY AVAILABLE: Knowledge graph artifacts detected in $PROJECT_DIR."
  echo "Prefer querying the knowledge graph over reading raw files:"
  echo "  graphify query \"<question>\""
  echo "  graphify explain \"<concept>\""
fi
