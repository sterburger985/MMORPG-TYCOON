"""Print a checksum per script so the repo can be compared with the scripts in the open place.
Studio side (run through the connector or command bar):
  local function h(s) local x = 0 for i = 1, #s do x = (x * 31 + string.byte(s, i)) % 1000000007 end return x end
  -- then print d.Name .. " " .. h(d.Source) for every script under Shared / Server / UnitTest
"""
import glob, os, sys

def h(b: bytes) -> int:
    x = 0
    for c in b:
        x = (x * 31 + c) % 1000000007
    return x

import json

# Usage: python3 tools/checksums.py hub.project.json   (or world.project.json)
project = sys.argv[1] if len(sys.argv) > 1 else "hub.project.json"

def files(node, acc):
    for k, v in node.items():
        if k == "$path":
            if os.path.isdir(v):
                acc += glob.glob(os.path.join(v, "**/*.luau"), recursive=True)
            else:
                acc.append(v)
        elif isinstance(v, dict):
            files(v, acc)
    return acc

rows = []
for f in sorted(set(files(json.load(open(project))["tree"], []))):
    name = os.path.basename(f).replace(".server.luau", "").replace(".client.luau", "").replace(".luau", "")
    rows.append(f"{name} {h(open(f, 'rb').read())}")
print("\n".join(sorted(rows)))
