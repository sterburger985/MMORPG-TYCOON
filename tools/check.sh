#!/usr/bin/env bash
# Build each place with Rojo and type-check the files that place actually uses.
# Needs rojo and luau-lsp (+ Roblox globalTypes.d.luau) in ~/tools.
set -u
cd "$(dirname "$0")/.."
status=0
for p in hub world; do
  ~/tools/rojo sourcemap "$p.project.json" -o sourcemap.json >/dev/null || status=1
  ~/tools/rojo build "$p.project.json" -o "/tmp/$p-check.rbxl" >/dev/null || status=1
  paths=$(python3 - "$p.project.json" <<'PY'
import json, sys
def walk(n, acc):
    for k, v in n.items():
        if k == "$path": acc.append(v)
        elif isinstance(v, dict): walk(v, acc)
    return acc
print(" ".join(walk(json.load(open(sys.argv[1]))["tree"], [])))
PY
)
  out=$(~/tools/luau-lsp analyze --sourcemap=sourcemap.json --definitions="$HOME/tools/globalTypes.d.luau" --platform=roblox $paths 2>&1 | grep -v '^\[')
  if [ -n "$out" ]; then echo "== $p: problems"; echo "$out"; status=1; else echo "== $p: build OK, 0 type errors"; fi
done
exit $status
