"""Generate Studio command-bar installer chunks from a Rojo project file.

Usage: python3 tools/make-installer.py world.project.json OUT_DIR [max_chunk_bytes]

Each chunk is plain Luau to paste into Studio's command bar (Edit mode). Together the
chunks write every script in the project into the open place (creating folders, fixing
wrong classes) and, in the final chunk, delete scripts under the managed roots that the
project no longer contains. This is the fallback when neither Rojo nor the Studio MCP
connector is available.
"""
import json
import os
import sys

project_path, out_dir = sys.argv[1], sys.argv[2]
max_chunk = int(sys.argv[3]) if len(sys.argv) > 3 else 40000

SERVICES = {"ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterPlayer", "Workspace", "ReplicatedFirst", "StarterGui"}


def class_for(filename):
    if filename.endswith(".server.luau") or filename.endswith(".server.lua"):
        return "Script"
    if filename.endswith(".client.luau") or filename.endswith(".client.lua"):
        return "LocalScript"
    return "ModuleScript"


def name_for(filename):
    base = os.path.basename(filename)
    for suffix in (".server.luau", ".client.luau", ".server.lua", ".client.lua", ".luau", ".lua"):
        if base.endswith(suffix):
            return base[: -len(suffix)]
    return base


entries = []  # (path parts, class, source)
managed_roots = []


def walk(node, parts):
    path = node.get("$path")
    if path:
        if os.path.isdir(path):
            for root, _dirs, files in os.walk(path):
                rel = os.path.relpath(root, path)
                sub = [] if rel == "." else rel.split(os.sep)
                for f in sorted(files):
                    if f.endswith((".luau", ".lua")):
                        entries.append((parts + sub + [name_for(f)], class_for(f), open(os.path.join(root, f), encoding="utf-8").read()))
        else:
            entries.append((parts, class_for(path), open(path, encoding="utf-8").read()))
    for key, child in node.items():
        if key.startswith("$") or not isinstance(child, dict):
            continue
        walk(child, parts + [key])


tree = json.load(open(project_path))["tree"]
for service, node in tree.items():
    if service.startswith("$"):
        continue
    for key, child in node.items():
        if key.startswith("$") or not isinstance(child, dict):
            continue
        if service == "StarterPlayer":
            for k2, c2 in child.items():
                if not k2.startswith("$") and isinstance(c2, dict):
                    managed_roots.append([service, key, k2])
                    walk(c2, [service, key, k2])
        else:
            managed_roots.append([service, key])
            walk(child, [service, key])


def long_string(src):
    level = 1
    while ("]" + "=" * level + "]") in src:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{src}]{eq}]"


HEADER = '''local function __node(parts, class)
	local cur = game:GetService(parts[1])
	for i = 2, #parts do
		local name = parts[i]
		local want = if i == #parts then class else "Folder"
		local child = cur:FindFirstChild(name)
		if child and i == #parts and child.ClassName ~= want then child:Destroy(); child = nil end
		if child == nil then
			child = Instance.new(want)
			child.Name = name
			child.Parent = cur
		end
		cur = child
	end
	return cur
end
local __n = 0
local function __put(parts, class, src)
	__node(parts, class).Source = src
	__n += 1
end
'''

chunks, current = [], []
size = 0
for parts, cls, src in entries:
    stmt = f'__put({json.dumps(parts)}, "{cls}", {long_string(src)})\n'.replace("[\"", "{\"", 1)
    # Luau table literal for the path
    stmt = "__put({" + ", ".join(json.dumps(p) for p in parts) + "}, \"" + cls + "\", " + long_string(src) + ")\n"
    if current and size + len(stmt) > max_chunk:
        chunks.append(current)
        current, size = [], 0
    current.append(stmt)
    size += len(stmt)
if current:
    chunks.append(current)

keep = {"/".join(p) for p, _c, _s in entries}
prune_lines = ["local __keep = {"] + [f'\t[{json.dumps(k)}] = true,' for k in sorted(keep)] + ["}"]
prune_lines.append("local __removed = 0")
prune_lines.append("for _, root in {" + ", ".join("{" + ", ".join(json.dumps(p) for p in r) + "}" for r in managed_roots) + "} do")
prune_lines.append('''	local cur = game:GetService(root[1])
	for i = 2, #root do cur = cur and cur:FindFirstChild(root[i]) end
	if cur then
		for _, d in cur:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				local parts = {}
				local x = d
				while x and x ~= game do table.insert(parts, 1, x.Name); x = x.Parent end
				parts[1] = game:GetService(parts[1]) and parts[1]
				if not __keep[table.concat(parts, "/")] then d:Destroy(); __removed += 1 end
			end
		end
	end
end''')

os.makedirs(out_dir, exist_ok=True)
for i, chunk in enumerate(chunks, 1):
    body = HEADER + "".join(chunk)
    if i == len(chunks):
        body += "\n".join(prune_lines) + "\n"
        body += f'print(("[Install] chunk {i}/{len(chunks)}: wrote %d scripts, removed %d stale"):format(__n, __removed))\n'
    else:
        body += f'print(("[Install] chunk {i}/{len(chunks)}: wrote %d scripts"):format(__n))\n'
    path = os.path.join(out_dir, f"install_{i:02d}.lua")
    open(path, "w", encoding="utf-8").write(body)
    print(path, len(body.encode()))
print(f"{len(entries)} scripts in {len(chunks)} chunks")
