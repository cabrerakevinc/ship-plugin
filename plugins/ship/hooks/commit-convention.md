# Commit message convention

Every `git commit` in this session uses this shape. A hook rejects any
that doesn't and shows this note again.

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
  `(BEV-123)`, `(T-012)` or `(#3551)`. A ship workflow always has a
  ticket, so it always fills this in.

Body: three `##` sections in this order, each non-empty, wrapped at 72
columns.
- **What**: what changed, written from `git diff --staged`, not from
  memory. Name the files or components that matter.
- **Why**: the problem or motivation, as bullets. For a fix, the root
  cause.
- **Risk**: what could break and how it was verified. `None.` plus a
  one-line reason when nothing was flagged.

Anything after Risk (a `Created by` trailer, `Co-authored-by`) is fine.
Pass the message with `-m "$(cat <<'EOF' ... EOF)"` so the hook can read
it.
