--!strict
-- WorldConfig: World-place persistence settings (server only).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataKeys = require(script.Parent.Parent.Travel.DataKeys)

local WorldConfig = {
	-- DataStore names come from DataKeys (shared with the hub). Studio sessions use a
	-- separate "StudioTest_" namespace so testing never touches live player worlds.
	WORLD_STORE_NAME = DataKeys.WORLDS,
	WORLD_INDEX_STORE_NAME = DataKeys.WORLD_INDEX,
	KEY_PREFIX = "world_", -- key = KEY_PREFIX .. ownerUserId (same as DataKeys.worldKey)

	-- Studio only: "Dev" uses the in-place test store (ServerStorage.WorldDevStore), which works
	-- without publishing. "DataStore" uses real DataStores (needs a published experience with
	-- Studio API access). Live servers always use real DataStores.
	STUDIO_STORE_MODE = "Dev",

	-- Saving
	AUTOSAVE_INTERVAL = 60, -- seconds between autosave checks (only saves if something changed)
	LOCK_REFRESH_INTERVAL = 120, -- even with no changes, refresh the session lock this often
	LOCK_STALE_SECONDS = 300, -- a lock older than this is treated as abandoned (crashed server)
	LOCK_WAIT_SECONDS = 35, -- how long a new session waits for an old one to finish saving
	MAX_RECORD_BYTES = 3_000_000, -- refuse to save above this (hard DataStore limit is 4,194,304)

	-- Retries for DataStore calls that throw (network or throttling errors)
	MAX_ATTEMPTS = 4,
	RETRY_BASE_DELAY = 1, -- seconds; doubles each attempt (1, 2, 4)

	DEFAULT_WORLD_NAME = Config.DEFAULT_WORLD_NAME,
	MAX_WORLD_NAME_LENGTH = 50,
	MAX_QUARANTINE = 100, -- invalid saved objects kept (not built) so they're never silently lost
}

return table.freeze(WorldConfig)
