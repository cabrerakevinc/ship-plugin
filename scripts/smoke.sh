#!/usr/bin/env bash
# Functional smoke test for the ship plugin, loaded via --plugin-dir (no install needed).
# Makes a few non-interactive Claude calls and exercises /ship:projma in a throwaway repo.
set -uo pipefail
cd "$(dirname "$0")/.."
PLUGIN="$PWD/plugins/ship"

fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
warn() { echo "WARN $1"; }

echo "=== 1. inventory ==="
inv=$(claude --plugin-dir "$PLUGIN" -p "List the name of every skill and every agent type you can see whose name starts with 'ship:', and the name of every MCP server you have (even if it is not authenticated). Output only the names, one per line, nothing else." --output-format text 2>/dev/null)
echo "$inv"
# new-ticket, new-feature and hotfix carry disable-model-invocation: true and are
# hidden from the model by design; they're verified structurally by scripts/check.sh
# and, after install, by `claude plugin details`.
for n in ship:projma \
         ship:ba-intake ship:solutions-architect \
         ship:front-end-ios-engineer ship:front-end-android-engineer \
         ship:front-end-web-designer ship:front-end-web-developer \
         ship:backend-engineer ship:qa-tester ship:tech-lead-reviewer; do
  if grep -q "$n" <<<"$inv"; then ok "inventory lists $n"; else bad "inventory missing $n"; fi
done
if grep -qiE '(^|:)linear$' <<<"$inv"; then ok "inventory lists the linear MCP server"; else warn "linear MCP server not listed (expected if not yet authenticated; verify with 'claude plugin details ship@kevthedev' after install)"; fi

echo "=== 2. /ship:projma in a throwaway repo ==="
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/ship-smoke-XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT
git -C "$SCRATCH" init -q -b main
ALLOW='Read,Write,Edit,Glob,Grep,Bash(mkdir:*),Bash(cp:*),Bash(touch:*),Bash(date:*),Bash(basename:*),Bash(pwd:*),Bash(sed:*),Bash(ls:*),Bash(cat:*),Bash(test:*),Bash(head:*)'
run() { (cd "$SCRATCH" && claude --plugin-dir "$PLUGIN" --add-dir "$PLUGIN" -p "$1" --output-format text --permission-mode acceptEdits --allowedTools "$ALLOW" 2>/dev/null); }
hashes() { (cd "$SCRATCH/docs/projma" 2>/dev/null && find . -type f -exec shasum {} + | sort); }

run "/ship:projma init" >"$SCRATCH/.init1.txt"; cat "$SCRATCH/.init1.txt"
for f in CLAUDE.md memory.md tasks.csv resources/.gitkeep; do
  if [ -f "$SCRATCH/docs/projma/$f" ]; then ok "init created docs/projma/$f"; else bad "init did not create docs/projma/$f"; fi
done
files=$(cd "$SCRATCH/docs/projma" 2>/dev/null && find . -type f | sort | tr '\n' ' ')
if [ "$files" = "./CLAUDE.md ./memory.md ./resources/.gitkeep ./tasks.csv " ]; then ok "init created exactly the four files"; else bad "init created unexpected set: $files"; fi
if grep -rq '{{DATE}}\|{{PROJECT}}' "$SCRATCH/docs/projma" 2>/dev/null; then bad "placeholders left unsubstituted"; else ok "placeholders substituted"; fi
if grep -q "$(date +%Y-%m-%d)" "$SCRATCH/docs/projma/CLAUDE.md" 2>/dev/null; then ok "today's date substituted"; else bad "today's date not found in CLAUDE.md"; fi
if grep -q "$(basename "$SCRATCH")" "$SCRATCH/docs/projma/CLAUDE.md" 2>/dev/null; then ok "project name substituted"; else bad "project folder name not found in CLAUDE.md"; fi
if [ "$(head -1 "$SCRATCH/docs/projma/tasks.csv" 2>/dev/null)" = "id,title,type,platforms,status,created,updated,file" ]; then ok "tasks.csv header intact"; else bad "tasks.csv header wrong"; fi

before=$(hashes)
run "/ship:projma init" >"$SCRATCH/.init2.txt"; cat "$SCRATCH/.init2.txt"
if [ "$before" = "$(hashes)" ]; then ok "second init changed nothing"; else bad "second init modified files"; fi
if grep -qi "exist" "$SCRATCH/.init2.txt"; then ok "second init reported the tracker already exists"; else bad "second init did not say the tracker exists"; fi

status=$(run "/ship:projma status"); echo "$status"
if [ "$before" = "$(hashes)" ]; then ok "status wrote nothing"; else bad "status modified files"; fi
if grep -qiE 'todo|in-progress|in-review|no .*tickets|0' <<<"$status"; then ok "status printed a summary"; else bad "status output unexpected"; fi

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

if [ "$fail" -eq 0 ]; then echo "SMOKE PASSED"; else echo "SMOKE FAILED"; exit 1; fi
