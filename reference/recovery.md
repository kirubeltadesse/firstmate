# Recovery (run at every session start, after the session-start digest)

You may have been restarted mid-flight.
Reconcile reality with your records before doing anything else, working from the `bin/fm-session-start.sh` digest section 3 already produced - its lock step, wake-queue drain, and fleet-state digest ARE recovery's data-gathering; do not re-run it or bulk-read its inputs here:

1. The digest's lock section already tells you whether this session acquired the lock or is operating read-only; act on that exactly as section 3 describes.
2. The digest's wake-queue section already printed the drained records; keep them as the first work queue for this recovery turn.
3. The digest's fleet-state section already printed `data/backlog.md`, `data/secondmates.md` (from the context section), every `state/*.meta`, and a bounded tail of every `state/*.status`.
   Treat those status tails as wake-event history; when you need a live current-state read for a recorded direct report, use `bin/fm-crew-state.sh <id>` instead of inferring from the last status line.
   If older wake-event history matters, read the individual full status log named in the digest instead of bulk-reading every status file.
4. Use the `window=` values from the digest's `state/*.meta` entries as the live direct-report set, and read the digest's per-task `endpoint: alive|dead` line for each - that cheap check is already done; do not re-probe it yourself.
   Do not sweep every `fm-*` tmux window, herdr tab, zellij tab, Orca terminal, or cmux workspace across all sessions during recovery; another firstmate home's child endpoints may share that namespace and are not this home's orphans.
5. If the digest reports a recorded direct-report's endpoint as `dead` (or a meta has no `window=`), reconcile it through its meta as described below.
6. For meta with no window, or an endpoint the digest reported dead, reconcile by kind.
   For ordinary crewmates, check the recorded backend metadata first; use `treehouse status` for treehouse-backed tasks, and the recorded `orca_worktree_id=`/`terminal=` for Orca tasks.
   For `kind=secondmate`, load `secondmate-provisioning`, treat it as a dead persistent direct report, and respawn it from recorded meta or the registry entry.
7. Do not reconstruct a secondmate's whole tree from the main home.
   The main firstmate reconciles only direct reports.
   Each secondmate is a firstmate in its own home, so it reconciles only work that is already its own and then idles; it never creates new work during recovery.
8. The digest already reports whether `state/.afk` is present.
   If it is, load `/afk`, ensure the daemon is running, do not separately arm the watcher because the daemon owns it, and resume away-mode supervision.
9. Surface only what needs the captain: pending decisions, PRs ready to merge, failures, or needed credentials.
   If there is nothing that needs them, say nothing and resume.
10. Having already handled the drained wakes from the digest, follow the section 8 watcher checklist through the digest's own closing reminder; if the lock was refused or `state/.afk` exists, follow the digest's no-direct-arm guidance.

A firstmate restart must be a non-event.
All truth lives in each task's backend live-task inventory (tmux by hard default, herdr or cmux when explicitly selected or auto-detected, and zellij/orca when explicitly selected), state files, data/backlog.md, data/captain.md, data/learnings.md, data/secondmates.md, persistent secondmate homes, treehouse, and Orca's recorded worktree/terminal ids; your conversation memory is a cache.
