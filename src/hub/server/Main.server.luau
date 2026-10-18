--!strict
-- Server bootstrap: Init every service, Start every service, then drive the player
-- lifecycle in a fixed order so no service races another on join or leave.

local Players = game:GetService("Players")

local Services = script.Parent.Services
local PlayerDataService = require(Services.PlayerDataService)
local PlotService = require(Services.PlotService)
local EconomyService = require(Services.EconomyService)
local PlacementService = require(Services.PlacementService)

type Service = { Init: () -> (), Start: () -> () }

local ordered: { Service } = { PlayerDataService, PlotService, EconomyService, PlacementService }

for _, service in ordered do
	service.Init()
end
for _, service in ordered do
	service.Start()
end

local function onPlayerAdded(player: Player)
	PlayerDataService.load(player)
	EconomyService.attach(player)
	if PlotService.assign(player) == nil then
		player:Kick("This server is full. Please join another server.")
	end
end

local function onPlayerRemoving(player: Player)
	PlacementService.forget(player)
	PlotService.release(player)
	PlayerDataService.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print("[Server] MMORPG Tycoon server ready")
