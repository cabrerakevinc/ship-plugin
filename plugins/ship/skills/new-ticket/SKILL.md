---
description: Turns a raw idea or bug report into a ticket via the ba-intake role
argument-hint: [description of the idea or bug]
disable-model-invocation: true
---

Take this raw request: $ARGUMENTS

Delegate to the `ship:ba-intake` subagent to draft the ticket: title, problem
statement, scope, platform(s) if apparent, and a Definition of Done checklist.
`ship:ba-intake` never touches the tracker — you do.

Create the actual ticket yourself from that draft. Resolve the tracker in
this order:

1. Linear, if its MCP tools are available and the project's root CLAUDE.md
   doesn't say otherwise (ask which team/project if CLAUDE.md doesn't
   specify one).
2. Otherwise the file tracker at `docs/projma/`, if it exists: read
   `docs/projma/CLAUDE.md` and follow it — add a row to `tasks.csv` with
   status `todo` and create the ticket file under `resources/`.
3. Otherwise ask the user once whether to create the standard `docs/projma/`
   tracker (invoke the `ship:projma` skill with `init`, then proceed as in
   step 2) or to use something else. Never create it without a yes.

Include the DoD checklist in the ticket body.

Report back the ticket ID or tracker reference and the DoD checklist.
