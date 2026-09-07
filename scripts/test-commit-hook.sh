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
  err=$(bash "$HOOK" 2>&1 >"$TMP/stdout"); got=$?
  if [ -s "$TMP/stdout" ]; then bad "$name: hook wrote to stdout"; head -3 "$TMP/stdout"; return; fi
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
t "rejection prints the convention" 2 "Commit message convention" <<'CMD'
git commit -m "feat: add thing"
CMD

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
t "--amend --no-edit with a bad -m" 2 "subject: must be" <<'CMD'
git commit --amend --no-edit -m "oops"
CMD
printf 'oops\n' >"$TMP/bad.txt"
t "-F file with a bad message" 2 "subject: must be" <<CMD
git commit -F $TMP/bad.txt
CMD
t "message from an unquoted shell variable" 2 "could not be read" <<'CMD'
git commit -m $MSG
CMD

echo "=== masking and argument forms ==="
t "opener nested in a python heredoc does not mask the commit" 2 "subject: must be" <<'CMD'
python3 - <<'PY'
x = 1 << 2
print(x)
PY
git commit -m "bad"
CMD
t "unterminated cat <<EOF quoted inside a doc heredoc does not mask the commit" 2 "subject: must be" <<'CMD'
cat > notes.md <<'DOC'
Example: cat <<EOF
hello
DOC
git commit -m "bad"
CMD
t "terminated heredoc then a bad commit" 2 "subject: must be" <<'CMD'
cat > plan.md <<'EOF'
Then commit.
EOF
git commit -m "bad"
CMD
t "terminated heredoc then a good commit" 0 <<'CMD'
cat > plan.md <<'EOF'
Then commit.
EOF
git commit -m "$(cat <<'MSG'
docs: add the plan

## What

Adds plan.md.

## Why

- We need a plan.

## Risk

None. Docs only.
MSG
)"
CMD
t "valid via attached -m" 0 <<'CMD'
git commit -m"$(cat <<'EOF'
feat: attach the message

## What

Attached form.

## Why

- Coverage.

## Risk

None.
EOF
)"
CMD
t "valid via --message=" 0 <<'CMD'
git commit --message="$(cat <<'EOF'
feat: use the long form

## What

Long form.

## Why

- Coverage.

## Risk

None.
EOF
)"
CMD
t "valid via -am" 0 <<'CMD'
git commit -am "$(cat <<'EOF'
feat: stage and commit

## What

Both at once.

## Why

- Coverage.

## Risk

None.
EOF
)"
CMD
t "valid via unquoted cat heredoc tag" 0 <<'CMD'
git commit -m "$(cat <<EOF
feat: unquoted tag

## What

Unquoted tag.

## Why

- Coverage.

## Risk

None.
EOF
)"
CMD
t "two invocations: first reported" 2 'got "one"' <<'CMD'
git commit -m "one" ; git commit -m "two"
CMD
t "two invocations: second reported" 2 'got "two"' <<'CMD'
git commit -m "one" ; git commit -m "two"
CMD
t "valid after a ; separator" 0 <<'CMD'
git status; git commit -m "$(cat <<'EOF'
chore: after a semicolon

## What

Semicolon.

## Why

- Coverage.

## Risk

None.
EOF
)"
CMD
t "valid inside a subshell" 0 <<'CMD'
(cd sub && git commit -m "$(cat <<'EOF'
chore: in a subshell

## What

Subshell.

## Why

- Coverage.

## Risk

None.
EOF
)")
CMD

if [ "$fail" -eq 0 ]; then echo "HOOK TESTS PASSED"; else echo "HOOK TESTS FAILED"; exit 1; fi
