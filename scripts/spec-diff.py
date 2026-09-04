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
