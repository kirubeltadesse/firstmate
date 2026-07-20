# Supervision protocol

The watcher is the backbone.
Whenever at least one task is in flight, keep `bin/fm-watch.sh` running through a harness-tracked `bin/fm-watch-arm.sh` background task.
It costs zero tokens while running.
**Always-on wake triage (absorb only when provably working).**
The watcher classifies every wake it detects in bash and absorbs the benign majority without ever waking you, but it never absorbs a crewmate that has stopped.
The no-verb signal path - a `signal` whose status carries no captain-relevant verb (a `working:` note, a bare turn-ended) - is absorbed ONLY while that crewmate shows positive evidence it is still working: its no-mistakes run for its branch is in an actively-running step, or its pane shows the harness busy signature.
For a fresh `stale` pane, the watcher checks the same positive evidence before trusting the status log: a provably-working crew is absorbed, and a crew that is NOT provably working surfaces whether the log looks terminal or non-terminal.
The watcher reads that evidence with `bin/fm-crew-state.sh` (run-step first, then pane), so a finish that wrote no `done:` status - for example one reported only through interactive pane menus - is no longer swallowed.
A `heartbeat` with no captain-relevant change is likewise absorbed.
Absorbed wakes are advanced past their suppression marker and logged to `state/.watch-triage.log` while the watcher keeps blocking - no queue entry, no exit, no LLM turn.
It exits with one reason line on an *actionable* wake: a `signal` carrying a captain-relevant verb (`needs-decision:`/`blocked:`/`failed:`/`done:`/`PR ready`/`checks green`/`ready in branch`/`merged`); a no-verb `signal` whose crewmate is NOT provably working (it stopped its turn with no running pipeline and no busy pane, so it may be done, waiting on a decision, or wedged); any `check`; a `stale` whose crewmate is not provably working, whether or not its status log's last line is captain-relevant (surfaced at once, never left to wait out the timer); a provably-working `stale` that stays idle past the wedge threshold (`FM_STALE_ESCALATE_SECS`, default 240s); or the heartbeat fleet-scan's fail-safe backstop catching a captain-relevant status the per-wake path missed.
A captain-relevant status-log line does not by itself make a stale pane terminal: a crewmate gets no new status entry once firstmate hands it to a no-mistakes validation, so its last line can still read `done:` from BEFORE that validation started for the run's entire duration; a provably-working crew therefore always wins over that stale line and is absorbed (with the same wedge-escalation safety net), and only a crewmate that is NOT provably working has its status log trusted to decide terminal-vs-non-terminal.
Only an actionable wake is written to the durable queue at `state/.wake-queue` - before advancing suppression markers such as `.seen-*`, `.stale-*`, `.last-check`, or `.last-heartbeat` - and only an actionable wake ends the background task, so you re-arm exactly once per actionable event instead of once per wake.
That is what eliminates the quiet-stretch churn without swallowing a finish: during a long crew validation the run is actively running, so the crewmate's `turn-ended`/`working:`/stale wakes (and no-change heartbeats) are absorbed in bash, the liveness beacon (`state/.last-watcher-beat`) stays fresh the whole time so `fm-guard.sh` never false-alarms, and your LLM is woken only when something genuinely needs you - including the moment that crewmate stops with no running pipeline, which now surfaces immediately.
The classifier lives in `bin/fm-classify-lib.sh` and is shared: the captain-relevant verb set and status-scan primitives back both this always-on watcher and the away-mode daemon, so the overlapping policy cannot drift; the provably-working predicate (`crew_is_provably_working`, reusing `bin/fm-crew-state.sh`) lives in that same library and runs only on the watcher's no-verb signal and first-sighting stale paths, never on every wake, so the per-wake triage stays cheap.
While `state/.afk` exists the daemon owns supervision, so the watcher reverts to one-shot - it surfaces every wake for the daemon to classify (skipping the provably-working read entirely) - and never double-triages; the daemon keeps its own bounded-latency stale backstop for a crewmate that stops in away mode.
At the start of every wake-handling turn, run `bin/fm-wake-drain.sh` before peeking panes, reading status files beyond the reason line, or starting new work.
Session-start recovery is the exception: `bin/fm-session-start.sh` already drained the queue when locked, or deliberately skipped the drain when read-only because another session owns it.
The printed reason line is still useful, but the drained queue is the lossless backlog.
**Keep exactly one live cycle.**
The arm chain IS the supervision: while any task is in flight, keep exactly one live `bin/fm-watch-arm.sh` background task at all times, because if no cycle is live firstmate is blind.
Each cycle is one harness-tracked background task that blocks until an actionable wake is due (benign wakes are absorbed in bash without ending the task), fires with one reason line, and ends, so the chain survives only when firstmate starts the next cycle after each fire.
After handling the drained wakes, re-arm before you end the turn by running `bin/fm-watch-arm.sh` as its own background task.
Arm or re-arm the watcher only through the harness's own tracked background mechanism - the one that survives the call and notifies you when the process exits - so the cycle actually persists and the next wake reaches you.
Never fire-and-forget the watcher with a shell `&` inside another call: that backgrounded child is reaped when the call returns, so supervision silently stops, and worse, the dying process reports a false "already running" that hides the gap.
**Standalone, never bundled.**
Run `bin/fm-watch-arm.sh` as its OWN background task with nothing else in that bash, never tacked onto the tail of a multi-command call: bundled, its self-verifying status line is buried in unrelated output and it can silently no-op as a side effect of those other commands, so no fresh cycle gets established and supervision lapses unnoticed.
`bin/fm-watch-arm.sh` is self-verifying: it confirms a genuinely live watcher with a fresh beacon and prints exactly one honest status line - `watcher: started ...`, `watcher: healthy ...`, or `watcher: FAILED - no live watcher with a fresh beacon` (which exits non-zero) - so treat that line, not a process count or an unverified "already running", as the source of truth for watcher state.
**Re-arm after each FIRE; do not churn on a no-op.**
Read that line to know whether a cycle is already live: `started` (this arm just launched the live cycle, now blocking for the next wake) and `healthy` (a live cycle already held the lock) both mean a cycle is live, so do NOT start another - re-running it while one is healthy only churns no-op tasks and never establishes a fresh cycle; `FAILED` means no live cycle, so arm one now after draining any queued wakes.
A cycle is down only when its background task completes carrying a WAKE REASON (`signal`/`stale`/`check`/`heartbeat`): that is the watcher firing, and that is the one moment to handle the wake and then start exactly one fresh cycle.
The watcher is singleton-safe: acquisition is race-proof, so under any number of concurrent arms at most one watcher ever holds this home's lock, and a duplicate that somehow starts self-evicts within one poll once it sees the lock no longer names it.
If one is already alive with a fresh liveness beacon, another invocation exits cleanly instead of creating a duplicate watcher; if the live holder's beacon is stale, the new invocation exits with an actionable failure.
**No turn ends blind, holds included.**
Never end a turn while any task is in flight without a live cycle running: a text-only "holding" or "waiting" reply with crewmates live and no live cycle is a bug, and because such a turn runs no supervision script it is exactly the blind gap the script-only guard (`fm-guard.sh`, below) cannot catch, so this discipline must.
If a forced restart is ever genuinely needed, use `bin/fm-watch-arm.sh --restart`, which stops only this home's watcher (the pid recorded in this home's `state/.watch.lock`) and starts a fresh one.
Never `pkill -f bin/fm-watch.sh`: that pattern matches every firstmate home's watcher, including secondmate homes that run the same script, so a broad pkill from one home kills sibling homes' watchers.
Away-mode supervision is provided by the `/afk` skill and its daemon; while `state/.afk` exists, the daemon owns the watcher.
Waiting on the watcher is intentionally silent.
After arming it, do not send idle progress updates to the captain; wait until it returns `signal`, `stale`, `check`, or `heartbeat`, unless the captain asks for status.
Empty polls, elapsed waiting time, and "still no change" are tool bookkeeping, not conversational progress.

```sh
bin/fm-watch-arm.sh        # safe verified re-arm; run as harness-tracked background; no-ops if healthy
bin/fm-watch-arm.sh --restart  # home-scoped forced restart; never a broad pkill
bin/fm-watch.sh            # the watcher itself; exits with: signal|stale|check|heartbeat
bin/fm-wake-drain.sh       # drain queued wake records at turn start; asserts guard after draining
bin/fm-crew-state.sh <id>  # one-line current-state read; reconciles matching run-step, pane, and status log
```

On wake, in order of cheapness:

1. Read the reason line and drain queued wake records with `bin/fm-wake-drain.sh`.
2. `signal:` read the listed status files first; a wake lists every signal that landed within the coalescing grace window (e.g. a status write plus the same turn's turn-end marker), and each is ~30 tokens and usually sufficient.
   A status line is the wake *event*, not the crewmate's current state; when you need the live state - especially to confirm a `needs-decision`/`blocked` is still real and not already resolved-and-resumed - read it with `bin/fm-crew-state.sh <id>`, which reconciles the authoritative run-step over the possibly-stale log line, and never `tail` the status log as the current-state source.
3. `stale:` the crewmate stopped without reporting; peek the pane (`bin/fm-peek.sh <window>`) to diagnose.
   If the pane is waiting, looping, confused, or unresponsive, load `stuck-crewmate-recovery`.
4. `check:` a per-task poll fired (usually a merge, or X mode when enabled); act on it.
5. `heartbeat:` a heartbeat wake now reaches you only when the watcher's bash fleet-scan caught a captain-relevant status the per-wake path missed (no-change heartbeats are absorbed in bash, never surfaced), so treat it as "something turned up" and review the whole fleet: read each crewmate's current state with `bin/fm-crew-state.sh <id>` (the cheap first read - it reconciles the authoritative run-step over a possibly-stale status-log line, so a crewmate whose gate you already resolved no longer reads as still parked), peek panes that look off, check PR-ready tasks for merge, reconcile data/backlog.md, then re-arm the watcher.
   Do not report that the fleet is unchanged.

When a task reaches a terminal state on any of these wakes (a `done`/merge `check:`, a `failed` signal, a scout report, a local-only merge), and X mode is enabled, load `fmx-respond` (section 13) and post the X-mention's **final** completion follow-up if that task is X-linked: `bin/fm-x-followup.sh --check <id>` then `bin/fm-x-followup.sh <id> --final --text-file <path>`, so the link always clears here regardless of how many of the up-to-three follow-ups were already spent on earlier milestones.

Heartbeats back off exponentially while they are the only wakes firing (600s doubling to a 2h cap - an idle fleet stops burning turns); any signal, stale, or check wake resets the cadence to the base interval.
Due per-task checks run before signal scanning so chatty crewmate status updates cannot starve slow polls like merge detection.

Never rely on hooks or status files alone; when a heartbeat wake does reach you, the review of every window is mandatory and unconditional.
Each task's backend live-task inventory is the ground truth (tmux when `backend=` is absent; a task's meta may record a different `backend=` - herdr, zellij, orca, and cmux are the other implemented, spawn-capable, experimental backends today, docs/herdr-backend.md, docs/zellij-backend.md, docs/orca-backend.md, and docs/cmux-backend.md).
For `kind=secondmate`, an idle pane is healthy.
A secondmate may be sitting on its own watcher with no visible pane changes, so parent supervision uses status writes plus heartbeat review, not pane-staleness.
`fm-watch.sh` therefore skips stale-pane wakes for windows whose meta records `kind=secondmate`.
This exception is narrow: ordinary crewmates still trip stale detection when their pane stops changing without a busy signature.

**Watcher liveness is guarded, not just disciplined.**
Arming the watcher is the last action of every wake-handling turn - but the protocol no longer relies on remembering that.
While running, `fm-watch.sh` touches `state/.last-watcher-beat` every poll cycle.
The supervision scripts (`fm-peek`, `fm-send`, `fm-spawn`, `fm-teardown`, `fm-pr-check`, `fm-promote`, `fm-review-diff`, `fm-fleet-sync`, `fm-update`) call `bin/fm-guard.sh` first, which warns to stderr when any task is in flight (`state/*.meta` exists) but queued wakes are pending, or that beacon is missing or older than `FM_GUARD_GRACE` (default 300s).
`bin/fm-wake-drain.sh` runs the same guard after it drains, so the liveness check also fires on a drain-and-handle turn that runs no other supervision script, narrowing the window in which a lapsed chain can hide; the grace beacon keeps it silent right after a normal fire and it warns only on a genuine stale-beyond-grace lapse.
The no-watcher case leads with a prominent, bordered ●-marked banner (in-flight count, beacon age, and the exact one-line re-arm command) so it reads as an alarm rather than a buried stderr line you can skim past.
So the next time you touch the fleet with queued wakes or no watcher alive, the tool output itself tells you what to do - a pull-based guard that works on any harness, since it rides the script output you already read rather than a harness-specific hook.
The grace window keeps normal handling (watcher briefly down between a wake and its re-arm) silent.
If a guard warning says queued wakes are pending, drain them before doing anything else.
If a guard warning says watcher liveness is stale, arm `bin/fm-watch-arm.sh` after draining any queued wakes.

`fm-guard.sh` carries a second, independent alarm in the same bordered ●-marked style: the **worktree-tangle** guard.
Firstmate is a treehouse-pooled git repo of itself - the primary checkout (the repo root, `FM_ROOT`) and every crewmate worktree and secondmate home are linked worktrees of one repo - and the primary must stay on its default branch.
If a crewmate sent to work firstmate-on-itself branches or commits in the primary instead of its own isolated worktree, the primary is stranded on a feature branch (the failure this guards against); the guard names the offending branch and prints the non-destructive restore (`git -C <root> checkout <default>`), so the tangle surfaces on the very next fleet action.
The check is scoped precisely to the primary: detached HEAD (the legitimate resting state of crewmate worktrees and secondmate homes on the default branch) and the default branch itself never alarm; only a named non-default branch checked out in the primary does.
The same assertion runs at session start as the bootstrap `TANGLE:` line inside the `bin/fm-session-start.sh` digest (section 3), with read-only wording when this session does not hold the fleet lock.
Two further guards prevent the tangle upstream: `fm-spawn` refuses to launch unless treehouse or Orca yields a genuine isolated worktree distinct from the primary checkout, and every ship brief's first instruction has the crewmate verify it is in its own worktree before branching (section 11).

On the `claude` harness, "no turn ends blind" has a structural backstop beyond the pull-based `fm-guard.sh` banner: `bin/fm-turnend-guard.sh`, a Claude Code Stop hook registered in the tracked `.claude/settings.json`, fires on every primary turn end and, when tasks are in flight without a live identity-matched watcher lock and fresh beacon, blocks the stop (exit 2 with a reason) so the turn cannot end without acting on it first.
It shares status fields with `fm-guard.sh` via `bin/fm-supervision-lib.sh`, uses `bin/fm-wake-lib.sh` for live watcher lock health, and never blocks more than once per turn (Claude Code's own `stop_hook_active` loop-guard field lets it always allow the retry).
It is scoped to fire only in the actual primary checkout - never in a crewmate/scout worktree or a secondmate home - and stays silent when supervision is healthy.
See `docs/turnend-guard.md` for the verified Stop-hook mechanism and the scoping details.
This backstop exists only for `claude` today; other harnesses still rely on the pull-based guard alone (future work, same empirical-verification-first pattern as every other harness fact in `harness-adapters`).
Watcher liveness is not enough if you are foreground-blocked.
Whenever one or more tasks are in flight, do not run long foreground-blocking operations in your own session.
This is about firstmate's own session: it includes a no-mistakes pipeline firstmate runs for this repo, long builds, and any other multi-minute command.
Background that work so watcher wakes can interleave with it and the supervision loop stays responsive.
A crewmate driving its own `no-mistakes` validation does the opposite: it drives that gate loop synchronously and processes every return, never idle-waiting for its own validation run to advance on its own.

Token discipline: for a crewmate's current state prefer `bin/fm-crew-state.sh <id>`, which looks for a branch-matched run-step before checking pane liveness, then falls back to the pane and log in that cheap-first order and treats the status log's last line as a wake event rather than the current state; default peeks to 40 lines; never stream a pane repeatedly through yourself; batch what you tell the captain.
The context-% shown in a peek is not actionable as crew health; ignore it and intervene only on real signals (`signal`, `stale`, `needs-decision`, `blocked`), looping or confusion in the pane, or a question the brief already answers.

## Away-mode stub

Invoke the `/afk` skill when the captain says `/afk`, says they are going afk, `state/.afk` exists, an incoming message starts with `FM_INJECT_MARK`, or any `state/.subsuper-*` marker is involved.
The skill owns the full daemon procedure: classification policy, batching, injection hardening, max-defer, verified submit, marker stripping, portable lock, dedupe, target discovery, reliability properties, and `FM_INJECT_SKIP`.
Inline facts that must survive without a loaded skill:

- Every daemon injection is prefixed with `FM_INJECT_MARK`, ASCII unit separator `0x1f`, so internal escalations are distinguishable from a captain message.
- While `state/.afk` exists, the daemon owns the watcher; do not separately arm `fm-watch-arm.sh` or `fm-watch.sh`.
- If firstmate receives a marked message while afk is active, it is an internal escalation: stay afk and process it.
- If the message starts with `/afk`, stay afk and refresh the flag.
- Any other unmarked message means the captain is back: clear `state/.afk`, stop the daemon, flush catch-up from `state/.wake-queue`, `state/.subsuper-escalations`, and `state/.subsuper-inject-wedged`, then re-arm normal watcher supervision.
- Afk never changes approval authority; PR merges, ask-user findings, destructive actions, irreversible actions, and security-sensitive choices still require the same approval they required before.
- Bias ambiguous cases toward exit because a present captain beats token savings and a false exit is self-correcting.

## Stuck-crewmate recovery

On `stale`, looping, repeated confusion, an answered-by-brief question, an unresponsive pane, or a failed steer, load `stuck-crewmate-recovery`.
That playbook escalates from peek, to one-line steer, to harness-specific interrupt, to relaunch with a progress note, to `failed` with evidence.
