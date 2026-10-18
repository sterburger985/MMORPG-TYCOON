--!strict
-- OwnerResolver: works out whose world this server hosts. The client is never asked.
--
-- Live servers: the World place only runs as reserved servers. The hub (travel phase)
-- will record PrivateServerId -> owner UserId in WorldIndex when it reserves a world's
-- server; here we read that record. Anything else (public server, missing record) fails
-- closed: no owner, no world.
-- Studio: there are no reserved servers, so the first player to join is the owner
-- (or ServerStorage.WorldDevStore's OwnerOverride attribute, for testing other owners).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataKeys = require(script.Parent.Parent.Travel.DataKeys)
local WorldConfig = require(script.Parent.WorldConfig)
local WorldSchema = require(script.Parent.WorldSchema)

local OwnerResolver = {}

local function studioOwner(): (number?, string)
	local dev = ServerStorage:FindFirstChild("WorldDevStore")
	local override = dev and dev:GetAttribute("OwnerOverride")
	if override ~= nil then
		if WorldSchema.isValidOwnerId(override) then
			return override :: number, "studio_override"
		end
		return nil, "studio_override_invalid"
	end
	local first = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	return first.UserId, "studio_first_player"
end

local function liveOwner(): (number?, string)
	if game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 then
		return nil, "not_a_reserved_server"
	end
	local ok, value = false, nil
	for attempt = 1, WorldConfig.MAX_ATTEMPTS do
		ok, value = pcall(function()
			local index = DataStoreService:GetDataStore(WorldConfig.WORLD_INDEX_STORE_NAME)
			return index:GetAsync(DataKeys.indexKey(game.PrivateServerId))
		end)
		if ok then
			break
		end
		warn(`[OwnerResolver] index lookup failed (attempt {attempt}): {value}`)
		task.wait(WorldConfig.RETRY_BASE_DELAY * 2 ^ (attempt - 1))
	end
	if not ok then
		return nil, "index_error"
	end
	if not WorldSchema.isValidOwnerId(value) then
		return nil, "index_missing"
	end
	return value, "index"
end

-- Yields. Returns the owner's UserId (or nil) and where it came from.
function OwnerResolver.resolve(): (number?, string)
	if RunService:IsStudio() then
		return studioOwner()
	end
	return liveOwner()
end

return OwnerResolver
