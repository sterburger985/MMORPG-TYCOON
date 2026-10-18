"""Build a Studio install model (.rbxm) for one place from its Rojo project.

Usage: python3 tools/make-install-model.py hub|world OUT.rbxm

The model is a Folder "Install_<place>" whose children mirror the services
(ReplicatedStorage, ServerScriptService, ServerStorage, StarterPlayerScripts) plus
Tools/BuildPlaceholderAssets. Insert it with File > Import Roblox Model and run the
snippet in tools/INSTALL-from-rbxm.md.
"""
import json, os, subprocess, sys, tempfile

place, out = sys.argv[1], sys.argv[2]
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tree = json.load(open(os.path.join(root, f"{place}.project.json")))["tree"]

def absolutize(node):
    node = dict(node)
    if "$path" in node:
        node["$path"] = os.path.join(root, node["$path"])
    for k, v in list(node.items()):
        if not k.startswith("$") and isinstance(v, dict):
            node[k] = absolutize(v)
    return node

inst = {"$className": "Folder"}
for service in ("ReplicatedStorage", "ServerScriptService", "ServerStorage"):
    folder = {"$className": "Folder"}
    for k, v in tree.get(service, {}).items():
        if not k.startswith("$") and isinstance(v, dict):
            folder[k] = absolutize(v)
    inst[service] = folder
sps = tree.get("StarterPlayer", {}).get("StarterPlayerScripts", {})
inst["StarterPlayerScripts"] = {"$className": "Folder", **{k: absolutize(v) for k, v in sps.items() if not k.startswith("$") and isinstance(v, dict)}}
inst["Tools"] = {"$className": "Folder", "BuildPlaceholderAssets": {"$path": os.path.join(root, "tools/BuildPlaceholderAssets.module.luau")}}

with tempfile.TemporaryDirectory() as d:
    proj = os.path.join(d, "default.project.json")
    json.dump({"name": f"Install_{place}", "tree": inst}, open(proj, "w"), indent=1)
    subprocess.run([os.path.expanduser("~/tools/rojo"), "build", proj, "-o", os.path.abspath(out)], check=True, stdout=subprocess.DEVNULL)
print("built", out)
