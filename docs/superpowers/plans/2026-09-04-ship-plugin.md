# `ship` Plugin and `kevthedev` Marketplace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn this repo into a Claude Code plugin marketplace (`kevthedev`) containing the `ship` plugin (9 agents after Task 8, 4 skills, bundled Linear MCP), verified locally, pushed to the existing public GitHub repo `cabrerakevinc/ship-plugin`, and installed from GitHub on this machine.

**Architecture:** One git repo is the marketplace: `.claude-plugin/marketplace.json` at the root points at `plugins/ship/`. The plugin is pure content (markdown agents and skills, three JSON manifests, three template files). Two shell scripts under `scripts/` are the test suite: `check.sh` does structural checks plus `claude plugin validate`, `smoke.sh` loads the plugin with `--plugin-dir` and exercises `/ship:projma` in a throwaway repo. `spec-diff.py` confirms each content file matches the spec appendix byte for byte.

**Tech Stack:** Claude Code 2.1.260 plugin system (`claude plugin validate|install|marketplace|details`), bash, python3 (stdlib only), git, `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-09-04-ship-plugin-design.md` — Appendix A holds the exact content of every agent, skill and template file. Read the spec alongside this plan.

## Global Constraints

- Plugin name is `ship`; marketplace name is `kevthedev`; install target is `ship@kevthedev`.
- Remote is the existing **public** repo `https://github.com/cabrerakevinc/ship-plugin` (already created, empty). Never run `gh repo create`.
- Repo layout: marketplace root here, plugin at `plugins/ship/`. Only `plugin.json` goes inside `plugins/ship/.claude-plugin/`; `agents/`, `skills/`, `.mcp.json` sit at the plugin root.
- `plugins/ship/.claude-plugin/plugin.json` has **no** `version` field (commit SHA is the version).
- Every reference to another agent inside agent and skill bodies is written `ship:<agent>` (e.g. `` `ship:ba-intake` ``). No bare backticked agent name may remain.
- Agent `name:` frontmatter stays bare (`name: ba-intake`), never `ship:ba-intake`.
- Agents use `model: sonnet` and the `tools:` lists from the spec, verbatim.
- After Task 8 there are nine agents: `architect` is gone (consolidated into `solutions-architect`) and `front-end-swift-engineer` is renamed `front-end-ios-engineer`. Tasks 1–7 were written before that amendment; Task 8 supersedes their agent lists.
- `new-ticket`, `new-feature`, `hotfix` carry `disable-model-invocation: true`. `projma` does **not** (it must be model-invocable).
- Content files are copied from the spec appendix exactly (verified by `scripts/spec-diff.py`); do not paraphrase or "improve" them.
- Nothing in this repo writes to `~/.claude/` or `~/.claude-bevz/` directly; installation goes through `claude plugin ...`.
- Every commit message ends with the line `Created by KevTheDev`.
- Work on `main` in this repo (it is brand new; no branching needed).

---

## File structure

| Path | Responsibility |
|---|---|
| `.claude-plugin/marketplace.json` | Marketplace manifest: name `kevthedev`, lists `./plugins/ship`. |
| `plugins/ship/.claude-plugin/plugin.json` | Plugin manifest: name, description, author, repository, keywords. No version. |
| `plugins/ship/.mcp.json` | Linear HTTP MCP server. |
| `plugins/ship/agents/<name>.md` ×10 | One subagent each; body is the system prompt. |
| `plugins/ship/skills/{new-ticket,new-feature,hotfix}/SKILL.md` | User-invoked orchestrating skills. |
| `plugins/ship/skills/projma/SKILL.md` | `/ship:projma init|status`; model-invocable so the other skills can call it. |
| `plugins/ship/skills/projma/templates/{CLAUDE.md,memory.md,tasks.csv}` | Copied into a target repo's `docs/projma/` by `init`. |
| `scripts/check.sh` | Structural checks + `claude plugin validate` (grows task by task). |
| `scripts/spec-diff.py` | Byte-for-byte comparison of content files against spec Appendix A. |
| `scripts/smoke.sh` | Functional test via `--plugin-dir`: inventory and `/ship:projma` behaviour. |
| `README.md` | Install, update, what `ship` provides, Linear toggle, developing, adding plugins. |

---

### Task 1: Check scripts and the three manifests

**Files:**
- Create: `scripts/check.sh`
- Create: `scripts/spec-diff.py`
- Create: `.claude-plugin/marketplace.json`
- Create: `plugins/ship/.claude-plugin/plugin.json`
- Create: `plugins/ship/.mcp.json`

**Interfaces:**
- Produces: `scripts/check.sh` (exit 0 = all checks pass; prints `ok   ...`/`FAIL ...` lines; sections delimited by `# === <name> ===` comments, with a final `# === summary ===` section that later tasks insert above). `scripts/spec-diff.py <path>...` (exit 0 when every given file equals its spec appendix block).

- [ ] **Step 1: Write the check script (manifests section only)**

```bash
mkdir -p scripts
cat > scripts/check.sh <<'EOF'
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
EOF
chmod +x scripts/check.sh
```

- [ ] **Step 2: Write the spec-diff script**

```bash
cat > scripts/spec-diff.py <<'EOF'
#!/usr/bin/env python3
"""Compare content files against the fenced blocks in the design spec's Appendix A.

Usage: scripts/spec-diff.py <repo-relative path>...
Exit 0 when every file equals its spec block byte for byte; 1 otherwise.
Bootstrap fidelity check only — after the initial build, the files are the source of truth.
"""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "docs/superpowers/specs/2026-09-04-ship-plugin-design.md"
spec = SPEC.read_text()

def block(path: str) -> str:
    """Return the body of the fenced block that follows the heading naming `path`."""
    h = spec.index(f"`{path}`\n")
    fs = spec.index("\n```", h) + 1          # start of the opening fence line
    fe = spec.index("\n", fs)                # end of the opening fence line
    fence = re.match(r"`+", spec[fs:fe]).group(0)
    s = fe + 1
    e = spec.index("\n" + fence + "\n", s)   # closing fence on its own line
    return spec[s:e] + "\n"

bad = 0
for p in sys.argv[1:]:
    want = block(p)
    got = (ROOT / p).read_text()
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
EOF
chmod +x scripts/spec-diff.py
```

- [ ] **Step 3: Run the check script; expect failure (manifests missing)**

Run: `scripts/check.sh`
Expected: three `FAIL missing ...` lines, `CHECKS FAILED`, exit code 1.

- [ ] **Step 4: Create the marketplace manifest**

```bash
mkdir -p .claude-plugin
cat > .claude-plugin/marketplace.json <<'EOF'
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "kevthedev",
  "description": "KevTheDev's Claude Code plugins",
  "owner": {
    "name": "Kevin Cabrera",
    "url": "https://github.com/cabrerakevinc"
  },
  "plugins": [
    {
      "name": "ship",
      "description": "Role-based dev team for Claude Code: ticket intake, solutions/feature architecture, iOS/Android/web/backend engineers, QA, and tech-lead review, orchestrated by /ship:new-ticket, /ship:new-feature and /ship:hotfix",
      "source": "./plugins/ship",
      "category": "development"
    }
  ]
}
EOF
```

- [ ] **Step 5: Create the plugin manifest and the MCP config**

```bash
mkdir -p plugins/ship/.claude-plugin
cat > plugins/ship/.claude-plugin/plugin.json <<'EOF'
{
  "name": "ship",
  "description": "Role-based dev team for Claude Code: ticket intake, solutions/feature architecture, iOS/Android/web/backend engineers, QA, and tech-lead review, orchestrated by /ship:new-ticket, /ship:new-feature and /ship:hotfix",
  "author": {
    "name": "Kevin Cabrera",
    "url": "https://github.com/cabrerakevinc"
  },
  "repository": "https://github.com/cabrerakevinc/ship-plugin",
  "keywords": ["agents", "workflow", "sdlc", "tickets", "linear"]
}
EOF
cat > plugins/ship/.mcp.json <<'EOF'
{
  "mcpServers": {
    "linear": {
      "type": "http",
      "url": "https://mcp.linear.app/mcp"
    }
  }
}
EOF
```

- [ ] **Step 6: Run the check script; expect pass**

Run: `scripts/check.sh`
Expected: all `ok` lines including `ok   claude plugin validate plugins/ship` and `ok   claude plugin validate . (marketplace)`, then `ALL CHECKS PASSED`, exit 0. If `claude plugin validate` prints warnings about the empty plugin (no skills/agents yet), that is acceptable as long as its exit code is 0.

- [ ] **Step 7: Commit**

```bash
git add scripts/check.sh scripts/spec-diff.py .claude-plugin/marketplace.json plugins/ship/.claude-plugin/plugin.json plugins/ship/.mcp.json
git commit -m "$(cat <<'MSG'
Add kevthedev marketplace, ship plugin manifests, and check scripts

Created by KevTheDev
MSG
)"
```

---

### Task 2: The ten agents

**Files:**
- Modify: `scripts/check.sh` (insert an `# === agents ===` section above `# === summary ===`)
- Create: `plugins/ship/agents/ba-intake.md`
- Create: `plugins/ship/agents/solutions-architect.md`
- Create: `plugins/ship/agents/architect.md`
- Create: `plugins/ship/agents/front-end-swift-engineer.md`
- Create: `plugins/ship/agents/front-end-android-engineer.md`
- Create: `plugins/ship/agents/front-end-web-designer.md`
- Create: `plugins/ship/agents/front-end-web-developer.md`
- Create: `plugins/ship/agents/backend-engineer.md`
- Create: `plugins/ship/agents/qa-tester.md`
- Create: `plugins/ship/agents/tech-lead-reviewer.md`

**Interfaces:**
- Consumes: `scripts/check.sh` section markers and `ok`/`bad`/`need_file` helpers from Task 1; `scripts/spec-diff.py`.
- Produces: the ten agent names that skills reference as `ship:<name>`.

- [ ] **Step 1: Add the agents section to the check script**

Insert this block into `scripts/check.sh` immediately above the line `# === summary ===`:

```bash
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

```

- [ ] **Step 2: Run the check script; expect failure (agents missing)**

Run: `scripts/check.sh`
Expected: ten `FAIL missing plugins/ship/agents/...` lines, `CHECKS FAILED`, exit 1.

- [ ] **Step 3: Create the ten agent files from the spec appendix**

Create each file below with **exactly** the content of the corresponding fenced block in `docs/superpowers/specs/2026-09-04-ship-plugin-design.md`, Appendix A (the text between the fence lines, not including the fences, ending in a single trailing newline). Use `cat > <path> <<'EOF' ... EOF` so nothing is expanded.

| File | Spec section |
|---|---|
| `plugins/ship/agents/ba-intake.md` | A.1 |
| `plugins/ship/agents/solutions-architect.md` | A.2 |
| `plugins/ship/agents/architect.md` | A.3 |
| `plugins/ship/agents/front-end-swift-engineer.md` | A.4 |
| `plugins/ship/agents/front-end-android-engineer.md` | A.5 |
| `plugins/ship/agents/front-end-web-designer.md` | A.6 |
| `plugins/ship/agents/front-end-web-developer.md` | A.7 |
| `plugins/ship/agents/backend-engineer.md` | A.8 |
| `plugins/ship/agents/qa-tester.md` | A.9 |
| `plugins/ship/agents/tech-lead-reviewer.md` | A.10 |

- [ ] **Step 4: Verify byte-for-byte fidelity against the spec**

Run:
```bash
scripts/spec-diff.py plugins/ship/agents/ba-intake.md plugins/ship/agents/solutions-architect.md plugins/ship/agents/architect.md plugins/ship/agents/front-end-swift-engineer.md plugins/ship/agents/front-end-android-engineer.md plugins/ship/agents/front-end-web-designer.md plugins/ship/agents/front-end-web-developer.md plugins/ship/agents/backend-engineer.md plugins/ship/agents/qa-tester.md plugins/ship/agents/tech-lead-reviewer.md
```
Expected: ten `match:` lines, exit 0. If any says `DIFFERS`, fix the file (not the spec) until it matches.

- [ ] **Step 5: Run the check script; expect pass**

Run: `scripts/check.sh`
Expected: `ALL CHECKS PASSED`, exit 0, including `ok   every backticked agent reference carries the ship: prefix` and all `-> ship:... xN` lines. `claude plugin validate plugins/ship` must still pass now that agents exist.

- [ ] **Step 6: Commit**

```bash
git add scripts/check.sh plugins/ship/agents
git commit -m "$(cat <<'MSG'
Add the ten ship agents

Created by KevTheDev
MSG
)"
```

---

### Task 3: The three orchestrating skills

**Files:**
- Modify: `scripts/check.sh` (insert an `# === orchestrating skills ===` section above `# === summary ===`)
- Create: `plugins/ship/skills/new-ticket/SKILL.md`
- Create: `plugins/ship/skills/new-feature/SKILL.md`
- Create: `plugins/ship/skills/hotfix/SKILL.md`

**Interfaces:**
- Consumes: agent names from Task 2; the `ship:projma` skill name (created in Task 4; referenced by text only, so order does not break anything).
- Produces: `/ship:new-ticket`, `/ship:new-feature`, `/ship:hotfix`.

- [ ] **Step 1: Add the orchestrating-skills section to the check script**

Insert immediately above `# === summary ===`:

```bash
# === orchestrating skills ===
S=plugins/ship/skills
for s in new-ticket new-feature hotfix; do
  f="$S/$s/SKILL.md"
  need_file "$f" || continue
  grep -q '^disable-model-invocation: true$' "$f" || bad "$f: disable-model-invocation: true missing"
  grep -q '^argument-hint: ' "$f"                || bad "$f: argument-hint missing"
  grep -q '^description: ' "$f"                  || bad "$f: description missing"
  grep -q '\$ARGUMENTS' "$f"                     || bad "$f: \$ARGUMENTS missing"
  grep -q 'docs/projma/' "$f"                    || bad "$f: must mention the docs/projma/ fallback"
  grep -q '^name: ' "$f"                         && bad "$f: no name field (folder name is the skill name)"
done
expect_refs $S/new-ticket/SKILL.md ba-intake 2
expect_refs $S/new-ticket/SKILL.md projma 1
expect_refs $S/new-feature/SKILL.md solutions-architect 3
expect_refs $S/new-feature/SKILL.md architect 1
expect_refs $S/new-feature/SKILL.md front-end-web-designer 1
expect_refs $S/new-feature/SKILL.md front-end-web-developer 2
expect_refs $S/new-feature/SKILL.md front-end-swift-engineer 1
expect_refs $S/new-feature/SKILL.md front-end-android-engineer 1
expect_refs $S/new-feature/SKILL.md backend-engineer 1
expect_refs $S/new-feature/SKILL.md qa-tester 2
expect_refs $S/new-feature/SKILL.md tech-lead-reviewer 2
expect_refs $S/new-feature/SKILL.md projma 1
for r in solutions-architect architect front-end-swift-engineer front-end-android-engineer front-end-web-developer backend-engineer qa-tester ba-intake projma; do
  expect_refs $S/hotfix/SKILL.md $r 1
done
expect_refs $S/hotfix/SKILL.md tech-lead-reviewer 2

```

- [ ] **Step 2: Run the check script; expect failure (skills missing)**

Run: `scripts/check.sh`
Expected: three `FAIL missing plugins/ship/skills/.../SKILL.md` lines, `CHECKS FAILED`, exit 1.

- [ ] **Step 3: Create the three skill files from the spec appendix**

Create each with **exactly** the fenced block content from the spec (heredoc with quoted `'EOF'` so `$ARGUMENTS` is not expanded):

| File | Spec section |
|---|---|
| `plugins/ship/skills/new-ticket/SKILL.md` | A.11 |
| `plugins/ship/skills/new-feature/SKILL.md` | A.12 |
| `plugins/ship/skills/hotfix/SKILL.md` | A.13 |

- [ ] **Step 4: Verify fidelity against the spec**

Run: `scripts/spec-diff.py plugins/ship/skills/new-ticket/SKILL.md plugins/ship/skills/new-feature/SKILL.md plugins/ship/skills/hotfix/SKILL.md`
Expected: three `match:` lines, exit 0.

- [ ] **Step 5: Run the check script; expect pass**

Run: `scripts/check.sh`
Expected: `ALL CHECKS PASSED`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/check.sh plugins/ship/skills/new-ticket plugins/ship/skills/new-feature plugins/ship/skills/hotfix
git commit -m "$(cat <<'MSG'
Add ship:new-ticket, ship:new-feature and ship:hotfix skills

Created by KevTheDev
MSG
)"
```

---

### Task 4: The `projma` skill and its templates

**Files:**
- Modify: `scripts/check.sh` (insert a `# === projma ===` section above `# === summary ===`)
- Create: `plugins/ship/skills/projma/SKILL.md`
- Create: `plugins/ship/skills/projma/templates/CLAUDE.md`
- Create: `plugins/ship/skills/projma/templates/memory.md`
- Create: `plugins/ship/skills/projma/templates/tasks.csv`

**Interfaces:**
- Produces: `/ship:projma [init|status]`; on `init` creates `docs/projma/{CLAUDE.md,memory.md,tasks.csv,resources/.gitkeep}` in the target repo with `{{DATE}}` → `YYYY-MM-DD` and `{{PROJECT}}` → repo folder name substituted. `tasks.csv` header is exactly `id,title,type,platforms,status,created,updated,file`.

- [ ] **Step 1: Add the projma section to the check script**

Insert immediately above `# === summary ===`:

```bash
# === projma ===
P=plugins/ship/skills/projma
if need_file $P/SKILL.md; then
  grep -q '^name: projma$' $P/SKILL.md                 || bad "$P/SKILL.md: name must be projma"
  grep -q '^argument-hint: \[init | status\]$' $P/SKILL.md || bad "$P/SKILL.md: argument-hint must be [init | status]"
  grep -q 'disable-model-invocation' $P/SKILL.md       && bad "$P/SKILL.md: must stay model-invocable (remove disable-model-invocation)"
  grep -q '\${CLAUDE_SKILL_DIR}/templates/' $P/SKILL.md || bad "$P/SKILL.md: must copy from \${CLAUDE_SKILL_DIR}/templates/"
  grep -q '\$ARGUMENTS' $P/SKILL.md                    || bad "$P/SKILL.md: \$ARGUMENTS missing"
fi
for tpl in CLAUDE.md memory.md tasks.csv; do need_file $P/templates/$tpl; done
if [ -f $P/templates/tasks.csv ]; then
  if [ "$(cat $P/templates/tasks.csv)" = "id,title,type,platforms,status,created,updated,file" ] && [ "$(wc -l < $P/templates/tasks.csv | tr -d ' ')" = "1" ]; then
    ok "tasks.csv template is exactly the header row"
  else
    bad "tasks.csv template must be exactly one line: id,title,type,platforms,status,created,updated,file"
  fi
fi
for tpl in CLAUDE.md memory.md; do
  if [ -f $P/templates/$tpl ]; then
    grep -q '{{DATE}}' $P/templates/$tpl    || bad "$P/templates/$tpl: {{DATE}} placeholder missing"
    grep -q '{{PROJECT}}' $P/templates/$tpl || bad "$P/templates/$tpl: {{PROJECT}} placeholder missing"
  fi
done
if [ -f $P/templates/CLAUDE.md ]; then
  for must in 'id,title,type,platforms,status,created,updated,file' '`todo`' '`in-progress`' '`in-review`' '`closed`' 'Sign-off log' 'Definition of Done' 'ship:tech-lead-reviewer'; do
    grep -qF -- "$must" $P/templates/CLAUDE.md || bad "$P/templates/CLAUDE.md: missing '$must'"
  done
fi

```

- [ ] **Step 2: Run the check script; expect failure (projma files missing)**

Run: `scripts/check.sh`
Expected: four `FAIL missing plugins/ship/skills/projma/...` lines, `CHECKS FAILED`, exit 1.

- [ ] **Step 3: Create the skill and templates from the spec appendix**

Create each with **exactly** the fenced block content from the spec (quoted heredocs; the `CLAUDE.md` template itself contains a ``` fenced example, which is fine inside a quoted heredoc):

| File | Spec section |
|---|---|
| `plugins/ship/skills/projma/SKILL.md` | A.14 |
| `plugins/ship/skills/projma/templates/CLAUDE.md` | A.15 |
| `plugins/ship/skills/projma/templates/memory.md` | A.16 |
| `plugins/ship/skills/projma/templates/tasks.csv` | A.17 |

- [ ] **Step 4: Verify fidelity against the spec**

Run: `scripts/spec-diff.py plugins/ship/skills/projma/SKILL.md plugins/ship/skills/projma/templates/CLAUDE.md plugins/ship/skills/projma/templates/memory.md plugins/ship/skills/projma/templates/tasks.csv`
Expected: four `match:` lines, exit 0.

- [ ] **Step 5: Run the check script; expect pass**

Run: `scripts/check.sh`
Expected: `ALL CHECKS PASSED`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/check.sh plugins/ship/skills/projma
git commit -m "$(cat <<'MSG'
Add ship:projma file-tracker skill and templates

Created by KevTheDev
MSG
)"
```

---

### Task 5: Functional smoke test with `--plugin-dir`

**Files:**
- Create: `scripts/smoke.sh`

**Interfaces:**
- Consumes: the complete plugin at `plugins/ship` (Tasks 1–4).
- Produces: `scripts/smoke.sh` (exit 0 = pass). Makes four `claude -p` calls; uses a throwaway git repo under `mktemp -d`; never touches this repo's files.

- [ ] **Step 1: Write the smoke test**

```bash
cat > scripts/smoke.sh <<'EOF'
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
         ship:ba-intake ship:solutions-architect ship:architect \
         ship:front-end-swift-engineer ship:front-end-android-engineer \
         ship:front-end-web-designer ship:front-end-web-developer \
         ship:backend-engineer ship:qa-tester ship:tech-lead-reviewer; do
  if grep -q "$n" <<<"$inv"; then ok "inventory lists $n"; else bad "inventory missing $n"; fi
done
if grep -qi "linear" <<<"$inv"; then ok "inventory lists the linear MCP server"; else warn "linear MCP server not listed (expected if not yet authenticated; verify with 'claude plugin details ship@kevthedev' after install)"; fi

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

if [ "$fail" -eq 0 ]; then echo "SMOKE PASSED"; else echo "SMOKE FAILED"; exit 1; fi
EOF
chmod +x scripts/smoke.sh
```

- [ ] **Step 2: Run the smoke test**

Run: `scripts/smoke.sh`
Expected: every `ok` line in section 1 for `ship:projma` and the ten agents (the three user-only skills are hidden from the model by design); in section 2, `init created ...` ×4, `exactly the four files`, `placeholders substituted`, `today's date substituted`, `project name substituted`, `tasks.csv header intact`, `second init changed nothing`, `second init reported the tracker already exists`, `status wrote nothing`, `status printed a summary`; final line `SMOKE PASSED`, exit 0. A `WARN` about the linear server is acceptable.

If a section-2 check fails, read the printed model output to see what the skill did, fix the wording in `plugins/ship/skills/projma/SKILL.md` **and** the same block in the spec (A.14) so they stay identical, re-run `scripts/spec-diff.py plugins/ship/skills/projma/SKILL.md`, then re-run the smoke test. Do not loosen the assertions to make it pass.

- [ ] **Step 3: Confirm the structural checks still pass**

Run: `scripts/check.sh`
Expected: `ALL CHECKS PASSED`.

- [ ] **Step 4: Commit**

```bash
git add scripts/smoke.sh
git add -A plugins/ship docs/superpowers/specs   # only if Step 2 required a wording fix
git commit -m "$(cat <<'MSG'
Add functional smoke test for the ship plugin

Created by KevTheDev
MSG
)"
```

---

### Task 6: README

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: the install/update commands and behaviour from spec sections 7 and 8.

- [ ] **Step 1: Write the README**

```bash
cat > README.md <<'EOF'
# ship-plugin

KevTheDev's Claude Code plugin marketplace, named `kevthedev`. One repo, installable on any machine with `claude plugin ...`.

| Plugin | What it is |
|---|---|
| [`ship`](plugins/ship) | A role-based dev team: ticket intake, architecture, platform engineers, QA and tech-lead review, run by `/ship:new-ticket`, `/ship:new-feature` and `/ship:hotfix`. Falls back to a file tracker (`/ship:projma`) when Linear isn't connected. |

## Install on a new machine

Requires Claude Code. The repo is public, so no GitHub login is needed.

```
claude plugin marketplace add cabrerakevinc/ship-plugin
claude plugin install ship@kevthedev
```

Then, inside Claude Code, run `/mcp` once and complete the Linear login.

Plugins are installed per config directory. If you use more than one profile (`CLAUDE_CONFIG_DIR`), repeat the two commands in each.

## Update

```
claude plugin marketplace update kevthedev
claude plugin update ship@kevthedev
```

Or open `/plugin` inside Claude Code. There is no version number to bump: the git commit is the version, so every push is an update.

## What `ship` gives you

Commands. You run these; Claude never triggers them on its own.

- `/ship:new-ticket <idea or bug>` — `ship:ba-intake` drafts a title, scope and a Definition of Done checklist; the ticket is created for you.
- `/ship:new-feature <ticket or description>` — solutions-architect (if multi-platform) → architect → platform engineer(s) → qa-tester → tech-lead-reviewer, posting a sign-off on the ticket after every step. Ends in the ready-for-review state. Never closes the ticket.
- `/ship:hotfix <ticket or bug>` — fast lane: reproduce, minimal fix, targeted tests, regression-focused review.
- `/ship:projma [init | status]` — the file-based tracker. `init` scaffolds `docs/projma/`; `status` summarises open tickets.

Agents. Read-only ones cannot edit code or touch the tracker.

- `ship:ba-intake` — ticket drafts with a DoD checklist (read-only)
- `ship:solutions-architect` — cross-platform shape of a ticket (read-only)
- `ship:architect` — single-platform technical design (read-only)
- `ship:front-end-swift-engineer` — iOS implementation
- `ship:front-end-android-engineer` — Android implementation
- `ship:front-end-web-designer` — web UI/UX spec (writes the spec file only)
- `ship:front-end-web-developer` — web implementation
- `ship:backend-engineer` — backend implementation
- `ship:qa-tester` — runs and writes tests, never edits production code
- `ship:tech-lead-reviewer` — item-by-item DoD review (read-only)

Only the main session writes to the ticket tracker; no subagent has Linear or file-tracker write access. Nothing here ever sets a ticket to Closed. That is your call, after your own final check.

## Linear is optional

The plugin registers the Linear MCP server (`https://mcp.linear.app/mcp`). To turn it off in one profile, open `/mcp` and toggle it; the plugin stays installed.

Without Linear, the skills use `docs/projma/` in the target repo: `tasks.csv` (the index and the only place status lives), one file per ticket under `resources/` with its DoD checklist and sign-off log, and `memory.md` for durable project context. The skills ask once before creating that folder. Conventions: [`plugins/ship/skills/projma/templates/CLAUDE.md`](plugins/ship/skills/projma/templates/CLAUDE.md).

## Developing

```
scripts/check.sh    # structural checks + claude plugin validate
scripts/smoke.sh    # functional test: a few Claude calls, throwaway repo
claude --plugin-dir plugins/ship    # try it in a real session without installing
```

Edit, run the checks, commit, push. In an open session, `/reload-plugins` picks up changes without restarting.

## Adding another plugin

1. Create `plugins/<name>/` with `.claude-plugin/plugin.json` and its `skills/`, `agents/`, `.mcp.json` as needed.
2. Add an entry to `.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`.
3. `claude plugin validate plugins/<name>` and `claude plugin validate .`, then push. Install with `claude plugin install <name>@kevthedev`.
EOF
```

- [ ] **Step 2: Verify the README carries the exact install and update commands and that validation still passes**

Run:
```bash
grep -c 'claude plugin marketplace add cabrerakevinc/ship-plugin' README.md
grep -c 'claude plugin install ship@kevthedev' README.md
grep -c 'claude plugin update ship@kevthedev' README.md
scripts/check.sh | tail -1
```
Expected: `1`, `1`, `1`, `ALL CHECKS PASSED`.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "$(cat <<'MSG'
Add README with install, update and development instructions

Created by KevTheDev
MSG
)"
```

---

### Task 7: Push to GitHub and install from there as the first consumer

**Files:**
- None created. This task pushes to the existing public repo and installs into the current Claude profile (`CLAUDE_CONFIG_DIR` = `~/.claude-bevz`).

**Interfaces:**
- Consumes: everything committed in Tasks 1–6 on `main`.
- Produces: `main` pushed to `https://github.com/cabrerakevinc/ship-plugin` (public); marketplace `kevthedev` and plugin `ship@kevthedev` installed at user scope.

- [ ] **Step 1: Confirm the tree is clean and GitHub auth is in place**

Run:
```bash
git status --short | wc -l
gh auth status 2>&1 | grep -E 'Logged in|account'
```
Expected: `0` (nothing uncommitted) and a line showing the `cabrerakevinc` account is logged in. If the tree is not clean, commit or discard before continuing.

- [ ] **Step 2: Push to the existing public repo**

The repo `cabrerakevinc/ship-plugin` already exists and is empty; do not create one.

```bash
gh repo view cabrerakevinc/ship-plugin --json visibility,isEmpty,url --jq '{visibility, isEmpty, url}'
git remote add origin https://github.com/cabrerakevinc/ship-plugin.git
git push -u origin main
gh repo view cabrerakevinc/ship-plugin --json visibility,url,defaultBranchRef --jq '{visibility, url, branch: .defaultBranchRef.name}'
```
Expected before the push: `"visibility": "PUBLIC"`, `"isEmpty": true`. After: `"visibility": "PUBLIC"`, the URL, and `"branch": "main"`. If `isEmpty` is `false` before the push, stop and report what the remote already contains rather than pushing over it.

- [ ] **Step 3: Add the marketplace from GitHub**

Run: `claude plugin marketplace add cabrerakevinc/ship-plugin`
Expected: success message naming the marketplace `kevthedev`. Then:

Run: `claude plugin marketplace list`
Expected: `kevthedev` appears with the GitHub source.

The repo is public, so no credentials are involved. If the add fails, the likely cause is that the push in Step 2 did not land or the manifest path is wrong; check `gh repo view cabrerakevinc/ship-plugin --json isEmpty` and that `.claude-plugin/marketplace.json` is at the repo root on `main`.

- [ ] **Step 4: Install the plugin and confirm its inventory**

```bash
claude plugin install ship@kevthedev
claude plugin list
claude plugin details ship@kevthedev
```
Expected: install succeeds at user scope; `claude plugin list` shows `ship@kevthedev` enabled; `claude plugin details ship@kevthedev` lists 4 skills (`new-ticket`, `new-feature`, `hotfix`, `projma`), 9 agents, and 1 MCP server (`linear`). If `details` does not accept the `@kevthedev` suffix, run `claude plugin details ship`.

- [ ] **Step 5: Confirm the installed copy matches the repo**

```bash
installed=$(python3 -c "import json,os; d=json.load(open(os.path.expandvars('$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json'))); print(d['plugins']['ship@kevthedev'][0]['installPath'])")
echo "$installed"
diff -r --exclude=.git "$installed" plugins/ship && echo "INSTALLED COPY MATCHES REPO"
```
Expected: the install path is printed and `INSTALLED COPY MATCHES REPO`. (If `CLAUDE_CONFIG_DIR` is unset in the shell, substitute `~/.claude-bevz` explicitly.)

- [ ] **Step 6: Report the remaining manual step**

Nothing to commit. Tell the user: open Claude Code, run `/mcp`, and complete the Linear login once for this profile. Repeat the two install commands in the `~/.claude` profile if the plugin is wanted there too. Mention that the repo is public, so the design docs under `docs/superpowers/` are public as well.

---

---

### Task 8: Consolidate the architect, add the infrastructure-first rule, rename the iOS engineer (amendment 2026-09-04)

Kevin asked, after Tasks 1–6 were built, to (1) remove `architect` and fold its role into `solutions-architect`, (2) make `solutions-architect` establish a high-level picture of the infrastructure before designing — repo docs/IaC first, then AWS MCP **read-only** with the user's explicit permission (run by the orchestrating skill, since the architect has no MCP access), else a user-supplied description or diagram — and (3) rename `front-end-swift-engineer` to `front-end-ios-engineer`. The spec (§2, §5 amendment paragraph, Appendix A.2, A.3 removed, A.4, A.5, A.7, A.8, A.12, A.13) already carries the new content; this task makes the files match it.

**Files:**
- Delete: `plugins/ship/agents/architect.md`
- Rename (git mv) then rewrite: `plugins/ship/agents/front-end-swift-engineer.md` → `plugins/ship/agents/front-end-ios-engineer.md` (spec A.4)
- Rewrite from spec: `plugins/ship/agents/solutions-architect.md` (A.2), `plugins/ship/agents/front-end-android-engineer.md` (A.5), `plugins/ship/agents/front-end-web-developer.md` (A.7), `plugins/ship/agents/backend-engineer.md` (A.8), `plugins/ship/skills/new-feature/SKILL.md` (A.12), `plugins/ship/skills/hotfix/SKILL.md` (A.13)
- Modify: `scripts/check.sh` (agents section and orchestrating-skills expectations)
- Modify: `scripts/smoke.sh` (inventory list)
- Modify: `README.md` (agent list and the `new-feature` flow line)

**Interfaces:**
- Consumes: `ok`/`bad`/`need_file`/`expect_refs` helpers in `scripts/check.sh`; spec Appendix A as the content source; `scripts/spec-diff.py`.
- Produces: nine agents; `ship:solutions-architect` returns either a brief + per-platform design notes or an infrastructure-context request; `/ship:new-feature` handles that request with the explicit read-only permission protocol.

- [ ] **Step 1: Update `scripts/check.sh` — agents section**

Replace the `AGENTS=(...)` line with:

```bash
AGENTS=(ba-intake solutions-architect front-end-ios-engineer front-end-android-engineer front-end-web-designer front-end-web-developer backend-engineer qa-tester tech-lead-reviewer)
```

Replace the `BARE='...'` line with (retired names stay in the pattern so a bare backticked mention of them is still caught):

```bash
BARE='`(ba-intake|solutions-architect|architect|front-end-ios-engineer|front-end-swift-engineer|front-end-android-engineer|front-end-web-designer|front-end-web-developer|backend-engineer|qa-tester|tech-lead-reviewer)`'
```

Replace everything from the line `A=plugins/ship/agents` through the line `if [ -f $A/tech-lead-reviewer.md ] && grep -q '`ship:' $A/tech-lead-reviewer.md; then bad "tech-lead-reviewer.md should reference no agents"; fi` with:

```bash
A=plugins/ship/agents
expect_refs $A/ba-intake.md tech-lead-reviewer 1
if [ -f $A/solutions-architect.md ] && grep -q '`ship:' $A/solutions-architect.md; then bad "solutions-architect.md should reference no agents"; fi
for e in front-end-ios-engineer front-end-android-engineer; do
  expect_refs $A/$e.md solutions-architect 1
  expect_refs $A/$e.md qa-tester 1;  expect_refs $A/$e.md tech-lead-reviewer 1
done
expect_refs $A/front-end-web-designer.md front-end-web-developer 2
expect_refs $A/front-end-web-developer.md front-end-web-designer 1
expect_refs $A/front-end-web-developer.md backend-engineer 1
expect_refs $A/front-end-web-developer.md qa-tester 1
expect_refs $A/front-end-web-developer.md tech-lead-reviewer 1
for r in solutions-architect front-end-ios-engineer front-end-android-engineer front-end-web-developer qa-tester tech-lead-reviewer; do
  expect_refs $A/backend-engineer.md $r 1
done
if [ -f $A/qa-tester.md ] && grep -q '`ship:' $A/qa-tester.md; then bad "qa-tester.md should reference no agents"; fi
if [ -f $A/tech-lead-reviewer.md ] && grep -q '`ship:' $A/tech-lead-reviewer.md; then bad "tech-lead-reviewer.md should reference no agents"; fi
[ -e $A/architect.md ] && bad "$A/architect.md must not exist (consolidated into solutions-architect)"
[ -e $A/front-end-swift-engineer.md ] && bad "$A/front-end-swift-engineer.md must not exist (renamed front-end-ios-engineer)"
if grep -rnE 'ship:architect`|front-end-swift-engineer' plugins/ship README.md 2>/dev/null; then
  bad "stale references to retired agent names found above"
else
  ok "no references to retired agent names (architect, front-end-swift-engineer)"
fi
```

- [ ] **Step 2: Update `scripts/check.sh` — orchestrating-skills expectations**

Replace everything from the line `expect_refs $S/new-ticket/SKILL.md ba-intake 2` through the line `expect_refs $S/hotfix/SKILL.md tech-lead-reviewer 2` with:

```bash
expect_refs $S/new-ticket/SKILL.md ba-intake 2
expect_refs $S/new-ticket/SKILL.md projma 1
expect_refs $S/new-feature/SKILL.md solutions-architect 5
expect_refs $S/new-feature/SKILL.md front-end-web-designer 1
expect_refs $S/new-feature/SKILL.md front-end-web-developer 2
expect_refs $S/new-feature/SKILL.md front-end-ios-engineer 1
expect_refs $S/new-feature/SKILL.md front-end-android-engineer 1
expect_refs $S/new-feature/SKILL.md backend-engineer 1
expect_refs $S/new-feature/SKILL.md qa-tester 2
expect_refs $S/new-feature/SKILL.md tech-lead-reviewer 2
expect_refs $S/new-feature/SKILL.md projma 1
grep -q 'read-only' $S/new-feature/SKILL.md 2>/dev/null || bad "$S/new-feature/SKILL.md must carry the read-only AWS permission protocol"
for r in solutions-architect front-end-ios-engineer front-end-android-engineer front-end-web-developer backend-engineer qa-tester ba-intake projma; do
  expect_refs $S/hotfix/SKILL.md $r 1
done
expect_refs $S/hotfix/SKILL.md tech-lead-reviewer 2
```

- [ ] **Step 3: Run the check script; expect failure**

Run: `scripts/check.sh`
Expected: `FAIL missing plugins/ship/agents/front-end-ios-engineer.md`, the two "must not exist" failures, the stale-references failure (listing lines in agents, skills and README), several `expected N ref(s)` failures, and `CHECKS FAILED`, exit 1.

- [ ] **Step 4: Apply the content changes from the spec**

```bash
git rm -q plugins/ship/agents/architect.md
git mv plugins/ship/agents/front-end-swift-engineer.md plugins/ship/agents/front-end-ios-engineer.md
```

Then rewrite each of these files with **exactly** the fenced block content from `docs/superpowers/specs/2026-09-04-ship-plugin-design.md` (quoted heredocs, single trailing newline):

| File | Spec section |
|---|---|
| `plugins/ship/agents/solutions-architect.md` | A.2 |
| `plugins/ship/agents/front-end-ios-engineer.md` | A.4 |
| `plugins/ship/agents/front-end-android-engineer.md` | A.5 |
| `plugins/ship/agents/front-end-web-developer.md` | A.7 |
| `plugins/ship/agents/backend-engineer.md` | A.8 |
| `plugins/ship/skills/new-feature/SKILL.md` | A.12 |
| `plugins/ship/skills/hotfix/SKILL.md` | A.13 |

- [ ] **Step 5: Update `scripts/smoke.sh`**

Replace the `for n in ship:projma \` … `ship:backend-engineer ship:qa-tester ship:tech-lead-reviewer; do` list so it reads:

```bash
for n in ship:projma \
         ship:ba-intake ship:solutions-architect \
         ship:front-end-ios-engineer ship:front-end-android-engineer \
         ship:front-end-web-designer ship:front-end-web-developer \
         ship:backend-engineer ship:qa-tester ship:tech-lead-reviewer; do
```

Nothing else in `smoke.sh` changes.

- [ ] **Step 6: Update `README.md`**

Replace the `/ship:new-feature` bullet with:

```
- `/ship:new-feature <ticket or description>` — solutions-architect (when the ticket is unclear, multi-platform, or non-trivial; it insists on understanding the infrastructure first, asking you for explicit read-only AWS access or a diagram if the repo doesn't tell it enough) → platform engineer(s) → qa-tester → tech-lead-reviewer, posting a sign-off on the ticket after every step. Ends in the ready-for-review state. Never closes the ticket.
```

Replace the agent list (the ten `- \`ship:...\`` lines) with these nine:

```
- `ship:ba-intake` — ticket drafts with a DoD checklist (read-only)
- `ship:solutions-architect` — cross-platform shape and per-platform design notes; infrastructure-first (read-only, no cloud access of its own)
- `ship:front-end-ios-engineer` — iOS implementation
- `ship:front-end-android-engineer` — Android implementation
- `ship:front-end-web-designer` — web UI/UX spec (writes the spec file only)
- `ship:front-end-web-developer` — web implementation
- `ship:backend-engineer` — backend implementation
- `ship:qa-tester` — runs and writes tests, never edits production code
- `ship:tech-lead-reviewer` — item-by-item DoD review (read-only)
```

- [ ] **Step 7: Verify fidelity, structure and behaviour**

Run:
```bash
scripts/spec-diff.py plugins/ship/agents/solutions-architect.md plugins/ship/agents/front-end-ios-engineer.md plugins/ship/agents/front-end-android-engineer.md plugins/ship/agents/front-end-web-developer.md plugins/ship/agents/backend-engineer.md plugins/ship/skills/new-feature/SKILL.md plugins/ship/skills/hotfix/SKILL.md
scripts/check.sh
scripts/smoke.sh
```
Expected: seven `match:` lines; `ALL CHECKS PASSED`; `SMOKE PASSED` with ten `inventory lists` ok lines (projma + nine agents) and section 2 unchanged (15 ok). A linear `WARN` is acceptable.

- [ ] **Step 8: Commit**

```bash
git add -A plugins/ship scripts/check.sh scripts/smoke.sh README.md
git commit -m "$(cat <<'MSG'
Consolidate architect into solutions-architect, add infrastructure-first rule, rename iOS engineer

solutions-architect now owns both the cross-platform brief and the per-platform
design notes, and must understand the infrastructure before designing: repo
docs/IaC first, then AWS MCP read-only with the user's explicit permission (run
by the orchestrating skill), else a user-supplied description or diagram.
front-end-swift-engineer is renamed front-end-ios-engineer.

Created by KevTheDev
MSG
)"
```

## Self-review notes

- **Spec coverage:** §3 layout → Tasks 1–4; §4 manifests → Task 1; §5 agents/skills with `ship:` prefix and exact reference counts → Tasks 2–3 (`expect_refs`); §6 tracker skill, templates, `init`/`status` behaviour → Task 4 (content) and Task 5 (behaviour); §7 README → Task 6; §8 install/update flow → Task 7 and README; §9 verification items 1, 2, 2a, 3, 4 → Tasks 1–5 and 7, item 5 (manual `/mcp`) → Task 7 Step 6; §10 out of scope respected (no nightcap-skills, no hooks, no root CLAUDE.md); §11 testing approach → `check.sh` reference grep.
- **Placeholders:** none; every file's content is either inline or a named spec appendix block verified by `spec-diff.py`.
- **Consistency:** helper names `ok`/`bad`/`need_file`/`expect_refs` and section markers are identical across Tasks 1–4; the `tasks.csv` header string is identical in Task 4, Task 5 and spec A.17.
