--!strict
-- PlotService (World place): the world's single build area.
-- Same interface as the hub's PlotService (getPlotOf / canBuild / surfaceCFrame and the
-- Plot type) so the shared PlacementService works unchanged, but here there is one plot
-- per server and permission comes from WorldState (owner only, and only while the world
-- is loaded and writable).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PlacementRules = require(ReplicatedStorage.Shared.PlacementRules)
local WorldState = require(script.Parent.WorldState)
local Decor = require(script.Parent.Parent.Util.Decor)

export type Plot = {
	id: number,
	model: Model,
	base: BasePart,
	placedFolder: Folder,
	spawnPad: BasePart,
	owner: Player?,
	state: PlacementRules.PlotState,
	characterConn: RBXScriptConnection?,
}

local PLOT_STUDS = Config.PLOT_CELLS * Config.CELL_SIZE

local plot: Plot? = nil
local hubGatePrompt: ProximityPrompt? = nil

local PlotService = {}

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- The starter environment every world begins with: a grass world tile with a stone rim,
-- a spawn pad and a name sign. Built by code so it's identical in every session.
local function buildWorldTile(): Model
	local surfaceY = Config.PLOT_SURFACE_HEIGHT
	local thickness = Config.PLOT_BASE_THICKNESS

	local model = Instance.new("Model")
	model.Name = "WorldPlot"

	local base = makePart({
		Name = "Base",
		Size = Vector3.new(PLOT_STUDS, thickness, PLOT_STUDS),
		CFrame = CFrame.new(0, surfaceY - thickness / 2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(104, 156, 74),
	})
	base.Parent = model
	model.PrimaryPart = base

	local rimHeight, rimWidth = 1.2, 2
	local outer = PLOT_STUDS + rimWidth * 2
	local rimY = surfaceY + rimHeight / 2 - 0.4
	local edges = {
		{ Vector3.new(outer, rimHeight, rimWidth), Vector3.new(0, 0, (PLOT_STUDS + rimWidth) / 2) },
		{ Vector3.new(outer, rimHeight, rimWidth), Vector3.new(0, 0, -(PLOT_STUDS + rimWidth) / 2) },
		{ Vector3.new(rimWidth, rimHeight, PLOT_STUDS), Vector3.new((PLOT_STUDS + rimWidth) / 2, 0, 0) },
		{ Vector3.new(rimWidth, rimHeight, PLOT_STUDS), Vector3.new(-(PLOT_STUDS + rimWidth) / 2, 0, 0) },
	}
	for n, edge in edges do
		makePart({
			Name = "Rim" .. n,
			Size = edge[1],
			CFrame = CFrame.new(edge[2].X, rimY, edge[2].Z),
			Material = Enum.Material.Cobblestone,
			Color = Color3.fromRGB(122, 112, 98),
			CanQuery = false,
		}).Parent = model
	end

	-- Warm lamps on the rim (corners and edge midpoints; the south midpoint is the gate)
	-- (outside the build grid, so they can never clip a player's build).
	local lamps = Instance.new("Folder")
	lamps.Name = "Lamps"
	lamps.Parent = model
	local edge = (PLOT_STUDS + rimWidth) / 2
	local rimTop = surfaceY + rimHeight - 0.4
	for _, xz in { { -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 0 }, { 1, 0 }, { -1, 1 }, { 1, 1 } } do
		Decor.lamp(lamps, Vector3.new(xz[1] * edge, rimTop, xz[2] * edge))
	end

	local pad = makePart({
		Name = "SpawnPad",
		Size = Vector3.new(10, 0.4, 10),
		CFrame = CFrame.new(0, surfaceY + 0.2, PLOT_STUDS / 2 - 8),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(196, 168, 112),
		CanQuery = false,
	})
	pad.Parent = model

	local sign = Instance.new("BillboardGui")
	sign.Name = "WorldSign"
	sign.Size = UDim2.fromOffset(260, 48)
	sign.StudsOffset = Vector3.new(0, 5, 0)
	sign.MaxDistance = 90 -- close-range only, so it does not stack on the gate label from afar
	sign.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 244, 214)
	label.TextStrokeTransparency = 0.4
	label.Text = ""
	label.Parent = sign
	sign.Parent = pad

	local placed = Instance.new("Folder")
	placed.Name = "Placed"
	placed.Parent = model

	-- Hub Gate just outside the south rim, behind the spawn pad: walk through to go home.
	local gatePos = Vector3.new(0, surfaceY, PLOT_STUDS / 2 + 12)
	local gate, portal = Decor.gate(model, CFrame.lookAt(gatePos, gatePos + Vector3.new(0, 0, -1)), Color3.fromRGB(255, 196, 90), "HubGate")
	local step = makePart({
		Name = "GateStep",
		-- Reaches below the terrain verge so no gap shows around it.
		Size = Vector3.new(16, surfaceY + 6, 10),
		CFrame = CFrame.new(gatePos - Vector3.new(0, (surfaceY + 6) / 2, 0)),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(150, 138, 120),
	})
	step.Parent = gate
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = "Return to Hub"
	prompt.ObjectText = "Hub Gate"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal
	hubGatePrompt = prompt
	local _, title, subtitle = Decor.label(gate:FindFirstChild("Lintel") :: BasePart, "GateLabel", 5, 260)
	title.Text = "World Hub"
	subtitle.Text = "Return to the hub"

	-- If the place has terrain, carve it out of the tile and gate area so it can't bury
	-- them (terrain grass and hills otherwise poke through the build surface). The
	-- terrain around the tile stays, so the world sits inset into the landscape.
	local terrain = Workspace.Terrain
	local margin = 8
	local clearHeight = 60
	local clearSize = Vector3.new(outer + margin * 2, clearHeight, outer + margin * 2 + 24)
	local clearCentre = Vector3.new(0, surfaceY - thickness + clearHeight / 2, 12)
	terrain:FillBlock(CFrame.new(clearCentre), clearSize, Enum.Material.Air)
	-- Under the tile, swap terrain for plain Ground: terrain grass blades grow up to a
	-- few studs from Grass voxels and would otherwise poke up through the build surface.
	local subDepth = 12
	terrain:FillBlock(
		CFrame.new(clearCentre.X, surfaceY - thickness - subDepth / 2, clearCentre.Z),
		Vector3.new(clearSize.X, subDepth, clearSize.Z),
		Enum.Material.Ground
	)
	-- Refill a grass verge around the rim (top just under the surface) so the carve
	-- doesn't leave a trench. The gate step's footprint is left clear so terrain grass
	-- can't grow up through it.
	local half = outer / 2
	local x0, x1 = -clearSize.X / 2, clearSize.X / 2
	local z0, z1 = clearCentre.Z - clearSize.Z / 2, clearCentre.Z + clearSize.Z / 2
	local vergeTop = surfaceY - 0.6
	local vergeBottom = surfaceY - thickness - 4
	local function verge(ax: number, az: number, bx: number, bz: number)
		local size = Vector3.new(bx - ax, vergeTop - vergeBottom, bz - az)
		if size.X > 0 and size.Z > 0 then
			terrain:FillBlock(CFrame.new((ax + bx) / 2, (vergeTop + vergeBottom) / 2, (az + bz) / 2), size, Enum.Material.Grass)
		end
	end
	verge(x0, z0, x1, -half) -- north
	verge(x0, -half, -half, half) -- west
	verge(half, -half, x1, half) -- east
	local stepHalf = 8 -- the gate step is 16 x 10 studs, centred on the gate
	local stepNear = PLOT_STUDS / 2 + 12 - 5
	local stepFar = PLOT_STUDS / 2 + 12 + 5
	verge(x0, half, -stepHalf, z1) -- south-west of the gate step
	verge(stepHalf, half, x1, z1) -- south-east of the gate step
	verge(-stepHalf, half, stepHalf, stepNear) -- between the rim and the step
	verge(-stepHalf, stepFar, stepHalf, z1) -- behind the gate step

	model.Parent = Workspace
	return model
end

function PlotService.Init()
	local existing = Workspace:FindFirstChild("WorldPlot")
	if existing then
		existing:Destroy() -- always start from the code-defined starter environment
	end
	local model = buildWorldTile()
	plot = {
		id = 1,
		model = model,
		base = model:FindFirstChild("Base") :: BasePart,
		placedFolder = model:FindFirstChild("Placed") :: Folder,
		spawnPad = model:FindFirstChild("SpawnPad") :: BasePart,
		owner = nil,
		state = PlacementRules.newPlotState(),
		characterConn = nil,
	}
end

function PlotService.Start() end

function PlotService.getHubGatePrompt(): ProximityPrompt?
	return hubGatePrompt
end

-- The world's plot, for anyone in this server, once the world is loaded.
function PlotService.getPlotOf(_player: Player): Plot?
	if not WorldState.isLive() then
		return nil
	end
	return plot
end

-- Raw access for the session service (restoring objects before players can act).
function PlotService.getWorldPlot(): Plot
	assert(plot ~= nil, "PlotService not initialised")
	return plot
end

-- Only the owner builds, and only while the world is loaded and writable.
function PlotService.canBuild(player: Player, _plot: Plot): boolean
	return WorldState.isOwner(player) and WorldState.canModify()
end

function PlotService.surfaceCFrame(p: Plot): CFrame
	return p.base.CFrame * CFrame.new(0, p.base.Size.Y / 2, 0)
end

-- Show the world's public details on the plot (name sign + replicated attributes).
-- Only non-sensitive fields: no session ids, no save data. Attributes replicate to
-- every client in the server, including a visitor who is about to be refused, so a
-- non-Public world's name is NOT published here; WorldSessionService sends it only to
-- players who passed the access gate.
function PlotService.showWorldInfo(name: string, visibility: string, ownerUserId: number, status: string)
	local p = PlotService.getWorldPlot()
	local public = visibility == "Public"
	p.model:SetAttribute("OwnerUserId", ownerUserId)
	p.model:SetAttribute("WorldName", if public then name else nil)
	p.model:SetAttribute("Visibility", visibility)
	p.model:SetAttribute("WorldStatus", status)
	local sign = p.spawnPad:FindFirstChild("WorldSign") :: BillboardGui?
	if sign then
		local label = sign:FindFirstChild("Label") :: TextLabel?
		if label then
			label.Text = if public then name else ""
		end
		sign.Enabled = public
	end
end

return PlotService
