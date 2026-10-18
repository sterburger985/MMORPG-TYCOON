--!strict
-- WorldStore: all DataStore reads and writes for world saves.
--
-- * One key per world: KEY_PREFIX .. ownerUserId (UserIds never change; usernames do).
-- * Every read and write goes through UpdateAsync so each one is atomic per key.
-- * A session lock (record.Session = { Id, Time }) makes sure only one server writes a
--   world at a time. Load takes the lock; every save checks we still hold it and
--   refreshes it; the final save on shutdown releases it. A lock older than
--   LOCK_STALE_SECONDS is treated as abandoned (crashed server) and can be taken over.
-- * DataStore calls that throw are retried with bounded exponential backoff.
-- * A failed read is reported as "error", never as "no save".
--
-- The backing store is injected (a real DataStore, the Studio dev store, or a test fake),
-- so the same code is exercised in unit tests and in game.

local HttpService = game:GetService("HttpService")

local WorldConfig = require(script.Parent.WorldConfig)
local WorldSchema = require(script.Parent.WorldSchema)

export type StoreLike = {
	UpdateAsync: (self: any, key: string, transform: (any, any) -> any) -> any,
}

export type LoadStatus = "new" | "loaded" | "locked" | "unsafe" | "error"
export type LoadResult = {
	status: LoadStatus,
	raw: any, -- the stored record (as written, for new/loaded) or as found (locked/unsafe)
	message: string?,
}

export type SaveStatus = "saved" | "lock_lost" | "missing" | "too_large" | "encode_error" | "error"
export type SaveResult = {
	status: SaveStatus,
	bytes: number?,
	message: string?,
}

export type Options = {
	store: StoreLike,
	sessionId: string,
	now: (() -> number)?,
	wait: ((number) -> ())?,
	encode: ((any) -> string)?,
	maxAttempts: number?,
	retryBaseDelay: number?,
	lockStaleSeconds: number?,
	maxBytes: number?,
	log: ((string) -> ())?,
}

export type WorldStore = {
	key: (self: WorldStore, ownerUserId: number) -> string,
	load: (self: WorldStore, ownerUserId: number) -> LoadResult,
	save: (self: WorldStore, ownerUserId: number, record: { [string]: any }, release: boolean) -> SaveResult,
	releaseLock: (self: WorldStore, ownerUserId: number) -> boolean,
}

local WorldStore = {}

function WorldStore.new(opts: Options): WorldStore
	assert(opts.store ~= nil, "WorldStore needs a store")
	assert(type(opts.sessionId) == "string" and #opts.sessionId > 0, "WorldStore needs a sessionId")

	local store = opts.store
	local sessionId = opts.sessionId
	local now: () -> number = opts.now or os.time
	local wait: (number) -> () = opts.wait or function(seconds: number)
		task.wait(seconds)
	end
	local encode: (any) -> string = opts.encode or function(value: any): string
		return HttpService:JSONEncode(value)
	end
	local maxAttempts = opts.maxAttempts or WorldConfig.MAX_ATTEMPTS
	local baseDelay = opts.retryBaseDelay or WorldConfig.RETRY_BASE_DELAY
	local staleSeconds = opts.lockStaleSeconds or WorldConfig.LOCK_STALE_SECONDS
	local maxBytes = opts.maxBytes or WorldConfig.MAX_RECORD_BYTES
	local log: (string) -> () = opts.log or function(message: string)
		print("[WorldStore] " .. message)
	end

	-- Run a DataStore call, retrying on errors. Returns ok, result-or-error.
	local function withRetry(label: string, fn: () -> any): (boolean, any)
		local lastError: any = nil
		for attempt = 1, maxAttempts do
			local ok, result = pcall(fn)
			if ok then
				return true, result
			end
			lastError = result
			log(`{label} failed (attempt {attempt}/{maxAttempts}): {result}`)
			if attempt < maxAttempts then
				wait(baseDelay * 2 ^ (attempt - 1))
			end
		end
		return false, lastError
	end

	local function lockIsOurs(current: any): boolean
		return type(current) == "table" and type(current.Session) == "table" and current.Session.Id == sessionId
	end

	local function lockIsHeldByOther(current: any, t: number): boolean
		if type(current) ~= "table" or type(current.Session) ~= "table" then
			return false
		end
		local session = current.Session
		if session.Id == sessionId then
			return false
		end
		local lockTime = if type(session.Time) == "number" then session.Time else 0
		return t - lockTime < staleSeconds
	end

	local self = {} :: WorldStore

	function self.key(_self: WorldStore, ownerUserId: number): string
		return WorldConfig.KEY_PREFIX .. tostring(ownerUserId)
	end

	function self.load(_self: WorldStore, ownerUserId: number): LoadResult
		if not WorldSchema.isValidOwnerId(ownerUserId) then
			return { status = "error", raw = nil, message = "invalid owner id" }
		end
		local key = self:key(ownerUserId)
		local status: LoadStatus = "error"
		local seen: any = nil

		local ok, result = withRetry("load " .. key, function()
			-- UpdateAsync may call this more than once; reset what we observed each time.
			return store:UpdateAsync(key, function(current: any)
				local t = now()
				seen = current
				if current == nil then
					-- Truly no save (UpdateAsync gives the authoritative value; failures throw instead).
					local record = WorldSchema.encode(WorldSchema.newWorld(ownerUserId, t))
					record.Session = { Id = sessionId, Time = t }
					record.SaveCount = 0
					record.UpdatedAt = t
					status = "new"
					return record
				end
				if
					type(current) ~= "table"
					or current.OwnerUserId ~= ownerUserId
					or (type(current.Version) == "number" and current.Version > WorldSchema.VERSION)
				then
					status = "unsafe" -- don't write anything to a record we can't safely own
					return nil
				end
				if lockIsHeldByOther(current, t) then
					status = "locked"
					return nil
				end
				current.Session = { Id = sessionId, Time = t }
				status = "loaded"
				return current
			end)
		end)

		if not ok then
			return { status = "error", raw = nil, message = tostring(result) }
		end
		if status == "new" or status == "loaded" then
			return { status = status, raw = result, message = nil }
		end
		return { status = status, raw = seen, message = nil }
	end

	function self.save(_self: WorldStore, ownerUserId: number, record: { [string]: any }, release: boolean): SaveResult
		if not WorldSchema.isValidOwnerId(ownerUserId) or record.OwnerUserId ~= ownerUserId then
			return { status = "error", message = "owner mismatch in save request" }
		end

		-- Check it serializes and fits before touching the DataStore.
		local encodedOk, encoded = pcall(encode, record)
		if not encodedOk or type(encoded) ~= "string" then
			return { status = "encode_error", message = tostring(encoded) }
		end
		local bytes = #encoded
		if bytes > maxBytes then
			return { status = "too_large", bytes = bytes, message = `record is {bytes} bytes (limit {maxBytes})` }
		end

		local key = self:key(ownerUserId)
		local status: SaveStatus = "error"
		local ok, result = withRetry("save " .. key, function()
			return store:UpdateAsync(key, function(current: any)
				if current == nil then
					status = "missing" -- the record vanished (e.g. deleted); never recreate it blindly
					return nil
				end
				if type(current) ~= "table" or current.OwnerUserId ~= ownerUserId or not lockIsOurs(current) then
					status = "lock_lost"
					return nil
				end
				local t = now()
				local new = table.clone(record)
				new.Session = if release then nil else { Id = sessionId, Time = t }
				new.SaveCount = (if type(current.SaveCount) == "number" then current.SaveCount else 0) + 1
				new.UpdatedAt = t
				status = "saved"
				return new
			end)
		end)

		if not ok then
			return { status = "error", bytes = bytes, message = tostring(result) }
		end
		if status == "saved" and result == nil then
			status = "error"
		end
		return { status = status, bytes = bytes, message = nil }
	end

	-- Drop our lock without changing anything else (used when we refuse to use a record).
	function self.releaseLock(_self: WorldStore, ownerUserId: number): boolean
		local key = self:key(ownerUserId)
		local released = false
		local ok = withRetry("release " .. key, function()
			return store:UpdateAsync(key, function(current: any)
				released = false
				if not lockIsOurs(current) then
					return nil
				end
				current.Session = nil
				released = true
				return current
			end)
		end)
		return ok and released
	end

	return self
end

return WorldStore
