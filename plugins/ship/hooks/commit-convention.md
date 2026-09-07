# Commit message convention

A project's own conventions come first. If this repository already says
how commits should look — a CONTRIBUTING guide, a commit template, a
commitlint or similar config, a rule in CLAUDE.md, or simply a consistent
pattern in `git log` — follow that, exactly as its contributors do, and
ignore the rest of this note. A newcomer does not bring their own style.

Only when the repository has no convention of its own, use this shape,
so that history stays readable:

    <type>(<scope>)?: <summary> (<ref>)?

    ## What

    <what changed>

    ## Why

    - <the problem or motivation>

    ## Risk

    <what could break, and how it was verified>

Subject: one line, at most 72 characters, no trailing period.
- `type` is one of feat, fix, chore, docs, refactor, test, perf, build,
  ci, style, revert.
- `scope` is optional: the module or area, lowercase, as in `fix(stores):`.
- `summary` is imperative: "move", not "moved" or "moves".
- `ref` is optional: the ticket ID or issue number when one exists, as in
  `(BEV-123)`, `(T-012)` or `(#3551)`.

Body: three `##` sections in this order, each non-empty, wrapped at 72
columns.
- **What**: what changed, written from `git diff --staged`, not from
  memory. Name the files or components that matter.
- **Why**: the problem or motivation, as bullets. For a fix, the root
  cause.
- **Risk**: what could break and how it was verified. `None.` plus a
  one-line reason when nothing was flagged.

Anything after Risk (a `Created by` trailer, `Co-authored-by`) is fine.
