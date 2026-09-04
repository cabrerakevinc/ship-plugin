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

# === summary ===
if [ "$fail" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; exit 1; fi
