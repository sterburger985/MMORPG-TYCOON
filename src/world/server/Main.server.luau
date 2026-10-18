--!strict
-- World place server bootstrap. Init every service, then Start every service.
-- WorldSessionService drives the world's lifecycle (owner, load, players, saving).

local Services = script.Parent.Services
local PlotService = require(Services.PlotService)
local WorldDecor = require(Services.WorldDecor)
local PlayerDataService = require(Services.PlayerDataService)
local EconomyService = require(Services.EconomyService)
local PlacementService = require(Services.PlacementService)
local WorldSessionService = require(Services.WorldSessionService)

type Service = { Init: () -> (), Start: () -> () }

local ordered: { Service } = { PlotService, WorldDecor, PlayerDataService, EconomyService, PlacementService, WorldSessionService }

for _, service in ordered do
	service.Init()
end
for _, service in ordered do
	service.Start()
end

print("[Server] MMORPG Tycoon WORLD server started")
