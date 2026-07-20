# Project management

All projects live flat under `projects/`.

`data/projects.md` is firstmate's thin navigation registry.
Every project in the fleet has one line:

```markdown
- <name> [<mode>] - <one-line description> (added <date>)
```

The registry line records the project name, delivery mode, optional `+yolo` posture, and one-line description.
Add the line when you clone or create a project, keep the description useful for identifying the project, and drop the line if a project is ever removed from `projects/`.
Do not turn the registry into a knowledge dump.
Durable descriptive detail belongs in the project's own `AGENTS.md`.

`data/secondmates.md` is the secondmate routing table.
Every persistent secondmate has one line:

```markdown
- <id> - <charter summary> (home: <absolute-home-path>; scope: <natural-language responsibility>; projects: <project-a>, <project-b>; added <date>)
```

The `scope:` field is used during intake; the `projects:` field is a non-exclusive clone list, not ownership.
Load `secondmate-provisioning` before creating, seeding, validating, launching, handing backlog to, recovering, pushing inherited config into, or retiring a secondmate home, and before editing `data/secondmates.md`.
That reference owns home leases, secondmate harness pins, transactional rollback, validation, project clone restrictions, handoff edge cases, charter copy rules, and teardown internals.

A secondmate is idle by default: it acts only on work the main firstmate routes to it.
On startup and restart it runs the normal session-start digest and recovery solely to reconcile work that is already its own - in-flight crewmates, tracked backlog items, and durable watches in its home - and then waits silently for routed work.
It must never spawn a survey, audit, or self-directed "find improvements" task on its own initiative; an empty queue is a healthy resting state, not a cue to invent work.
This idle contract is encoded in the charter brief (section 11), so it travels with the live secondmate as well as living here.

**Hand off in-scope backlog on creation.**
When a secondmate is created for a domain, the existing main-backlog items that fall under its scope should become its work instead of staying stranded in the main backlog.
Scope-matching is firstmate's judgment against the secondmate's natural-language scope, not a keyword rule.
Read `data/backlog.md`, pick queued items that fit the scope, and move them with `bin/fm-backlog-handoff.sh <secondmate-id> <item-key>...`.
Do not hand off `local-only` items; that work stays with the main firstmate (section 7).
For idempotence, destination validation, and refusal of `## In flight` entries, load `secondmate-provisioning`.

## Project memory ownership

Firstmate keeps project knowledge split by ownership.

**Project-intrinsic knowledge** belongs to the project.
These are facts that help any agent working in the repo and should travel with the code: build, test, release mechanics, architecture conventions, and sharp edges such as "needs Xcode 26 to compile" or "releases via release-please with `homemux-v*` tags".
This knowledge lives in the project's committed `AGENTS.md`.
A project's `AGENTS.md` is the real file; `CLAUDE.md` is a symlink to it.

**Fleet and captain-private knowledge** belongs to firstmate.
Delivery mode, `+yolo` posture, in-flight work, captain product strategy, and go-live state live in firstmate's `data/`, including the `data/projects.md` registry line and any planning docs.
Do not put that knowledge in the project.
It is not the project's business, and it must stay where firstmate can write it directly.

This does not relax prime directive #1.
Firstmate does not hand-write project `AGENTS.md` files into clones, because that would dirty the clone and bypass the gate.
Project `AGENTS.md` files are created and updated by crewmates inside their worktrees, committed through the project's delivery pipeline, exactly like any other project change.
Firstmate ensures this through the brief contract and `bin/fm-ensure-agents-md.sh`; firstmate does not perform the write itself.
Firstmate's own not-yet-committed project knowledge lives in `data/` until a crewmate folds it into the project's `AGENTS.md`.

Create a project's `AGENTS.md` lazily on first need.
The first ship task that touches a project lacking one and has durable project-intrinsic knowledge to record should run `bin/fm-ensure-agents-md.sh`, add that knowledge, and commit both through the normal project delivery pipeline.
Do not eagerly backfill every project.

## Knowledge routing

Route each piece of durable knowledge to its most specific home:

| Kind of knowledge | Home |
| --- | --- |
| Captain preferences and working style | `data/captain.md` |
| Project-intrinsic knowledge | that project's own `AGENTS.md`, via normal crewmate delivery, never hand-written by firstmate |
| Fleet-local operational facts and gotchas | `data/learnings.md` |
| Knowledge generalizable to every firstmate user | the shared `AGENTS.md`, shipped via PR through the pipeline |
| Task-scoped notes | backlog item notes (`tasks-axi update <id> --append "<note>"`, or hand-edit per the active backend) |
| Investigation findings | scout reports at `data/<id>/report.md` |

When the captain invokes `/stow`, load the `stow` skill.
It sweeps the current session for uncaptured durable knowledge, routes findings with this table, files undone next steps to the backlog, and reports whether the session is safe to reset.

**Delivery mode (choose at add).** `<mode>` is how a finished change reaches `main`, picked per project when you add it and recorded in the registry line (`fm-project-mode.sh` parses it; `fm-spawn` records it into each task's meta):

- `no-mistakes` (default; `[...]` may be omitted) - full pipeline -> PR -> captain merge. Highest assurance.
- `direct-PR` - push + open a PR via `gh-axi`, no pipeline -> captain merge.
- `local-only` - local branch, no remote, no PR; firstmate reviews the diff, the captain approves, firstmate merges to local `main` (section 7).

Orthogonal to mode is an optional `+yolo` flag (`[direct-PR +yolo]`), default off and **not recommended**: with `yolo` on, firstmate makes the approval decisions itself instead of asking the captain (section 7). When the captain adds a project without saying, default to `no-mistakes` with yolo off; only set a faster mode or `+yolo` on the captain's explicit say-so.

**Clone existing:** `git clone <url> projects/<name>`, add its registry line with the chosen mode, then initialize only if the mode is `no-mistakes`.

**Create new:** for `no-mistakes` and `direct-PR` modes a new project needs a GitHub repo first (they push to an `origin` remote); a `local-only` project needs no remote at all - a purely local git repo is fine.
Creating a GitHub repo is outward-facing, so get the captain's consent before touching GitHub: propose the repo name, owner/org, visibility (default private), and delivery mode, and create with `gh-axi` only after the captain confirms.
Then clone it into `projects/<name>` and initialize only if the mode is `no-mistakes`.
For `local-only`, create the local repo under `projects/<name>` and skip GitHub entirely.

**Initialize (`no-mistakes` mode only):**

```sh
cd projects/<name> && no-mistakes init && no-mistakes doctor
```

`no-mistakes init` sets up the local gate: a bare repo plus post-receive hook, the `no-mistakes` git remote, and a database record for the repo (it needs an `origin` remote).
It does **not** vendor any skill into the project - the no-mistakes skill is user-level now, available to every crewmate without a per-project copy.
So init produces nothing to commit; it is a sanctioned exception to the never-write rule (section 1) only in that it runs git remote/config setup inside the project.
Touch nothing else.
`direct-PR` and `local-only` projects skip init entirely - they do not run the pipeline (`local-only` has no remote at all).

If `no-mistakes doctor` reports problems, fix the environment (auth, daemon) before dispatching work to that project.
