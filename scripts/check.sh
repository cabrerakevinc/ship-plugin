#!/usr/bin/env bash
# Structural checks for the kevthedev marketplace and the ship plugin.
# Run from anywhere: scripts/check.sh   (exit 0 = pass)
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
need_file() { if [ -f "$1" ]; then ok "exists $1"; else bad "missing $1"; return 1; fi; }

# === manifests ===
need_file .claude-plugin/marketplace.json
need_file plugins/ship/.claude-plugin/plugin.json
need_file plugins/ship/.mcp.json
if python3 - <<'PY'
import json
m = json.load(open('.claude-plugin/marketplace.json'))
assert m['name'] == 'kevthedev', m['name']
assert [p['name'] for p in m['plugins']] == ['ship'], m['plugins']
assert m['plugins'][0]['source'] == './plugins/ship', m['plugins'][0]['source']
p = json.load(open('plugins/ship/.claude-plugin/plugin.json'))
assert p['name'] == 'ship', p['name']
assert 'version' not in p, "plugin.json must not have a version (commit-SHA versioning)"
c = json.load(open('plugins/ship/.mcp.json'))
assert c['mcpServers']['linear'] == {'type': 'http', 'url': 'https://mcp.linear.app/mcp'}, c
PY
then ok "manifests parse and match the spec"; else bad "manifests do not match the spec"; fi

out=$(mktemp)
if claude plugin validate plugins/ship >"$out" 2>&1; then ok "claude plugin validate plugins/ship"; else bad "claude plugin validate plugins/ship"; cat "$out"; fi
if claude plugin validate . >"$out" 2>&1; then ok "claude plugin validate . (marketplace)"; else bad "claude plugin validate . (marketplace)"; cat "$out"; fi
rm -f "$out"

# === agents ===
AGENTS=(ba-intake solutions-architect architect front-end-swift-engineer front-end-android-engineer front-end-web-designer front-end-web-developer backend-engineer qa-tester tech-lead-reviewer)
for a in "${AGENTS[@]}"; do
  f="plugins/ship/agents/$a.md"
  need_file "$f" || continue
  grep -q "^name: $a\$" "$f"        || bad "$f: frontmatter name must be exactly '$a'"
  grep -q "^model: sonnet\$" "$f"   || bad "$f: model must be sonnet"
  grep -q "^tools: " "$f"           || bad "$f: tools line missing"
  grep -q "^description: " "$f"     || bad "$f: description missing"
done

# No bare (unprefixed) agent name inside backticks anywhere in agent or skill bodies.
BARE='`(ba-intake|solutions-architect|architect|front-end-swift-engineer|front-end-android-engineer|front-end-web-designer|front-end-web-developer|backend-engineer|qa-tester|tech-lead-reviewer)`'
if [ -d plugins/ship/agents ] || [ -d plugins/ship/skills ]; then
  if grep -rnE "$BARE" plugins/ship/agents plugins/ship/skills 2>/dev/null; then
    bad "unprefixed agent references found above (must be ship:<name>)"
  else
    ok "every backticked agent reference carries the ship: prefix"
  fi
fi

# Exact reference counts from spec section 5.
expect_refs() { # file agent count
  [ -f "$1" ] || return 0
  local n; n=$(grep -o "\`ship:$2\`" "$1" | wc -l | tr -d ' ')
  if [ "$n" = "$3" ]; then ok "$1 -> ship:$2 x$3"; else bad "$1 expected $3 ref(s) to ship:$2, found $n"; fi
}
A=plugins/ship/agents
expect_refs $A/ba-intake.md tech-lead-reviewer 1
expect_refs $A/solutions-architect.md architect 2
expect_refs $A/architect.md solutions-architect 1
for e in front-end-swift-engineer front-end-android-engineer; do
  expect_refs $A/$e.md architect 1; expect_refs $A/$e.md solutions-architect 1
  expect_refs $A/$e.md qa-tester 1;  expect_refs $A/$e.md tech-lead-reviewer 1
done
expect_refs $A/front-end-web-designer.md front-end-web-developer 2
expect_refs $A/front-end-web-developer.md front-end-web-designer 1
expect_refs $A/front-end-web-developer.md backend-engineer 1
expect_refs $A/front-end-web-developer.md qa-tester 1
expect_refs $A/front-end-web-developer.md tech-lead-reviewer 1
for r in architect solutions-architect front-end-swift-engineer front-end-android-engineer front-end-web-developer qa-tester tech-lead-reviewer; do
  expect_refs $A/backend-engineer.md $r 1
done
if [ -f $A/qa-tester.md ] && grep -q '`ship:' $A/qa-tester.md; then bad "qa-tester.md should reference no agents"; fi
if [ -f $A/tech-lead-reviewer.md ] && grep -q '`ship:' $A/tech-lead-reviewer.md; then bad "tech-lead-reviewer.md should reference no agents"; fi

# === summary ===
if [ "$fail" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; exit 1; fi
