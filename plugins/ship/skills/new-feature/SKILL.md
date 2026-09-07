---
description: Implements a feature end to end across the relevant platform(s) - solutions-architect (if needed), implementation, QA, tech-lead review, one commit
argument-hint: [ticket ID or description]
disable-model-invocation: true
---

Work on: $ARGUMENTS

Before doing anything else, check for a CLAUDE.md at the project root. If
it's missing, tell the user and suggest running the native `/init` command
first — proceed carefully and ask for context rather than assuming
conventions.

Resolve the tracker: Linear if its MCP tools are available and the root
CLAUDE.md doesn't say otherwise; otherwise `docs/projma/` if it exists (read
`docs/projma/CLAUDE.md` and follow it, and read `docs/projma/memory.md` for
context before starting); otherwise ask the user once whether to create the
standard tracker (invoke the `ship:projma` skill with `init`) or use
something else — never create it without a yes.

If this refers to a ticket ID, fetch its full spec and Definition of Done
checklist (from Linear, or from the ticket's file under
`docs/projma/resources/`). If it's a description with no ticket yet, create
the ticket first exactly as `/ship:new-ticket` would, so the sign-offs below
have somewhere to live. Mark the ticket in progress (Linear status, or
`in-progress` in `tasks.csv`).

You own every write to the ticket from here — no subagent has tracker
access. After each subagent below finishes its step, post its output as an
attributed sign-off comment on the ticket (a Linear comment, or an entry
appended to the ticket file's Sign-off log in `docs/projma/`) before moving
on. This is the paper trail; don't batch it into one summary at the end.

Figure out which platform(s) this touches: iOS (Swift), Android, web (design
and/or development), backend, or a combination.
- If it's unclear, plausibly spans more than one platform, or is non-trivial
  on any single platform, invoke `ship:solutions-architect` and wait for its
  brief and per-platform design note(s) before writing any code — post them
  as a sign-off comment.
- If it's clearly single-platform, small and well-understood, skip
  `ship:solutions-architect`.

`ship:solutions-architect` will not design against infrastructure it doesn't
understand and has no cloud access of its own. If it comes back with a
request for infrastructure context instead of a design, do this before
re-invoking it:
1. If an AWS MCP server is connected in this session, show the user the
   exact read-only queries the architect asked for and ask for explicit
   permission to run them read-only. Only on a clear yes, run those
   describe/list/get operations yourself — never anything that creates,
   modifies or deletes — and collect the results.
2. If the user declines, or no AWS MCP server is connected, ask the user to
   describe the infrastructure at a high level or to provide a diagram (an
   image, a Mermaid/PlantUML file, or a link) and collect that instead.
Re-invoke `ship:solutions-architect` with what you gathered, then post its
brief and design note(s) as a sign-off comment.

If new web UI is involved (not just wiring up existing components), invoke
`ship:front-end-web-designer` first, post its spec as a sign-off comment, and hand
it to `ship:front-end-web-developer`.

Implement using the matching specialist(s), posting each one's "what I
changed" report as a sign-off comment as it finishes:
- iOS → `ship:front-end-ios-engineer`
- Android → `ship:front-end-android-engineer`
- Web → `ship:front-end-web-developer`
- Backend/API/data → `ship:backend-engineer`

If multiple platforms are involved, sequence them per `ship:solutions-architect`'s
brief (e.g. backend contract before the clients that depend on it), and make
sure each specialist knows about contract changes from the others.

Once implemented, invoke `ship:qa-tester` (scoped to what changed on each platform)
and post its report as a sign-off comment. Then invoke `ship:tech-lead-reviewer` and
post its item-by-item Definition of Done verdict as a sign-off comment. If
either flags issues, fix them and re-run that subagent, posting a new
sign-off comment for the re-run. Update docs (README/CHANGELOG) if behavior
changed.

Don't finish until `ship:qa-tester` and `ship:tech-lead-reviewer` are satisfied against
every item on the Definition of Done, across every platform touched. Once
they are, move the ticket to whatever this tracker calls its pre-closed,
ready-for-review state — in Linear, e.g. "Done," "In Review," or reassigning
it to the user (check CLAUDE.md or ask if it isn't obvious); in
`docs/projma/`, status `in-review` in `tasks.csv`, with the confirmed DoD
items ticked in the ticket file and one to three terse bullets of durable
learnings appended to `docs/projma/memory.md`. Never set the ticket to
"Closed" (or your tracker's equivalent) yourself — that's the user's call
alone.

Then commit — once, yourself, on the branch that is checked out. Run
`git status` and stage only what belongs to this ticket: the files the
specialists reported changing, the docs you updated and, on the file
tracker, the `docs/projma/` files you just wrote, so the sign-off log lands
with the code. Never `git add -A`; leave out any untracked file you can't
account for and name it to the user. Write the message from
`git diff --staged`. If this project has its own commit convention — a
CONTRIBUTING guide, a commit template, a commitlint config, a rule in
CLAUDE.md, or a consistent pattern in `git log` — follow it exactly, the
way any newcomer to the project would; the plugin's shape never overrides
a project's. Only if the project has none, use the default shape from the
session-start note: subject `feat: <summary> (<ticket ID>)` — `fix`,
`chore`, `docs`, `refactor`, `test` or `perf` when that is more honest —
then `## What` (the changes, condensed from the specialists'
reports), `## Why` (the ticket's problem and scope, as bullets) and
`## Risk` (what `ship:qa-tester` and `ship:tech-lead-reviewer` flagged and how
it was handled; `None.` with a one-line reason otherwise). No push, no
branch, checkout, remote, amend, rebase or reset — those are the user's.
If there is nothing to commit or the commit fails, say so and stop; the
ticket stays in review. After a successful commit, post its short SHA and
subject as the final sign-off comment, and tell the user clearly that it's
ready for their final check.
