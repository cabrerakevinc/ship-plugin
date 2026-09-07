# Commit convention for the `ship` plugin — design

**Date:** 2026-09-05
**Status:** approved design, awaiting implementation plan
**Amends:** `2026-09-04-ship-plugin-design.md` (§10 listed hooks as out of scope; this spec brings them in)

## 1. Purpose

Commits Claude writes in Kevin's sessions are accurate but unstructured: a
subject line, sometimes one prose paragraph, and the `Created by KevTheDev`
trailer. Kevin wants every commit to have the same shape, so that anyone
reading history can see *what* changed, *why*, and *what could break*:

```
chore: remove stray empty file accidentally committed in #3539 (#3551)

## What

Removes a 0-byte file with a garbled name from the repo root. It was
accidentally committed in #3539 (commit `6d6cfd5ff`) and has no content
or purpose — debris, not part of that datacap fix.

## Why

- Empty blob (`e69de29`), unparseable name, no extension.
- Unrelated to the entitlement fix it rode in on.
- Clutters the repo root.

## Risk

None. The file is empty and unreferenced.
```

This applies to *every* commit, not only the ones a `ship` workflow makes:
a `/ship:hotfix`, a superpowers plan step, or an ad-hoc fix in
`bevz-server`. The `ship` plugin today never commits at all; its workflows
end with the ticket in review and the working tree dirty.

## 2. Decisions

| Decision | Choice | Why |
|---|---|---|
| Where the convention lives | Inside the `ship` plugin, as two hooks plus a commit step in `new-feature` and `hotfix` | Versioned in git, travels with the plugin, applies in every repo of every profile where `ship` is enabled. Alternatives (a user-level CLAUDE.md, a hook in `settings.json`) are private to one machine and unversioned. |
| How the model learns the shape | A `SessionStart` hook injects `hooks/commit-convention.md` as additional context | The first attempt is already right; the hook is a backstop, not the teacher. Same mechanism superpowers uses. |
| How it is enforced | A `PreToolUse` hook on `Bash` rejects any `git commit` whose message does not have the shape, with the reasons and the convention | Exit 2 blocks the call before it runs and hands stderr to the model, which rewrites and retries. Structure is enforced; accuracy is asked for. |
| Who commits in a `ship` workflow | The orchestrating session, once, at the end. Subagents never commit | Subagents cannot see the ticket, and a subagent committed and pushed unasked on 2026-09-04. One commit per ticket keeps the sign-off log and the code together. |
| What the plugin never does | Push, branch, checkout, add/remove remotes, amend, rebase, reset | Those are the user's. The commit is reversible; a push is not. |
| Subject reference | Optional in general; always the ticket ID in a `ship` workflow | Ad-hoc commits often have no ticket. Kevin's example carries a PR number the plugin does not have; the ticket ID is what it does have. |
| Subject scope | Optional, `type(scope):` | Kevin's current messages already use it (`fix(stores):`); Conventional Commits allow it. |
| Trailer | Not added by the plugin | `Created by KevTheDev` comes from the `attribution.commit` setting in Kevin's profiles. Other installs will not have it; anything after `## Risk` is allowed. |
| Hook failure policy | Fail open | A crash in the checker (bad JSON, unexpected shape) exits 0 and lets the command through. A bug in the hook must never block every Bash call. |
| Spec fidelity | `scripts/spec-diff.py` looks up a file's block in the newest spec that defines it | This spec redefines files the 2026-09-04 spec also defines. Newest wins; the old spec stays as history, untouched. |

## 3. The convention

The text below is `plugins/ship/hooks/commit-convention.md`, byte for byte
(Appendix A.2). It is the single source of truth: the SessionStart hook
injects it, the PreToolUse hook prints it on rejection, the README links
to it.

Shape:

```
<type>(<scope>)?: <summary> (<ref>)?

## What

<what changed>

## Why

- <the problem or motivation>

## Risk

<what could break, and how it was verified>
```

Rules the hook enforces (§5.3) are marked **[H]**; the rest is guidance the
model follows because it was told to.

- **[H]** Subject is one line, at most 72 characters, does not end with `.`.
- **[H]** Subject starts with `type`, one of `feat fix chore docs refactor
  test perf build ci style revert`, optionally followed by `(scope)` and
  `!`, then `: ` and a non-empty summary.
- `scope` is lowercase, the module or area.
- `summary` is imperative.
- `ref` is the ticket ID or issue number in parentheses at the end of the
  subject, when one exists. Not validated: the hook cannot know whether a
  ticket exists.
- **[H]** The second line is blank.
- **[H]** The body has the lines `## What`, `## Why`, `## Risk`, each
  exactly once, in that order, each followed by at least one non-blank line
  before the next header or the end.
- **What** is written from `git diff --staged`, not from memory, and names
  the files or components that matter.
- **Why** is bullets: the problem or motivation, and the root cause for a
  fix.
- **Risk** says what could break and how it was verified, or `None.` with a
  one-line reason.
- Lines wrap at 72 columns. Not validated: URLs and paths break it
  legitimately.
- Anything after the Risk section's content is allowed (trailers).

## 4. Components

### 4.1 Plugin layout after this change

```
plugins/ship/
  hooks/
    hooks.json              # registers the two hooks
    session-start.sh        # SessionStart: emits commit-convention.md as additionalContext
    check-commit.sh         # PreToolUse(Bash): fast path, then delegates to the checker
    check-commit-msg.py     # the checker: stdin JSON → exit 0 | exit 2 + stderr
    commit-convention.md    # the convention text (§3)
scripts/
  test-commit-hook.sh       # fixture-driven tests for check-commit.sh (§6)
  check.sh                  # gains a `# === hooks ===` section (§6)
  smoke.sh                  # gains a `# === 3. hooks ===` section (§6)
  spec-diff.py              # newest-spec-wins lookup (§4.7)
```

### 4.2 `hooks/hooks.json`

Appendix A.1. Two events:

- `SessionStart`, matcher `startup|clear|compact` (not `resume`: the
  earlier injection is still in the transcript), runs `session-start.sh`.
- `PreToolUse`, matcher `Bash`, runs `check-commit.sh`.

Both commands are `bash "${CLAUDE_PLUGIN_ROOT}/hooks/<script>"` with a
10-second timeout. No `async`: the PreToolUse hook must finish before the
command runs, and the SessionStart context must land before the first turn.

### 4.3 `hooks/session-start.sh`

Appendix A.3. Reads `commit-convention.md` from its own directory and prints

```json
{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "<the file>"}}
```

JSON encoding is done by a three-line embedded python so quoting is never
hand-rolled. Exit 0 always; if the file is missing the script prints
nothing and exits 0 (the plugin still works, minus the reminder).

### 4.4 `hooks/check-commit.sh`

Appendix A.4. Reads all of stdin. If the text does not contain both `git`
and `commit` it exits 0 without starting python: most Bash calls are not
commits and the hook must cost nothing on them. Otherwise it pipes the
input to `check-commit-msg.py` and exits with its status.

### 4.5 `hooks/check-commit-msg.py`

Not reproduced in an appendix: it is code, written test-first from the
behaviour below and the fixture matrix in §6. Stdlib only, python3.

**Input.** The PreToolUse payload on stdin: `tool_input.command` is the
shell command about to run; `cwd` is the working directory. Anything else
is ignored. If stdin is not JSON, or `tool_name` is not `Bash`, or there is
no `command`: exit 0.

**Output.** Exit 0 to allow. Exit 2 to block, with stderr:

```
ship commit convention: commit message rejected.
  - <one line per problem>
Fix the message and run the commit again. The convention:

<commit-convention.md, verbatim>
```

Nothing is printed on stdout in either case.

**Detection (§5.1).** Find `git commit` invocations in command position.
Occurrences inside a heredoc body that was opened *before* them are not
commands (they are content being written to a file) and are skipped. If no
invocation remains: exit 0.

**Extraction (§5.2).** For each invocation, read its arguments up to the end
of that shell command and recover the message. If the invocation is one the
hook does not judge (`--amend` with `--no-edit`, `--fixup`, `--squash`,
`-C`/`-c`/`--reuse-message`/`--reedit-message`, or no message argument at
all): skip it. If a message argument exists but cannot be read (command
substitution other than a `cat` heredoc, a `-F` file that does not exist,
`-F -`): block with the reason `message could not be read; pass it with
-m "$(cat <<'EOF' ... EOF)"`.

**Validation (§5.3).** Check the recovered message. Every invocation in the
command must pass; problems from all of them are listed.

### 4.6 Skills and agents

- `skills/new-feature/SKILL.md` (Appendix A.5) and `skills/hotfix/SKILL.md`
  (Appendix A.6): the closing paragraph is split. The tracker is moved to
  in-review as before; then a new paragraph commits: stage only the
  ticket's files by name after `git status`, never `git add -A`, write the
  message from `git diff --staged` in the convention with the ticket ID as
  `ref`, `feat:` (or a more honest type) for a feature and `fix:` for a
  hotfix, no push/branch/checkout/remote/amend/rebase/reset, stop and say
  so if there is nothing to commit or the commit fails, and post the short
  SHA and subject as the final sign-off comment before telling the user it
  is ready for their final check.
- The four implementing agents (`front-end-ios-engineer`,
  `front-end-android-engineer`, `front-end-web-developer`,
  `backend-engineer`; Appendix A.7–A.10) gain one sentence at the end of
  their "When done" paragraph: *Don't commit, branch or push — the calling
  skill commits once at the end.* Their `tools:` lists are unchanged;
  Bash stays because they need it to build and run.
- `new-ticket`, `projma`, and the read-only agents are untouched.

### 4.7 `scripts/spec-diff.py`

`block(path)` currently reads one hard-coded spec. It now scans
`docs/superpowers/specs/*.md` in descending filename order (dates sort) and
uses the first spec containing the heading `` `path` ``. Usage and exit
codes are unchanged. The docstring says so. The 2026-09-04 spec's Appendix
A is left as it was: its blocks for the six files this spec changes are now
historical, and `spec-diff.py` no longer consults them.

### 4.8 README

- The `ship` row in the plugin table mentions the commit convention.
- The `new-feature` and `hotfix` bullets say the workflow ends with one
  commit in the convention and never pushes.
- A new `## Commit convention` section after `## What ship gives you`:
  the shape, that two hooks under `plugins/ship/hooks/` teach and enforce
  it in every repo where `ship` is enabled, that the ticket ID is the
  `ref`, that any `Created by` trailer comes from the user's own
  `attribution` setting, and how to test the hook.
- The Developing block lists `scripts/test-commit-hook.sh`.

## 5. Checker behaviour in detail

### 5.1 Detection

A `git commit` invocation is a match of

```
(?:^|[;&|({\n]|\$\()\s*git\s+(?:(?:-C|-c)\s+\S+\s+|--[\w-]+(?:=\S+)?\s+)*commit(?![\w-])
```

i.e. `git`, optional global options (`-C dir`, `-c k=v`, `--git-dir=…`),
then the `commit` subcommand, at the start of the command or right after a
command separator. `commit-tree`, `git log --grep commit`, and `git commit`
inside a quoted string (`grep "git commit"`) do not match: the quote
character precedes `git`.

Heredoc masking: before matching, find every heredoc opener
`<<-?\s*(['"]?)(\w+)\1` in the command in order; its body runs from the
start of the next line to the line that equals the delimiter (leading tabs
stripped if `<<-`), or to the end of the command if none. Matches whose
`git` falls inside a body whose opener precedes it are dropped. A commit's
own message heredoc (`-m "$(cat <<'EOF'`) opens *after* `git commit`, so it
never masks its own invocation. This is what lets the model write a plan
file containing example commit commands without the hook judging them.

### 5.2 Extraction

Arguments are read from the character after `commit` to the first unquoted
`&&`, `||`, `;`, `|`, or newline (newlines inside a heredoc body or a
quoted string do not end the command). Tokens:

- `"…"` with `\"` and `\\` escapes; `'…'` with none.
- Inside `"…"`, a `$(cat <<'TAG'` / `$(cat <<TAG` / `$(cat <<"TAG"` opener
  means the message is the heredoc body (lines after the opener up to the
  `TAG` line), regardless of what follows the closing `)`.
- Any other `$(`, a backtick, or a `$NAME` / `${NAME}` expansion inside a
  message argument → *could not be read*.
- `-m X`, `-mX`, `--message X`, `--message=X`: collect in order; the
  message is the parts joined by a blank line (git's behaviour).
- `-F X`, `--file X`, `--file=X`: `-` → *could not be read*; otherwise the
  path, relative to the payload's `cwd`, is read if it exists, else *could
  not be read*.
- Options the hook does not judge (§4.5) → skip this invocation.
- Neither `-m`/`--message` nor `-F`/`--file` → skip (git will open an
  editor or fail on its own).

### 5.3 Validation

Given the recovered message split on `\n` (a trailing newline dropped):

| # | Check | Problem text |
|---|---|---|
| 1 | Line 1 matches `^(feat|fix|chore|docs|refactor|test|perf|build|ci|style|revert)(\([^()\s]+\))?!?: \S` | `subject: must be "<type>(<scope>)?: <summary> (<ref>)?", got "<line 1>"` |
| 2 | Line 1 is ≤ 72 characters | `subject: <n> characters, limit is 72` |
| 3 | Line 1 does not end with `.` | `subject: no trailing period` |
| 4 | If there is a line 2, it is blank | `body: line 2 must be blank` |
| 5 | Exactly one line equals `## What`, one `## Why`, one `## Risk`, and they appear in that order | `body: missing "## What"` / `body: "## Why" appears twice` / `body: sections must be in the order What, Why, Risk` |
| 6 | Between each header and the next header (or the end), at least one non-blank line | `body: "## Risk" is empty` |

A message with only a subject fails 5 (all three missing). Checks run in
order and every failing check is reported; the hook never stops at the
first problem.

## 6. Testing

**Unit: `scripts/test-commit-hook.sh`.** Runs `hooks/check-commit.sh` with
`CLAUDE_PLUGIN_ROOT=plugins/ship` on fixture payloads and asserts exit
code and, for rejections, a stderr substring. Each fixture is a heredoc in
the script (JSON built with python so escaping is right). Matrix:

| Fixture | Expect |
|---|---|
| `npm test` | 0 |
| `git status && git diff` | 0 |
| Valid message via `-m "$(cat <<'EOF' … EOF)"`, all sections | 0 |
| Valid with scope, `!`, ref and a `Created by` trailer | 0 |
| Valid via two `-m` (subject, then body) | 0 |
| Valid via `git -C /path commit -m …` | 0 |
| Valid, chained: `git add a && git commit -m … && git log -1` | 0 |
| Message is inside an outer heredoc (`cat > plan.md <<'EOF' … git commit -m "bad" … EOF`) | 0 |
| `grep -rn "git commit -m" scripts/` | 0 |
| `git commit --amend --no-edit` | 0 |
| `git commit --fixup HEAD~1` | 0 |
| `git commit` (no message) | 0 |
| stdin not JSON | 0 |
| `tool_name: Read` with a command-like field | 0 |
| `git commit -m "Final review fixes: README note"` | 2, `subject: must be` |
| Subject 80 characters | 2, `limit is 72` |
| Subject ending in `.` | 2, `trailing period` |
| No blank line after subject | 2, `line 2 must be blank` |
| Missing `## Risk` | 2, `missing "## Risk"` |
| Sections in order What, Risk, Why | 2, `order What, Why, Risk` |
| `## Why` header with no content | 2, `"## Why" is empty` |
| `## What` twice | 2, `appears twice` |
| One-line `-m "feat: add thing"` | 2, `missing "## What"` |
| `-F /nonexistent` | 2, `could not be read` |
| `-m "$(git log -1 --format=%s)"` | 2, `could not be read` |
| `-m "$MSG"` (a shell variable) | 2, `could not be read` |
| Rejection stderr | contains `Commit message convention` (the convention itself was printed; `## Risk` also appears in a problem line, so it proves nothing) |

**Structural: `scripts/check.sh`, new `# === hooks ===` section.**

- The five `hooks/` files exist; `hooks.json` parses; it has a
  `SessionStart` entry with matcher `startup|clear|compact` and a
  `PreToolUse` entry with matcher `Bash`; every `command` names a file
  that exists once `${CLAUDE_PLUGIN_ROOT}` is replaced by `plugins/ship`.
- `hooks/check-commit-msg.py` parses under `ast.parse` (`py_compile` would write `__pycache__` under `plugins/ship/`).
- `session-start.sh` output parses as JSON and its `additionalContext`
  contains `## What`, `## Why`, `## Risk`.
- `scripts/test-commit-hook.sh` passes.
- `new-feature` and `hotfix` contain `git status`, `git diff --staged`,
  `## What`, `## Why`, `## Risk`, ``Never `git add -A` ``; neither contains
  `git push`.
- The four implementing agents contain `Don't commit, branch or push`.
- Reference counts: `new-feature` qa-tester 3, tech-lead-reviewer 3;
  `hotfix` qa-tester 2, tech-lead-reviewer 3.
- `claude plugin validate plugins/ship` still passes (it validates
  `hooks.json`).

**Functional: `scripts/smoke.sh`, new `# === 3. hooks ===` section**, in
the same throwaway repo, after configuring a git identity there:

- Ask a fresh `--plugin-dir` session: "Which three `##` sections must a
  commit message body have, per your session-start notes? Output only the
  three headers." Expect `What`, `Why`, `Risk`.
- Stage a file, ask the session to run exactly
  `git commit -m "bad message"` and report the result, with
  `--allowedTools 'Bash(git commit:*)'`. Expect zero commits in the repo
  and the output to mention the convention or rejection.
- Ask the session to commit the staged file with a message that follows
  the convention. Expect one commit whose body contains `## Risk`.

**Fidelity: `scripts/spec-diff.py`** on every file in Appendix A must
report `match:`.

## 7. Rollout

1. Push `main`. `claude plugin update ship@kevthedev` in the `claude-bevz`
   profile; also in `~/.claude` if `ship` is installed there. Start a new
   session: `/hooks` lists both hooks under the plugin.
2. From then on every commit Claude makes in that profile is checked.
   Superpowers workflows that commit (`executing-plans`,
   `subagent-driven-development`, `finishing-a-development-branch`) will
   have their first non-conforming attempt rejected and rewritten; that is
   the intended behaviour, not a conflict.
3. To turn it off in one profile: disable the plugin, or remove the
   plugin's hooks from `/hooks`.

## 8. Out of scope

- Validating `ref` against the tracker, or requiring it outside `ship`
  workflows.
- Enforcing 72-column body wrapping, imperative mood, or lowercase scope.
- A `commit-msg` git hook in target repos (would also catch commits Kevin
  makes by hand; not asked for).
- Making the plugin push, branch, or open pull requests.
- Windows: hook scripts are bash; the polyglot wrapper superpowers ships is
  not needed on Kevin's machines.
- Commits made through tools other than Bash (there are none).

---

## Appendix A — final file contents

Files in this appendix are the source of truth for `scripts/spec-diff.py`
(newest spec wins). `check-commit-msg.py`, `test-commit-hook.sh`,
`check.sh`, `smoke.sh`, `spec-diff.py` and `README.md` are not here: they
are code and prose written from §4–§6, not copied.

### A.1 `plugins/ship/hooks/hooks.json`

```json
{
  "description": "ship commit convention: hands the model the convention at session start and rejects git commit commands whose message does not follow it",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh\"",
            "timeout": 10
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/check-commit.sh\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### A.2 `plugins/ship/hooks/commit-convention.md`

```markdown
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
```

### A.3 `plugins/ship/hooks/session-start.sh`

```bash
#!/usr/bin/env bash
# SessionStart hook: hand the commit convention to the model as additional context.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[ -f "$here/commit-convention.md" ] || exit 0
python3 - "$here/commit-convention.md" <<'PY'
import json, sys
text = open(sys.argv[1], encoding="utf-8").read()
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart",
                                         "additionalContext": text}}))
PY
exit 0
```

### A.4 `plugins/ship/hooks/check-commit.sh`

```bash
#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash). Fast path first: most commands are not commits.
set -uo pipefail
input="$(cat)"
case "$input" in
  *git*commit*) ;;
  *) exit 0 ;;
esac
here="$(cd "$(dirname "$0")" && pwd)"
printf '%s' "$input" | python3 "$here/check-commit-msg.py"
```

### A.5 `plugins/ship/skills/new-feature/SKILL.md`

```markdown
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
`git diff --staged` in the plugin's commit convention (the session-start
note carries it; a hook enforces it): subject `feat: <summary> (<ticket
ID>)` — `fix`, `chore`, `docs`, `refactor`, `test` or `perf` when that is
more honest — then `## What` (the changes, condensed from the specialists'
reports), `## Why` (the ticket's problem and scope, as bullets) and
`## Risk` (what `ship:qa-tester` and `ship:tech-lead-reviewer` flagged and how
it was handled; `None.` with a one-line reason otherwise). No push, no
branch, checkout, remote, amend, rebase or reset — those are the user's.
If there is nothing to commit or the commit fails, say so and stop; the
ticket stays in review. After a successful commit, post its short SHA and
subject as the final sign-off comment, and tell the user clearly that it's
ready for their final check.
```

### A.6 `plugins/ship/skills/hotfix/SKILL.md`

```markdown
---
description: Fast lane for bug fixes and hotfixes - minimal fix, targeted test, quick review, one commit
argument-hint: [ticket ID or bug description]
disable-model-invocation: true
---

This is a hotfix for: $ARGUMENTS

Skip `ship:solutions-architect`. Check for a CLAUDE.md at the project root
for relevant conventions; if it's missing, note that and proceed carefully.

Resolve the tracker the same way `/ship:new-feature` does: Linear if its MCP
tools are available and the root CLAUDE.md doesn't say otherwise; otherwise
`docs/projma/` if it exists (read `docs/projma/CLAUDE.md` and follow it);
otherwise ask the user once before creating it with the `ship:projma` skill
(`init`). If there's no ticket yet for this bug, create one first exactly as
`/ship:new-ticket` would, so the sign-offs have somewhere to live. Mark it in
progress.

Identify which platform this touches (iOS, Android, web, backend) and
reproduce the issue there first, ideally with a failing test. Apply the
minimal fix with the matching specialist (`ship:front-end-ios-engineer`,
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
learnings appended to `docs/projma/memory.md`). Never mark it "Closed" (or
equivalent) yourself.

Then commit — once, yourself, on the branch that is checked out. Run
`git status` and stage only what belongs to this fix: the files the
specialist reported changing, the test you added and, on the file tracker,
the `docs/projma/` files you just wrote. Never `git add -A`; leave out any
untracked file you can't account for and name it to the user. Write the
message from `git diff --staged` in the plugin's commit convention (the
session-start note carries it; a hook enforces it): subject `fix: <summary>
(<ticket ID>)`, then `## What` (the change, condensed from the specialist's
report), `## Why` (the bug and its root cause, as bullets) and `## Risk`
(what `ship:qa-tester` and `ship:tech-lead-reviewer` flagged and how it was
handled; `None.` with a one-line reason otherwise). No push, no branch,
checkout, remote, amend, rebase or reset — those are the user's. If there
is nothing to commit or the commit fails, say so and stop; the ticket stays
in review. After a successful commit, post its short SHA and subject as the
final sign-off comment, and tell the user it's ready for their final check.
```

### A.7 `plugins/ship/agents/front-end-ios-engineer.md`

```markdown
---
name: front-end-ios-engineer
description: Implements iOS features and fixes in Swift (SwiftUI or UIKit), following a design note from solutions-architect
tools: Read, Write, Edit, Bash, Grep, Glob
model: sonnet
---

You are the iOS engineer, working in Swift (SwiftUI or UIKit, matching
whatever this codebase already uses).

Treat this repository as shared work others rely on, whether it's a team or a
solo developer — be careful, and don't act on assumptions you haven't checked.

Check for a CLAUDE.md at the project root. If it exists, follow its
conventions (project structure, dependency manager, style, testing approach).
If it doesn't exist, tell the user/master and suggest running the native
`/init` command first — proceed carefully and ask before assuming conventions
you can't verify from the existing code.

Implement the ticket or design note you're given, matching the existing
codebase's patterns (module/target structure, state management, networking
layer) rather than introducing your own. If no design note exists and the
change is non-trivial, ask for one from `ship:solutions-architect` before
writing code. If something is ambiguous or missing context you need to
implement confidently, stop and ask rather than guessing.

When done, report what you changed and flag anything `ship:qa-tester` or
`ship:tech-lead-reviewer` should pay particular attention to (device/OS version
considerations, App Store review implications). Don't commit, branch or
push — the calling skill commits once at the end.
```

### A.8 `plugins/ship/agents/front-end-android-engineer.md`

```markdown
---
name: front-end-android-engineer
description: Implements Android features and fixes in Kotlin (or Java), following a design note from solutions-architect
tools: Read, Write, Edit, Bash, Grep, Glob
model: sonnet
---

You are the Android engineer, working in Kotlin (or Java, matching whatever
this codebase already uses).

Treat this repository as shared work others rely on, whether it's a team or a
solo developer — be careful, and don't act on assumptions you haven't checked.

Check for a CLAUDE.md at the project root. If it exists, follow its
conventions (module structure, build system/Gradle setup, style, testing
approach). If it doesn't exist, tell the user/master and suggest running the
native `/init` command first — proceed carefully and ask before assuming
conventions you can't verify from the existing code.

Implement the ticket or design note you're given, matching the existing
codebase's patterns (architecture pattern, dependency injection, networking
layer) rather than introducing your own. If no design note exists and the
change is non-trivial, ask for one from `ship:solutions-architect` before
writing code. If something is ambiguous or missing context you need to
implement confidently, stop and ask rather than guessing.

When done, report what you changed and flag anything `ship:qa-tester` or
`ship:tech-lead-reviewer` should pay particular attention to (device/OS
fragmentation, Play Store review implications). Don't commit, branch or
push — the calling skill commits once at the end.
```

### A.9 `plugins/ship/agents/front-end-web-developer.md`

```markdown
---
name: front-end-web-developer
description: Implements web features and fixes, from a design spec (front-end-web-designer) and/or architecture note (solutions-architect)
tools: Read, Write, Edit, Bash, Grep, Glob
model: sonnet
---

You are the web developer, implementing in whatever framework this codebase
already uses (don't introduce a different one).

Treat this repository as shared work others rely on, whether it's a team or a
solo developer — be careful, and don't act on assumptions you haven't checked.

Check for a CLAUDE.md at the project root. If it exists, follow its
conventions (framework, styling approach, state management, testing). If it
doesn't exist, tell the user/master and suggest running the native `/init`
command first — proceed carefully and ask before assuming conventions you
can't verify from the existing code.

If a design spec exists from `ship:front-end-web-designer`, implement from it. If
none exists and the change is purely visual/UX (not just wiring up existing
components), ask for one first rather than making design calls yourself. If
the ticket is backend-adjacent (new API calls, data shape changes), coordinate
with `ship:backend-engineer` rather than guessing at a contract.

Implement the ticket, matching existing patterns rather than introducing your
own. If something is ambiguous or missing context you need to implement
confidently, stop and ask rather than guessing.

When done, report what you changed and flag anything `ship:qa-tester` or
`ship:tech-lead-reviewer` should pay particular attention to (browser/device
support, performance). Don't commit, branch or push — the calling skill
commits once at the end.
```

### A.10 `plugins/ship/agents/backend-engineer.md`

```markdown
---
name: backend-engineer
description: Implements backend features and fixes - APIs, data/storage, integrations, serverless infrastructure - following a design note from solutions-architect
tools: Read, Write, Edit, Bash, Grep, Glob
model: sonnet
---

You are the backend engineer, working in whatever stack this codebase already
uses (don't assume any one stack applies across every repo — confirm from the
code, not from habit).

Treat this repository as shared work others rely on, whether it's a team or a
solo developer — be careful, and don't act on assumptions you haven't checked.

Check for a CLAUDE.md at the project root. If it exists, follow its
conventions (architecture pattern, IaC tooling, testing, deployment process).
If it doesn't exist, tell the user/master and suggest running the native
`/init` command first — proceed carefully and ask before assuming conventions
you can't verify from the existing code.

Implement the ticket or design note you're given, matching existing patterns
(domain boundaries, error handling, event/data contracts) rather than
introducing your own. If no design note exists and the change is non-trivial
(new service, new data model, anything affecting other platforms' contracts),
ask for one from `ship:solutions-architect` before writing code. If a change
affects an API/data contract that
`ship:front-end-ios-engineer`, `ship:front-end-android-engineer`, or
`ship:front-end-web-developer` depend on, call that out explicitly so it isn't
discovered late.

If something is ambiguous or missing context you need to implement
confidently, stop and ask rather than guessing.

When done, report what you changed, including any contract changes other
platforms need to know about, and flag anything `ship:qa-tester` or
`ship:tech-lead-reviewer` should pay particular attention to (backward
compatibility, cost/scaling implications, security). Don't commit, branch or
push — the calling skill commits once at the end.
```
