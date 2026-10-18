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
	sign.StudsOffset = Vector3.new(0, 7, 0)
	sign.MaxDistance = 220
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
-- Only non-sensitive fields: no session ids, no save data.
function PlotService.showWorldInfo(name: string, visibility: string, ownerUserId: number, status: string)
	local p = PlotService.getWorldPlot()
	p.model:SetAttribute("OwnerUserId", ownerUserId)
	p.model:SetAttribute("WorldName", name)
	p.model:SetAttribute("Visibility", visibility)
	p.model:SetAttribute("WorldStatus", status)
	local sign = p.spawnPad:FindFirstChild("WorldSign") :: BillboardGui?
	if sign then
		local label = sign:FindFirstChild("Label") :: TextLabel?
		if label then
			label.Text = name
		end
		sign.Enabled = true
	end
end

return PlotService
