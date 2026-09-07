# ship-plugin

KevTheDev's Claude Code plugin marketplace, named `kevthedev`. One repo, installable on any machine with `claude plugin ...`.

| Plugin | What it is |
|---|---|
| [`ship`](plugins/ship) | A role-based dev team: ticket intake, architecture, platform engineers, QA and tech-lead review, run by `/ship:new-ticket`, `/ship:new-feature` and `/ship:hotfix`. Falls back to a file tracker (`/ship:projma`) when Linear isn't connected. Teaches and enforces a What / Why / Risk [commit convention](#commit-convention) in every repo where it's enabled. |

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

Commands. You run the first three; Claude never triggers them on its own. `/ship:projma` can also be invoked by those skills, after you say yes to creating the tracker.

- `/ship:new-ticket <idea or bug>` — `ship:ba-intake` drafts a title, scope and a Definition of Done checklist; the ticket is created for you.
- `/ship:new-feature <ticket or description>` — solutions-architect (when the ticket is unclear, multi-platform, or non-trivial; it insists on understanding the infrastructure first, asking you for explicit read-only AWS access or a diagram if the repo doesn't tell it enough) → platform engineer(s) → qa-tester → tech-lead-reviewer, posting a sign-off on the ticket after every step. Ends with the ticket in the ready-for-review state and one commit in the [commit convention](#commit-convention), ticket ID in the subject. Never pushes. Never closes the ticket.
- `/ship:hotfix <ticket or bug>` — fast lane: reproduce, minimal fix, targeted tests, regression-focused review, one commit.
- `/ship:projma [init | status]` — the file-based tracker. `init` scaffolds `docs/projma/`; `status` summarises open tickets.

Agents. Read-only ones cannot edit code or touch the tracker.

- `ship:ba-intake` — ticket drafts with a DoD checklist (read-only)
- `ship:solutions-architect` — cross-platform shape and per-platform design notes; infrastructure-first (read-only, no cloud access of its own)
- `ship:front-end-ios-engineer` — iOS implementation
- `ship:front-end-android-engineer` — Android implementation
- `ship:front-end-web-designer` — web UI/UX spec (writes the spec file only)
- `ship:front-end-web-developer` — web implementation
- `ship:backend-engineer` — backend implementation
- `ship:qa-tester` — runs and writes tests, never edits production code
- `ship:tech-lead-reviewer` — item-by-item DoD review (read-only)

Only the main session writes to the ticket tracker; no subagent has Linear or file-tracker write access. Nothing here ever sets a ticket to Closed. That is your call, after your own final check.

## Commit convention

With `ship` enabled, every commit Claude makes, in any repo, has this shape:

```
<type>(<scope>)?: <summary> (<ref>)?

## What
## Why
## Risk
```

Two hooks in [`plugins/ship/hooks/`](plugins/ship/hooks/) do it. A SessionStart hook hands the model [the convention](plugins/ship/hooks/commit-convention.md); a PreToolUse hook rejects any `git commit` whose message doesn't follow it and shows the convention again. The hook checks structure, not content: the subject type, the 72-character limit, and three non-empty sections in order. `/ship:new-feature` and `/ship:hotfix` end by committing the finished work this way, with the ticket ID as the `ref`; they never push. A `Created by …` trailer comes from your own `attribution` setting, not the plugin. To turn it off in one profile, disable the plugin or remove its hooks under `/hooks`.

## Linear is optional

The plugin registers the Linear MCP server (`https://mcp.linear.app/mcp`). To turn it off in one profile, open `/mcp` and toggle it; the plugin stays installed.

Without Linear, the skills use `docs/projma/` in the target repo: `tasks.csv` (the index and the only place status lives), one file per ticket under `resources/` with its DoD checklist and sign-off log, and `memory.md` for durable project context. The skills ask once before creating that folder. Conventions: [`plugins/ship/skills/projma/templates/CLAUDE.md`](plugins/ship/skills/projma/templates/CLAUDE.md).

## Developing

```
scripts/check.sh    # structural checks + claude plugin validate
scripts/smoke.sh    # functional test: a few Claude calls, throwaway repo
scripts/test-commit-hook.sh    # fixture tests for the commit-message hook
claude --plugin-dir plugins/ship    # try it in a real session without installing
```

Edit, run the checks, commit, push. In an open session, `/reload-plugins` picks up changes without restarting.

`claude plugin validate` warns that no version is specified. That is expected: the git commit is the version.

## Adding another plugin

1. Create `plugins/<name>/` with `.claude-plugin/plugin.json` and its `skills/`, `agents/`, `.mcp.json` as needed.
2. Add an entry to `.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`.
3. `claude plugin validate plugins/<name>` and `claude plugin validate .`, then push. Install with `claude plugin install <name>@kevthedev`.
