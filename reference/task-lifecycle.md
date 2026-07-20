# Task lifecycle

## Intake

**Resolve the project first.**
The captain will rarely name the project explicitly, and may juggle several projects across messages.
Resolve each message independently; never assume the last-discussed project out of habit.
Use these signals in order:

1. An explicit project name in the message wins.
2. A clear follow-up ("also add tests for that", a reply to a PR you reported) inherits the project of the thing it refers to.
3. Otherwise, match the message content against what you know: project names under `projects/`, in-flight tasks in `data/backlog.md`, and the projects' own code and READMEs (read them; that is what your read access is for). A mentioned feature, file, stack trace, or technology usually points at exactly one project.
4. One confident match: proceed, but state the project in plain outcome language in your reply ("I'll work on this in `yourapp`") so a wrong guess costs one correction instead of wasted work.
5. More than one plausible match, or none: ask a one-line question. A misdirected dispatch is recoverable because crewmates work in isolated worktrees, but it is expensive; a question is cheap.

Then resolve the secondmate scope.
Read `data/secondmates.md` before dispatching and compare the work request to each registered `scope:`.
Route by the nature of the task, not just the project name.
A project may appear in several `projects:` clone lists, so choose the secondmate whose natural-language scope actually fits the work, such as triage versus feature development.
If the resolved project is `local-only`, keep the work with the main firstmate even when a secondmate scope sounds relevant.
If a secondmate's scope fits, steer that secondmate with one concise instruction via `bin/fm-send.sh fm-<id> '<work request>'` and let it run the normal lifecycle inside its own home.
The bare `fm-<id>` target resolves through this home's `state/<id>.meta`; pass an explicit backend target only when intentionally targeting an endpoint outside this firstmate home.
A secondmate is itself a firstmate, so a request reaches it in its own chat, which you never read - the return channel that wakes you is its status file.
So `fm-send` to a bare `fm-<id>` whose meta is `kind=secondmate` automatically prepends a from-firstmate marker (`bin/fm-marker-lib.sh`); the secondmate recognizes it and returns its answer via its status file, or via a doc under its home plus a status pointer for a detailed response, never only in chat.
Expect and read that response on the status/doc path the same way you read any other status signal; do not peek the secondmate's chat for the answer.
A captain typing directly into the secondmate's window is unmarked and stays a conversational captain intervention, so do not relay captain-destined chat through this path; the marker is applied only by `fm-send` to a `kind=secondmate` target.
Do not spawn a direct crewmate for work that belongs to a secondmate scope unless the secondmate is blocked or the captain explicitly redirects it.
If no secondmate scope fits, proceed in the main firstmate or create a new secondmate with the captain when that domain should become persistent.
When you create a new secondmate, hand its in-scope queued items off from the main backlog into its home with `bin/fm-backlog-handoff.sh` so it owns its domain's queue from day one (section 6).

Then classify the shape:

- **Ship** (the default): the deliverable is a change to the project. It ships through the project's delivery mode: `no-mistakes`, `direct-PR`, or `local-only`.
- **Scout:** the deliverable is knowledge - an investigation, a plan, a bug reproduction, an audit. It ends in a report at `data/<id>/report.md`, never a PR. When the captain asks "what's wrong", "how would we", or "find out why" about a project, that is a scout task; dispatch it instead of doing the digging yourself.

Then classify readiness:

- **Dispatchable:** no overlap with in-flight tasks. Dispatch immediately. There is no concurrency cap.
- **Blocked:** touches the same files or subsystem as an in-flight task, or explicitly depends on an unmerged PR. Record it in `data/backlog.md` with `blocked-by: <id>` and tell the captain what work is waiting and why. Scout tasks are read-mostly and almost never block on anything.

Keep dependency judgment coarse: same repo plus overlapping area means serialize; everything else runs parallel.
For `no-mistakes` projects, the pipeline rebase step absorbs mild overlaps; for other modes, have the crewmate rebase before review or merge if needed.

Write the brief per section 11.

## Spawn

Load `harness-adapters` before spawning or recovering any direct report so trust dialogs, verified adapters, and harness-specific behavior are handled correctly.

```sh
bin/fm-spawn.sh <id> projects/<repo>             # uses the active crewmate harness only when no crew-dispatch.json is active
bin/fm-spawn.sh <id> projects/<repo> --harness codex   # explicit per-task harness override
bin/fm-spawn.sh <id> projects/<repo> codex       # per-task harness override
bin/fm-spawn.sh <id> projects/<repo> grok        # per-task harness override
bin/fm-spawn.sh <id> projects/<repo> --harness codex --model gpt-5.5 --effort high   # explicit profile axes
bin/fm-spawn.sh <id> projects/<repo> --backend tmux   # explicit runtime backend; tmux is the verified reference backend (docs/tmux-backend.md)
bin/fm-spawn.sh <id> projects/<repo> --backend herdr  # experimental herdr backend (docs/herdr-backend.md); version-gates at spawn
bin/fm-spawn.sh <id> projects/<repo> --backend zellij # experimental zellij backend (docs/zellij-backend.md); version-gates at spawn
bin/fm-spawn.sh <id> projects/<repo> --backend orca   # experimental Orca backend (docs/orca-backend.md); Orca owns worktree + terminal; Escape unsupported
bin/fm-spawn.sh <id> projects/<repo> --backend cmux   # experimental cmux backend (docs/cmux-backend.md); GUI-first macOS-only, treehouse still owns worktree; requires a one-time socket-access setup (docs/cmux-backend.md "Setup")
bin/fm-spawn.sh <id> projects/<repo> --scout     # scout task; records kind=scout in meta
bin/fm-spawn.sh <id> --secondmate                 # launch a registered persistent secondmate in its home
bin/fm-spawn.sh <id> <firstmate-home> --secondmate   # launch or recover an explicit secondmate home
bin/fm-spawn.sh <id1>=projects/<repo1> <id2>=projects/<repo2> [--scout]   # batch: one call, several tasks
```

Dispatch several tasks in one call by passing `id=repo` pairs instead of a single `<id> <project>`; each pair is spawned through the same single-task path, shared `--scout`, `--harness`, `--model`, `--effort`, and `--backend` flags apply to all, and the looping happens inside the script so you never hand-write a multi-task shell loop.
If one pair fails, the rest still run and the batch exits non-zero.
When `config/crew-dispatch.json` exists, include a shared `--harness` for every crewmate or scout batch after consulting the dispatch rules.

The script resolves the harness (`fm-harness.sh crew` for crewmate/scout tasks only when `config/crew-dispatch.json` is absent, `fm-harness.sh secondmate` for `kind=secondmate`; section 4), resolves the runtime backend (`--backend`, then `FM_BACKEND`, then `config/backend`, then runtime auto-detection - the runtime firstmate itself is executing inside, from `$TMUX`/`HERDR_ENV=1`/cmux runtime signals, nesting resolved innermost-first (`$TMUX`, then `HERDR_ENV=1`, then cmux's primary `CMUX_WORKSPACE_ID` marker and documented macOS-only fallbacks last, since cmux is a terminal application rather than a nestable multiplexer; docs/cmux-backend.md "Runtime auto-detection") - then `tmux`; an auto-detected herdr or cmux spawn prints a loud stderr notice, auto-detected tmux stays silent; zellij and orca are never auto-detected, only explicit `--backend <name>`/`FM_BACKEND=<name>`/`config/backend`), validates the requested backend against spawn-capable adapters, owns the verified launch templates, resolves the project's delivery mode (`fm-project-mode.sh`) for ship/scout tasks, and records `harness=`, `model=`, `effort=`, `kind=`, `mode=`, and `yolo=` in the task's meta; only a non-default runtime backend is recorded as `backend=` because absent means tmux.
A backend spawn refusal - a missing dependency, an unauthenticated socket, or a version gate - must be surfaced to the captain as a blocker; never silently retry the spawn on a different backend to work around it.
A non-flag third argument containing whitespace is treated as a raw launch command (only for verifying new adapters).
When `config/crew-dispatch.json` exists, the script refuses crewmate or scout launches without an explicit harness because firstmate must have already resolved the profile choice at intake.
When `--model` or `--effort` is omitted, the corresponding meta value is `default` and no launch flag is passed for that axis, except that a `kind=secondmate` spawn can fill the omitted axis from the optional tokens in `config/secondmate-harness`.
For `kind=secondmate`, the same script launches in the registered or explicit firstmate home instead of running `treehouse get` for a project, records `home=` and `projects=`, and uses the charter brief as the launch prompt.

For ship and scout tasks, tmux/herdr/zellij/cmux create a runtime endpoint and run `treehouse get`; Orca creates an Orca-owned worktree, validates it, then creates the terminal. In all cases, the script asserts the resolved worktree is a genuine isolated worktree distinct from the primary checkout (aborting the spawn otherwise, to prevent the worktree tangle of section 8), installs the turn-end hook, records `state/<id>.meta`, and launches the agent with the brief.
For grok, the turn-end hook is one firstmate-owned global hook under `$GROK_HOME/hooks/`, or `~/.grok/hooks/` when `GROK_HOME` is unset, activated only when the worktree holds the per-task `.fm-grok-turnend` token pointer that matches `state/<id>.grok-turnend-token`; teardown removes the pointer and token.
For `kind=secondmate`, the script creates the same kind of runtime endpoint but starts directly in the persistent home.
With herdr, ordinary crewmate and scout spawns use the current `FM_HOME` workspace; a primary `--secondmate` spawn uses the secondmate target home's workspace, so secondmate-owned tabs do not mix into the primary `firstmate` space.
With zellij there is no per-home workspace split: every task, primary or secondmate, lands as a tab in the one shared `firstmate` zellij session (docs/zellij-backend.md).
Before launching a secondmate, the script fast-forwards its home worktree to firstmate's own current default-branch commit, so a freshly spawned or recovery-respawned secondmate always starts on firstmate's current version.
This is a purely local fast-forward of tracked files - never a fetch from origin, and never touching the gitignored operational dirs - so the secondmate's backlog, projects, and any prior in-flight work are untouched; a dirty, diverged, or in-flight home is left as-is and launches unchanged.
If that pre-launch fast-forward is skipped, `fm-spawn.sh` prints a concise warning to stderr and still launches the secondmate from its unchanged checkout.
The spawn also propagates the primary's inheritable config into the secondmate home's `config/`, mirroring the bootstrap sweep (section 3).
No nudge is needed at spawn because the agent reads `AGENTS.md` fresh on launch.
For already-live secondmates, use `bin/fm-config-push.sh` when only this inherited config needs to be pushed.
Project worktrees start at detached HEAD on a clean default branch; ship briefs tell the crewmate to create its branch, while scout briefs keep the worktree scratch.
After spawning, peek the endpoint to confirm the crewmate is processing the brief and handle any trust dialog with `harness-adapters`.
Add the task to `data/backlog.md` under In flight.

## Supervise

Covered by reference/supervision.md.
Steer a crewmate only with short single lines via `bin/fm-send.sh`; anything long belongs in a file the crewmate can read.
Steer a secondmate the same way.
Its charter retargets escalation to the main firstmate's status file, so routine internal churn stays inside the secondmate home and only `done`, `blocked`, `needs-decision`, `failed`, or captain-relevant phase changes wake the main firstmate.
Because `fm-send` to a `kind=secondmate` target marks the request as from-firstmate (section 7 intake), the secondmate's answer comes back on that status/doc path too, not in its chat; read the response there as an ordinary status signal and do not peek its chat for it.

## Delivery modes and yolo

A ship task's path from `done` to landed on `main` is set by the project's `mode` (recorded in meta; section 6); `yolo` decides who approves. The Validate / PR ready / Ship teardown stages below are written for the `no-mistakes` path; the other modes diverge:

- **no-mistakes** - the stages below as written: no-mistakes validation pipeline -> PR -> captain merge.
- **direct-PR** - no pipeline. The crewmate pushes and opens the PR itself (its brief says so) and reports `done: PR <url>`. Skip the Validate step and go straight to PR ready (run `fm-pr-check`, relay the PR). Teardown uses the normal landed-work check.
- **local-only** - no remote, no PR. The crewmate stops at `done: ready in branch fm/<id>`. Review the diff with `bin/fm-review-diff.sh <id>`, relay a one-paragraph summary to the captain, and on approval run `bin/fm-merge-local.sh <id>` to fast-forward local `main` (it refuses anything but a clean fast-forward - if it does, have the crewmate rebase). No `fm-pr-check`. Then teardown, whose safety check requires the branch already merged into local `main`, OR the work pushed to any remote (a fork counts - relevant for upstream-contribution PRs on a local-only-registered project).

**Upstream PR rule (all modes).** All PRs must target the upstream repo (`Swarmies/*`), never the captain's fork (`kirubeltadesse/*`). Crewmates must push branches to the `upstream` remote and create PRs with `gh pr create --repo Swarmies/<repo> --base main --head <branch>`. GitHub Actions CI does not trigger on fork PRs, so cross-fork PRs will never run CI. Briefs must include this instruction explicitly.

When reviewing any crewmate branch diff, use `bin/fm-review-diff.sh <id>` rather than `git diff <default>...branch` directly.
Pooled clones keep their local default refs frozen at clone time and can lag `origin`; the helper always compares against the authoritative base.
When the task meta records `pr=`, the helper also compares that base against the authoritative PR head (`pr_head=` when reachable, otherwise a fresh `refs/pull/<n>/head` fetch) so no-mistakes fix rounds pushed to the PR are included even if the local worktree branch is stale.
If the PR head cannot be resolved, it warns loudly and falls back to the local branch.
In target project repos shipped through that project's own no-mistakes pipeline, commits under `.no-mistakes/evidence/` in a crew branch are the pipeline's own PR-viewable validation evidence, committed by design so it rides along with the change.
Do not steer a crewmate to strip them, do not count them against the change or treat them as pollution during firstmate's own pre-merge review, and do not have them rebased away.
Evidence-hosting end-state (gists, an orphan evidence branch, or similar) is a deferred design decision; until that changes, committed evidence in the branch is correct behavior.
Firstmate's own repo is the exception: its `.no-mistakes/` stays gitignored, untracked local state, and CI rejects tracked `.no-mistakes` paths.
This do-not-fight rule does not license evidence commits in firstmate's own repo.

**yolo (orthogonal).** With `yolo=off` (default) every approval is the captain's: ask-user findings, PR merges, the local-only merge.
With `yolo=on`, firstmate makes those calls itself without asking - resolve ask-user findings on your judgment, and run `bin/fm-pr-merge.sh <id> <full GitHub PR URL>` / `bin/fm-merge-local.sh` once the work is green/approved - EXCEPT anything destructive, irreversible, or security-sensitive, which still escalates to the captain.
Never merge a red PR even under yolo.
`bin/fm-pr-merge.sh` always records `pr=` and records `pr_head=` when available before merging, parses the full `https://github.com/<owner>/<repo>/pull/<n>` URL into `gh-axi pr merge <n> --repo <owner>/<repo>`, and defaults to `--squash` unless an explicit merge method is forwarded after `--`; this holds even on a repo with no PR CI where the "checks green" signal that normally triggers `bin/fm-pr-check.sh` never fires - do not call `gh-axi pr merge` directly for a task's PR, or the recording step can be silently skipped and a later `fm-teardown.sh` has nothing to verify a squash merge against.
After any merge you perform without asking the captain, post a one-line "merged <full PR URL or local main> after checks passed" FYI so the captain keeps a trail.

## Validate

For `no-mistakes`-mode ship tasks, when a crewmate's status says `done`, trigger validation using the crew's harness from `state/<id>.meta`.
Load `harness-adapters` for the target harness's skill invocation form; natural language also works if uncertain.

The crewmate drives the no-mistakes pipeline (review, test, document, lint, push, PR, CI) itself.
The ship brief intentionally does not restate no-mistakes gate mechanics; it points the crewmate to the version-matched SKILL.md loaded by `/no-mistakes`, `no-mistakes axi run --help`, and per-response `help` lines.
Firstmate's wrapper stays narrow: `ask-user` findings return through `needs-decision`, captain-owned decisions go back through `no-mistakes axi respond`, crewmate validation avoids `--yes`, and CI-green completion is reported as `done: PR {url} checks green`.
Use chat for yes/no decisions; use lavish-axi when there are multiple findings or options to triage.

Judge a validating crewmate by the run's step status, never by whether its shell is still running.
Read its current state with `bin/fm-crew-state.sh <id>`: a deterministic, token-tight one-line read that takes the matching no-mistakes run-step as the source of truth and reconciles it against the crewmate's `state/<id>.status` log.
Because the run-step is authoritative before pane liveness, a crewmate whose window closed after or during validation can still report `done` or `working` from its run; a missing pane becomes `unknown` only when no matching run exists.
That log is an append-only wake-*event* log, not a current-state field, and it goes stale the moment a resolved gate lets the run resume: after you answer a `needs-decision`/`blocked` and the crewmate silently resumes (responds to the gate, the pipeline fixes, it re-validates), the log's last line still reads `needs-decision`/`blocked` while the run-step has moved on.
So never infer current state from a `tail` of that log; `bin/fm-crew-state.sh` reports the live run-step state and explicitly flags the stale log line superseded, where a raw `tail` would mislead you into re-escalating settled work.
The fields below name the run-step states and outcomes it reads from `no-mistakes axi status`; run that command directly when you want the full gate findings.

- `running`/`fixing`/`ci` - the pipeline is working (a fix round, a test, or CI monitoring); these run for many minutes and quiet is normal, so leave it alone.
- `awaiting_approval`/`fix_review` - the run is parked waiting on the agent, surfaced as a top-level `awaiting_agent: parked <duration>` line right after `status:` in `axi status`.
  The crewmate owes a response; if it is idle-waiting for the run to advance on its own, steer it to follow no-mistakes' active-gate help.
- `outcome: passed` or `checks-passed` - the helper reports `done`; `passed` means the PR is already merged or closed, while `checks-passed` means it is ready for PR review.
- `outcome: failed` or `cancelled` - the helper reports `failed`; inspect the run details and recover or report failure with evidence.
- Red flag - self-fix duplication: a validating crewmate making fresh hand-commits, aborting the run, or re-running it mid-validation is re-doing work the pipeline already owns.
  Steer it back to no-mistakes' respond flow; the pipeline, not the crewmate, applies validation fixes.

## PR ready

For PR-based ship tasks, the ready signal depends on mode: `no-mistakes` reports `done: PR <url> checks green` after CI is green, while `direct-PR` reports `done: PR <url>` after opening the PR.
Run `bin/fm-pr-check.sh <id> <PR url>` - it records `pr=` and GitHub's `pr_head=` when available in the task's meta and arms the watcher's merge poll.
Tell the captain: the PR's full URL (always the complete `https://...` link, never a bare `#number` - the captain's terminal makes a full URL clickable), a one-paragraph summary, and, for `no-mistakes`, the risk level it emitted.
(The check contract, for any custom `state/<id>.check.sh` you write yourself: print one line only when firstmate should wake, print nothing otherwise, and finish before `FM_CHECK_TIMEOUT`.)

If the captain says "merge it", run `bin/fm-pr-merge.sh <id> <full GitHub PR URL>` yourself; that instruction is the explicit approval.
If `yolo=on`, merge a green/approved PR yourself the same way and post the required FYI.
The helper defaults to `--squash`, accepts explicit merge-method flags such as `-- --merge`, `-- --rebase`, or `-- --method=merge`, and refuses `--repo` or `-R` overrides because the repository is derived from the URL.

## Ship teardown (only after merge is confirmed)

```sh
bin/fm-teardown.sh <id>
```

The script refuses if the worktree holds uncommitted changes or committed work that has not landed; treat a refusal as a stop-and-investigate, not an obstacle.
"Landed" is broader than remote-reachable: for a normal ship task whose commits are not reachable from any remote-tracking branch, the script also accepts the work when its PR is merged and GitHub reports a PR head that contains the current local work, or when its content is already present in the up-to-date default branch.
Containment means local `HEAD` is the PR head, local `HEAD` is an ancestor of the PR head, or the unpushed local patches have matching patch IDs in that PR head after no-mistakes replayed the branch.
This recognizes the common squash-merge-then-delete-branch flow, where the branch's own commits live nowhere on a remote yet the change is fully in `main`; a merged-and-deleted branch now tears down cleanly instead of false-refusing.
The PR is looked up from the task's recorded `pr=` when present, or, when no `pr=` was ever recorded, by finding a merged PR whose head branch matches the worktree's branch and fetching its head via `refs/pull/<n>/head` if the branch itself was deleted - so a task whose merge skipped `bin/fm-pr-check.sh` (typically a yolo-authorized merge on a repo with no PR CI, where the "checks green" trigger never fires) still tears down cleanly instead of false-refusing.
Genuinely unlanded work (no merged PR head containing the local work and content not in the default branch) and dirty worktrees still refuse, and a gh lookup error falls back to the content check rather than silently allowing.
Known benign case: after an external-PR task, a squash merge leaves the branch commits reachable only on the contributor's fork; add the fork as a remote and fetch (`git remote add fork <fork url> && git fetch fork`), then retry - never reach for `--force`.
After a successful PR-based teardown, it also runs `bin/fm-fleet-sync.sh` for that project, best-effort, so safe clone states catch up to the merge, clean detached ancestor drift self-heals, and the just-merged branch, now gone on the remote and free of its worktree, is pruned immediately.
Unsafe drift is reported as `STUCK:` and left untouched.
Then update the backlog using the teardown reminder: run `tasks-axi done` when the default tasks-axi backend is active and compatible, otherwise move the task to Done in `data/backlog.md` manually with the full `https://...` PR URL or local merge note and date and keep Done to the 10 most recent.
Re-evaluate the queue and dispatch only queued work whose blockers are gone and whose time/date gate, if any, has arrived.

## Secondmate teardown (explicit only)

A secondmate is persistent by default.
An empty queue is healthy and does not trigger teardown.
Run `bin/fm-teardown.sh <id>` for `kind=secondmate` only when the captain or main firstmate explicitly decides to retire that persistent supervisor.
Load `secondmate-provisioning` before retiring it.
The safety check is the secondmate's own home: teardown refuses while its `state/*.meta` contains in-flight work.
With `--force`, teardown is the explicit discard path for child windows, child work, state, route, lease, and home; never use it unless the captain explicitly said to discard the work.

## Scout tasks (report instead of PR)

A scout task follows Intake, Spawn, and Supervise exactly as above - scaffold the brief with `bin/fm-brief.sh <id> <repo> --scout`, spawn with `--scout` - then diverges after the work:

- There is no Validate or PR-ready stage. When the crewmate's status says `done`, read `data/<id>/report.md`.
- Relay the findings to the captain: plain chat for a focused answer, lavish-axi when the report has structure worth a visual (multiple findings, options, a plan).
- Tear down immediately - no merge gate. `bin/fm-teardown.sh` allows a scout worktree's scratch commits and dirty files once the report exists; if the report is missing, it refuses, because the findings are the work product.
- Record it in Done with the report path instead of a PR link using `tasks-axi done` when the default tasks-axi backend is active and compatible, otherwise hand-edit `data/backlog.md` and keep Done to the 10 most recent, then re-evaluate the queue and dispatch only queued work whose blockers are gone and whose time/date gate, if any, has arrived.

**Promotion.** When a scout's findings reveal shippable work (a reproduced bug with a clear fix) and the captain wants it shipped, promote the task in place instead of respawning: run `bin/fm-promote.sh <id>` (flips `kind=` to ship in meta, restoring teardown's full protection), then send the crewmate its ship instructions - inventory scratch state, reset to a clean default-branch base, carry over only intended fix changes, create branch `fm/<id>`, implement, and report `done` according to the project's delivery mode.
The crewmate keeps its worktree, loaded context, and repro, but the ship branch must start from a clean base with only intended changes; scratch commits and debug edits from the scout phase never ride along.
The repro becomes the regression test.
From there the task is an ordinary ship task through its mode-specific validation, PR or local merge, and Teardown.
