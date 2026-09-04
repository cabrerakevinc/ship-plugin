---
description: Implements a feature end to end across the relevant platform(s) - solutions-architect (if needed), architect, implementation, QA, tech-lead review
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

Figure out which platform(s) this touches: iOS (Swift), Android, web (design
and/or development), backend, or a combination.
- If it's unclear, or it plausibly spans more than one platform, invoke
  `ship:solutions-architect` first and use its brief to decide what happens next.
- If it's clearly single-platform and straightforward, skip `ship:solutions-architect`.

You own every write to the ticket from here — no subagent has tracker
access. After each subagent below finishes its step, post its output as an
attributed sign-off comment on the ticket (a Linear comment, or an entry
appended to the ticket file's Sign-off log in `docs/projma/`) before moving
on. This is the paper trail; don't batch it into one summary at the end.

For each platform involved, if the feature is non-trivial, invoke the
`ship:architect` subagent (once per platform, if more than one) and wait for its
design note before writing any code — post it as a sign-off comment. Skip
this for small, well-understood changes.

If new web UI is involved (not just wiring up existing components), invoke
`ship:front-end-web-designer` first, post its spec as a sign-off comment, and hand
it to `ship:front-end-web-developer`.

Implement using the matching specialist(s), posting each one's "what I
changed" report as a sign-off comment as it finishes:
- iOS → `ship:front-end-swift-engineer`
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
learnings appended to `docs/projma/memory.md` — and tell the user clearly
that it's ready for their final check. Never set the ticket to "Closed" (or
your tracker's equivalent) yourself — that's the user's call alone.
