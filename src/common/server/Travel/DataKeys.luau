--!strict
-- DataKeys: every DataStore name and key format, in one place, so the Hub and World
-- places always read and write the same records. Studio sessions use a separate
-- "StudioTest_" namespace so testing can never touch live player worlds.

local RunService = game:GetService("RunService")

local PREFIX = if RunService:IsStudio() then "StudioTest_" else ""

local DataKeys = table.freeze({
	-- One record per world: settings, objects, Cash, session lock (written only by the World server).
	WORLDS = PREFIX .. "Worlds_v1",
	-- Small per-world travel record: the reserved-server access code (written by the hub).
	WORLD_META = PREFIX .. "WorldMeta_v1",
	-- PrivateServerId -> owner UserId, so a World server learns whose world it hosts.
	WORLD_INDEX = PREFIX .. "WorldIndex_v1",

	worldKey = function(ownerUserId: number): string
		return "world_" .. tostring(ownerUserId)
	end,
	metaKey = function(ownerUserId: number): string
		return "meta_" .. tostring(ownerUserId)
	end,
	indexKey = function(privateServerId: string): string
		return "ps_" .. privateServerId
	end,
})

return DataKeys
