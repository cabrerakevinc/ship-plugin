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
