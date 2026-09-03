#!/usr/bin/env bash
# fm-graphify-launchd.sh - Set up launchd plists for nightly Graphify builds.
# Generates and loads a per-project plist into ~/Library/LaunchAgents.
# Usage: fm-graphify-launchd.sh <project-dir> [project-dir...]
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
REFRESH_SCRIPT="$FM_ROOT/bin/fm-graphify-refresh.sh"

[ $# -ge 1 ] || { echo "usage: $0 <project-dir> [project-dir...]" >&2; exit 1; }

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS_DIR"

for PROJECT_DIR in "$@"; do
  [ -d "$PROJECT_DIR" ] || { echo "error: $PROJECT_DIR is not a valid directory" >&2; exit 1; }
  PROJECT_NAME=$(basename "$PROJECT_DIR")
  LABEL="com.firstmate.graphify.$PROJECT_NAME"
  PLIST_PATH="$LAUNCH_AGENTS_DIR/$LABEL.plist"
  LOG_PATH="$HOME/Library/Logs/firstmate-graphify-$PROJECT_NAME.log"

  cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$REFRESH_SCRIPT</string>
    <string>$PROJECT_DIR</string>
    <string>--full</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>2</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>$LOG_PATH</string>
  <key>StandardErrorPath</key>
  <string>$LOG_PATH</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
EOF

  echo "generated: $PLIST_PATH"
  launchctl load "$PLIST_PATH" || echo "warning: could not load $PLIST_PATH (may already be loaded)"
done
