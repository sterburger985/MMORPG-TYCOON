--!strict
-- WorldConfig: World-place persistence settings (server only).

local RunService = game:GetService("RunService")

local IS_STUDIO = RunService:IsStudio()

local WorldConfig = {
	-- DataStore names. Studio sessions use a separate namespace so testing can never
	-- touch live player worlds, even after the experience is published.
	WORLD_STORE_NAME = if IS_STUDIO then "StudioTest_Worlds_v1" else "Worlds_v1",
	WORLD_INDEX_STORE_NAME = if IS_STUDIO then "StudioTest_WorldIndex_v1" else "WorldIndex_v1",
	KEY_PREFIX = "world_", -- key = KEY_PREFIX .. ownerUserId

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

	DEFAULT_WORLD_NAME = "My MMORPG",
	MAX_WORLD_NAME_LENGTH = 50,
	MAX_QUARANTINE = 100, -- invalid saved objects kept (not built) so they're never silently lost
}

return table.freeze(WorldConfig)
