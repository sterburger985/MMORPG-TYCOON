--!strict
-- Hub place server bootstrap. The hub is the social space: everyone gets a plot that
-- shows off their world, with a World Gate to enter it (or to visit someone else's).
-- Building happens in the World place.

local Players = game:GetService("Players")

local Services = script.Parent.Services
local PlotService = require(Services.PlotService)
local HubEnvironment = require(Services.HubEnvironment)
local TravelService = require(Services.TravelService)

type Service = { Init: () -> (), Start: () -> () }

local ordered: { Service } = { PlotService, HubEnvironment, TravelService }

for _, service in ordered do
	service.Init()
end
for _, service in ordered do
	service.Start()
end

local function onPlayerAdded(player: Player)
	local plot = PlotService.assign(player)
	if plot == nil then
		player:Kick("This hub server is full. Please join another server.")
		return
	end
	TravelService.onPlayerJoined(player, plot)
end

local function onPlayerRemoving(player: Player)
	TravelService.onPlayerLeaving(player, PlotService.getPlotOf(player))
	PlotService.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print("[Server] MMORPG Tycoon HUB server ready")
