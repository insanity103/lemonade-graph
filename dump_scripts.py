#!/usr/bin/env python3
import re, sys, pathlib

# Only writes files: scripts deleted in Studio would linger if this targeted the
# mirror directly. Split into a staging dir, diff it against lemonade-game/, then sync.
if len(sys.argv) < 2:
    sys.exit("usage: dump_scripts.py <run_code dump file> [out_dir]")
SRC = sys.argv[1]
OUT = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "lemonade-game")

text = pathlib.Path(SRC).read_text(encoding="utf-8", errors="replace")

# Strip a leading "[OUTPUT]" line if present
pat = re.compile(r"<<<FILE path=(?P<path>.+?) class=(?P<cls>\w+)>>>\n(?P<body>.*?)\n<<<ENDFILE>>>", re.S)

ext = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}
count = 0
for m in pat.finditer(text):
    rbx_path = m.group("path").strip()
    cls = m.group("cls").strip()
    body = m.group("body")
    parts = rbx_path.split("/")
    fname = parts[-1] + ext.get(cls, ".luau")
    # sanitize path segments (spaces -> keep, but strip weird chars minimally)
    dirs = [p.replace("\x00", "") for p in parts[:-1]]
    dest = OUT.joinpath(*dirs, fname)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(body, encoding="utf-8")
    count += 1
    print(f"{cls:13} {rbx_path}  ->  {dest}")

tot = re.search(r"<<<TOTAL (\d+)>>>", text)
print(f"\nwrote {count} files" + (f" (script reported {tot.group(1)})" if tot else ""))
