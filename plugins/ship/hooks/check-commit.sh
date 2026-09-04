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
