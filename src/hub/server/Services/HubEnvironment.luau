--!strict
-- HubEnvironment: dresses the hub around the existing plot layout without moving it:
-- grass ground, cobblestone roads in the walkways between plots, a central plaza around
-- the spawn, fountains at the crossroads, street lamps, a forest ring and the shared
-- lighting preset. Built in code from the same layout numbers PlotService uses, so it
-- always lines up and the repo stays the source of truth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Decor = require(script.Parent.Parent.Util.Decor)
local LightingPreset = require(script.Parent.Parent.Util.LightingPreset)

local HubEnvironment = {}

local PLOT_STUDS = Config.PLOT_CELLS * Config.CELL_SIZE
local PITCH = PLOT_STUDS + Config.PLOT_GAP
local COLS = Config.PLOT_COLUMNS
local ROWS = math.ceil(Config.PLOT_COUNT / COLS)
local HALF_W = (COLS * PITCH) / 2 -- half width of the plot field incl. walkways
local HALF_D = (ROWS * PITCH) / 2

local ROAD = Color3.fromRGB(156, 144, 128)
local ROAD_EDGE = Color3.fromRGB(112, 102, 92)
local PLAZA = Color3.fromRGB(196, 182, 156)

-- A cobblestone road with low kerbs along both long edges. `gaps` lists spans along the
-- road's long axis ({ centre, halfWidth } in world coordinates) where the kerbs stop:
-- crossings, the plaza and fountains, so no kerb ever cuts through them.
local function road(parent: Instance, center: Vector3, size: Vector3, gaps: { { number } }?)
	Decor.part(parent, { Name = "Road", Size = size, CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0)), Material = Enum.Material.Cobblestone, Color = ROAD })
	local alongX = size.X >= size.Z
	local axisCentre = if alongX then center.X else center.Z
	local length = if alongX then size.X else size.Z
	local width = if alongX then size.Z else size.X
	-- Turn the gaps into the solid segments between them.
	local cuts: { { number } } = table.clone(gaps or {})
	table.sort(cuts, function(a, b)
		return a[1] < b[1]
	end)
	local segments = {}
	local cursor = axisCentre - length / 2
	local stop = axisCentre + length / 2
	for _, gap: { number } in cuts do
		local gapStart, gapEnd = gap[1] - gap[2], gap[1] + gap[2]
		if gapStart > cursor then
			table.insert(segments, { cursor, math.min(gapStart, stop) })
		end
		cursor = math.max(cursor, gapEnd)
	end
	if cursor < stop then
		table.insert(segments, { cursor, stop })
	end
	for _, side in { -1, 1 } do
		local across = side * (width / 2 + 0.5)
		for _, seg in segments do
			local segLength = seg[2] - seg[1]
			if segLength > 0.5 then
				local mid = (seg[1] + seg[2]) / 2
				local position = if alongX then Vector3.new(mid, center.Y + 0.35, center.Z + across) else Vector3.new(center.X + across, center.Y + 0.35, mid)
				local kerbSize = if alongX then Vector3.new(segLength, 0.5, 1) else Vector3.new(1, 0.5, segLength)
				Decor.part(parent, { Name = "Kerb", Size = kerbSize, CFrame = CFrame.new(position), Material = Enum.Material.Slate, Color = ROAD_EDGE })
			end
		end
	end
end

local function fountain(parent: Instance, center: Vector3)
	local model = Instance.new("Model")
	model.Name = "Fountain"
	Decor.disc(model, center + Vector3.new(0, 0.35, 0), 17, 0.3, { Name = "Plaza", Material = Enum.Material.Slate, Color = PLAZA })
	Decor.disc(model, center + Vector3.new(0, 2.2, 0), 8, 2, { Name = "Basin", Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(150, 140, 150) })
	Decor.disc(model, center + Vector3.new(0, 2.25, 0), 7, 0.4, {
		Name = "Water",
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(90, 170, 220),
		Transparency = 0.25,
	})
	Decor.part(model, { Name = "Column", Size = Vector3.new(2, 6, 2), CFrame = CFrame.new(center + Vector3.new(0, 5, 0)), Material = Enum.Material.Marble, Color = Color3.fromRGB(230, 226, 220) })
	local crystal = Decor.part(model, {
		Name = "Crystal",
		Size = Vector3.new(2.2, 3.2, 2.2),
		CFrame = CFrame.new(center + Vector3.new(0, 9.6, 0)) * CFrame.Angles(0, math.rad(45), math.rad(45)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 210, 255),
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(140, 210, 255)
	light.Range = 20
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = crystal
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Rate = 24
	spray.Lifetime = NumberRange.new(1, 1.6)
	spray.Speed = NumberRange.new(5, 7)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.Acceleration = Vector3.new(0, -14, 0)
	spray.Size = NumberSequence.new(0.35, 0.1)
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	spray.Parent = crystal
	model.Parent = parent
end

function HubEnvironment.build()
	local old = Workspace:FindFirstChild("HubEnvironment")
	if old then
		old:Destroy()
	end
	local env = Instance.new("Folder")
	env.Name = "HubEnvironment"
	env.Parent = Workspace

	-- Ground: keep the existing Baseplate, just make it read as grass.
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Material = Enum.Material.Grass
		baseplate.Color = Color3.fromRGB(88, 140, 62)
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") then
				child:Destroy()
			end
		end
	end

	-- Roads in the existing walkways: one main avenue between the rows, one street
	-- between each pair of columns, and a ring road around the whole field.
	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	roads.Parent = env
	local ringX, ringZ = HALF_W + 18, HALF_D + 18
	local streetXs, avenueZs = {}, {}
	for col = 1, COLS - 1 do
		table.insert(streetXs, (col - COLS / 2) * PITCH)
	end
	for row = 1, ROWS - 1 do
		table.insert(avenueZs, (row - ROWS / 2) * PITCH)
	end
	local PLAZA_GAP = 22 -- the plaza disc (radius 21) plus a margin
	-- Kerb gaps where a road along X meets the streets, the ring and (at the centre) the plaza.
	local function gapsAlongX(includePlaza: boolean): { { number } }
		local g = { { ringX, 13 }, { -ringX, 13 } }
		for _, x in streetXs do
			table.insert(g, { x, 13 })
		end
		if includePlaza then
			table.insert(g, { 0, PLAZA_GAP })
		end
		return g
	end
	local function gapsAlongZ(): { { number } }
		local g = { { ringZ, 13 }, { -ringZ, 13 } }
		for _, z in avenueZs do
			table.insert(g, { z, 15 })
		end
		return g
	end
	for _, z in avenueZs do
		road(roads, Vector3.new(0, 0, z), Vector3.new(ringX * 2, 0.2, 28), gapsAlongX(z == 0))
	end
	for _, x in streetXs do
		road(roads, Vector3.new(x, 0, 0), Vector3.new(24, 0.2, ringZ * 2), gapsAlongZ())
	end
	road(roads, Vector3.new(0, 0, ringZ), Vector3.new(ringX * 2 + 24, 0.2, 24), gapsAlongX(false))
	road(roads, Vector3.new(0, 0, -ringZ), Vector3.new(ringX * 2 + 24, 0.2, 24), gapsAlongX(false))
	road(roads, Vector3.new(ringX, 0, 0), Vector3.new(24, 0.2, ringZ * 2), gapsAlongZ())
	road(roads, Vector3.new(-ringX, 0, 0), Vector3.new(24, 0.2, ringZ * 2), gapsAlongZ())

	-- Central plaza around the spawn point, with a glowing rune ring.
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"
	Decor.disc(plaza, Vector3.new(0, 0.32, 0), 21, 0.3, { Name = "Floor", Material = Enum.Material.Slate, Color = PLAZA })
	Decor.disc(plaza, Vector3.new(0, 0.36, 0), 10, 0.3, {
		Name = "RuneRing",
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(90, 190, 255),
		Transparency = 0.55,
		CastShadow = false,
	})
	plaza.Parent = env
	local spawn = Workspace:FindFirstChild("SpawnLocation")
	if spawn and spawn:IsA("BasePart") then
		spawn.Material = Enum.Material.Marble
		spawn.Color = Color3.fromRGB(236, 230, 214)
		spawn.Size = Vector3.new(12, 1, 12)
		local decal = spawn:FindFirstChildOfClass("Decal")
		if decal then
			decal.Transparency = 0.6
		end
	end

	-- Fountains at the crossroads of the avenue and the streets.
	for col = 1, COLS - 1 do
		for row = 1, ROWS - 1 do
			fountain(env, Vector3.new((col - COLS / 2) * PITCH, 0, (row - ROWS / 2) * PITCH))
		end
	end

	-- Street lamps along both sides of the avenue and the streets.
	local lamps = Instance.new("Folder")
	lamps.Name = "Lamps"
	lamps.Parent = env
	local crossX: { number } = {}
	for col = 1, COLS - 1 do
		table.insert(crossX, (col - COLS / 2) * PITCH)
	end
	local function nearCross(v: number, list: { number }, gap: number): boolean
		for _, c in list do
			if math.abs(v - c) < gap then
				return true
			end
		end
		return math.abs(v) < 30
	end
	for row = 1, ROWS - 1 do
		local z = (row - ROWS / 2) * PITCH
		local x = -ringX + 24
		local side = 1
		while x <= ringX - 24 do
			if not nearCross(x, crossX, 24) then
				Decor.lamp(lamps, Vector3.new(x, 0.2, z + side * 16))
				side = -side
			end
			x += 40
		end
	end
	for _, x in crossX do
		local z = -ringZ + 30
		local side = 1
		while z <= ringZ - 30 do
			if math.abs(z) > 34 then
				Decor.lamp(lamps, Vector3.new(x + side * 14, 0.2, z))
				side = -side
			end
			z += 44
		end
	end

	-- Forest ring outside the ring road (seeded, so it's the same every server).
	local forest = Instance.new("Folder")
	forest.Name = "Forest"
	forest.Parent = env
	local rng = Random.new(1234)
	local innerX, innerZ = ringX + 22, ringZ + 22
	local outerX, outerZ = innerX + 90, innerZ + 90
	local placedTrees = 0
	local tries = 0
	while placedTrees < 90 and tries < 2000 do
		tries += 1
		local x = rng:NextNumber(-outerX, outerX)
		local z = rng:NextNumber(-outerZ, outerZ)
		if math.abs(x) > innerX or math.abs(z) > innerZ then
			local isRock = rng:NextNumber() < 0.22
			local model = if isRock
				then Decor.prop(forest, "Boulder", Vector3.new(x, 0, z), rng:NextNumber(0, math.pi * 2), rng:NextNumber(1.4, 2.6))
				else Decor.prop(forest, "OakTree", Vector3.new(x, 0, z), rng:NextNumber(0, math.pi * 2), rng:NextNumber(1.2, 2.1))
			if model then
				placedTrees += 1
			else
				break -- item models missing; skip scenery rather than fail
			end
		end
	end

	LightingPreset.apply()
end

function HubEnvironment.Init()
	HubEnvironment.build()
end

function HubEnvironment.Start() end

return HubEnvironment
