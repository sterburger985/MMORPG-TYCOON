# Installing a build into Studio

Use this while Rojo / the Studio connector isn't available. Each `*-install-rN.rbxm` holds every script for one place. Use the highest `rN`; older files can be deleted.

1. Open the place in Studio (hub: `MMORPG TYCOON.rbxl`; world: `MMORPG TYCOON WORLD.rbxl`).
2. Select **Workspace** in the Explorer, then **File → Import Roblox Model** and pick `hub-install-rN.rbxm` or `world-install-rN.rbxm` from this folder. An `Install_hub` / `Install_world` folder appears in Workspace.
3. Open the command bar (View → Command Bar), paste the snippet below and press **Run**. If Studio shows "Dangerous Command Detected", click **Continue** (it only deletes the installer folder after moving its contents).
4. Check the Output window for `[Install] … moved 4 roots, scripts now N` (hub 27, world 40), then **Ctrl+S**.

```lua
local inst = workspace:FindFirstChild("Install_world") or workspace:FindFirstChild("Install_hub"); local moved = 0; for _, svcFolder in inst:GetChildren() do if svcFolder.Name ~= "Tools" then local target = svcFolder.Name == "StarterPlayerScripts" and game.StarterPlayer.StarterPlayerScripts or game:GetService(svcFolder.Name); for _, child in svcFolder:GetChildren() do local old = target:FindFirstChild(child.Name); if old then old:Destroy() end; child.Parent = target; moved += 1 end end end; require(inst.Tools.BuildPlaceholderAssets); local n = 0; for _, d in game:GetDescendants() do if d:IsA("LuaSourceContainer") and (d:IsDescendantOf(game.ServerScriptService) or d:IsDescendantOf(game.ReplicatedStorage) or d:IsDescendantOf(game.ServerStorage) or d:IsDescendantOf(game.StarterPlayer)) then n += 1 end end; print("[Install] " .. inst.Name .. " moved " .. moved .. " roots, scripts now " .. n); inst:Destroy()
```

It replaces `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `ServerStorage.UnitTest` and `StarterPlayerScripts.Client` as whole folders and rebuilds `ReplicatedStorage.Assets.Items`. Nothing else in the place is touched.
