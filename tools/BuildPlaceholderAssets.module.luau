-- BuildPlaceholderAssets (dev helper, run in EDIT mode from the command bar or the Studio connector)
-- Rebuilds the Phase 1 placeholder item models in ReplicatedStorage.Assets.Items.
-- Each model:
--   * is built at the origin with its footprint centred on X/Z and its bottom at Y = 0
--   * has WorldPivot at the bottom centre (what GridMath.footprintCFrame expects)
--   * has an invisible "Hitbox" PrimaryPart covering the footprint (the only queryable part,
--     used later by remove-mode raycasts); decorative parts have CanQuery/CanTouch off
-- Footprint sizes must match ItemCatalog (cells x 4 studs). Final art replaces these in Phase 3.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CELL = 4
local PREVIEW = false -- set to true to drop a preview row at (0, 0, 300)

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local items = folder(folder(ReplicatedStorage, "Assets"), "Items")

local function part(model, props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "ClassName" then
			p[k] = v
		end
	end
	p.Parent = model
	return p
end

local function newModel(name, wCells, dCells, height)
	local old = items:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = name
	local hit = part(m, {
		Name = "Hitbox",
		Size = Vector3.new(wCells * CELL, height, dCells * CELL),
		CFrame = CFrame.new(0, height / 2, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = true,
		CastShadow = false,
	})
	m.PrimaryPart = hit
	return m
end

local function finish(m)
	-- A model with a PrimaryPart pivots on PrimaryPart.CFrame * PivotOffset (WorldPivot is
	-- ignored), so the bottom-centre pivot has to be set on the hitbox itself.
	m.PrimaryPart.PivotOffset = m.PrimaryPart.CFrame:Inverse() * CFrame.new(0, 0, 0)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = items
	return m
end

-- Palette (shared look across all placeholders)
local STONE = Color3.fromRGB(163, 162, 155)
local STONE_DARK = Color3.fromRGB(120, 119, 114)
local BARK = Color3.fromRGB(110, 76, 50)
local LEAF = Color3.fromRGB(84, 140, 62)
local LEAF_LIGHT = Color3.fromRGB(112, 168, 78)
local PLASTER = Color3.fromRGB(236, 224, 198)
local TIMBER = Color3.fromRGB(96, 66, 44)
local ROOF = Color3.fromRGB(168, 74, 52)

-- Stone Path: 1x1 Floor tile, flagstones set into a mortar slab.
do
	local m = newModel("StonePath", 1, 1, 0.6)
	part(m, { Name = "Mortar", Size = Vector3.new(4, 0.3, 4), CFrame = CFrame.new(0, 0.15, 0),
		Material = Enum.Material.Concrete, Color = STONE_DARK, CastShadow = false })
	local stones = {
		{ Vector3.new(1.7, 0.25, 1.6), Vector3.new(-0.95, 0, -0.95), 4 },
		{ Vector3.new(1.6, 0.25, 1.7), Vector3.new(0.95, 0, -0.9), -6 },
		{ Vector3.new(1.65, 0.25, 1.6), Vector3.new(-0.9, 0, 0.95), -3 },
		{ Vector3.new(1.7, 0.25, 1.65), Vector3.new(0.95, 0, 0.95), 7 },
	}
	for i, s in stones do
		part(m, { Name = "Stone" .. i, Size = s[1],
			CFrame = CFrame.new(s[2].X, 0.38, s[2].Z) * CFrame.Angles(0, math.rad(s[3]), 0),
			Material = Enum.Material.Slate, Color = STONE, CastShadow = false })
	end
	finish(m)
end

-- Boulder: 1x1 Object, a big rock with a smaller one leaning on it.
do
	local m = newModel("Boulder", 1, 1, 3)
	part(m, { Name = "Rock", Size = Vector3.new(3, 2.4, 2.8),
		CFrame = CFrame.new(-0.2, 1.1, 0) * CFrame.Angles(math.rad(8), math.rad(25), math.rad(-6)),
		Material = Enum.Material.Rock, Color = STONE })
	part(m, { Name = "RockSmall", Size = Vector3.new(1.5, 1.2, 1.4),
		CFrame = CFrame.new(1.05, 0.55, 0.7) * CFrame.Angles(math.rad(-10), math.rad(-30), math.rad(12)),
		Material = Enum.Material.Rock, Color = STONE_DARK })
	finish(m)
end

-- Oak Tree: 2x2 Object, trunk with a clustered round canopy.
do
	local m = newModel("OakTree", 2, 2, 14)
	part(m, { Name = "Trunk", ClassName = "Part", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(7, 1.6, 1.6), CFrame = CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Wood, Color = BARK })
	part(m, { Name = "Roots", Size = Vector3.new(2.6, 0.6, 2.6), CFrame = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Wood, Color = BARK })
	local blobs = {
		{ 6.4, Vector3.new(0, 9.4, 0), LEAF },
		{ 4.6, Vector3.new(1.9, 8.2, 1.1), LEAF_LIGHT },
		{ 4.4, Vector3.new(-1.8, 8.4, -1.0), LEAF_LIGHT },
		{ 4.0, Vector3.new(-0.6, 11.4, 1.2), LEAF },
	}
	for i, b in blobs do
		part(m, { Name = "Leaves" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(b[1], b[1], b[1]),
			CFrame = CFrame.new(b[2]), Material = Enum.Material.Grass, Color = b[3] })
	end
	finish(m)
end

-- Cottage: 4x3 Object (16 x 12 studs), plaster walls, timber frame, gabled roof, chimney.
do
	local m = newModel("Cottage", 4, 3, 13)
	local W, D, H = 14, 10, 6.5
	part(m, { Name = "Foundation", Size = Vector3.new(W + 1, 0.6, D + 1), CFrame = CFrame.new(0, 0.3, 0),
		Material = Enum.Material.Cobblestone, Color = STONE_DARK })
	part(m, { Name = "Walls", Size = Vector3.new(W, H, D), CFrame = CFrame.new(0, 0.6 + H / 2, 0),
		Material = Enum.Material.Plaster, Color = PLASTER })
	-- Corner posts and a beam around the top of the walls.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, { Name = "Post", Size = Vector3.new(0.7, H, 0.7),
				CFrame = CFrame.new(sx * (W / 2), 0.6 + H / 2, sz * (D / 2)), Material = Enum.Material.Wood, Color = TIMBER })
		end
	end
	part(m, { Name = "BeamFront", Size = Vector3.new(W + 0.7, 0.6, 0.7), CFrame = CFrame.new(0, 0.6 + H - 0.3, -D / 2),
		Material = Enum.Material.Wood, Color = TIMBER })
	part(m, { Name = "BeamBack", Size = Vector3.new(W + 0.7, 0.6, 0.7), CFrame = CFrame.new(0, 0.6 + H - 0.3, D / 2),
		Material = Enum.Material.Wood, Color = TIMBER })
	-- Door and windows on the front (-Z) face.
	part(m, { Name = "Door", Size = Vector3.new(2.4, 4, 0.3), CFrame = CFrame.new(0, 0.6 + 2, -D / 2 - 0.1),
		Material = Enum.Material.WoodPlanks, Color = TIMBER })
	for _, sx in { -1, 1 } do
		part(m, { Name = "Window", Size = Vector3.new(2.2, 1.8, 0.3), CFrame = CFrame.new(sx * 4.2, 0.6 + 3.9, -D / 2 - 0.1),
			Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 196, 220), Transparency = 0.2 })
		part(m, { Name = "Shutter", Size = Vector3.new(2.6, 0.35, 0.4), CFrame = CFrame.new(sx * 4.2, 0.6 + 2.85, -D / 2 - 0.15),
			Material = Enum.Material.Wood, Color = TIMBER })
	end
	-- Gabled roof from two wedges meeting along the X axis, with a small overhang.
	local roofH, over = 4.5, 0.8
	local half = D / 2 + over
	for _, sz in { -1, 1 } do
		part(m, { Name = "Roof", ClassName = "WedgePart", Size = Vector3.new(W + over * 2, roofH, half),
			CFrame = CFrame.new(0, 0.6 + H + roofH / 2, sz * half / 2) * CFrame.Angles(0, sz == 1 and 0 or math.pi, 0),
			Material = Enum.Material.Slate, Color = ROOF })
	end
	part(m, { Name = "Chimney", Size = Vector3.new(1.4, 4, 1.4), CFrame = CFrame.new(4.5, 0.6 + H + 2.6, 2),
		Material = Enum.Material.Brick, Color = Color3.fromRGB(150, 98, 82) })
	finish(m)
end

-- Shared accents for the fantasy set
local IRON = Color3.fromRGB(52, 50, 58)
local ARCANE = Color3.fromRGB(90, 200, 255)
local ARCANE_DEEP = Color3.fromRGB(40, 110, 230)
local CLOTH_BLUE = Color3.fromRGB(48, 110, 210)
local CLOTH_WHITE = Color3.fromRGB(236, 240, 248)
local WOOD = Color3.fromRGB(140, 98, 62)

local function light(parentPart, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parentPart
	return l
end

-- Arcane Crystal: 1x1 Magic, a cluster of glowing blue crystals on a rock.
do
	local m = newModel("ArcaneCrystal", 1, 1, 6)
	part(m, { Name = "Base", Size = Vector3.new(3.2, 1, 3), CFrame = CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.rad(20), 0),
		Material = Enum.Material.Rock, Color = STONE_DARK })
	local shards = {
		{ Vector3.new(1.1, 4.6, 1.1), Vector3.new(0, 3.1, 0), 0, 6 },
		{ Vector3.new(0.8, 3.0, 0.8), Vector3.new(0.85, 2.2, 0.4), 22, -18 },
		{ Vector3.new(0.7, 2.4, 0.7), Vector3.new(-0.8, 1.9, -0.3), -25, 14 },
		{ Vector3.new(0.6, 1.8, 0.6), Vector3.new(0.2, 1.6, -0.9), 18, 25 },
	}
	for i, sh in shards do
		local c = part(m, { Name = "Crystal" .. i, Size = sh[1],
			CFrame = CFrame.new(sh[2]) * CFrame.Angles(math.rad(sh[3]), math.rad(i * 37), math.rad(sh[4])),
			Material = Enum.Material.Neon, Color = if i == 1 then ARCANE else ARCANE_DEEP, Transparency = 0.15, CastShadow = false })
		if i == 1 then
			light(c, ARCANE, 14, 1.6)
		end
	end
	finish(m)
end

-- Lantern Post: 1x1 Decor, an iron post with a warm glowing lantern.
do
	local m = newModel("LanternPost", 1, 1, 8)
	part(m, { Name = "Foot", Size = Vector3.new(1.6, 0.5, 1.6), CFrame = CFrame.new(0, 0.25, 0), Material = Enum.Material.Slate, Color = IRON })
	part(m, { Name = "Post", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6.4, 0.45, 0.45),
		CFrame = CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = IRON })
	part(m, { Name = "Arm", Size = Vector3.new(1.6, 0.25, 0.25), CFrame = CFrame.new(0.7, 6.6, 0), Material = Enum.Material.Metal, Color = IRON })
	part(m, { Name = "Cap", Size = Vector3.new(1.1, 0.3, 1.1), CFrame = CFrame.new(1.4, 6.4, 0), Material = Enum.Material.Metal, Color = IRON })
	local glow = part(m, { Name = "Lantern", Size = Vector3.new(0.8, 1, 0.8), CFrame = CFrame.new(1.4, 5.7, 0),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 214, 140), CastShadow = false })
	light(glow, Color3.fromRGB(255, 200, 130), 16, 1.4)
	finish(m)
end

-- Wooden Fence: 1x1 Decor, two posts and two rails along the local X axis.
do
	local m = newModel("WoodenFence", 1, 1, 3)
	for _, sx in { -1, 1 } do
		part(m, { Name = "Post", Size = Vector3.new(0.5, 3, 0.5), CFrame = CFrame.new(sx * 1.7, 1.5, 0), Material = Enum.Material.Wood, Color = TIMBER })
	end
	for i, y in { 1.1, 2.3 } do
		part(m, { Name = "Rail" .. i, Size = Vector3.new(4, 0.35, 0.25), CFrame = CFrame.new(0, y, 0), Material = Enum.Material.WoodPlanks, Color = WOOD })
	end
	finish(m)
end

-- Stone Well: 2x2 Buildings, round stone wall, water, posts and a little roof.
do
	local m = newModel("StoneWell", 2, 2, 8)
	local ring = 8
	for i = 0, ring - 1 do
		local a = i / ring * math.pi * 2
		part(m, { Name = "Stone" .. i, Size = Vector3.new(2.3, 2.2, 0.8),
			CFrame = CFrame.new(math.cos(a) * 2.6, 1.1, math.sin(a) * 2.6) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Material = Enum.Material.Cobblestone, Color = if i % 2 == 0 then STONE else STONE_DARK })
	end
	part(m, { Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 4.6, 4.6),
		CFrame = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Glass,
		Color = Color3.fromRGB(70, 150, 220), Transparency = 0.25, CastShadow = false })
	for _, sx in { -1, 1 } do
		part(m, { Name = "Post", Size = Vector3.new(0.5, 4.5, 0.5), CFrame = CFrame.new(sx * 2.6, 4.2, 0), Material = Enum.Material.Wood, Color = TIMBER })
	end
	part(m, { Name = "Crank", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5.4, 0.4, 0.4), CFrame = CFrame.new(0, 5.2, 0),
		Material = Enum.Material.Wood, Color = WOOD })
	for _, sz in { -1, 1 } do
		part(m, { Name = "Roof", ClassName = "WedgePart", Size = Vector3.new(6.6, 1.6, 2.2),
			CFrame = CFrame.new(0, 7.2, sz * 1.1) * CFrame.Angles(0, sz == 1 and 0 or math.pi, 0), Material = Enum.Material.Slate, Color = CLOTH_BLUE })
	end
	finish(m)
end

-- Market Stall: 3x2 Buildings, counter with goods and a striped blue-and-white canopy.
do
	local m = newModel("MarketStall", 3, 2, 8)
	local W, D = 11, 7
	part(m, { Name = "Counter", Size = Vector3.new(W - 1, 2.6, 2), CFrame = CFrame.new(0, 1.3, -D / 2 + 1.4), Material = Enum.Material.WoodPlanks, Color = WOOD })
	part(m, { Name = "CounterTop", Size = Vector3.new(W - 0.6, 0.3, 2.4), CFrame = CFrame.new(0, 2.75, -D / 2 + 1.4), Material = Enum.Material.Wood, Color = TIMBER })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(m, { Name = "Post", Size = Vector3.new(0.5, 6, 0.5), CFrame = CFrame.new(sx * (W / 2 - 0.4), 3, sz * (D / 2 - 0.4)), Material = Enum.Material.Wood, Color = TIMBER })
		end
	end
	local stripes = 6
	for i = 0, stripes - 1 do
		part(m, { Name = "Canopy" .. i, Size = Vector3.new(W / stripes, 0.3, D + 1),
			CFrame = CFrame.new(-W / 2 + (i + 0.5) * W / stripes, 6.5, 0) * CFrame.Angles(math.rad(-10), 0, 0),
			Material = Enum.Material.Fabric, Color = if i % 2 == 0 then CLOTH_BLUE else CLOTH_WHITE })
	end
	local goods = { Color3.fromRGB(220, 80, 70), Color3.fromRGB(240, 190, 70), Color3.fromRGB(110, 190, 90), ARCANE }
	for i, c in goods do
		part(m, { Name = "Goods" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(-3.6 + i * 1.6, 3.4, -D / 2 + 1.4), Material = if c == ARCANE then Enum.Material.Neon else Enum.Material.SmoothPlastic, Color = c })
	end
	part(m, { Name = "Crate", Size = Vector3.new(1.8, 1.8, 1.8), CFrame = CFrame.new(3.6, 0.9, 1.6) * CFrame.Angles(0, math.rad(15), 0), Material = Enum.Material.WoodPlanks, Color = WOOD })
	finish(m)
end

-- Mage Tower: 3x3 Buildings, a stone tower with a blue spire and a floating arcane orb.
do
	local m = newModel("MageTower", 3, 3, 30)
	part(m, { Name = "Plinth", Size = Vector3.new(11.5, 1, 11.5), CFrame = CFrame.new(0, 0.5, 0), Material = Enum.Material.Cobblestone, Color = STONE_DARK })
	part(m, { Name = "Tower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 8.4, 8.4),
		CFrame = CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Brick, Color = STONE })
	part(m, { Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 9.6, 9.6),
		CFrame = CFrame.new(0, 17, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Slate, Color = STONE_DARK })
	part(m, { Name = "Door", Size = Vector3.new(2.4, 4, 0.4), CFrame = CFrame.new(0, 3, -4.15), Material = Enum.Material.WoodPlanks, Color = TIMBER })
	for i, y in { 7, 12 } do
		part(m, { Name = "Window" .. i, Size = Vector3.new(1.1, 2, 0.4), CFrame = CFrame.new(0, y, -4.15),
			Material = Enum.Material.Neon, Color = ARCANE, CastShadow = false })
	end
	local tiers = { { 9.2, 2.2 }, { 7, 2.2 }, { 4.8, 2.2 }, { 2.6, 2.2 }, { 1.0, 2.0 } }
	local y = 17.5
	for i, t in tiers do
		part(m, { Name = "Spire" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(t[2], t[1], t[1]),
			CFrame = CFrame.new(0, y + t[2] / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Slate, Color = CLOTH_BLUE })
		y += t[2]
	end
	local orb = part(m, { Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = CFrame.new(0, y + 1.4, 0),
		Material = Enum.Material.Neon, Color = ARCANE, CastShadow = false })
	light(orb, ARCANE, 24, 2)
	finish(m)
end

-- Optional preview row in Workspace (deleted again by the caller after a screenshot).
if PREVIEW then
	local prev = workspace:FindFirstChild("_AssetPreview")
	if prev then prev:Destroy() end
	prev = Instance.new("Folder")
	prev.Name = "_AssetPreview"
	prev.Parent = workspace
	local x = 0
	for _, n in { "StonePath", "Boulder", "OakTree", "Cottage", "ArcaneCrystal", "LanternPost", "WoodenFence", "StoneWell", "MarketStall", "MageTower" } do
		local c = items[n]:Clone()
		c:PivotTo(CFrame.new(x, 0, 300))
		c.Parent = prev
		x += 20
	end
end

local names = {}
for _, m in items:GetChildren() do
	table.insert(names, m.Name)
end
table.sort(names)
print("[BuildPlaceholderAssets] built: " .. table.concat(names, ", "))
return table.concat(names, ", ")
