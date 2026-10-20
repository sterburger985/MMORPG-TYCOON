--!nonstrict
-- BorderBuilder (Studio edit mode only): adds the section borders to the continent that
-- is already saved in the World place. Nothing here regenerates the map:
--   * terrain is only ADDED to (overlapping terrain balls form low embankments along
--     the section edges; trail entrances get a worn path material),
--   * props go into Workspace.Continent.SectionBorders (marked Permanent),
--   * existing scenery right next to a new embankment is lifted onto it (its original
--     height is kept in the BorderBaseY attribute so a rebuild starts clean).
-- Running build() twice gives the same result (terrain balls are identical, the props
-- folder is replaced). Player objects (Workspace.WorldPlot) are never touched.
--
-- Usage (command bar, edit mode):
--   require(game.ServerStorage.WorldTools.BorderBuilder).build()
-- To remove the borders completely: BorderBuilder.remove() (rewrites the base terrain
-- from Continent, exactly as ContinentBuilder made it, then deletes the props).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RegionConfig = require(Shared.RegionConfig)
local Sections = require(Shared.Sections)
local Continent = require(Shared.Continent)
local BorderKit = require(script.Parent.BorderKit)

local Builder = {}
Builder.VERSION = 1

local function rgbOf(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Folder
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }
rayParams.IgnoreWater = true

-- Ground height of the real terrain (after embankments), or the fallback. Rays start
-- above the highest peak (~310 studs): a ray that starts inside terrain misses the top.
local function surface(x: number, z: number, fallback: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -900, 0), rayParams)
	return if hit then hit.Position.Y else fallback
end

local function styleOpts(styleId: string, lantern: boolean?)
	local st = RegionConfig.BORDER_STYLES[styleId]
	local region = RegionConfig.get(styleId)
	return {
		stone = rgbOf(st.stone),
		edgeMaterial = (Enum.Material :: any)[st.edgeMaterial],
		glow = if region then rgbOf(region.signColor) else Color3.fromRGB(120, 220, 255),
		lantern = lantern,
	}
end

local function countParts(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- Put lifted scenery back where ContinentBuilder placed it.
local function restoreScenery(continent: Instance): number
	local n = 0
	local scenery = continent:FindFirstChild("Scenery")
	if not scenery then
		return 0
	end
	for _, m in scenery:GetDescendants() do
		if m:IsA("Model") then
			local baseY = m:GetAttribute("BorderBaseY")
			if baseY then
				local p = m:GetPivot()
				m:PivotTo(p + Vector3.new(0, baseY - p.Position.Y, 0))
				m:SetAttribute("BorderBaseY", nil)
				n += 1
			end
		end
	end
	return n
end

local function terrainMaterial(name: string): Enum.Material
	return (Enum.Material :: any)[name]
end

local PATH_FROM = { "Grass", "LeafyGrass", "Sand", "Snow", "Mud", "Salt", "Basalt", "Slate", "Rock", "Limestone", "Sandstone", "Asphalt", "Glacier", "Ground" }
local PATH_TO = {
	SunscarDesert = "Sandstone",
	GlacialExpanse = "Snow",
	Ashenreach = "Cobblestone",
	DragonsEnd = "Cobblestone",
	StarfallHighlands = "Limestone",
	Mirehollow = "Mud",
}

function Builder.build()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "BorderBuilder runs in Studio edit mode only")
	local continent = Workspace:FindFirstChild("Continent")
	assert(continent, "Workspace.Continent is missing: build the continent first")
	local terrain = Workspace.Terrain
	local started = os.clock()

	local plan = Sections.plan(task.wait)
	print(("[Borders] plan ready in %.1fs: %d ridge points, %d gates, %d trails, %d props"):format(os.clock() - started, plan.counts.ridge, #plan.gates, #plan.trails, #plan.decor))

	local old = continent:FindFirstChild("SectionBorders")
	if old then
		old:Destroy()
	end
	local restored = restoreScenery(continent)
	local root = Instance.new("Folder")
	root.Name = "SectionBorders"
	root:SetAttribute("Permanent", true)
	root:SetAttribute("BordersVersion", Builder.VERSION)
	root.Parent = continent

	-- 1. Embankments (terrain, additive). Each ridge point gets:
	--    * a core block of the bank material (earth, rock, sandstone...), aligned with
	--      the border and tilted with the ground,
	--    * a rounded crest (bank material, or the biome's ground in patches),
	--    * a low, wide skirt of the biome's ground so the foot blends into the land.
	terrain:SetMaterialColor(Enum.Material.Pavement, Color3.fromRGB(150, 138, 196)) -- Starfall flank stone (only borders use Pavement)
	local balls = 0
	for n, p in plan.points do
		if p.kind == "ridge" then
			local st = RegionConfig.BORDER_STYLES[p.style]
			local flank = terrainMaterial(st.bank)
			local top = terrainMaterial(if p.crest then st.crest else st.bank)
			local h, w = p.height, p.radius * 0.95
			local ax, az = p.x - p.tx * 5.5, p.z - p.tz * 5.5
			local bx, bz = p.x + p.tx * 5.5, p.z + p.tz * 5.5
			local a = Vector3.new(ax, Continent.height(ax, az), az)
			local b = Vector3.new(bx, Continent.height(bx, bz), bz)
			if math.abs(b.Y - a.Y) > 8 then
				b = Vector3.new(bx, a.Y + math.sign(b.Y - a.Y) * 8, bz)
			end
			local mid = (a + b) / 2
			local frame = CFrame.lookAt(a, b).Rotation + mid
			-- A wide core (2-3 voxels across, so terrain draws a flat-topped embankment
			-- rather than a sharp roof), then a low dome on the crest.
			terrain:FillBlock(frame * CFrame.new(0, (h - 5.5) / 2, 0), Vector3.new(w * 1.05, h + 4.5, 11.5), flank)
			terrain:FillBall(mid + Vector3.new(0, h - w * 0.4, 0), w * 0.45, top)
			local r = p.radius * 1.1
			terrain:FillBall(Vector3.new(p.x, p.y - (r - 1.6), p.z), r, terrainMaterial(st.crest))
			balls += 1
		end
		if n % 200 == 0 then
			task.wait()
		end
	end

	-- 2. Trail entrances: a worn path across the gap (or a plank walkway in the swamp).
	local entrances = folder(root, "Entrances")
	for i, t in plan.trails do
		local nx, nz = -t.tz, t.tx -- across the border
		local opts = styleOpts(t.style, false)
		if t.walkway then
			local y = surface(t.x, t.z, t.y)
			local m = BorderKit.build("Walkway", CFrame.lookAt(Vector3.new(t.x, y, t.z), Vector3.new(t.x + nx, y, t.z + nz)), 1, i * 13, opts)
			m.Name = "Walkway"
			m.Parent = entrances
		else
			local to = terrainMaterial(PATH_TO[t.style] or "Ground")
			for s = -16, 16, 8 do
				local cx, cz = t.x + nx * s, t.z + nz * s
				local cy = surface(cx, cz, t.y)
				local region = Region3.new(Vector3.new(cx - 4, cy - 6, cz - 4), Vector3.new(cx + 4, cy + 2, cz + 4)):ExpandToGrid(4)
				for _, from in PATH_FROM do
					local fm = terrainMaterial(from)
					if fm ~= to then
						terrain:ReplaceMaterial(region, 4, fm, to)
					end
				end
			end
		end
		-- waystones flank the gap, standing in the line of the border
		for _, side in { -1, 1 } do
			local off = Sections.TRAIL_GAP - 1
			local x, z = t.x + t.tx * off * side, t.z + t.tz * off * side
			local y = surface(x, z, t.y)
			local m = BorderKit.build("Waystone", CFrame.new(x, y - 0.6, z) * CFrame.Angles(0, math.atan2(nx, nz), 0), 1, i * 7 + side, opts)
			m.Name = "Waystone"
			m:SetAttribute("Sections", Sections.all()[t.a].id .. "|" .. Sections.all()[t.b].id)
			m.Parent = entrances
		end
		if i % 20 == 0 then
			task.wait()
		end
	end

	-- 3. Road gateways: a taller pair of lantern waystones either side of the road.
	for i, g in plan.gates do
		local opts = styleOpts(g.style, true)
		local px, pz = -g.dz, g.dx
		for _, side in { -1, 1 } do
			local x, z = g.x + px * 12 * side, g.z + pz * 12 * side
			local y = surface(x, z, g.y)
			local m = BorderKit.build("Waystone", CFrame.new(x, y - 0.8, z) * CFrame.Angles(0, math.atan2(g.dx, g.dz), 0), 1.35, i * 11 + side, opts)
			m.Name = "Gateway"
			m:SetAttribute("Sections", Sections.all()[g.a].id .. "|" .. Sections.all()[g.b].id)
			m:SetAttribute("Road", g.road)
			m.Parent = entrances
		end
	end

	-- 4. Border props, seated on the real (embanked) surface.
	local props = 0
	local skipped = 0
	local byStyle = {}
	for n, d in plan.decor do
		local y = surface(d.x, d.z, 0)
		local cf = CFrame.new(d.x, y, d.z) * CFrame.Angles(0, d.rot, 0)
		local linear = BorderKit.kinds[d.kind] ~= nil and (d.kind:find("Wall") or d.kind:find("Run") or d.kind:find("Edge"))
		if linear then
			-- follow the ground along the run; skip pieces on very uneven ground
			local fx, fz = math.sin(d.rot) * 4.5, math.cos(d.rot) * 4.5
			local y1 = surface(d.x - fx, d.z - fz, y)
			local y2 = surface(d.x + fx, d.z + fz, y)
			if math.abs(y2 - y1) > 4 then
				skipped += 1
				continue
			end
			local pitch = -math.atan((y2 - y1) / 9)
			cf = CFrame.new(d.x, math.min(y, (y1 + y2) / 2), d.z) * CFrame.Angles(0, d.rot, 0) * CFrame.Angles(pitch, 0, 0)
		else
			cf = cf - Vector3.new(0, 0.3, 0)
		end
		local m = BorderKit.build(d.kind, cf, d.scale, math.floor(d.x * 31 + d.z * 17), styleOpts(d.style, false))
		if m and linear then
			-- a run sunk into a crest bump would be invisible: leave it out
			local bcf, size = m:GetBoundingBox()
			if bcf.Position.Y + size.Y / 2 < surface(d.x, d.z, y) + 1 then
				m:Destroy()
				m = nil
				skipped += 1
			end
		end
		if m then
			local f = byStyle[d.style]
			if not f then
				f = folder(root, d.style)
				byStyle[d.style] = f
			end
			m.Parent = f
			props += 1
		end
		if n % 120 == 0 then
			task.wait()
		end
	end

	-- 5. Lift existing scenery that now stands in an embankment.
	local buckets = {}
	for _, p in plan.points do
		if p.kind == "ridge" then
			local k = math.floor(p.x / 16) * 100000 + math.floor(p.z / 16)
			buckets[k] = buckets[k] or {}
			table.insert(buckets[k], p)
		end
	end
	local lifted = 0
	local scenery = continent:FindFirstChild("Scenery")
	if scenery then
		for n, m in scenery:GetDescendants() do
			if m:IsA("Model") and m.Parent and m.Parent.Parent == scenery then
				local pos = m:GetPivot().Position
				local near = false
				for bx = math.floor((pos.X - 14) / 16), math.floor((pos.X + 14) / 16) do
					for bz = math.floor((pos.Z - 14) / 16), math.floor((pos.Z + 14) / 16) do
						for _, p in buckets[bx * 100000 + bz] or {} do
							if (p.x - pos.X) ^ 2 + (p.z - pos.Z) ^ 2 < (p.radius + 2) ^ 2 then
								near = true
								break
							end
						end
					end
				end
				if near then
					local y = surface(pos.X, pos.Z, pos.Y) - 0.3
					if y - pos.Y > 0.4 then
						m:SetAttribute("BorderBaseY", pos.Y)
						m:PivotTo(m:GetPivot() + Vector3.new(0, y - pos.Y, 0))
						lifted += 1
					end
				end
			end
			if n % 2000 == 0 then
				task.wait()
			end
		end
	end

	local parts = countParts(root)
	root:SetAttribute("Sections", #Sections.all())
	root:SetAttribute("Parts", parts)
	local summary = ("[Borders] v%d built in %.0fs: %d sections, %d embankment segments, %d gateways, %d trail entrances, %d props (%d skipped on steep or bumpy ground), %d parts, %d scenery lifted (%d restored first)"):format(
		Builder.VERSION, os.clock() - started, #Sections.all(), balls, #plan.gates, #plan.trails, props, skipped, parts, lifted, restored
	)
	print(summary)
	return summary
end

-- Undo everything: base terrain back exactly as ContinentBuilder wrote it, scenery back
-- to its original heights, props removed.
function Builder.remove()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "BorderBuilder runs in Studio edit mode only")
	local continent = Workspace:FindFirstChild("Continent")
	assert(continent, "Workspace.Continent is missing")
	local restored = restoreScenery(continent)
	local old = continent:FindFirstChild("SectionBorders")
	if old then
		old:Destroy()
	end
	local ContinentBuilder = require(script.Parent.ContinentBuilder)
	ContinentBuilder.buildTerrain(Workspace.Terrain)
	print(("[Borders] removed: base terrain rewritten, %d scenery items restored"):format(restored))
end

return Builder
