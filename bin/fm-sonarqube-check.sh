#!/usr/bin/env bash
# fm-sonarqube-check.sh - Check SonarQube quality gate and issues for a task's project
# and save feedback to state/<task-id>.sonarqube.md for agent ingestion.
# Usage: fm-sonarqube-check.sh <task-id>
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
PROJ=$(grep '^project=' "$META" | cut -d= -f2-)
TARGET_DIR="${WT:-${PROJ:-}}"
[ -n "$TARGET_DIR" ] && [ -d "$TARGET_DIR" ] || { echo "error: valid target directory required for task $ID" >&2; exit 1; }

REPORT="$STATE/$ID.sonarqube.md"
echo "# SonarQube Quality & Issue Feedback for $ID" > "$REPORT"
echo "" >> "$REPORT"

# Search for projectKey in common config locations
PROJECT_KEY=""
if [ -f "$TARGET_DIR/.sonarlint/connectedMode.json" ]; then
  PROJECT_KEY=$(grep -o '"projectKey"[[:space:]]*:[[:space:]]*"[^"]*"' "$TARGET_DIR/.sonarlint/connectedMode.json" | head -1 | cut -d'"' -f4)
elif [ -f "$TARGET_DIR/package.json" ]; then
  PROJECT_KEY=$(grep -o '"sonarKey"[[:space:]]*:[[:space:]]*"[^"]*"' "$TARGET_DIR/package.json" | head -1 | cut -d'"' -f4 || true)
elif [ -f "$TARGET_DIR/sonar-project.properties" ]; then
  PROJECT_KEY=$(grep '^sonar.projectKey' "$TARGET_DIR/sonar-project.properties" | cut -d= -f2 | tr -d '[:space:]' || true)
fi

if [ -n "$PROJECT_KEY" ]; then
  echo "Detected Project Key: $PROJECT_KEY" >> "$REPORT"
else
  echo "Project Key not auto-detected from connectedMode.json, package.json, or sonar-project.properties." >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "Note: Use SonarQube MCP tools (sonarqube_get_project_quality_gate_status, sonarqube_search_sonar_issues_in_projects) with project key '$PROJECT_KEY' for complete server-side gate status and issue details." >> "$REPORT"
