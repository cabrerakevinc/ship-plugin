---
description: Fast lane for bug fixes and hotfixes - minimal fix, targeted test, quick review
argument-hint: [ticket ID or bug description]
disable-model-invocation: true
---

This is a hotfix for: $ARGUMENTS

Skip `ship:solutions-architect` and `ship:architect`. Check for a CLAUDE.md at the project
root for relevant conventions; if it's missing, note that and proceed
carefully.

Resolve the tracker the same way `/ship:new-feature` does: Linear if its MCP
tools are available and the root CLAUDE.md doesn't say otherwise; otherwise
`docs/projma/` if it exists (read `docs/projma/CLAUDE.md` and follow it);
otherwise ask the user once before creating it with the `ship:projma` skill
(`init`). If there's no ticket yet for this bug, create one first exactly as
`/ship:new-ticket` would, so the sign-offs have somewhere to live. Mark it in
progress.

Identify which platform this touches (iOS, Android, web, backend) and
reproduce the issue there first, ideally with a failing test. Apply the
minimal fix with the matching specialist (`ship:front-end-swift-engineer`,
`ship:front-end-android-engineer`, `ship:front-end-web-developer`, or `ship:backend-engineer`) —
no unrelated refactors. If the fix genuinely touches more than one platform,
treat that as a signal this might not be a hotfix — flag it and ask before
proceeding.

You own every write to the ticket — no subagent has tracker access. Post
each subagent's output as an attributed sign-off comment (a Linear comment,
or an entry appended to the ticket file's Sign-off log in `docs/projma/`) as
soon as it finishes.

Invoke `ship:qa-tester` scoped to the relevant tests only, post its report as a
sign-off comment. Invoke `ship:tech-lead-reviewer` for a quick regression-focused
check against the ticket's Definition of Done (or, if there isn't one for an
undocumented hotfix, against "issue no longer reproduces, no regressions"),
and post its verdict as a sign-off comment.

If the fix is a workaround rather than a root-cause fix, use the `ship:ba-intake`
subagent to draft a follow-up ticket, and create it yourself (Linear, or
`docs/projma/`) before finishing.

Once `ship:tech-lead-reviewer` is satisfied, move the ticket to whatever this
tracker calls its pre-closed, ready-for-review state (`in-review` in
`tasks.csv` for `docs/projma/`, with one to three terse bullets of durable
learnings appended to `docs/projma/memory.md`) and tell the user it's ready
for their final check. Never mark it "Closed" (or equivalent) yourself.
