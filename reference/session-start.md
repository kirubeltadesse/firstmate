# Session start (run at every session start)

Session start is one command, not a sequence of separate reads.
Run `bin/fm-session-start.sh`.
It composes today's `fm-lock.sh`, `fm-bootstrap.sh`, and `fm-wake-drain.sh` - calling each as a real subprocess, never reimplementing their logic - then prints a full context digest and fleet-state digest, in one ordered, clearly delimited report:

1. **Lock** - acquires the per-home session lock first, before anything mutates shared state.
2. **Bootstrap** - detect-only diagnostics (tool/version problems, GitHub auth, the worktree-tangle check, harness override, dispatch-profile validation, backlog-backend status) always run and always print.
   When the lock could not be acquired, the worktree-tangle check uses read-only advisory wording without a checkout repair command.
   The three MUTATING sweeps - fleet sync, the local secondmate fast-forward sweep, and X-mode artifact writes - run only when this session actually holds the lock from step 1.
3. **Wake queue** - when locked, drains the durable wake queue and prints the records prominently as this turn's first work queue, exactly as `bin/fm-wake-drain.sh` did before; a lapsed watcher chain still surfaces here via the same guard banner.
   When the lock could not be acquired, the queue is left untouched because another session owns it, and the guard's tangle/watcher-liveness alarms still print in read-only advisory mode without drain, re-arm, or checkout repair commands.
4. **Context digest** - the full contents of `data/projects.md`, `data/secondmates.md`, `data/captain.md`, and `data/learnings.md`, each clearly delimited.
   A file that does not exist prints an explicit `ABSENT` marker, never confused with an empty-but-present file: absence is meaningful (`captain.md` absent means use this template's defaults, `projects.md` absent means rebuild it from the clones under `projects/`, etc.).
5. **Fleet-state digest** - the full `data/backlog.md`; every `state/<id>.meta`; a bounded tail of each task's `state/<id>.status` (labeled as wake-EVENT history, not current state, with the full log path printed for a deeper read); the `state/.afk` flag; and one cheap alive/dead read of each task's recorded backend endpoint.
   That liveness line is a fast presence check only, not a full state read - when you need a crew's actual current state (a run-step, not just "is the pane there"), read it with `bin/fm-crew-state.sh <id>` as before; the digest deliberately skips that deeper, slower read for every task so it stays fast and bounded.
6. **Next step** - a conditional closing reminder for the actual watcher owner: stay read-only when the lock was refused, use `/afk` when away mode is active, source `config/x-mode.env` before arming when X mode is active, or arm normally otherwise.
   The script itself never arms the watcher, because a fire-and-forget arm from inside a script that then exits would be reaped immediately, silently dropping supervision.

**Everything in this digest is read exactly once, at session start.**
Do not separately run `bin/fm-bootstrap.sh`, `bin/fm-lock.sh`, or `bin/fm-wake-drain.sh`, and do not separately read `data/projects.md`, `data/secondmates.md`, `data/captain.md`, `data/learnings.md`, `data/backlog.md`, or any `state/*.meta` afterward - they were just printed in full, and re-reading them defeats the entire point of collapsing session start into one command.
Do not bulk-read `state/*.status` afterward either: the digest printed bounded tails with full log paths for targeted follow-up when older wake-event history is actually needed.
Re-read a file only if the digest flagged it `ABSENT` (then rebuild or create it per the guidance in this section and section 6), its contents looked unparseable or corrupt, or an individual full status log is needed for older wake-event history.
Those three composed scripts also keep working standalone, unchanged, for the flows that call them directly: `bin/fm-bootstrap.sh install <tools>` after consent, `/updatefirstmate`, the afk daemon, and existing tests.

If the digest's lock step could not acquire the lock, it prints a loud, bordered read-only banner instead of silently continuing: another live session already holds the fleet, every mutating step was skipped, and the rest of the digest is the read-only-safe subset described above.
Tell the captain another active session is already managing the work and operate read-only until resolved - do not spawn, steer, merge, or otherwise mutate fleet state from this session.

Bootstrap is detect, then consent, then install.
Never install anything the captain has not approved in this session.
The mutating sweeps that run only when locked: fleet sync via `bin/fm-fleet-sync.sh`, best-effort and non-fatal, under the hard-rule exception in section 1 (set `FM_FLEET_PRUNE=0` to temporarily disable that branch pruning); and a sweep of every live secondmate home, fast-forwarding each one's worktree to firstmate's own current default-branch commit so the fleet stays converged on whatever version firstmate is on.
The live set comes from `state/<id>.meta` records with `kind=secondmate`; `data/secondmates.md` only backfills `home=` for older or incomplete meta records.
This is a purely local fast-forward (every secondmate home is a worktree of this same repo, sharing one object store), never a fetch from origin and never a surprise pull: the version followed is simply whatever the primary is currently on, which only the captain changes deliberately via `git pull` or `/updatefirstmate`.
A tracked-files fast-forward never touches the gitignored operational dirs, so a secondmate's backlog, projects, and in-flight work are never disturbed; a dirty, diverged, or in-flight home is skipped untouched.
The same sweep also propagates the primary's declared inheritable config (`config/crew-dispatch.json`, `config/crew-harness`, and `config/backlog-backend`; sections 4 and 10) into each live secondmate home's `config/`, so every secondmate's own crewmates, dispatch profiles, and backlog backend stay on the primary's settings.
Because `config/` is gitignored this is a separate, primary-authoritative copy independent of the tracked-files fast-forward: it re-converges every live home whether or not its tracked files advanced, and it touches only the declared inheritable items (never `config/secondmate-harness`).
For a mid-session inheritable-config change that should reach live secondmates without a full session start, run `bin/fm-config-push.sh`.
It is config-only: it uses the same live secondmate discovery and the same `propagate_inheritable_config` helper as bootstrap, prints a per-home/per-item summary, does not fast-forward tracked files, and does not nudge secondmates.
The propagation helper itself keeps stdout silent for existing callers, but warns on stderr when an item is skipped because the destination does not allow it or when a copy/remove error occurs.
The sweep reports the `NUDGE_SECONDMATES:` line below only when a running secondmate actually advanced with an instruction-surface change (`AGENTS.md`, `bin/`, or `.agents/skills/`), so firstmate knows which ones to live-converge.
Silence in the bootstrap section of the digest means all good: say nothing and move on.
Otherwise it prints one line per problem or capability fact; handle each:

- `MISSING: <tool> (install: <command>)` - list the missing tools to the captain with a one-line purpose each plus the printed install commands, wait for consent (one approval may cover the list), then run `bin/fm-bootstrap.sh install <approved tools...>`.
  For `treehouse`, this also covers an installed version whose `treehouse get` lacks `--lease`; treat it as an upgrade request.
  For `no-mistakes`, this also covers an installed version older than 1.31.2, because crewmate validation briefs delegate gate mechanics to no-mistakes' version-matched guidance.
  For `tasks-axi`, this appears only when `config/backlog-backend` is absent or set to `tasks-axi`; hand-edit fallback continues until the captain approves installation.
- `NEEDS_GH_AUTH` - ask the captain to run `! gh auth login` (interactive; you cannot run it for them).
- `TANGLE: <remediation>` - the primary checkout is stranded on a feature branch instead of its default branch; section 8 explains why this guard exists and what it protects.
  The work is safe on that branch ref; restore the primary to its default branch with the printed `git -C <root> checkout <default>`, then re-validate that branch in a proper worktree.
  This is the only sanctioned firstmate-initiated git write to the primary, and it is a non-destructive branch switch that strands nothing.
- `CREW_HARNESS_OVERRIDE: <name>` - record and use the override silently; surface a harness fact only if it actually blocks work or the captain asks.
- `CREW_DISPATCH: invalid config/crew-dispatch.json - <reason>` - the optional dispatch profile file exists but failed low-cost bootstrap validation; continue with the normal fallback chain, resolve and pass the chosen fallback harness explicitly while the file remains present, fix the JSON, unverified harness name, or invalid harness/effort pair when convenient, and do not select a bad profile.
- `CREW_DISPATCH: active config/crew-dispatch.json` - bootstrap validated the optional dispatch profile file and printed its active rules as `rule: <when> -> <harness[/model[/effort]]>` lines, plus `default:` when present.
  Keep this block top-of-mind during intake; it is the reminder that every crewmate or scout dispatch must consult the rules before spawning.
- `FLEET_SYNC: <repo>: skipped: <reason>` - a benign one-off skip (offline, no origin, local-only); bootstrap continued, investigate only if it blocks work.
- `FLEET_SYNC: <repo>: recovered: <detail>` - the clone had drifted onto a clean detached HEAD holding no unique commits and the sync self-healed it (re-attached the default branch and fast-forwarded); no action needed, it is reported only so the self-heal is visible.
- `FLEET_SYNC: <repo>: STUCK: on <state>, N commits behind <base> - needs attention` - the clone is dirty, on a non-default branch, detached with unique commits, or diverged, so the sync left it untouched (never forcing or discarding); it will keep falling behind until you look. A loud STUCK, especially a growing N across bootstraps, means that clone needs hands-on attention; dispatch a crewmate or resolve it before it strands work.
- `SECONDMATE_SYNC: secondmate <id>: skipped: <reason>` - the local-HEAD secondmate sync left a live secondmate home on its existing checkout because the home was dirty, diverged, unsafe, on the wrong branch, missing the primary target commit, or otherwise not fast-forwardable; bootstrap continued, but inspect the reason because the secondmate may be stale after a primary update.
- `TASKS_AXI: available` - a default-backend capability fact, not a problem; record it silently and use section 10 for backlog mutations.
  It prints only when `config/backlog-backend` is absent or set to `tasks-axi` and the compatibility probe accepts `tasks-axi --version` as 0.1.1 or newer.
  If the backend is not opted out and `tasks-axi` is missing or incompatible, bootstrap reports `MISSING: tasks-axi (install: npm install -g tasks-axi)` but still falls back to hand-editing and never blocks work.
  If `config/backlog-backend=manual`, bootstrap hand-edits and does not suggest installing `tasks-axi`.
- `NUDGE_SECONDMATES: <window-targets...>` - the secondmate sweep fast-forwarded one or more *running* secondmate homes to firstmate's current version and their instruction surface (`AGENTS.md`, `bin/`, or `.agents/skills/`) actually changed; for each listed window, send a one-line re-read nudge with `bin/fm-send.sh <window-target> 'firstmate was updated to the latest - please re-read your AGENTS.md to pick up the new instructions.'` so that secondmate picks up its new instructions.
  This mirrors `/updatefirstmate`'s `nudge-secondmates:` report: it is a gentle steer, never an interruption, and the fast-forward already landed safely.
  A secondmate that was skipped, already current, or whose advance changed no instructions is not listed and must not be disturbed.
- `FMX: X mode on ...` / `FMX: X mode off ...` - bootstrap confirmed or removed the local X-mode poll artifacts; follow section 14 for watcher cadence restart only when a running watcher needs the transition applied immediately.

Bootstrap's fleet refresh is bounded by `FM_FLEET_SYNC_BOOTSTRAP_TIMEOUT` seconds, default 20; a timeout is reported as a `FLEET_SYNC` skip and does not block startup.

The digest's context section already contains `data/projects.md`, the fleet registry of what each project is; `data/secondmates.md`, the registered secondmate routing table used to route work by scope (section 7); `data/captain.md`, this captain's curated preferences and working style; and `data/learnings.md`, fleet-local operational facts and gotchas this home has captured.
Treat any harness memory of captain preferences as a recall cache only; `data/captain.md` is the canonical, harness-portable home.
If the digest reported `data/projects.md` as `ABSENT` or disagreeing with what is actually under `projects/`, rebuild it from the clones (a README skim per project is enough) before taking on work.
An `ABSENT` `data/captain.md` or `data/secondmates.md` or `data/learnings.md` means exactly what section 2 says it means (template defaults, no registered secondmates, nothing captured yet) - not a problem to fix.

Do not dispatch any work until the tools that work needs are present and GitHub auth is good.
Use `gh-axi` for all GitHub operations, `chrome-devtools-axi` for all browser operations, and `lavish-axi` when a decision or report is complex enough to deserve a rich review surface.
Do not memorize their flags; their session hooks and `--help` are the source of truth.
If the captain names a different static crewmate harness at bootstrap or later, write it to `config/crew-harness` (local, gitignored).
If the captain expresses a standing dispatch preference such as "use grok for news-dependent work", codify it in `config/crew-dispatch.json` instead.
