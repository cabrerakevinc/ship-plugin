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
