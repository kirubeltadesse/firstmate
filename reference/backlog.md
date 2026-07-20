# Backlog format

`data/backlog.md` is the durable queue.
Update it on every dispatch, completion, and decision.

```markdown
## In flight
- [ ] <id> - <one line> (repo: <name>, since <date>)

## Queued
- [ ] <id> - <one line> (repo: <name>) blocked-by: <id> - <reason>

## Done
- [x] <id> - <one line> - <https://github.com/owner/repo/pull/number> (merged <date>)
- [x] <id> - <one line> - local main (merged <date>)
- [x] <id> - <one line> - data/<id>/report.md (reported <date>)
```

Re-evaluate Queued on every teardown and every heartbeat: anything whose blocker is gone and whose time/date gate, if any, has arrived gets dispatched.

A tracked `.tasks.toml` at this repo root pins the default `tasks-axi` markdown backend to `data/backlog.md`, with `done_keep = 10` and an archive at `data/done-archive.md`.
The local, gitignored `config/backlog-backend` file is the explicit opt-out knob.
Absent or `tasks-axi` means use the default tasks-axi backend; `manual` means force hand-editing even when `tasks-axi` is installed.
Compatible means the shared bootstrap probe accepts `tasks-axi --version` as 0.1.1 or newer.
When the default backend is selected and compatible `tasks-axi` is on PATH, firstmate mutates the backlog through its verbs instead of hand-editing, with secondmate handoffs still going through the validated helper described in section 6.
When the default backend is selected but `tasks-axi` is missing or incompatible, bootstrap suggests `npm install -g tasks-axi` through the normal consent flow, and every firstmate home falls back to hand-editing `data/backlog.md` exactly as this section describes until it is installed.
When `config/backlog-backend=manual`, every firstmate home hand-edits and bootstrap does not suggest installing `tasks-axi`.
The `## In flight` / `## Queued` / `## Done` format above stays the contract: the verbs edit `data/backlog.md` in place, byte-exact, preserving whatever item forms the file already uses - the bold in-flight `- **<id>**` form, the `- [ ]`/`- [x]` queued and done forms, and `blocked-by: <id> - <reason>` - rather than reformatting them.
Secondmates inherit `config/backlog-backend` from the primary.
If the primary leaves the file absent, each home uses the default tasks-axi backend path with its own `.tasks.toml`; if the primary opts out with `manual`, secondmate homes hand-edit too.
Keep Done to the 10 most recent entries.
With the active compatible tasks-axi backend, `tasks-axi done` auto-prunes Done and archives pruned entries to `data/done-archive.md`, so do not hand-prune.
When hand-editing, prune older Done entries manually whenever you add to the section.
Pruning loses nothing: finished PR-based ship tasks live on as GitHub PRs, local-only ship tasks live on in local `main`, and scout tasks live on as report files.
Map firstmate's real backlog operations to the approved commands:

- File an item: `tasks-axi add <id> "<one line>" --kind <ship|scout> --repo <name>`, plus `--start` for immediate dispatch (In flight) or the default queue placement, and `--blocked-by <id>` (repeatable) when it waits on another task.
- Start an existing queued item: `tasks-axi start <id>` before dispatching work from Queued, after checking that blockers are gone and any time/date gate has arrived.
- Move a finished task to Done: `tasks-axi done <id> --pr <url>` for a PR-based ship, `--report <path>` for a scout, or `--note "local main"` for a local-only merge.
- Append a status note: `tasks-axi update <id> --append "<note>"`; replace fields with `--title`, `--body`, or `--body-file <path>`.
- Manage dependencies: `tasks-axi block <id> --by <other>` and `tasks-axi unblock <id> --by <other>`, then `tasks-axi ready` to list queued work with no unresolved blockers.
  This is a dependency check only; future-dated items still stay queued until their date arrives.
- Read an item's full notes: `tasks-axi show <id> --full`.
- Hand a task off to a secondmate home: keep using `bin/fm-backlog-handoff.sh <secondmate-id> <item-key>...`; do not call bare `tasks-axi mv` for this path, because the helper resolves and validates the secondmate home before moving anything.
- Normalize the file: `tasks-axi render` rewrites every id'd task in canonical form and leaves free-form lines untouched.

**Note hygiene:** Keep free-form backlog and task note/status prose free of volatile incidental specifics that rot: temp paths, in-flight versions, moving state locations, and ephemeral IDs.
Reference the authoritative source instead of duplicating it into prose - "state per the module's backend config", not a literal path.
Before acting on a note's volatile detail, verify it against the source of truth (the config, the live system, the API); notes drift.
The backlog format's structured fields are different: task IDs, blocked-by IDs, and Done-entry PR URLs or report paths from `tasks-axi done --pr <url>` or `--report <path>` are the durable record required by this schema.
Correct or delete stale free-form notes the moment you catch them, and put durable facts in curated memory (section 6's knowledge-routing homes), not scattered across one-off task notes.
