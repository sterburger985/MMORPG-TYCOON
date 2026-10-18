--!strict
-- PlotService: owns the plot slots. Builds them if the place doesn't have them,
-- assigns one per player on join, frees it on leave, keeps the owner spawning on
-- their own plot, and holds each plot's occupancy state.
--
-- canBuild() is the single permission choke point, so co-builders or visit
-- permissions can be added later without touching PlacementService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PlacementRules = require(ReplicatedStorage.Shared.PlacementRules)

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

local BASE_COLOR = Color3.fromRGB(104, 156, 74)
local EDGE_COLOR = Color3.fromRGB(122, 112, 98)
local PAD_COLOR = Color3.fromRGB(196, 168, 112)

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}

local PlotService = {}

-- Centre (X, Z) of plot slot i (1-based), laid out in rows of PLOT_COLUMNS around the origin.
local function slotCenter(i: number): Vector3
	local cols = Config.PLOT_COLUMNS
	local rows = math.ceil(Config.PLOT_COUNT / cols)
	local col = (i - 1) % cols
	local row = (i - 1) // cols
	local pitch = PLOT_STUDS + Config.PLOT_GAP
	local x = (col - (cols - 1) / 2) * pitch
	local z = (row - (rows - 1) / 2) * pitch
	return Vector3.new(x, 0, z)
end

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

-- Builds one plot model: grass base, raised stone rim, spawn pad, owner sign.
local function buildPlotModel(i: number, parent: Instance): Model
	local center = slotCenter(i)
	local surfaceY = Config.PLOT_SURFACE_HEIGHT
	local thickness = Config.PLOT_BASE_THICKNESS

	local model = Instance.new("Model")
	model.Name = "Plot_" .. i

	local base = makePart({
		Name = "Base",
		Size = Vector3.new(PLOT_STUDS, thickness, PLOT_STUDS),
		CFrame = CFrame.new(center.X, surfaceY - thickness / 2, center.Z),
		Material = Enum.Material.Grass,
		Color = BASE_COLOR,
	})
	base.Parent = model
	model.PrimaryPart = base

	-- Rim: four low walls just outside the buildable area so it reads as a separate world.
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
		local rim = makePart({
			Name = "Rim" .. n,
			Size = edge[1],
			CFrame = CFrame.new(center.X + edge[2].X, rimY, center.Z + edge[2].Z),
			Material = Enum.Material.Cobblestone,
			Color = EDGE_COLOR,
			CanQuery = false,
		})
		rim.Parent = model
	end

	-- Spawn pad just inside the edge that faces the central walkway.
	local facing = if center.Z <= 0 then 1 else -1
	local pad = makePart({
		Name = "SpawnPad",
		Size = Vector3.new(10, 0.4, 10),
		CFrame = CFrame.new(center.X, surfaceY + 0.2, center.Z + facing * (PLOT_STUDS / 2 - 8)),
		Material = Enum.Material.Slate,
		Color = PAD_COLOR,
		CanQuery = false,
	})
	pad.Parent = model

	local sign = Instance.new("BillboardGui")
	sign.Name = "OwnerSign"
	sign.Size = UDim2.fromOffset(240, 48)
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

	model:SetAttribute("PlotId", i)
	model:SetAttribute("OwnerUserId", 0)
	model.Parent = parent
	return model
end

local function teleportToPlot(character: Model, plot: Plot)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil or character.Parent == nil then
		return
	end
	character:PivotTo(plot.spawnPad.CFrame + Vector3.new(0, 4, 0))
end

local function setSign(plot: Plot, text: string?)
	local sign = plot.spawnPad:FindFirstChild("OwnerSign") :: BillboardGui?
	if sign then
		local label = sign:FindFirstChild("Label") :: TextLabel?
		if label then
			label.Text = text or ""
		end
		sign.Enabled = text ~= nil
	end
end

function PlotService.Init()
	local folder = Workspace:FindFirstChild("Plots")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "Plots"
		folder.Parent = Workspace
	end
	assert(folder ~= nil)

	for i = 1, Config.PLOT_COUNT do
		local model = folder:FindFirstChild("Plot_" .. i) :: Model?
		if model == nil then
			model = buildPlotModel(i, folder)
		end
		assert(model ~= nil)
		local base = model:FindFirstChild("Base") :: BasePart
		local placedFolder = model:FindFirstChild("Placed") :: Folder
		local spawnPad = model:FindFirstChild("SpawnPad") :: BasePart
		assert(base and placedFolder and spawnPad, "Plot_" .. i .. " is missing Base, Placed or SpawnPad")
		placedFolder:ClearAllChildren()
		plots[i] = {
			id = i,
			model = model,
			base = base,
			placedFolder = placedFolder,
			spawnPad = spawnPad,
			owner = nil,
			state = PlacementRules.newPlotState(),
			characterConn = nil,
		}
	end
end

function PlotService.Start() end

-- Give the player the first free plot. Returns nil when every plot is taken.
function PlotService.assign(player: Player): Plot?
	if plotByPlayer[player] then
		return plotByPlayer[player]
	end
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			plotByPlayer[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("PlotId", plot.id)
			setSign(plot, player.DisplayName .. "'s World")

			plot.characterConn = player.CharacterAdded:Connect(function(character)
				teleportToPlot(character, plot)
			end)
			if player.Character then
				task.spawn(teleportToPlot, player.Character, plot)
			end
			return plot
		end
	end
	return nil
end

-- Free the player's plot and clear everything on it.
function PlotService.release(player: Player)
	local plot = plotByPlayer[player]
	if plot == nil then
		return
	end
	plotByPlayer[player] = nil
	if plot.characterConn then
		plot.characterConn:Disconnect()
		plot.characterConn = nil
	end
	plot.owner = nil
	plot.state = PlacementRules.newPlotState()
	plot.placedFolder:ClearAllChildren()
	plot.model:SetAttribute("OwnerUserId", 0)
	setSign(plot, nil)
	if player.Parent == Players then
		player:SetAttribute("PlotId", nil)
	end
end

function PlotService.getPlotOf(player: Player): Plot?
	return plotByPlayer[player]
end

-- The single build-permission check. Phase 1: only the owner may build.
function PlotService.canBuild(player: Player, plot: Plot): boolean
	return plot.owner == player
end

-- CFrame at the centre of the plot's top face (the grid origin for GridMath).
function PlotService.surfaceCFrame(plot: Plot): CFrame
	return plot.base.CFrame * CFrame.new(0, plot.base.Size.Y / 2, 0)
end

function PlotService.getPlots(): { Plot }
	return plots
end

-- Set (or clear, with nil) the text on a plot's spawn-pad sign.
function PlotService.setSign(plot: Plot, text: string?)
	setSign(plot, text)
end

return PlotService
