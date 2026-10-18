--!strict
-- TravelService (Hub): world gates on every plot, world info on signs, and travel.
--
-- * Each plot gets a glowing World Gate with a ProximityPrompt. The server handles the
--   prompt, so the player is trusted (no client-chosen ids): your own gate opens your
--   world; anyone else's gate is a visit request to that plot owner's world.
-- * "Enter My World" HUD button -> RequestEnterMyWorld (no arguments).
-- * Visits are checked here with the same AccessPolicy the World server applies again on
--   arrival (Public / FriendsOnly via IsFriendsWithAsync, fails closed / Private).
-- * Access codes never leave the server; teleport data carries nothing trusted.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local AccessPolicy = require(ReplicatedStorage.Shared.AccessPolicy)
local Net = require(ReplicatedStorage.Shared.Net)

local PlotService = require(script.Parent.PlotService)
local Server = script.Parent.Parent
local Decor = require(Server.Util.Decor)
local RateLimiter = require(Server.Util.RateLimiter)
local Remotes = require(Server.Util.Remotes)
local Places = require(Server.Travel.Places)
local SafeTeleport = require(Server.Travel.SafeTeleport)
local WorldDirectory = require(Server.Travel.WorldDirectory)

type Gate = { model: Model, portal: BasePart, prompt: ProximityPrompt, title: TextLabel, subtitle: TextLabel }

local GLOW = Color3.fromRGB(80, 170, 255) -- arcane blue, matching the UI theme
local VISIBILITY_LABEL = {
	Public = "🌍 Public",
	FriendsOnly = "👥 Friends only",
	Private = "🔒 Private",
}

local directory = WorldDirectory.new({
	getStore = function(name: string): any
		return DataStoreService:GetDataStore(name)
	end,
	reserve = function(placeId: number): (string, string)
		local code, privateServerId = TeleportService:ReserveServerAsync(placeId)
		return code, privateServerId
	end,
	worldPlaceId = function(): number?
		local _, world = Places.get()
		return world
	end,
})

local gates: { [number]: Gate } = {}
local limiter = RateLimiter.new(0.5, 2) -- about one travel request every 2 s
local busy: { [Player]: boolean } = {}

local TravelService = {}

local function gateFor(plot: PlotService.Plot): Gate?
	return gates[plot.id]
end

local function showFreePlot(plot: PlotService.Plot)
	local gate = gateFor(plot)
	if gate then
		gate.title.Text = "Unclaimed Plot"
		gate.subtitle.Text = "Waiting for a world-builder"
		gate.prompt.Enabled = false
	end
	plot.model:SetAttribute("WorldName", nil)
	plot.model:SetAttribute("Visibility", nil)
	plot.model:SetAttribute("ObjectCount", nil)
end

-- Read the owner's saved world summary and show it on their plot (public info only).
local function refreshWorldInfo(player: Player, plot: PlotService.Plot)
	local gate = gateFor(plot)
	if gate then
		gate.title.Text = player.DisplayName .. "'s World"
		gate.subtitle.Text = "Loading world info..."
		gate.prompt.Enabled = true
	end
	local ok, summary = directory:peek(player.UserId)
	if plot.owner ~= player then
		return -- they left while we were reading
	end
	if not ok or summary == nil then
		plot.model:SetAttribute("WorldInfo", "unavailable")
		if gate then
			gate.subtitle.Text = "World info unavailable"
		end
		PlotService.setSign(plot, player.DisplayName .. "'s World")
		return
	end
	plot.model:SetAttribute("WorldInfo", "ok")
	local private = summary.visibility == Net.Visibility.Private
	local title = if private then "Private World" else summary.name
	plot.model:SetAttribute("WorldName", if private then nil else summary.name)
	plot.model:SetAttribute("Visibility", summary.visibility)
	plot.model:SetAttribute("ObjectCount", if private then nil else summary.objects)
	if gate then
		gate.title.Text = title
		gate.subtitle.Text = `by {player.DisplayName}  ·  {VISIBILITY_LABEL[summary.visibility] or summary.visibility}`
	end
	PlotService.setSign(plot, title)
end

type TravelResult = { ok: boolean, reason: string? }

-- Send `player` to `owner`'s world after server-side checks. Never trusts the client.
local function travel(player: Player, owner: Player): TravelResult
	if busy[player] then
		return { ok = false, reason = "Already travelling..." }
	end
	if not limiter:tryConsume(player) then
		return { ok = false, reason = Net.Message.RateLimited }
	end
	busy[player] = true
	local result: TravelResult = (function(): TravelResult
		if owner.Parent ~= Players or PlotService.getPlotOf(owner) == nil then
			return { ok = false, reason = "That world's owner isn't here any more." }
		end
		if not SafeTeleport.isAvailable() then
			return { ok = false, reason = "Travel between places only works in the live game, not in Studio playtests." }
		end
		local _, worldPlaceId = Places.get()
		if worldPlaceId == nil then
			return { ok = false, reason = "The World place isn't set up in this experience yet." }
		end

		local isOwner = owner == player
		local worldName = "your world"
		if not isOwner then
			local ok, summary = directory:peek(owner.UserId)
			if not ok or summary == nil then
				return { ok = false, reason = "Couldn't check that world right now. Try again." }
			end
			local isFriend = false
			if summary.visibility == Net.Visibility.FriendsOnly then
				local okFriend, friends = pcall(function()
					return player:IsFriendsWithAsync(owner.UserId)
				end)
				isFriend = okFriend and friends == true -- unknown = not a friend (fail closed)
			end
			local decision = AccessPolicy.decide(summary.visibility, false, isFriend)
			if decision ~= "allowed" then
				return { ok = false, reason = AccessPolicy.message(decision) }
			end
			worldName = summary.name
		end

		local ok, code, err = directory:ensureAccessCode(owner.UserId)
		if not ok or code == nil then
			warn(`[Travel] access code for {owner.UserId} failed: {err}`)
			return { ok = false, reason = "Couldn't open that world right now. Try again in a moment." }
		end

		Remotes.notify(player, "travel", if isOwner then "Opening your world..." else `Travelling to {worldName}...`, if isOwner then "Your World" else worldName)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData({ from = "hub" }) -- cosmetic only; never used for permissions
		local sent, message = SafeTeleport.teleport(worldPlaceId, { player }, options)
		if not sent then
			return { ok = false, reason = message }
		end
		return { ok = true }
	end)()
	busy[player] = nil
	if not result.ok and result.reason then
		Remotes.notify(player, "error", result.reason)
	end
	return result
end

function TravelService.Init()
	for _, plot in PlotService.getPlots() do
		local pad = plot.spawnPad
		local base = plot.base
		local towardRoad = if pad.Position.Z >= base.Position.Z then 1 else -1
		local position = pad.Position + Vector3.new(0, -0.2, -towardRoad * 15)
		local cframe = CFrame.lookAt(position, position + Vector3.new(0, 0, towardRoad))
		local model, portal = Decor.gate(plot.model, cframe, GLOW, "WorldGate")
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TravelPrompt"
		prompt.ActionText = "Enter World"
		prompt.ObjectText = "World Gate"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = portal
		local _, title, subtitle = Decor.label(model:FindFirstChild("Lintel") :: BasePart, "GateLabel", 5, 320)
		gates[plot.id] = { model = model, portal = portal, prompt = prompt, title = title, subtitle = subtitle }
		showFreePlot(plot)

		prompt.Triggered:Connect(function(player: Player)
			local owner = plot.owner
			if owner == nil then
				Remotes.notify(player, "info", "Nobody has claimed this plot yet.")
				return
			end
			travel(player, owner)
		end)
	end

	Remotes.event(Net.Notify)
	Remotes.func(Net.RequestEnterMyWorld).OnServerInvoke = function(player: Player)
		local ok, result = pcall(travel, player, player)
		if ok then
			return result
		end
		warn("[Travel] enter my world error: " .. tostring(result))
		busy[player] = nil
		return { ok = false, reason = Net.Message.Internal }
	end

	SafeTeleport.onFailure(function(player: Player, message: string)
		Remotes.notify(player, "error", message)
	end)
end

function TravelService.Start() end

-- Called by Main after the player has been given a plot.
function TravelService.onPlayerJoined(player: Player, plot: PlotService.Plot)
	task.spawn(refreshWorldInfo, player, plot)
end

-- Called by Main before the plot is released.
function TravelService.onPlayerLeaving(player: Player, plot: PlotService.Plot?)
	busy[player] = nil
	limiter:forget(player)
	if plot then
		showFreePlot(plot)
	end
end

return TravelService
