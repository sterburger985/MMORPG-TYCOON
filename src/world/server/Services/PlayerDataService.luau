--!strict
-- PlayerDataService (World place): gives the shared PlacementService/EconomyService the
-- world's live profile (Cash, placed objects, next id). Same interface as the hub's
-- PlayerDataService, but the data belongs to the WORLD (its owner), not to whoever asks.
--
-- Safety: get() returns the profile for anyone in the server so PlacementService can give
-- visitors a clear NotOwner answer, but every change is gated by PlotService.canBuild
-- (owner only), and EconomyService.attach is only ever called for the owner, so visitors
-- never see or spend the owner's Cash.

local WorldSchema = require(script.Parent.WorldSchema)
local WorldState = require(script.Parent.WorldState)

local PlayerDataService = {}

function PlayerDataService.Init() end

function PlayerDataService.Start() end

function PlayerDataService.get(_player: Player): WorldSchema.Profile?
	if not WorldState.isLive() then
		return nil
	end
	return WorldState.profile
end

function PlayerDataService.newPlacedId(profile: WorldSchema.Profile): string
	local id = "p" .. profile.nextId
	profile.nextId += 1
	return id
end

-- Hub-compatible no-ops: in the World place the world's lifecycle is driven by
-- WorldSessionService, not by individual players joining or leaving.
function PlayerDataService.load(_player: Player): WorldSchema.Profile?
	return WorldState.profile
end

function PlayerDataService.release(_player: Player) end

return PlayerDataService
