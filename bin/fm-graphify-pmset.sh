#!/usr/bin/env bash
# fm-graphify-pmset.sh - Schedule a daily Mac wake at 01:55 AM so the
# user-level Graphify launchd jobs (scheduled for 02:00 AM) can run reliably
# even if the computer is asleep. Requires sudo for pmset.
# Usage: fm-graphify-pmset.sh
set -eu

WAKE_HOUR=1
WAKE_MINUTE=55

echo "Registering daily wake schedule at $(printf '%02d:%02d' "$WAKE_HOUR" "$WAKE_MINUTE")..."
sudo pmset repeat wakeorpoweron MTWRFSU "$(printf '%02d:%02d:00' "$WAKE_HOUR" "$WAKE_MINUTE")" || {
  echo "error: failed to register pmset wake schedule" >&2
  exit 1
}
echo "Daily wake schedule registered successfully."
echo "Mac will wake at $(printf '%02d:%02d' "$WAKE_HOUR" "$WAKE_MINUTE") daily to run Graphify builds."
