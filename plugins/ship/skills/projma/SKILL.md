---
name: projma
description: File-based ticket tracker at docs/projma/ (tasks.csv index, one file per ticket with DoD checklist and sign-off log, memory.md). `init` scaffolds it; `status` or no argument summarises open tickets. Invoked by ship:new-ticket, ship:new-feature and ship:hotfix when Linear isn't available.
argument-hint: [init | status]
---

Argument: $ARGUMENTS

The tracker root is `docs/projma/`, relative to the project root. The
conventions live in `docs/projma/CLAUDE.md` once it exists; the pristine copy
is `${CLAUDE_SKILL_DIR}/templates/CLAUDE.md`.

## `init`

1. If `docs/projma/` already exists, say so and stop. Never overwrite an
   existing tracker.
2. Otherwise create `docs/projma/` and `docs/projma/resources/`, then copy
   `${CLAUDE_SKILL_DIR}/templates/CLAUDE.md`, `memory.md` and `tasks.csv`
   into `docs/projma/`, and create an empty `docs/projma/resources/.gitkeep`.
3. In the copied `CLAUDE.md` and `memory.md`, replace `{{DATE}}` with today's
   date (`YYYY-MM-DD`) and `{{PROJECT}}` with the project root folder name.
4. List the files created and remind the user to commit them. Make no other
   changes.

When another ship skill invokes you with `init`, the user has already agreed
to create the tracker; don't ask again.

## `status` (or no argument)

- If `docs/projma/` doesn't exist, say so and offer to run `init`. Don't
  create anything without a yes.
- Otherwise read `docs/projma/tasks.csv` and print: a one-line count per
  status, then every non-`closed` ticket as `id — title (status; platforms)`,
  `in-review` first, then `in-progress`, then `todo`. Write nothing.

Anything else as an argument: say the valid arguments are `init` and
`status`.
