# Commit Convention for `ship` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Superseded 2026-09-07:** the enforcing checker built in Tasks 3–5 was withdrawn in favour of guidance that defers to a project's own conventions. See the spec's Revision section. The tasks below are the record of what was built.

**Goal:** Every commit Claude makes in a session where `ship` is enabled has the shape `type: summary (ref)` + `## What` / `## Why` / `## Risk`, taught by a SessionStart hook, enforced by a PreToolUse hook, and produced by `/ship:new-feature` and `/ship:hotfix` at the end of their workflows.

**Architecture:** The plugin gains a `hooks/` directory: `hooks.json` registers a SessionStart hook (emits `commit-convention.md` as additional context) and a PreToolUse hook on Bash (`check-commit.sh`, a bash fast path that hands anything mentioning `git` and `commit` to `check-commit-msg.py`, which parses the command, recovers the message, validates it, and exits 2 with reasons to block). The two orchestrating skills get a final commit step; the four implementing agents are told not to commit. `scripts/test-commit-hook.sh` is a fixture harness for the checker; `check.sh` and `smoke.sh` grow matching sections; `spec-diff.py` learns that the newest spec defining a file wins.

**Tech Stack:** Claude Code 2.1.260 plugin hooks (`hooks/hooks.json`, `${CLAUDE_PLUGIN_ROOT}`, PreToolUse exit 2 = block, SessionStart `hookSpecificOutput.additionalContext`), bash, python3 3.13 stdlib only, git. macOS.

**Spec:** `docs/superpowers/specs/2026-09-05-commit-convention-design.md`. §3 is the convention, §5 the checker's exact behaviour, §6 the test matrix, Appendix A the byte-exact content of ten files. Read the spec alongside this plan; when the plan and the spec disagree, the spec wins and the plan has a bug.

## Global Constraints

- Every commit in this plan follows the convention it implements: subject `<type>(<scope>)?: <summary> (<ref>)?` (≤ 72 chars, no trailing period), blank line, `## What`, `## Why`, `## Risk`, each non-empty, then the trailer line `Created by KevTheDev`. Pass it as `-m "$(cat <<'EOF' … EOF)"`. Each task's commit message is given verbatim in its last step.
- Git guardrails for whoever executes a task: stage files **by name**, never `git add -A` or `git add .`. Never run `git push`, `git remote`, `git branch`, `git checkout`, `git switch`, `git reset`, `git rebase`, or `git commit --amend`. Never run `claude plugin install|update|marketplace`. Task 8 is the only task that pushes, and it is executed by Kevin's main session after Kevin says so, never by a subagent.
- Work on `main` in this repo. The working tree must be clean (`git status --short` prints nothing) before each task starts and after each task's commit.
- Content files listed in spec Appendix A are materialised with `scripts/spec-diff.py --write <path>` (Task 1 adds `--write`) and verified with `scripts/spec-diff.py <path>` → `match:`. Do not hand-type or "improve" them.
- Code files (`check-commit-msg.py`, `test-commit-hook.sh`, `check.sh`, `smoke.sh`, `spec-diff.py`, `README.md`) are written from this plan and the spec §4–§6; they are not in any appendix.
- Python: stdlib only, no `__pycache__` inside `plugins/ship/` (use `ast.parse`, not `py_compile`, for syntax checks). Shell scripts are bash, invoked as `bash <path>`, so the executable bit is a courtesy, not a requirement; set it anyway.
- Every script prints `ok   …` / `FAIL …` lines and ends with a PASSED/FAILED line, exit 0 only when nothing failed, like the existing `check.sh` and `smoke.sh`.
- `claude plugin validate plugins/ship` must pass after every task. Its warning about a missing version is expected.

---

## File structure

| Path | Responsibility | Task |
|---|---|---|
| `scripts/spec-diff.py` | Compare or write content files from the newest spec that defines them. | 1 |
| `plugins/ship/hooks/commit-convention.md` | The convention text: single source of truth, injected at session start, printed on rejection, linked from README. | 2 |
| `plugins/ship/hooks/session-start.sh` | SessionStart hook: prints the convention as `additionalContext` JSON. | 2 |
| `plugins/ship/hooks/check-commit.sh` | PreToolUse hook entry: exits 0 fast unless stdin mentions `git` and `commit`; else runs the checker. | 3 |
| `plugins/ship/hooks/check-commit-msg.py` | The checker: detect `git commit` invocations, recover the message, validate, block with reasons. | 3, 4 |
| `scripts/test-commit-hook.sh` | Fixture harness: feeds PreToolUse payloads to `check-commit.sh`, asserts exit code and stderr. | 3, 4 |
| `plugins/ship/hooks/hooks.json` | Registers the two hooks. This is the switch that turns the feature on. | 5 |
| `scripts/check.sh` | Structural checks; gains a `# === hooks ===` section and updated skill/agent assertions. | 2, 3, 5, 6 |
| `plugins/ship/skills/new-feature/SKILL.md`, `plugins/ship/skills/hotfix/SKILL.md` | Final commit step. | 6 |
| `plugins/ship/agents/{front-end-ios-engineer,front-end-android-engineer,front-end-web-developer,backend-engineer}.md` | "Don't commit, branch or push" line. | 6 |
| `README.md` | Commit convention section, workflow bullets, developing block. | 7 |
| `scripts/smoke.sh` | `# === 3. hooks ===` end-to-end section. | 7 |

---

### Task 1: `spec-diff.py` — newest spec wins, `--write`, `MISSING`

**Files:**
- Modify: `scripts/spec-diff.py` (whole file)

**Interfaces:**
- Consumes: `docs/superpowers/specs/*.md`, each with headings of the form `### A.n \`<repo-relative path>\`` followed by a fenced block.
- Produces: `scripts/spec-diff.py <path>...` → prints `match: p` / `DIFFERS: p` / `MISSING: p`, exit 0 iff all match. `scripts/spec-diff.py --write <path>...` → writes each file from its newest spec block (creating directories), prints `wrote: p`, exit 0. Tasks 2, 5 and 6 depend on `--write`.

- [ ] **Step 1: Run the current script to see the behaviour that must change**

Run:
```bash
scripts/spec-diff.py plugins/ship/skills/new-feature/SKILL.md plugins/ship/agents/ba-intake.md; echo "exit=$?"
scripts/spec-diff.py plugins/ship/hooks/hooks.json; echo "exit=$?"
```
Expected today: the first prints `match:` for both and `exit=0` (it only reads the 2026-09-04 spec, which the current skill file still matches). The second dies with a Python traceback (`FileNotFoundError`), because the file does not exist yet and nothing handles that. After this task the first must print `DIFFERS: plugins/ship/skills/new-feature/SKILL.md` (the 2026-09-05 spec defines a newer version) and `match: plugins/ship/agents/ba-intake.md` (only the old spec defines it), `exit=1`; the second must print `MISSING: plugins/ship/hooks/hooks.json`, `exit=1`.

- [ ] **Step 2: Replace the script**

Write `scripts/spec-diff.py` with exactly this content:

```python
#!/usr/bin/env python3
"""Compare content files against the fenced blocks in the design specs' appendices.

Usage: scripts/spec-diff.py [--write] <repo-relative path>...
  default   exit 0 when every file equals its spec block byte for byte; 1 otherwise
  --write   write each file from its spec block (creating directories), exit 0

A file's block is the fenced block under a heading that names the file in
backticks (e.g. "### A.5 `plugins/ship/skills/hotfix/SKILL.md`").  When more
than one spec under docs/superpowers/specs/ defines the same file, the newest
(highest filename, i.e. latest date) wins; older specs stay as history.
Bootstrap fidelity check only: after a build, the files are the source of truth.
"""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPECS = sorted((ROOT / "docs/superpowers/specs").glob("*.md"), reverse=True)

def block(path: str) -> str:
    """Body of the fenced block under the heading naming `path`, from the newest spec that has one."""
    heading = re.compile(r"^#{1,6} .*`" + re.escape(path) + r"`[ \t]*$", re.M)
    for spec_path in SPECS:
        spec = spec_path.read_text()
        m = heading.search(spec)
        if not m:
            continue
        fs = spec.index("\n```", m.end()) + 1     # start of the opening fence line
        fe = spec.index("\n", fs)                  # end of the opening fence line
        fence = re.match(r"`+", spec[fs:fe]).group(0)
        s = fe + 1
        e = spec.index("\n" + fence + "\n", s)     # closing fence on its own line
        return spec[s:e] + "\n"
    sys.exit(f"no spec under docs/superpowers/specs/ defines {path}")

args = sys.argv[1:]
write = bool(args) and args[0] == "--write"
if write:
    args = args[1:]
bad = 0
for p in args:
    want = block(p)
    target = ROOT / p
    if write:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(want)
        print(f"wrote:   {p}")
        continue
    if not target.exists():
        bad += 1
        print(f"MISSING: {p}")
        continue
    got = target.read_text()
    if want != got:
        bad += 1
        print(f"DIFFERS: {p}")
        wl, gl = want.splitlines(), got.splitlines()
        for i, (a, b) in enumerate(zip(wl, gl), 1):
            if a != b:
                print(f"  first difference at line {i}:\n    spec: {a!r}\n    file: {b!r}")
                break
        else:
            print(f"  line counts differ: spec {len(wl)}, file {len(gl)}")
    else:
        print(f"match:   {p}")
sys.exit(1 if bad else 0)
```

- [ ] **Step 3: Verify the new behaviour**

Run:
```bash
scripts/spec-diff.py plugins/ship/skills/new-feature/SKILL.md plugins/ship/agents/ba-intake.md; echo "exit=$?"
scripts/spec-diff.py plugins/ship/hooks/hooks.json; echo "exit=$?"
scripts/spec-diff.py plugins/ship/agents/ba-intake.md plugins/ship/agents/qa-tester.md plugins/ship/skills/new-ticket/SKILL.md plugins/ship/skills/projma/SKILL.md; echo "exit=$?"
```
Expected: `DIFFERS: plugins/ship/skills/new-feature/SKILL.md` with a "first difference at line 2" note (the description line changed), `match: plugins/ship/agents/ba-intake.md`, `exit=1`; then `MISSING: plugins/ship/hooks/hooks.json`, `exit=1`; then four `match:` lines and `exit=0` (files only the old spec defines still resolve to it).

- [ ] **Step 4: Verify `--write` is byte-exact**

Run:
```bash
scripts/spec-diff.py --write plugins/ship/agents/ba-intake.md && git status --short; echo "dirty=$(git status --short | wc -l | tr -d ' ')"
```
Expected: `wrote:   plugins/ship/agents/ba-intake.md`, then `git status --short` shows only ` M scripts/spec-diff.py` and `dirty=1`. If `ba-intake.md` shows as modified, `--write` is not byte-exact: fix `block()` before continuing.

- [ ] **Step 5: Commit**

```bash
git add scripts/spec-diff.py
git commit -m "$(cat <<'EOF'
chore: let spec-diff pick the newest spec and write files from it

## What

scripts/spec-diff.py now finds a file's block in the newest spec under
docs/superpowers/specs/ whose heading names that file, prints MISSING
for a file that does not exist yet instead of crashing, and gains
--write to materialise a file from its block.

## Why

- The 2026-09-05 spec redefines files the 2026-09-04 spec also defines;
  the newest definition must win without editing the old spec.
- Later tasks create new files from the appendix; typing them by hand
  invites copy errors.

## Risk

None. Files only the old spec defines still match it (checked on
ba-intake, qa-tester, new-ticket, projma); --write round-trips
ba-intake.md without a diff.

Created by KevTheDev
EOF
)"
```

---

### Task 2: Convention text and SessionStart hook

**Files:**
- Create: `plugins/ship/hooks/commit-convention.md` (spec Appendix A.2, via `--write`)
- Create: `plugins/ship/hooks/session-start.sh` (spec Appendix A.3, via `--write`)
- Modify: `scripts/check.sh` — insert a `# === hooks ===` section immediately above the line `# === summary ===`

**Interfaces:**
- Consumes: `scripts/spec-diff.py --write` from Task 1.
- Produces: `plugins/ship/hooks/commit-convention.md`, read at runtime by `session-start.sh` (this task) and by `check-commit-msg.py` (Task 3, which prints it on rejection). `bash plugins/ship/hooks/session-start.sh` prints one JSON object `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "<file text>"}}` and exits 0.

- [ ] **Step 1: Add the failing checks to `check.sh`**

In `scripts/check.sh`, insert this block on the line before `# === summary ===`:

```bash
# === hooks ===
H=plugins/ship/hooks
for f in commit-convention.md session-start.sh; do need_file "$H/$f"; done
ctx=$(CLAUDE_PLUGIN_ROOT="$PWD/plugins/ship" bash "$H/session-start.sh" 2>/dev/null)
if python3 -c 'import json,sys; c=json.load(sys.stdin)["hookSpecificOutput"]; assert c["hookEventName"]=="SessionStart"; t=c["additionalContext"]; assert all(h in t for h in ("## What","## Why","## Risk")), t' <<<"$ctx" 2>/dev/null; then
  ok "session-start.sh emits the convention as SessionStart additionalContext"
else
  bad "session-start.sh output is not the expected JSON"
fi

```

- [ ] **Step 2: Run `check.sh` to see the new checks fail**

Run: `scripts/check.sh 2>&1 | grep -E '^FAIL|PASSED|FAILED'`
Expected: `FAIL missing plugins/ship/hooks/commit-convention.md`, `FAIL missing plugins/ship/hooks/session-start.sh`, `FAIL session-start.sh output is not the expected JSON`, `CHECKS FAILED`. No other FAIL lines.

- [ ] **Step 3: Materialise the two files from the spec**

Run:
```bash
scripts/spec-diff.py --write plugins/ship/hooks/commit-convention.md plugins/ship/hooks/session-start.sh
chmod +x plugins/ship/hooks/session-start.sh
scripts/spec-diff.py plugins/ship/hooks/commit-convention.md plugins/ship/hooks/session-start.sh
```
Expected: two `wrote:` lines, then two `match:` lines.

- [ ] **Step 4: Run the hook by hand and inspect its output**

Run:
```bash
CLAUDE_PLUGIN_ROOT="$PWD/plugins/ship" bash plugins/ship/hooks/session-start.sh | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["hookSpecificOutput"]["hookEventName"]); print(d["hookSpecificOutput"]["additionalContext"][:120])'
```
Expected: `SessionStart` then the first 120 characters of the convention, starting `# Commit message convention`.

- [ ] **Step 5: Run `check.sh` and `claude plugin validate`**

Run: `scripts/check.sh 2>&1 | grep -E '^FAIL|PASSED|FAILED'; claude plugin validate plugins/ship`
Expected: `ALL CHECKS PASSED`; validate passes (with the usual no-version warning). A `hooks/` directory without `hooks.json` must not upset validate; if it does, stop and report — do not create `hooks.json` early.

- [ ] **Step 6: Commit**

```bash
git add plugins/ship/hooks/commit-convention.md plugins/ship/hooks/session-start.sh scripts/check.sh
git commit -m "$(cat <<'EOF'
feat(hooks): add the commit convention text and its SessionStart hook

## What

plugins/ship/hooks/commit-convention.md holds the message shape and its
rules. hooks/session-start.sh prints it as SessionStart
additionalContext JSON. scripts/check.sh gains a hooks section that
asserts both files exist and the JSON carries the three section headers.

## Why

- The model should know the shape before its first commit, not learn it
  from a rejection.

## Risk

None. Nothing registers the hook yet (hooks.json is Task 5), so no
session behaviour changes.

Created by KevTheDev
EOF
)"
```

---

### Task 3: The checker, its wrapper, and the fixture harness (core validation)

**Files:**
- Create: `plugins/ship/hooks/check-commit.sh` (spec Appendix A.4, via `--write`)
- Create: `plugins/ship/hooks/check-commit-msg.py`
- Create: `scripts/test-commit-hook.sh`
- Modify: `scripts/check.sh` — append to the `# === hooks ===` section

**Interfaces:**
- Consumes: `plugins/ship/hooks/commit-convention.md` (printed on rejection).
- Produces: `bash plugins/ship/hooks/check-commit.sh` reads a PreToolUse JSON payload on stdin; exit 0 = allow, exit 2 = block with reasons on stderr (format in spec §4.5). Python module-level functions Task 4 will replace or extend: `find_invocations(command) -> list[int]`, `tokenize(command, pos) -> list[tuple[str, bool]]`, `message_from(tokens) -> str | None`, `validate(message) -> list[str]`, `main() -> int`, `heredoc_body(text, start, tag, strip_tabs) -> tuple[str, int]`, `skip_substitution(command, pos) -> int`, exception `Unreadable`.

- [ ] **Step 1: Write the fixture harness with this task's fixtures**

Create `scripts/test-commit-hook.sh`:

```bash
#!/usr/bin/env bash
# Fixture tests for plugins/ship/hooks/check-commit.sh, the commit-convention
# PreToolUse hook.  Each case feeds one PreToolUse payload to the hook and
# asserts its exit code and, for rejections, a substring of stderr.
# Run from anywhere: scripts/test-commit-hook.sh   (exit 0 = all pass)
set -uo pipefail
cd "$(dirname "$0")/.."
HOOK=plugins/ship/hooks/check-commit.sh
export CLAUDE_PLUGIN_ROOT="$PWD/plugins/ship"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/commit-hook-test-XXXXXX"); trap 'rm -rf "$TMP"' EXIT

fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

# payload: read a shell command on stdin, print the PreToolUse JSON for a Bash call running it.
payload() {
  python3 -c 'import json,sys; print(json.dumps({"session_id":"test","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":sys.stdin.read()},"cwd":sys.argv[1]}))' "$PWD"
}
# run <name> <expected-exit> [stderr-substring]: payload JSON on stdin.
run() {
  local name=$1 want=$2 needle=${3:-} err got
  err=$(bash "$HOOK" 2>&1 >/dev/null); got=$?
  if [ "$got" != "$want" ]; then bad "$name: exit $got, expected $want"; [ -n "$err" ] && printf '%s\n' "$err" | head -5; return; fi
  if [ -n "$needle" ] && ! grep -qF -- "$needle" <<<"$err"; then bad "$name: stderr lacks '$needle'"; printf '%s\n' "$err" | head -8; return; fi
  ok "$name"
}
# t <name> <expected-exit> [stderr-substring]: shell command on stdin (usually a heredoc).
t() { local json; json=$(payload); run "$1" "$2" "${3:-}" <<<"$json"; }

echo "=== not a commit ==="
t "npm test" 0 <<'CMD'
npm test
CMD
t "git status && git diff" 0 <<'CMD'
git status && git diff
CMD
t "git commit quoted inside grep" 0 <<'CMD'
grep -rn "git commit -m" scripts/
CMD
t "git commit --amend --no-edit" 0 <<'CMD'
git commit --amend --no-edit
CMD
t "git commit --fixup" 0 <<'CMD'
git commit --fixup HEAD~1
CMD
t "git commit with no message argument" 0 <<'CMD'
git commit
CMD
run "stdin is not JSON" 0 <<<'not json, but it says git commit -m x'
run "tool is not Bash" 0 <<<'{"tool_name":"Read","tool_input":{"file_path":"git commit -m x"}}'

echo "=== conforming messages ==="
t "valid heredoc message" 0 <<'CMD'
git commit -m "$(cat <<'EOF'
feat: add the thing

## What

Adds the thing to the place.

## Why

- We needed the thing.

## Risk

None. Covered by the new unit test.
EOF
)"
CMD
t "valid with scope, bang, ref and trailer" 0 <<'CMD'
git commit -q -m "$(cat <<'EOF'
fix(stores)!: move MenuService to @aws-sdk/client-s3 (BEV-123)

## What

MenuService imports @aws-sdk/client-s3 instead of aws-sdk v2.

## Why

- MenuUploadApi could not cold-start: the runtime layer lacks aws-sdk v2.

## Risk

Low. Keys, bodies and returned URLs are unchanged; offline suite added.

Created by KevTheDev
EOF
)"
CMD
t "valid via two -m" 0 <<'CMD'
git commit -m "chore: tidy the thing (#42)" -m "$(cat <<'EOF'
## What

Tidies it.

## Why

- It was untidy.

## Risk

None. Whitespace only.
EOF
)"
CMD
t "valid via git -C" 0 <<'CMD'
git -C /tmp/repo commit -m "$(cat <<'EOF'
docs: explain the thing

## What

Explains it in the README.

## Why

- Nobody understood it.

## Risk

None. Docs only.
EOF
)"
CMD
t "valid, chained with &&" 0 <<'CMD'
git add a.txt && git commit -m "$(cat <<'EOF'
test: cover the thing

## What

Adds a test for it.

## Why

- It had none.

## Risk

None. Test only.
EOF
)" && git log -1 --oneline
CMD

echo "=== rejected messages ==="
t "subject without type" 2 "subject: must be" <<'CMD'
git commit -m "$(cat <<'EOF'
Final review fixes: README note

## What

Fixes.

## Why

- Review.

## Risk

None.
EOF
)"
CMD
t "subject over 72 characters" 2 "limit is 72" <<'CMD'
git commit -m "$(cat <<'EOF'
feat: add a very long subject line that keeps going well past the limit, on and on

## What

Adds.

## Why

- Because.

## Risk

None.
EOF
)"
CMD
t "subject with trailing period" 2 "trailing period" <<'CMD'
git commit -m "$(cat <<'EOF'
feat: add the thing.

## What

Adds.

## Why

- Because.

## Risk

None.
EOF
)"
CMD
t "no blank line after subject" 2 "line 2 must be blank" <<'CMD'
git commit -m "$(cat <<'EOF'
feat: add the thing
## What

Adds.

## Why

- Because.

## Risk

None.
EOF
)"
CMD
t "missing Risk" 2 'missing "## Risk"' <<'CMD'
git commit -m "$(cat <<'EOF'
feat: add the thing

## What

Adds.

## Why

- Because.
EOF
)"
CMD
t "sections out of order" 2 "order What, Why, Risk" <<'CMD'
git commit -m "$(cat <<'EOF'
feat: add the thing

## What

Adds.

## Risk

None.

## Why

- Because.
EOF
)"
CMD
t "empty Why" 2 '"## Why" is empty' <<'CMD'
git commit -m "$(cat <<'EOF'
feat: add the thing

## What

Adds.

## Why

## Risk

None.
EOF
)"
CMD
t "What twice" 2 '"## What" appears twice' <<'CMD'
git commit -m "$(cat <<'EOF'
feat: add the thing

## What

Adds.

## What

Adds again.

## Why

- Because.

## Risk

None.
EOF
)"
CMD
t "one-line message" 2 'missing "## What"' <<'CMD'
git commit -m "feat: add thing"
CMD
t "rejection prints the convention" 2 "## Risk" <<'CMD'
git commit -m "feat: add thing"
CMD

if [ "$fail" -eq 0 ]; then echo "HOOK TESTS PASSED"; else echo "HOOK TESTS FAILED"; exit 1; fi
```

Then `chmod +x scripts/test-commit-hook.sh`.

- [ ] **Step 2: Run the harness to see it fail**

Run: `scripts/test-commit-hook.sh 2>&1 | tail -30`
Expected: every case prints `FAIL … exit 127, expected …` (the hook script does not exist yet) or similar, ending `HOOK TESTS FAILED`.

- [ ] **Step 3: Materialise the wrapper from the spec**

Run:
```bash
scripts/spec-diff.py --write plugins/ship/hooks/check-commit.sh && chmod +x plugins/ship/hooks/check-commit.sh
scripts/spec-diff.py plugins/ship/hooks/check-commit.sh
```
Expected: `wrote:` then `match:`.

- [ ] **Step 4: Write the checker**

Create `plugins/ship/hooks/check-commit-msg.py` with exactly this content (Task 4 will replace `find_invocations`, `message_from` and `main` and add `masked_ranges`; everything else is final):

```python
#!/usr/bin/env python3
"""PreToolUse hook for Bash: reject `git commit` commands whose message does not
follow the ship commit convention (commit-convention.md, next to this file).

stdin: the PreToolUse JSON payload.  exit 0 = allow.  exit 2 = block; the
reasons and the convention go to stderr.  Anything unexpected exits 0 (fail
open): a bug here must never block every Bash call.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CONVENTION = os.path.join(HERE, "commit-convention.md")

TYPES = "feat|fix|chore|docs|refactor|test|perf|build|ci|style|revert"
SUBJECT_RE = re.compile(r"^(" + TYPES + r")(\([^()\s]+\))?!?: \S")
SUBJECT_MAX = 72
HEADERS = ("## What", "## Why", "## Risk")

# `git [global options] commit` in command position: at the start, or right
# after ; & | ( { a newline or $( .  A quote before `git` means it is text.
COMMIT_RE = re.compile(
    r"(?:^|[;&|({\n]|\$\()\s*(git)\s+(?:(?:-C|-c)\s+\S+\s+|--[\w-]+(?:=\S+)?\s+)*commit(?![\w-])"
)
# $(cat <<'TAG'  -- the one command substitution the hook can read.
CAT_HEREDOC_RE = re.compile(r"\$\(\s*cat\s+<<(-?)\s*(['\"]?)(\w+)\2[^\n]*\n")


class Unreadable(Exception):
    """A message exists but the hook cannot recover its text."""


def heredoc_body(text, start, tag, strip_tabs):
    """Body of a heredoc whose first body line starts at `start`.
    Returns (body, index just after the terminator line)."""
    lines, pos = [], start
    while pos < len(text):
        nl = text.find("\n", pos)
        line = text[pos:] if nl == -1 else text[pos:nl]
        if strip_tabs:
            line = line.lstrip("\t")
        if line == tag:
            return "\n".join(lines), (len(text) if nl == -1 else nl + 1)
        lines.append(line)
        if nl == -1:
            break
        pos = nl + 1
    return "\n".join(lines), len(text)


def skip_substitution(command, pos):
    """`pos` is at the `$` of a `$(`; return the index after its matching `)`."""
    depth, pos = 0, pos + 1
    while pos < len(command):
        if command[pos] == "(":
            depth += 1
        elif command[pos] == ")":
            depth -= 1
            if depth == 0:
                return pos + 1
        pos += 1
    raise Unreadable()


def find_invocations(command):
    """Index just after each `commit` word that starts a git commit command."""
    return [m.end() for m in COMMIT_RE.finditer(command)]


def tokenize(command, pos):
    """The arguments of one invocation as (text, readable) pairs, up to the end
    of that shell command.  `readable` is False when the shell would compute
    the text (command substitution, backticks) and the hook therefore cannot."""
    tokens, n = [], len(command)
    while True:
        while pos < n and command[pos] in " \t":
            pos += 1
        if pos >= n or command[pos] in ";|\n" or command.startswith(("&&", "||"), pos):
            return tokens
        word, readable = [], True
        while pos < n and command[pos] not in " \t\n;|":
            ch = command[pos]
            if ch == "&" and command.startswith("&&", pos):
                break
            if ch == "'":
                end = command.find("'", pos + 1)
                if end == -1:
                    raise Unreadable()
                word.append(command[pos + 1:end])
                pos = end + 1
            elif ch == '"':
                pos += 1
                while pos < n and command[pos] != '"':
                    c = command[pos]
                    if c == "\\" and pos + 1 < n and command[pos + 1] in '"\\$`':
                        word.append(command[pos + 1])
                        pos += 2
                    elif command.startswith("$(", pos):
                        m = CAT_HEREDOC_RE.match(command, pos)
                        if m is None:
                            readable = False
                            pos = skip_substitution(command, pos)
                        else:
                            body, pos = heredoc_body(command, m.end(), m.group(3), m.group(1) == "-")
                            word.append(body)
                            close = command.find(")", pos)
                            if close == -1:
                                raise Unreadable()
                            pos = close + 1
                    elif c == "`":
                        readable = False
                        pos += 1
                    else:
                        word.append(c)
                        pos += 1
                if pos >= n:
                    raise Unreadable()
                pos += 1
            elif command.startswith("$(", pos):
                readable = False
                pos = skip_substitution(command, pos)
            elif ch == "`":
                readable = False
                pos += 1
            elif ch == "\\" and pos + 1 < n:
                word.append(command[pos + 1])
                pos += 2
            else:
                word.append(ch)
                pos += 1
        tokens.append(("".join(word), readable))


def message_from(tokens):
    """The message an invocation passes with -m/--message, or None if it has none."""
    parts = []
    i = 0
    while i < len(tokens):
        text, _readable = tokens[i]
        nxt = tokens[i + 1][0] if i + 1 < len(tokens) else None
        if text.startswith("--message"):
            name, eq, val = text.partition("=")
            if name == "--message":
                if eq:
                    parts.append(val)
                elif nxt is not None:
                    parts.append(nxt)
                    i += 1
        elif text.startswith("-") and not text.startswith("--") and "m" in text[1:]:
            rest = text[text.index("m", 1) + 1:]
            if rest:
                parts.append(rest)
            elif nxt is not None:
                parts.append(nxt)
                i += 1
        i += 1
    return "\n\n".join(parts) if parts else None


def validate(message):
    """Problems with a commit message under the convention; empty when it conforms."""
    problems = []
    lines = message.rstrip("\n").split("\n")
    subject = lines[0]
    if not SUBJECT_RE.match(subject):
        problems.append('subject: must be "<type>(<scope>)?: <summary> (<ref>)?", got "%s"' % subject)
    if len(subject) > SUBJECT_MAX:
        problems.append("subject: %d characters, limit is %d" % (len(subject), SUBJECT_MAX))
    if subject.rstrip().endswith("."):
        problems.append("subject: no trailing period")
    if len(lines) > 1 and lines[1].strip():
        problems.append("body: line 2 must be blank")
    where = {h: [i for i, l in enumerate(lines) if l.rstrip() == h] for h in HEADERS}
    for h in HEADERS:
        if not where[h]:
            problems.append('body: missing "%s"' % h)
        elif len(where[h]) > 1:
            problems.append('body: "%s" appears twice' % h)
    firsts = [where[h][0] for h in HEADERS if where[h]]
    if len(firsts) == len(HEADERS) and firsts != sorted(firsts):
        problems.append("body: sections must be in the order What, Why, Risk")
    header_lines = sorted(i for h in HEADERS for i in where[h])
    for h in HEADERS:
        for start in where[h]:
            end = next((i for i in header_lines if i > start), len(lines))
            if not any(l.strip() for l in lines[start + 1:end]):
                problems.append('body: "%s" is empty' % h)
    return problems


def reject(problems):
    try:
        with open(CONVENTION, encoding="utf-8") as fh:
            convention = fh.read()
    except OSError:
        convention = "(commit-convention.md is missing)\n"
    sys.stderr.write("ship commit convention: commit message rejected.\n")
    for p in problems:
        sys.stderr.write("  - " + p + "\n")
    sys.stderr.write("Fix the message and run the commit again. The convention:\n\n")
    sys.stderr.write(convention)


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    if not isinstance(payload, dict) or payload.get("tool_name") != "Bash":
        return 0
    command = (payload.get("tool_input") or {}).get("command")
    if not isinstance(command, str):
        return 0
    problems = []
    for pos in find_invocations(command):
        message = message_from(tokenize(command, pos))
        if message is not None:
            problems.extend(validate(message))
    if not problems:
        return 0
    reject(problems)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # fail open: a bug here must never block Bash
        sys.stderr.write("ship commit hook: internal error, allowing the command: %r\n" % (exc,))
        sys.exit(0)
```

Then `chmod +x plugins/ship/hooks/check-commit-msg.py`.

- [ ] **Step 5: Run the harness until it passes**

Run: `scripts/test-commit-hook.sh`
Expected: 23 `ok` lines and `HOOK TESTS PASSED`. If a case fails, read its printed stderr, fix the checker (not the fixture: the fixtures are the spec's §6 matrix), and rerun. Two cases worth knowing about: "git commit quoted inside grep" passes because the `"` before `git` fails `COMMIT_RE`'s command-position prefix; "subject over 72 characters" has an 82-character subject that still matches `SUBJECT_RE`, so its only problem is the length.

- [ ] **Step 6: Try the hook from a real shell, once, to see the rejection text**

Run:
```bash
python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"git commit -m \"wip\""}}))' | bash plugins/ship/hooks/check-commit.sh; echo "exit=$?"
```
Expected on stderr: `ship commit convention: commit message rejected.`, three `  - body: missing "## …"` lines and one `  - subject: must be …` line, then `Fix the message and run the commit again. The convention:` and the full convention; `exit=2`.

- [ ] **Step 7: Extend `check.sh`**

In `scripts/check.sh`, inside the `# === hooks ===` section, after the `session-start.sh` check's closing `fi`, add:

```bash
for f in check-commit.sh check-commit-msg.py; do need_file "$H/$f"; done
if python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$H/check-commit-msg.py" 2>/dev/null; then ok "check-commit-msg.py parses"; else bad "check-commit-msg.py does not parse"; fi
hout=$(mktemp)
if scripts/test-commit-hook.sh >"$hout" 2>&1; then ok "scripts/test-commit-hook.sh"; else bad "scripts/test-commit-hook.sh"; grep -E '^FAIL' "$hout"; fi
rm -f "$hout"
```

Run: `scripts/check.sh 2>&1 | grep -E '^FAIL|PASSED|FAILED'; claude plugin validate plugins/ship; ls plugins/ship/hooks`
Expected: `ALL CHECKS PASSED`; validate passes; the listing shows exactly `check-commit-msg.py check-commit.sh commit-convention.md session-start.sh` and no `__pycache__`.

- [ ] **Step 8: Commit**

```bash
git add plugins/ship/hooks/check-commit.sh plugins/ship/hooks/check-commit-msg.py scripts/test-commit-hook.sh scripts/check.sh
git commit -m "$(cat <<'EOF'
feat(hooks): add the commit message checker with its fixture tests

## What

hooks/check-commit-msg.py reads a PreToolUse payload, finds git commit
invocations in command position, recovers the -m message (quoted or a
cat heredoc, one or several -m) and checks the subject type, the
72-character limit, the trailing period, the blank second line and the
What/Why/Risk sections. hooks/check-commit.sh is the bash fast path in
front of it. scripts/test-commit-hook.sh runs 23 fixtures through the
wrapper; check.sh runs that harness and a syntax check.

## Why

- Structure has to be enforced, not only requested; the checker is the
  backstop behind the session-start note.

## Risk

Low. Not registered in hooks.json yet, so it runs only under the tests.
Any internal error exits 0 and lets the command through.

Created by KevTheDev
EOF
)"
```

---

### Task 4: Checker hardening — heredoc masking, `-F`, skips, unreadable messages

**Files:**
- Modify: `plugins/ship/hooks/check-commit-msg.py` — replace `find_invocations`, `message_from`, `main`; add `HEREDOC_RE`, `UNREADABLE`, `SKIP_LONG`, `masked_ranges`; extend `tokenize` so a `$NAME`/`${NAME}` expansion marks its token unreadable (Task 3 review ruling)
- Modify: `scripts/test-commit-hook.sh` — add a fixture section before the final PASSED/FAILED line

**Interfaces:**
- Consumes: Task 3's module.
- Produces: final checker behaviour per spec §5. `message_from(tokens, cwd)` now takes `cwd` and may raise `Unreadable`; `find_invocations` ignores heredoc bodies; `tokenize` marks `$NAME`/`${NAME}` expansions unreadable.

- [ ] **Step 1: Add the fixtures**

In `scripts/test-commit-hook.sh`, insert this block on the line before `if [ "$fail" -eq 0 ]; then echo "HOOK TESTS PASSED" …`:

```bash
echo "=== reading the message ==="
t "git commit inside a heredoc being written to a file" 0 <<'CMD'
cat > docs/plan.md <<'EOF'
Then commit:

git commit -m "bad message"
EOF
CMD
t "body line starting with git commit is not an invocation" 0 <<'CMD'
git commit -m "$(cat <<'EOF'
feat: add the hook

## What

git commit -m "anything" is now checked by a hook.

## Why

- Messages were unstructured.

## Risk

None. Fail-open on internal errors.
EOF
)"
CMD
printf 'chore: message from a file\n\n## What\n\nFrom a file.\n\n## Why\n\n- Testing -F.\n\n## Risk\n\nNone.\n' >"$TMP/good.txt"
t "valid via -F file" 0 <<CMD
git commit -F $TMP/good.txt
CMD
t "-F file that does not exist" 2 "could not be read" <<'CMD'
git commit -F /nonexistent/message.txt
CMD
t "-F - (stdin)" 2 "could not be read" <<'CMD'
git commit -F -
CMD
t "message from command substitution" 2 "could not be read" <<'CMD'
git commit -m "$(git log -1 --format=%s)"
CMD
t "message from backticks" 2 "could not be read" <<'CMD'
git commit -m "`date`"
CMD
t "message from a shell variable" 2 "could not be read" <<'CMD'
git commit -m "$MSG"
CMD
t "-c reuses a message" 0 <<'CMD'
git commit -c HEAD~1
CMD
t "--amend with a conforming message" 0 <<'CMD'
git commit --amend -m "$(cat <<'EOF'
fix: correct the thing

## What

Corrects it.

## Why

- It was wrong.

## Risk

None. Same test still passes.
EOF
)"
CMD
t "--amend with a bad message" 2 "subject: must be" <<'CMD'
git commit --amend -m "oops"
CMD

```

- [ ] **Step 2: Run the harness to see the new cases fail**

Run: `scripts/test-commit-hook.sh 2>&1 | grep -E '^FAIL|PASSED|FAILED'`
Expected FAIL lines, exactly these seven:
- `git commit inside a heredoc being written to a file: exit 2, expected 0`
- `body line starting with git commit is not an invocation: exit 2, expected 0`
- `-F file that does not exist: exit 0, expected 2`
- `-F - (stdin): exit 0, expected 2`
- `message from command substitution: stderr lacks 'could not be read'` (it is rejected, but for the wrong reason)
- `message from backticks: stderr lacks 'could not be read'`
- `message from a shell variable: stderr lacks 'could not be read'` (validated as the literal text `$MSG`, so rejected for the wrong reason)
and `HOOK TESTS FAILED`. ("valid via -F file" passes already because Task 3 ignores `-F` entirely; that changes below.)

- [ ] **Step 3: Add heredoc masking**

In `check-commit-msg.py`, after the `CAT_HEREDOC_RE = …` line add:

```python
# Any heredoc opener (not a <<< here-string).  Its body is content, not commands.
HEREDOC_RE = re.compile(r"(?<!<)<<(?!<)(-?)\s*(['\"]?)(\w+)\2")

UNREADABLE = "message could not be read; pass it with -m \"$(cat <<'EOF' ... EOF)\""
SKIP_LONG = ("--fixup", "--squash", "--reuse-message", "--reedit-message")
```

Replace `find_invocations` with:

```python
def masked_ranges(text):
    """Character ranges that are heredoc bodies: file content, not commands."""
    ranges = []
    for m in HEREDOC_RE.finditer(text):
        nl = text.find("\n", m.end())
        if nl == -1:
            continue
        _body, end = heredoc_body(text, nl + 1, m.group(3), m.group(1) == "-")
        ranges.append((nl + 1, end))
    return ranges


def find_invocations(command):
    """Index just after each `commit` word that starts a git commit command.
    A `git commit` inside a heredoc body opened earlier is content being
    written to a file (or a message body), not a command, and is skipped."""
    masks = masked_ranges(command)
    found = []
    for m in COMMIT_RE.finditer(command):
        git_at = m.start(1)
        if any(a <= git_at < b for a, b in masks):
            continue
        found.append(m.end())
    return found
```

- [ ] **Step 4: Replace `message_from`**

```python
def message_from(tokens, cwd):
    """The message an invocation will use, or None when the hook does not judge
    it: --amend --no-edit, --fixup/--squash, -C/-c (reuse a message), or no
    message argument at all.  Raises Unreadable when a message exists that
    the hook cannot recover."""
    parts, files = [], []
    amend = no_edit = False
    i = 0
    while i < len(tokens):
        text, readable = tokens[i]
        nxt = tokens[i + 1] if i + 1 < len(tokens) else None
        if text.startswith("--"):
            name, eq, val = text.partition("=")
            if name in SKIP_LONG:
                return None
            if name == "--amend":
                amend = True
            elif name == "--no-edit":
                no_edit = True
            elif name in ("--message", "--file"):
                if eq:
                    value = (val, readable)
                elif nxt is not None:
                    value = nxt
                    i += 1
                else:
                    return None
                (parts if name == "--message" else files).append(value)
        elif text.startswith("-") and len(text) > 1:
            for j, ch in enumerate(text[1:], 1):
                if ch in "Cc":
                    return None
                if ch in "mF":
                    rest = text[j + 1:]
                    if rest:
                        value = (rest, readable)
                    elif nxt is not None:
                        value = nxt
                        i += 1
                    else:
                        return None
                    (parts if ch == "m" else files).append(value)
                    break
        i += 1
    if (amend and no_edit) or not (parts or files):
        return None
    texts = []
    for text, readable in parts:
        if not readable:
            raise Unreadable()
        texts.append(text)
    for text, readable in files:
        if not readable or text == "-":
            raise Unreadable()
        path = text if os.path.isabs(text) else os.path.join(cwd, text)
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                texts.append(fh.read())
        except OSError:
            raise Unreadable()
    return "\n\n".join(texts)
```

- [ ] **Step 5: Replace `main`**

```python
def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    if not isinstance(payload, dict) or payload.get("tool_name") != "Bash":
        return 0
    command = (payload.get("tool_input") or {}).get("command")
    if not isinstance(command, str):
        return 0
    cwd = payload.get("cwd") or os.getcwd()
    problems = []
    for pos in find_invocations(command):
        try:
            message = message_from(tokenize(command, pos), cwd)
        except Unreadable:
            problems.append(UNREADABLE)
            continue
        if message is not None:
            problems.extend(validate(message))
    if not problems:
        return 0
    reject(problems)
    return 2
```

- [ ] **Step 5b: Make `tokenize` treat shell variables as unreadable**

Task 3's review found that `git commit -m "$MSG"` was validated as the literal text `$MSG` and rejected with a misleading subject error. The hook cannot see the variable's value, so the honest answer is the same as for `$(...)`: unreadable, block with the heredoc guidance. In `tokenize`, inside the double-quote loop, directly after the `elif command.startswith("$(", pos):` branch (the one that ends with `pos = close + 1`) and before `elif c == "`":`, add:

```python
                    elif c == "$" and pos + 1 < n and (command[pos + 1].isalnum() or command[pos + 1] in "_{@*#?!$-"):
                        readable = False
                        pos += 1
```

And in the unquoted branch, directly after the `elif command.startswith("$(", pos):` branch (the one that calls `skip_substitution`) and before `elif ch == "`":`, add:

```python
            elif ch == "$" and pos + 1 < n and (command[pos + 1].isalnum() or command[pos + 1] in "_{@*#?!$-"):
                readable = False
                pos += 1
```

The `$` is consumed and the name characters after it are collected as ordinary text; the token is flagged unreadable, and `message_from` (Step 4) turns that into `Unreadable` → `could not be read`. A `$` followed by a space, a quote, or the end of the string stays literal, as in bash.

- [ ] **Step 6: Run the harness and `check.sh`**

Run: `scripts/test-commit-hook.sh 2>&1 | grep -E '^FAIL|PASSED|FAILED'; scripts/check.sh 2>&1 | grep -E '^FAIL|PASSED|FAILED'`
Expected: `HOOK TESTS PASSED` (34 cases) and `ALL CHECKS PASSED`. If "git commit inside a heredoc being written to a file" still fails, print `masked_ranges(command)` for that fixture: the range must start on the line after `<<'EOF'` and end after the `EOF` line, and `m.start(1)` of the inner `git` must fall inside it.

- [ ] **Step 7: Commit**

```bash
git add plugins/ship/hooks/check-commit-msg.py scripts/test-commit-hook.sh
git commit -m "$(cat <<'EOF'
fix(hooks): mask heredocs, read -F, refuse unreadable messages

## What

check-commit-msg.py skips a git commit that sits inside a heredoc body
opened earlier (file content or a message body, not a command), reads
-F/--file messages relative to the payload's cwd, leaves --amend
--no-edit, --fixup/--squash and -C/-c alone, and rejects a message the
shell would compute ($(...), backticks, $VAR, -F -) with a "could not be
read" reason. Eleven fixtures added to scripts/test-commit-hook.sh.

## Why

- Writing a plan or doc that quotes a commit command must not be blocked.
- A message the hook cannot see must not pass unchecked.

## Risk

Low. All 34 fixtures pass; internal errors still exit 0.

Created by KevTheDev
EOF
)"
```

---

### Task 5: Register the hooks

**Files:**
- Create: `plugins/ship/hooks/hooks.json` (spec Appendix A.1, via `--write`)
- Modify: `scripts/check.sh` — append to the `# === hooks ===` section

**Interfaces:**
- Consumes: `session-start.sh` (Task 2), `check-commit.sh` (Tasks 3–4).
- Produces: the live feature. From this commit on, a session with `ship` loaded runs both hooks.

- [ ] **Step 1: Add the failing check**

In `scripts/check.sh`, at the end of the `# === hooks ===` section (after the `rm -f "$hout"` line), add:

```bash
need_file "$H/hooks.json"
if python3 - <<'PY'
import json, os, re
h = json.load(open('plugins/ship/hooks/hooks.json'))['hooks']
ss, pt = h['SessionStart'], h['PreToolUse']
assert len(ss) == 1 and ss[0]['matcher'] == 'startup|clear|compact', ss
assert len(pt) == 1 and pt[0]['matcher'] == 'Bash', pt
for ev in ss + pt:
    for hk in ev['hooks']:
        assert hk['type'] == 'command' and hk.get('timeout') == 10 and not hk.get('async'), hk
        paths = re.findall(r'\$\{CLAUDE_PLUGIN_ROOT\}(/\S+?)"', hk['command'])
        assert paths, hk['command']
        for p in paths:
            assert os.path.isfile('plugins/ship' + p), p
PY
then ok "hooks.json registers SessionStart(startup|clear|compact) and PreToolUse(Bash) with existing scripts"; else bad "hooks.json does not match the spec"; fi
```

Run: `scripts/check.sh 2>&1 | grep -E '^FAIL|PASSED|FAILED'`
Expected: `FAIL missing plugins/ship/hooks/hooks.json`, `FAIL hooks.json does not match the spec`, `CHECKS FAILED`.

- [ ] **Step 2: Materialise `hooks.json`**

Run:
```bash
scripts/spec-diff.py --write plugins/ship/hooks/hooks.json && scripts/spec-diff.py plugins/ship/hooks/hooks.json
scripts/check.sh 2>&1 | grep -E '^FAIL|PASSED|FAILED'
claude plugin validate plugins/ship
```
Expected: `wrote:` and `match:`; `ALL CHECKS PASSED`; validate passes. If validate rejects `hooks.json`, read its message: the schema is `{"description": …, "hooks": {"<Event>": [{"matcher": …, "hooks": [{"type": "command", "command": …, "timeout": 10}]}]}}`. Do not change the file to satisfy validate without also changing spec A.1 and saying so in the commit.

- [ ] **Step 3: Prove the hooks load in a real session**

Run, from the repo root:
```bash
claude --plugin-dir plugins/ship -p "Output only the first line of the commit message convention you were given at session start, nothing else." --output-format text
```
Expected: `# Commit message convention`. Then:
```bash
SCRATCH=$(mktemp -d) && git -C "$SCRATCH" init -q -b main && git -C "$SCRATCH" config user.email t@example.com && git -C "$SCRATCH" config user.name t && echo hi >"$SCRATCH/a.txt" && git -C "$SCRATCH" add a.txt
(cd "$SCRATCH" && claude --plugin-dir "$OLDPWD/plugins/ship" -p 'Run exactly this command, unchanged: git commit -m "wip". If it is blocked or fails, do not retry or change it; report the first line of the error in one sentence.' --output-format text --allowedTools 'Bash(git commit:*)')
git -C "$SCRATCH" rev-list --count HEAD 2>/dev/null || echo "no commits"
rm -rf "$SCRATCH"
```
Expected: the model reports the commit was rejected by the ship commit convention, and `no commits` (or `0`). If a commit was made, the PreToolUse hook did not run: stop and report before committing this task.

- [ ] **Step 4: Commit**

```bash
git add plugins/ship/hooks/hooks.json scripts/check.sh
git commit -m "$(cat <<'EOF'
feat(hooks): register the SessionStart and PreToolUse hooks

## What

plugins/ship/hooks/hooks.json runs session-start.sh on
startup|clear|compact and check-commit.sh on every Bash call, each with
a 10-second timeout. check.sh asserts the manifest's shape and that each
command's script exists.

## Why

- This is the switch: from here, every session with ship enabled is
  handed the convention and every git commit is checked against it.

## Risk

Medium: applies to all Bash calls in every repo where ship is enabled.
Mitigated by the bash fast path (python runs only when the command
mentions git and commit), fail-open on internal errors, and a live check
that a bad commit is blocked with --plugin-dir. claude plugin validate
passes.

Created by KevTheDev
EOF
)"
```

---

### Task 6: Skills commit once; agents don't

**Files:**
- Modify: `plugins/ship/skills/new-feature/SKILL.md` (spec A.5, via `--write`)
- Modify: `plugins/ship/skills/hotfix/SKILL.md` (spec A.6, via `--write`)
- Modify: `plugins/ship/agents/front-end-ios-engineer.md` (A.7), `front-end-android-engineer.md` (A.8), `front-end-web-developer.md` (A.9), `backend-engineer.md` (A.10), via `--write`
- Modify: `scripts/check.sh` — reference counts and new assertions in `# === orchestrating skills ===`

**Interfaces:**
- Consumes: the live hooks (Task 5), which the skills' commit step relies on for enforcement.
- Produces: `/ship:new-feature` and `/ship:hotfix` end with one commit; implementing agents never commit.

- [ ] **Step 1: Update `check.sh` first**

In `scripts/check.sh`, change these four `expect_refs` lines:

```bash
expect_refs $S/new-feature/SKILL.md qa-tester 3
expect_refs $S/new-feature/SKILL.md tech-lead-reviewer 3
```
(were `2` and `2`), and replace the hotfix block
```bash
for r in solutions-architect front-end-ios-engineer front-end-android-engineer front-end-web-developer backend-engineer qa-tester ba-intake projma; do
  expect_refs $S/hotfix/SKILL.md $r 1
done
expect_refs $S/hotfix/SKILL.md tech-lead-reviewer 2
```
with
```bash
for r in solutions-architect front-end-ios-engineer front-end-android-engineer front-end-web-developer backend-engineer ba-intake projma; do
  expect_refs $S/hotfix/SKILL.md $r 1
done
expect_refs $S/hotfix/SKILL.md qa-tester 2
expect_refs $S/hotfix/SKILL.md tech-lead-reviewer 3
```
Then, directly after that, add:

```bash
# Final commit step (spec 2026-09-05 §4.6): stage by name, message from the staged diff, never push.
for s in new-feature hotfix; do
  f="$S/$s/SKILL.md"; [ -f "$f" ] || continue
  for must in 'git status' 'git diff --staged' '## What' '## Why' '## Risk' 'Never `git add -A`' 'short SHA'; do
    grep -qF -- "$must" "$f" || bad "$f: commit step must mention '$must'"
  done
  if grep -q 'git push' "$f"; then bad "$f: must not mention git push"; else ok "$f: commit step present, no git push"; fi
done
for a in front-end-ios-engineer front-end-android-engineer front-end-web-developer backend-engineer; do
  f="$A/$a.md"; [ -f "$f" ] || continue
  if grep -q "Don't commit, branch or" "$f"; then ok "$f: tells the agent not to commit"; else bad "$f: missing the don't-commit line"; fi
done
```

Run: `scripts/check.sh 2>&1 | grep -E '^FAIL|PASSED|FAILED'`
Expected: FAIL lines for the four changed reference counts, seven `commit step must mention` lines per skill, four `missing the don't-commit line`, and `CHECKS FAILED`.

- [ ] **Step 2: Materialise the six files**

Run:
```bash
F="plugins/ship/skills/new-feature/SKILL.md plugins/ship/skills/hotfix/SKILL.md plugins/ship/agents/front-end-ios-engineer.md plugins/ship/agents/front-end-android-engineer.md plugins/ship/agents/front-end-web-developer.md plugins/ship/agents/backend-engineer.md"
scripts/spec-diff.py --write $F && scripts/spec-diff.py $F
git diff --stat
```
Expected: six `wrote:` then six `match:` lines. The diffstat shows the two skills gaining a paragraph and a changed description line, and each agent gaining two lines.

- [ ] **Step 3: Read the diff of one skill and one agent**

Run: `git diff plugins/ship/skills/hotfix/SKILL.md plugins/ship/agents/backend-engineer.md`
Expected: the hotfix diff adds the "Then commit — once, yourself…" paragraph and moves "tell the user it's ready for their final check" to the end of it; the backend diff adds "Don't commit, branch or push — the calling skill commits once at the end." Nothing else changes. If anything else changed, the spec appendix drifted from the files: stop and report.

- [ ] **Step 4: Run everything**

Run: `scripts/check.sh 2>&1 | grep -E '^FAIL|PASSED|FAILED'; claude plugin validate plugins/ship`
Expected: `ALL CHECKS PASSED`; validate passes.

- [ ] **Step 5: Commit**

```bash
git add plugins/ship/skills/new-feature/SKILL.md plugins/ship/skills/hotfix/SKILL.md plugins/ship/agents/front-end-ios-engineer.md plugins/ship/agents/front-end-android-engineer.md plugins/ship/agents/front-end-web-developer.md plugins/ship/agents/backend-engineer.md scripts/check.sh
git commit -m "$(cat <<'EOF'
feat: commit once at the end of new-feature and hotfix

## What

new-feature and hotfix now end by staging the ticket's files by name
after git status and making one commit in the convention, written from
git diff --staged with the ticket ID as ref, then posting the short SHA
as the final sign-off comment. The four implementing agents are told
not to commit, branch or push. check.sh reference counts and assertions
follow.

## Why

- The workflows ended with a dirty tree and left committing to the user.
- One commit per ticket, made by the orchestrator, keeps the sign-off
  log and the code together and stops a subagent committing mid-flow.

## Risk

Low. The skills never push, branch, amend or reset. spec-diff matches
all six files against the 2026-09-05 spec.

Created by KevTheDev
EOF
)"
```

---

### Task 7: README and end-to-end smoke test

**Files:**
- Modify: `README.md`
- Modify: `scripts/smoke.sh` — insert `# === 3. hooks ===` before the final PASSED/FAILED line

**Interfaces:**
- Consumes: everything above.
- Produces: user-facing documentation; a smoke test that proves Claude Code runs both hooks.

- [ ] **Step 1: Add the smoke section**

In `scripts/smoke.sh`, insert this block on the line before `if [ "$fail" -eq 0 ]; then echo "SMOKE PASSED" …`:

```bash
echo "=== 3. hooks ==="
git -C "$SCRATCH" config user.email smoke@example.com
git -C "$SCRATCH" config user.name smoke
GITALLOW="$ALLOW,Bash(git commit:*),Bash(git log:*),Bash(git status:*),Bash(git diff:*)"
grun() { (cd "$SCRATCH" && claude --plugin-dir "$PLUGIN" -p "$1" --output-format text --permission-mode acceptEdits --allowedTools "$GITALLOW" 2>/dev/null); }

hdr=$(run "Which three '##' sections must a commit message body have, according to the commit message convention you were given at session start? Output only the three headers, one per line, nothing else.")
echo "$hdr"
for w in What Why Risk; do
  if grep -q "$w" <<<"$hdr"; then ok "session-start hook: model knows section $w"; else bad "session-start hook: '$w' missing from the model's answer"; fi
done

echo "smoke" >"$SCRATCH/smoke.txt"; git -C "$SCRATCH" add smoke.txt
out=$(grun 'Run exactly this command, unchanged: git commit -m "bad message". If it is blocked or fails, do not retry and do not change the message; report the outcome in one sentence.'); echo "$out"
if [ "$(git -C "$SCRATCH" rev-list --count HEAD 2>/dev/null || echo 0)" = "0" ]; then ok "PreToolUse hook blocked the bad commit"; else bad "a commit was made despite the bad message"; fi
if grep -qiE 'convention|reject|blocked' <<<"$out"; then ok "model reported the rejection"; else warn "model's report did not mention the rejection"; fi

out=$(grun 'Commit the already-staged file smoke.txt with a message that follows the commit message convention from your session-start notes; use type chore. Do not push.'); echo "$out"
if [ "$(git -C "$SCRATCH" rev-list --count HEAD 2>/dev/null || echo 0)" = "1" ]; then ok "conforming commit landed"; else bad "expected exactly one commit after the conforming attempt"; fi
if git -C "$SCRATCH" log -1 --format=%B 2>/dev/null | grep -q '^## Risk'; then ok "commit body has ## Risk"; else bad "commit body lacks ## Risk"; fi

```

- [ ] **Step 2: Run the smoke test**

Run: `scripts/smoke.sh 2>&1 | grep -E '^(ok|FAIL|WARN|===)|PASSED|FAILED'`
Expected: sections 1 and 2 unchanged, then in section 3: three `ok session-start hook…`, `ok PreToolUse hook blocked the bad commit`, `ok model reported the rejection` (a WARN here is acceptable), `ok conforming commit landed`, `ok commit body has ## Risk`, and `SMOKE PASSED`. This takes a few minutes; each `claude -p` call is a real model call. If "conforming commit landed" fails because the model made zero commits, print `$out`: the model may have been rejected once and given up; rerun once before treating it as a bug.

- [ ] **Step 3: Update the README**

In `README.md`:

1. Replace the `ship` table row's description with:
```
A role-based dev team: ticket intake, architecture, platform engineers, QA and tech-lead review, run by `/ship:new-ticket`, `/ship:new-feature` and `/ship:hotfix`. Falls back to a file tracker (`/ship:projma`) when Linear isn't connected. Teaches and enforces a What / Why / Risk [commit convention](#commit-convention) in every repo where it's enabled.
```
2. Replace the `/ship:new-feature` bullet's last two sentences (`Ends in the ready-for-review state. Never closes the ticket.`) with:
```
Ends with the ticket in the ready-for-review state and one commit in the [commit convention](#commit-convention), ticket ID in the subject. Never pushes. Never closes the ticket.
```
3. Replace the `/ship:hotfix` bullet with:
```
- `/ship:hotfix <ticket or bug>` — fast lane: reproduce, minimal fix, targeted tests, regression-focused review, one commit.
```
4. Insert this section between the paragraph starting `Only the main session writes to the ticket tracker` and `## Linear is optional`:

````markdown
## Commit convention

With `ship` enabled, every commit Claude makes, in any repo, has this shape:

```
<type>(<scope>)?: <summary> (<ref>)?

## What
## Why
## Risk
```

Two hooks in [`plugins/ship/hooks/`](plugins/ship/hooks/) do it. A SessionStart hook hands the model [the convention](plugins/ship/hooks/commit-convention.md); a PreToolUse hook rejects any `git commit` whose message doesn't follow it and shows the convention again. The hook checks structure, not content: the subject type, the 72-character limit, and three non-empty sections in order. `/ship:new-feature` and `/ship:hotfix` end by committing the finished work this way, with the ticket ID as the `ref`; they never push. A `Created by …` trailer comes from your own `attribution` setting, not the plugin. To turn it off in one profile, disable the plugin or remove its hooks under `/hooks`.

````
5. In the `## Developing` code block, add after the `scripts/smoke.sh` line:
```
scripts/test-commit-hook.sh    # fixture tests for the commit-message hook
```

- [ ] **Step 4: Check the README renders sensibly and nothing else regressed**

Run: `grep -n 'commit convention\|Commit convention\|test-commit-hook' README.md; scripts/check.sh 2>&1 | grep -E '^FAIL|PASSED|FAILED'`
Expected: five or more matching lines (table row, new-feature bullet, section heading, developing block); `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit**

```bash
git add README.md scripts/smoke.sh
git commit -m "$(cat <<'EOF'
docs: document the commit convention and smoke-test both hooks

## What

README gains a Commit convention section, updated table row and
workflow bullets, and lists scripts/test-commit-hook.sh under
Developing. smoke.sh gains a hooks section that, in the throwaway repo,
checks the session-start note reached the model, a bad commit is
blocked, and a conforming one lands with a ## Risk section.

## Why

- The convention is a user-visible behaviour of the plugin and belongs
  where installing and updating are explained.
- The fixture harness proves the checker; only a real session proves
  Claude Code runs the hooks.

## Risk

None. Docs and tests only.

Created by KevTheDev
EOF
)"
```

---

### Task 8: Release — Kevin's main session only, after Kevin says "push"

**Not for subagents.** This task pushes to the public repo `cabrerakevinc/ship-plugin` and updates Kevin's installed plugin. It runs in the main session, after Kevin has explicitly asked for the push in this conversation. A subagent that reaches this task stops and reports instead.

**Files:** none changed.

- [ ] **Step 1: Preconditions**

Run: `git status --short | wc -l; git log --oneline origin/main..HEAD; scripts/check.sh 2>&1 | tail -1`
Expected: `0`, the seven commits from Tasks 1–7 (plus the spec and plan commits), `ALL CHECKS PASSED`.

- [ ] **Step 2: Push (fast-forward only)**

```bash
git push origin main
```
Expected: a fast-forward to `origin/main`. Never `--force`.

- [ ] **Step 3: Update the installed plugin and verify the hooks are live**

```bash
claude plugin marketplace update kevthedev && claude plugin update ship@kevthedev
```
Then start a new Claude Code session in any repo and run `/hooks`: both hooks appear under the `ship` plugin. Make a throwaway commit attempt with `-m "wip"` in a scratch repo: it is rejected with the convention. If `ship` is also installed in the `~/.claude` profile, repeat the update there (`CLAUDE_CONFIG_DIR=~/.claude claude plugin update ship@kevthedev`).

- [ ] **Step 4: Tell Kevin**

Report: the commit range pushed, that both hooks show in `/hooks`, and that from now on every commit in this profile is checked. Mention that the repo is public, so the new spec and plan under `docs/superpowers/` are public too.
