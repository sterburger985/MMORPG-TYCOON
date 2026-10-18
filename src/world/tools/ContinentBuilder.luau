--!nonstrict
-- ContinentBuilder (STUDIO TOOL, edit mode only): writes the continent into the World
-- place once. Never runs in a live server.
--
--   require(game.ServerStorage.WorldTools.ContinentBuilder).build()
--
-- Steps: clear the old continent (terrain + Workspace.Continent) -> set terrain colours
-- -> write terrain in 256 x 256-stud chunks with WriteVoxels -> place scenery, landmarks,
-- bridges and signs from Continent's deterministic plans -> record the version.
-- Running it again rebuilds the same continent (nothing duplicates). The player build
-- plot (WorldPlot, built by PlotService at runtime) and saved objects are untouched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Continent = require(ReplicatedStorage.Shared.Continent)
local RegionConfig = require(ReplicatedStorage.Shared.RegionConfig)
local Scenery = require(script.Parent.Scenery)
local Landmarks = require(script.Parent.Landmarks)

local Builder = {}

local VOXEL = 4
local CHUNK = 64 -- columns per chunk side

local COLORS = {
	Grass = Color3.fromRGB(96, 168, 70),
	LeafyGrass = Color3.fromRGB(58, 116, 52),
	Ground = Color3.fromRGB(132, 104, 72),
	Mud = Color3.fromRGB(80, 66, 50),
	Rock = Color3.fromRGB(126, 124, 120),
	Slate = Color3.fromRGB(70, 72, 84),
	Sand = Color3.fromRGB(224, 198, 140),
	Sandstone = Color3.fromRGB(192, 134, 86),
	Snow = Color3.fromRGB(240, 244, 250),
	Glacier = Color3.fromRGB(162, 212, 242),
	Ice = Color3.fromRGB(184, 222, 250),
	Basalt = Color3.fromRGB(48, 44, 48),
	Asphalt = Color3.fromRGB(34, 30, 32), -- scorched ash (the texture is bright, so the colour is dark)
	CrackedLava = Color3.fromRGB(232, 98, 38),
	Salt = Color3.fromRGB(178, 160, 226), -- lavender, so Starfall never reads as snow
	Limestone = Color3.fromRGB(206, 198, 168),
	Cobblestone = Color3.fromRGB(108, 106, 100),
	WoodPlanks = Color3.fromRGB(140, 102, 64),
}

local function applyColors(terrain: Terrain)
	for name, color in COLORS do
		terrain:SetMaterialColor((Enum.Material :: any)[name], color)
	end
	terrain.WaterColor = Color3.fromRGB(40, 118, 168)
	terrain.WaterTransparency = 0.45
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	terrain.WaterReflectance = 0.6
	pcall(function()
		(terrain :: any).Decoration = true -- animated grass on Grass terrain
	end)
end

local MAT = {}
for name in COLORS do
	MAT[name] = Enum.Material[name]
end
MAT.Water = Enum.Material.Water
MAT.Air = Enum.Material.Air

local function writeChunk(terrain: Terrain, x0: number, z0: number, nx: number, nz: number): number
	-- Heights on a grid with a 1-column border (for slopes).
	local cols = {}
	local hgrid = {}
	for i = 0, nx + 1 do
		hgrid[i] = {}
		cols[i] = {}
		for k = 0, nz + 1 do
			local x = x0 + (i - 0.5) * VOXEL
			local z = z0 + (k - 0.5) * VOXEL
			local c = Continent.column(x, z)
			cols[i][k] = c
			local h = c.h
			if c.ice and c.lake then
				h = c.lake.level
			end
			hgrid[i][k] = h
		end
	end
	local yLow, yHigh = math.huge, -math.huge
	for i = 1, nx do
		for k = 1, nz do
			local c = cols[i][k]
			local h = hgrid[i][k]
			yLow = math.min(yLow, h - 10)
			yHigh = math.max(yHigh, h, c.water)
		end
	end
	local y0 = math.floor(yLow / VOXEL) * VOXEL
	local y1 = math.ceil((yHigh + 1) / VOXEL) * VOXEL
	local ny = (y1 - y0) / VOXEL

	local materials, occupancy = table.create(nx), table.create(nx)
	for i = 1, nx do
		local mi, oi = table.create(ny), table.create(ny)
		materials[i], occupancy[i] = mi, oi
		for j = 1, ny do
			mi[j], oi[j] = table.create(nz), table.create(nz)
		end
		for k = 1, nz do
			local c = cols[i][k]
			local h = hgrid[i][k]
			local slope = math.max(math.abs(hgrid[i + 1][k] - hgrid[i - 1][k]), math.abs(hgrid[i][k + 1] - hgrid[i][k - 1])) / (2 * VOXEL)
			local x = x0 + (i - 0.5) * VOXEL
			local z = z0 + (k - 0.5) * VOXEL
			local topName = if c.ice then "Ice" else Continent.material(c, slope, x, z)
			local top = MAT[topName] or MAT.Grass
			local region = RegionConfig.regions[c.region]
			local deep = MAT[region.materials.deep] or MAT.Rock
			local water = c.water
			for j = 1, ny do
				local vy = y0 + (j - 1) * VOXEL
				local m, o = MAT.Air, 0
				if h >= vy + VOXEL then
					m, o = if h - vy < 8 then top else deep, 1
				elseif h > vy then
					local frac = (h - vy) / VOXEL
					if water > vy + VOXEL * 0.5 and frac < 0.5 then
						m, o = MAT.Water, 1
					else
						m, o = top, math.max(frac, 0.1)
					end
				elseif water > vy then
					m, o = MAT.Water, math.min(1, (water - vy) / VOXEL)
				end
				materials[i][j][k] = m
				occupancy[i][j][k] = o
			end
		end
	end
	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + nx * VOXEL, y1, z0 + nz * VOXEL))
	terrain:WriteVoxels(region, VOXEL, materials, occupancy)
	return nx * ny * nz
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

local function rgbOf(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

function Builder.buildTerrain(terrain: Terrain)
	local b = RegionConfig.BOUNDS
	local minX = math.floor(b.minX / VOXEL) * VOXEL
	local minZ = math.floor(b.minZ / VOXEL) * VOXEL
	local spanX = math.ceil((b.maxX - minX) / VOXEL)
	local spanZ = math.ceil((b.maxZ - minZ) / VOXEL)
	local voxels, chunks = 0, 0
	local total = math.ceil(spanX / CHUNK) * math.ceil(spanZ / CHUNK)
	local started = os.clock()
	for ci = 0, spanX - 1, CHUNK do
		for ck = 0, spanZ - 1, CHUNK do
			local nx = math.min(CHUNK, spanX - ci)
			local nz = math.min(CHUNK, spanZ - ck)
			voxels += writeChunk(terrain, minX + ci * VOXEL, minZ + ck * VOXEL, nx, nz)
			chunks += 1
			if chunks % 10 == 0 then
				print(("[Continent] terrain %d/%d chunks (%.0fs)"):format(chunks, total, os.clock() - started))
			end
			task.wait()
		end
	end
	return voxels, chunks, os.clock() - started
end

function Builder.buildScenery(root: Instance): (number, number)
	local sceneryRoot = folder(root, "Scenery")
	local plan = Continent.planScenery()
	local parts = 0
	for n, item in plan do
		local cf = CFrame.new(item.x, item.y - 0.3, item.z) * CFrame.Angles(0, item.rot, 0)
		local seed = math.floor(item.x * 31 + item.z * 17)
		local model = Scenery.build(item.kind, cf, item.scale, seed)
		if model then
			model.Parent = folder(sceneryRoot, item.region)
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					parts += 1
				end
			end
		end
		if n % 200 == 0 then
			task.wait()
		end
	end
	return #plan, parts
end

function Builder.buildLandmarks(root: Instance): number
	local lmRoot = folder(root, "Landmarks")
	local count = 0
	local roads = Continent.roads
	for _, l in Continent.landmarks do
		local y = Continent.height(l.x, l.z)
		local angle = (math.floor(math.abs(l.x * 7 + l.z * 3)) % 360) * math.pi / 180
		if l.kind == "Waterfall" then
			angle = 0
		elseif l.kind == "Citadel" or l.kind == "Dragonbones" or l.kind == "JungleTemple" or l.kind == "Observatory" or l.kind == "SandstoneArch" then
			-- face the nearest road point
			local best, bx, bz = math.huge, l.x, l.z + 1
			for _, road in roads do
				for _, p in road.pts do
					local d = (p[1] - l.x) ^ 2 + (p[2] - l.z) ^ 2
					if d < best then
						best, bx, bz = d, p[1], p[2]
					end
				end
			end
			angle = math.atan2(bx - l.x, bz - l.z)
		end
		local model = Landmarks.build(l.kind, CFrame.new(l.x, y, l.z) * CFrame.Angles(0, angle, 0), #l.id * 97)
		if model then
			model.Name = l.id
			model:SetAttribute("LandmarkName", l.name)
			model.Parent = lmRoot
			count += 1
		end
	end
	return count
end

function Builder.buildRoadside(root: Instance): (number, number)
	local f = folder(root, "Roadside")
	local bridges = Continent.planBridges()
	for _, b in bridges do
		Landmarks.bridge(CFrame.new(b.x, b.y, b.z) * CFrame.Angles(0, b.angle, 0), b.length).Parent = f
	end
	local signs = Continent.planSigns()
	for _, s in signs do
		local r = RegionConfig.get(s.region)
		if r then
			local m = Landmarks.sign(CFrame.new(s.x, s.y, s.z) * CFrame.Angles(0, s.angle, 0), r.name, ("Recommended Lv %d–%d"):format(r.minLevel, r.maxLevel), rgbOf(r.signColor))
			m.Name = "Sign_" .. r.id
			m.Parent = f
		end
	end
	return #bridges, #signs
end

-- Sum of heights at fixed points: compare with the local renderer to prove the map is
-- identical on every machine.
function Builder.fingerprint(): number
	local sum = 0
	for i = -10, 10 do
		for k = -10, 10 do
			sum += Continent.height(i * 131.7, -600 + k * 117.3)
		end
	end
	return math.floor(sum * 1000 + 0.5) / 1000
end

function Builder.build(options: { skipTerrain: boolean?, skipScenery: boolean? }?)
	assert(RunService:IsStudio() and not RunService:IsRunning(), "ContinentBuilder runs in Studio edit mode only")
	local opts = options or {}
	local terrain = Workspace.Terrain
	local old = Workspace:FindFirstChild("Continent")
	if old then
		old:Destroy()
	end
	local legacy = Workspace:FindFirstChild("WorldDecor")
	if legacy then
		legacy:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Continent"
	root:SetAttribute("Permanent", true)
	root:SetAttribute("ContinentVersion", RegionConfig.VERSION)
	root.Parent = Workspace

	local voxels, chunks, seconds = 0, 0, 0
	if not opts.skipTerrain then
		terrain:Clear()
		applyColors(terrain)
		voxels, chunks, seconds = Builder.buildTerrain(terrain)
	end
	local items, parts = 0, 0
	if not opts.skipScenery then
		items, parts = Builder.buildScenery(root)
	end
	local landmarks = Builder.buildLandmarks(root)
	local bridges, signs = Builder.buildRoadside(root)
	local fp = Builder.fingerprint()
	root:SetAttribute("Fingerprint", fp)
	local totalParts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			totalParts += 1
		end
	end
	local summary = ("[Continent] v%d built: %d chunks, %d voxels in %.0fs; %d scenery items (%d parts); %d landmarks; %d bridges; %d signs; %d parts total; fingerprint %s"):format(
		RegionConfig.VERSION, chunks, voxels, seconds, items, parts, landmarks, bridges, signs, totalParts, tostring(fp)
	)
	print(summary)
	return summary
end

return Builder
