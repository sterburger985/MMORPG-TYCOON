--!strict
-- Places: finds the Hub and World place ids of this experience at runtime, so nothing
-- has to be hard-coded. The World place is the place whose name contains "world";
-- the Hub is the experience's other (start) place. Config.HUB_PLACE_ID /
-- Config.WORLD_PLACE_ID override the lookup when they are non-zero.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type PlaceInfo = { Name: string, PlaceId: number }

local Places = {}

local cached: { hub: number?, world: number? }? = nil

-- Pure: pick hub and world ids from a list of places. `currentPlaceId` helps when
-- names are ambiguous (the current server is always one of the two).
function Places.pick(list: { PlaceInfo }, currentPlaceId: number): (number?, number?)
	local world: number? = nil
	for _, p in list do
		if string.find(string.lower(p.Name), "world", 1, true) then
			world = p.PlaceId
			break
		end
	end
	local hub: number? = nil
	for _, p in list do
		if p.PlaceId ~= world then
			hub = p.PlaceId
			break
		end
	end
	-- If this server is not the world place and no other candidate was found, it is the hub.
	if hub == nil and currentPlaceId ~= 0 and currentPlaceId ~= world then
		hub = currentPlaceId
	end
	return hub, world
end

local function lookup(): { hub: number?, world: number? }
	local hub: number? = if Config.HUB_PLACE_ID ~= 0 then Config.HUB_PLACE_ID else nil
	local world: number? = if Config.WORLD_PLACE_ID ~= 0 then Config.WORLD_PLACE_ID else nil
	if hub and world then
		return { hub = hub, world = world }
	end
	if game.PlaceId == 0 then
		return { hub = hub, world = world } -- unpublished: no places to look up
	end
	local ok, result = pcall(function()
		local list: { PlaceInfo } = {}
		local pages = AssetService:GetGamePlacesAsync()
		while true do
			for _, place in pages:GetCurrentPage() do
				table.insert(list, { Name = place.Name, PlaceId = place.PlaceId })
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
		return list
	end)
	if not ok then
		warn("[Places] place lookup failed: " .. tostring(result))
		return { hub = hub, world = world }
	end
	local foundHub, foundWorld = Places.pick(result, game.PlaceId)
	return { hub = hub or foundHub, world = world or foundWorld }
end

-- Yields on first call. Returns nil ids when they can't be determined (e.g. unpublished).
function Places.get(): (number?, number?)
	if cached == nil or cached.hub == nil or cached.world == nil then
		cached = lookup()
	end
	local c = cached :: { hub: number?, world: number? }
	return c.hub, c.world
end

return Places
