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
