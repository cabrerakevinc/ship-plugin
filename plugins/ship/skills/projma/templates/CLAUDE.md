# Project tracker (`docs/projma/`)

File-based ticket tracker for {{PROJECT}}, used when Linear isn't connected.
Scaffolded by the `ship` Claude Code plugin (`/ship:projma init`) on {{DATE}}.

## Files

- `tasks.csv` — the index, one row per ticket. The **only** place a ticket's
  status lives.
- `resources/<id>-<slug>.md` — one file per ticket: problem, scope,
  Definition of Done, sign-off log. Also holds any reference material
  (specs, exports, screenshots) that tickets link to.
- `memory.md` — durable project context learned across tickets. Read it
  before starting work; append to it after finishing.

## tasks.csv

Header: `id,title,type,platforms,status,created,updated,file`

- `id` — `T-001`, `T-002`, … zero-padded to three digits. Next id = highest
  existing + 1.
- `title` — short. Long text belongs in the ticket file.
- `type` — `feature` | `bug` | `hotfix` | `chore`.
- `platforms` — `;`-separated subset of `ios`, `android`, `web`, `backend`,
  or `tbd` if not yet known.
- `status` — `todo` | `in-progress` | `in-review` | `closed`.
- `created`, `updated` — `YYYY-MM-DD`. Update `updated` on every change.
- `file` — path relative to this folder, e.g.
  `resources/T-001-dark-mode-toggle.md`.

Rules: RFC 4180 quoting (wrap a field in double quotes if it contains a
comma, a double quote or a newline; double any quotes inside). Never reorder
or delete rows.

## Statuses

- `todo` — created, not started.
- `in-progress` — being worked on.
- `in-review` — implemented, QA and tech-lead review passed; waiting for the
  user's final check.
- `closed` — set **only by the user**, after their own final check (merge,
  deploy). Automation never sets this.

## Ticket file

Every ticket gets a file, even a short one. Status is **not** recorded in
the file; `tasks.csv` is the source of truth.

```
# T-001 — Add dark mode toggle

- Type: feature
- Platforms: ios, web
- Created: 2026-09-04

## Problem

## Scope

## Definition of Done

- [ ] …

## Sign-off log

### 2026-09-04 14:02 — ship:ba-intake

…
```

- **Sign-off log:** append one entry per agent step, newest last, headed
  `### <YYYY-MM-DD HH:MM> — <agent name>`, containing that agent's report.
  Never edit earlier entries. This is the equivalent of the Linear comment
  trail.
- **Definition of Done:** tick a box only when `ship:tech-lead-reviewer` has
  confirmed that item.

## memory.md

Append one to three terse bullets per finished ticket under a dated
heading: decisions made, conventions discovered, gotchas. It is not a log —
consolidate or prune stale entries when you notice them.

## Who writes here

Only the main session (the orchestrating `ship` skills, or the user).
Subagents are read-only.
