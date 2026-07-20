# Section 3. Session start (run once at every session start)

Run `bin/fm-session-start.sh` exactly once at session start.
Its header is the single owner of composed commands, ordering, and digest contents.
`bin/fm-supervision-instructions.sh` renders the emitted supervision block from `docs/supervision-protocols/`.
Do not reimplement it by separately running its lock, bootstrap, or initial wake-drain components.
Tracked native session-open adapters only nudge this command; `docs/sessionstart-nudge.md` owns their enforcement mechanics and verification evidence.

Read the complete digest once and trust it as this turn's startup and recovery input.
Do not separately re-read the context, backlog, metadata, or bulk status inputs it just printed unless a source was reported absent or corrupt, older history is specifically needed, or a targeted workflow must inspect before writing.
An `ABSENT` captain, shared-captain, secondmate, or learnings file means the firstmate repo's built-in defaults, no shared captain preferences, no registered secondmates, or no captured learnings; rebuild an absent or stale project registry from the clones before dispatch.

If the session lock is refused, tell the captain another active session is managing the fleet and remain read-only.
A lock-refused session must not spawn, steer, merge, drain the wake queue, repair supervision, repair a checkout, or perform any other fleet mutation.

1. **Lock** - acquires the per-home session lock first, before anything mutates shared state.
2. **Bootstrap** - detect-only checks (tool/version problems, GitHub auth, the worktree-tangle check, harness override, dispatch-profile validation, backlog-backend status) always run, but routine confirmations stay silent by default.
   When the lock could not be acquired, the worktree-tangle check uses read-only advisory wording without a checkout repair command.
   The five MUTATING sweeps - non-executing legacy PR-check migration, fleet sync, the local secondmate fast-forward sweep, the secondmate liveness sweep, and X-mode artifact writes - run only when this session actually holds the lock from step 1.
   The secondmate liveness sweep deterministically guarantees every registered secondmate is actually running: it probes each live secondmate's endpoint for a real agent process (not just pane presence), respawns only on a confident dead reading, and reports only skipped or failed guarantees as `SECONDMATE_LIVENESS:` lines (`bin/fm-bootstrap.sh`; `bin/fm-backend.sh`'s `fm_backend_agent_alive`).
3. **Wake queue** - when locked, drains the durable wake queue and prints the records prominently as this turn's first work queue, exactly as `bin/fm-wake-drain.sh` did before; a lapsed watcher chain still surfaces here via the same guard alarm.
   When the lock could not be acquired, the queue is left untouched because another session owns it, and the guard's tangle/watcher-liveness alarms still print in read-only advisory mode without drain, supervision repair, or checkout repair commands.
4. **Context digest** - the full contents of `data/projects.md`, `data/secondmates.md`, `data/captain.md`, `data/captain-shared.md`, and `data/learnings.md`, each clearly delimited.
   A file that does not exist prints an explicit `ABSENT` marker, never confused with an empty-but-present file: absence is meaningful (`captain.md` absent means use the firstmate repo's built-in defaults, `projects.md` absent means rebuild it from the clones under `projects/`, etc.).
5. **Fleet-state digest** - the compact backlog listing owned by `bin/fm-session-start.sh`; every `state/<id>.meta`; a bounded tail of each task's `state/<id>.status` (labeled as wake-EVENT history, not current state, with the full log path printed for a deeper read); the `state/.afk` flag; and one cheap alive/dead read of each task's recorded backend endpoint.
   That liveness line is a fast presence check only, not a full state read - when you need a crew's actual current state (a run-step, not just "is the pane there"), read it with `bin/fm-crew-state.sh <id>` as before; the digest deliberately skips that deeper, slower read for every task so it stays fast and bounded.
6. **Supervision operating instructions and next step** - after the wake queue and before context, the digest emits exactly one operating block for the detected primary harness.
   The closing reminder points back to that emitted block and preserves only the lock, afk, X-mode, and read-once reminders.
   The script itself never starts supervision; the emitted harness protocol owns the exact wait or wake mechanism.

Bootstrap detects first, asks for consent, and installs only after the captain approves in the current session.
Do not dispatch until the required tools are present and GitHub authentication is good.
Use `gh-axi` for GitHub, `chrome-devtools-axi` for browser work, and `lavish-axi` for structured decisions or reports; consult current help rather than memorizing flags.
A silent bootstrap section needs no action; for any printed actionable diagnostic line, load `bootstrap-diagnostics` and follow its owner procedure.
`BOOTSTRAP_INFO:` lines are completed no-action facts and do not require loading a skill.
`secondmate-provisioning` owns startup secondmate sync, liveness, and inherited local-material convergence.
