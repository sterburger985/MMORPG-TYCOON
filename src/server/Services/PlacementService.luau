--!strict
-- PlacementService: the only place the world changes. Handles RequestPlace and
-- RequestRemove, running the full validation chain from TECHNICAL_ARCHITECTURE §7:
--   rate limit -> argument shape -> known item -> owner plot -> bounds -> occupancy
--   -> limit -> funds -> atomic commit (charge, occupy, record, spawn; rolled back if spawn fails)
--
-- Nothing between validation and commit yields, so two requests can't interleave.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local GridMath = require(Shared.GridMath)
local ItemCatalog = require(Shared.ItemCatalog)
local Net = require(Shared.Net)
local PlacementRules = require(Shared.PlacementRules)

local EconomyService = require(script.Parent.EconomyService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local Reason = Net.Reason

local limiter = RateLimiter.new(Config.RATE_LIMIT_PER_SEC, Config.RATE_LIMIT_BURST)
local itemsFolder: Instance

local PlacementService = {}

local function fail(reason: string): Net.PlaceResult
	return { ok = false, reason = reason }
end

-- Clone the item's template, configure it and put it on the plot.
local function spawnModel(plot: PlotService.Plot, item: ItemCatalog.Item, x: number, z: number, rot: number, placedId: string): Model
	local template = itemsFolder:FindFirstChild(item.model)
	assert(template and template:IsA("Model"), "missing item model " .. item.model)

	local model = template:Clone()
	model.Name = placedId
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model:SetAttribute("ItemId", item.id)
	model:SetAttribute("PlacedId", placedId)
	model:SetAttribute("CellX", x)
	model:SetAttribute("CellZ", z)
	model:SetAttribute("Rot", rot)
	model:PivotTo(GridMath.footprintCFrame(
		PlotService.surfaceCFrame(plot),
		x,
		z,
		item.size.w,
		item.size.d,
		rot,
		Config.CELL_SIZE,
		Config.PLOT_CELLS
	))
	model.Parent = plot.placedFolder
	return model
end

function PlacementService.place(player: Player, itemId: any, x: any, z: any, rot: any): Net.PlaceResult
	if not limiter:tryConsume(player) then
		return fail(Reason.RateLimited)
	end
	local argsOk, argsReason = PlacementRules.validatePlaceArgs(itemId, x, z, rot)
	if not argsOk then
		return fail(argsReason :: string)
	end
	local item = ItemCatalog.get(itemId)
	if item == nil then
		return fail(Reason.BadItem)
	end
	local profile = PlayerDataService.get(player)
	local plot = PlotService.getPlotOf(player)
	if profile == nil or plot == nil then
		return fail(Reason.NoPlot)
	end
	if not PlotService.canBuild(player, plot) then
		return fail(Reason.NotOwner)
	end
	local ok, reason = PlacementRules.check(plot.state, item, x, z, rot, profile.cash, Config.PLOT_CELLS, Config.MAX_PLACED_PER_PLOT)
	if not ok then
		return fail(reason :: string)
	end

	-- Commit.
	if not EconomyService.charge(player, item.price) then
		return fail(Reason.InsufficientFunds)
	end
	local placedId = PlayerDataService.newPlacedId(profile)
	PlacementRules.occupy(plot.state, item, x, z, rot, Config.PLOT_CELLS, placedId)
	profile.placed[placedId] = { i = item.id, x = x, z = z, r = rot }

	local spawned, err = pcall(spawnModel, plot, item, x, z, rot, placedId)
	if not spawned then
		PlacementRules.vacate(plot.state, item, x, z, rot, Config.PLOT_CELLS)
		profile.placed[placedId] = nil
		local leftover = plot.placedFolder:FindFirstChild(placedId)
		if leftover then
			leftover:Destroy()
		end
		EconomyService.grant(player, item.price)
		warn(`[PlacementService] spawn failed for {player.Name} {item.id}: {err}`)
		return fail(Reason.Internal)
	end

	return { ok = true, placedId = placedId }
end

function PlacementService.remove(player: Player, placedId: any): Net.RemoveResult
	if not limiter:tryConsume(player) then
		return { ok = false, reason = Reason.RateLimited }
	end
	local argsOk, argsReason = PlacementRules.validateRemoveArgs(placedId)
	if not argsOk then
		return { ok = false, reason = argsReason }
	end
	local profile = PlayerDataService.get(player)
	local plot = PlotService.getPlotOf(player)
	if profile == nil or plot == nil then
		return { ok = false, reason = Reason.NoPlot }
	end
	if not PlotService.canBuild(player, plot) then
		return { ok = false, reason = Reason.NotOwner }
	end
	-- Only objects in the player's own record can be removed; anyone else's id is simply NotFound.
	local record = profile.placed[placedId]
	if record == nil then
		return { ok = false, reason = Reason.NotFound }
	end
	local item = ItemCatalog.get(record.i)
	if item == nil then
		return { ok = false, reason = Reason.Internal }
	end

	PlacementRules.vacate(plot.state, item, record.x, record.z, record.r, Config.PLOT_CELLS)
	profile.placed[placedId] = nil
	local model = plot.placedFolder:FindFirstChild(placedId)
	if model then
		model:Destroy()
	end
	local refund = math.floor(item.price * Config.REFUND_RATE)
	EconomyService.grant(player, refund)
	return { ok = true, refund = refund }
end

-- Drop per-player state when they leave.
function PlacementService.forget(player: Player)
	limiter:forget(player)
end

function PlacementService.Init()
	local assets = ReplicatedStorage:WaitForChild("Assets", 10)
	assert(assets, "ReplicatedStorage.Assets is missing (item models)")
	local items = assets:WaitForChild("Items", 10)
	assert(items, "ReplicatedStorage.Assets.Items is missing")
	itemsFolder = items

	local folder = ReplicatedStorage:FindFirstChild(Net.FolderName)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = Net.FolderName
		folder.Parent = ReplicatedStorage
	end
	assert(folder ~= nil)
	for _, name in { Net.RequestPlace, Net.RequestRemove } do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function PlacementService.Start()
	local folder = ReplicatedStorage:FindFirstChild(Net.FolderName) :: Folder
	local placeRemote = folder:FindFirstChild(Net.RequestPlace) :: RemoteFunction
	local removeRemote = folder:FindFirstChild(Net.RequestRemove) :: RemoteFunction

	-- Handlers never throw back to the client: any internal error becomes { ok = false, reason = "Internal" }.
	placeRemote.OnServerInvoke = function(player: Player, itemId: any, x: any, z: any, rot: any)
		local ok, result = pcall(PlacementService.place, player, itemId, x, z, rot)
		if ok then
			return result
		end
		warn(`[PlacementService] place error for {player.Name}: {result}`)
		return fail(Reason.Internal)
	end
	removeRemote.OnServerInvoke = function(player: Player, placedId: any)
		local ok, result = pcall(PlacementService.remove, player, placedId)
		if ok then
			return result
		end
		warn(`[PlacementService] remove error for {player.Name}: {result}`)
		return { ok = false, reason = Reason.Internal }
	end
end

return PlacementService
