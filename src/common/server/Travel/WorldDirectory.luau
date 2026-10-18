--!strict
-- WorldDirectory: the hub's read-only view of worlds, and the keeper of each world's
-- reserved-server access code.
--
-- peek(owner)              read a world's public summary (name, visibility, object count)
--                          without locking it. Missing record = a world that hasn't been
--                          opened yet (defaults). A record for another owner is an error.
-- ensureAccessCode(owner)  return the world's ONE access code, creating it on first use:
--                          reserve a World server -> write index (PrivateServerId -> owner)
--                          -> write meta (keeps an existing code if another server won the race).
--                          The index is written BEFORE the meta, so a stored code always has
--                          an index entry and a World server can always resolve its owner.
--
-- Dependencies are injected so unit tests can use fakes; the hub passes real ones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local DataKeys = require(script.Parent.DataKeys)

export type Summary = {
	exists: boolean,
	name: string,
	visibility: string,
	objects: number,
}

export type Deps = {
	getStore: (name: string) -> any, -- object with GetAsync / UpdateAsync
	reserve: (placeId: number) -> (string, string), -- access code, PrivateServerId
	worldPlaceId: () -> number?,
	now: (() -> number)?,
	wait: ((number) -> ())?,
	attempts: number?,
	log: ((string) -> ())?,
}

export type WorldDirectory = {
	peek: (self: WorldDirectory, ownerUserId: number) -> (boolean, Summary?),
	ensureAccessCode: (self: WorldDirectory, ownerUserId: number) -> (boolean, string?, string?),
}

local WorldDirectory = {}

local function validOwner(v: any): boolean
	return type(v) == "number" and v == v and v > 0 and v < 2 ^ 53 and math.floor(v) == v
end

function WorldDirectory.new(deps: Deps): WorldDirectory
	local attempts = deps.attempts or 3
	local now: () -> number = deps.now or os.time
	local wait: (number) -> () = deps.wait or function(s: number)
		task.wait(s)
	end
	local log: (string) -> () = deps.log or function(m: string)
		print("[WorldDirectory] " .. m)
	end

	local function retry(label: string, fn: () -> any): (boolean, any)
		local lastError: any = nil
		for attempt = 1, attempts do
			local ok, result = pcall(fn)
			if ok then
				return true, result
			end
			lastError = result
			log(`{label} failed ({attempt}/{attempts}): {result}`)
			if attempt < attempts then
				wait(attempt)
			end
		end
		return false, lastError
	end

	-- Make sure index[ps_<psid>] == owner (idempotent; no write when already correct).
	local function ensureIndex(psid: string, owner: number): boolean
		local gotStore, index = pcall(deps.getStore, DataKeys.WORLD_INDEX)
		if not gotStore then
			log(`index {psid}: no DataStore access: {index}`)
			return false
		end
		local ok = retry("index " .. psid, function()
			return index:UpdateAsync(DataKeys.indexKey(psid), function(current: any): any
				if current == owner then
					return nil -- already correct: cancel the write
				end
				return owner
			end)
		end)
		return ok
	end

	local self = {} :: WorldDirectory

	function self.peek(_self: WorldDirectory, ownerUserId: number): (boolean, Summary?)
		if not validOwner(ownerUserId) then
			return false, nil
		end
		-- GetDataStore itself can throw (unpublished place, API access off), so it is
		-- guarded like any other DataStore call.
		local gotStore, store = pcall(deps.getStore, DataKeys.WORLDS)
		if not gotStore then
			log(`peek {ownerUserId}: no DataStore access: {store}`)
			return false, nil
		end
		local ok, record = retry("peek " .. ownerUserId, function()
			return store:GetAsync(DataKeys.worldKey(ownerUserId))
		end)
		if not ok then
			return false, nil
		end
		if record == nil then
			return true, { exists = false, name = Config.DEFAULT_WORLD_NAME, visibility = Net.Visibility.Public, objects = 0 }
		end
		if type(record) ~= "table" or record.OwnerUserId ~= ownerUserId then
			log(`peek {ownerUserId}: record is not this owner's; refusing to use it`)
			return false, nil
		end
		local settings = if type(record.Settings) == "table" then record.Settings else {}
		local visibility = settings.Visibility
		if type(visibility) ~= "string" or Net.Visibility[visibility] ~= visibility then
			visibility = Net.Visibility.Public
		end
		local name = record.WorldName
		if type(name) ~= "string" or #name < 1 or #name > 50 then
			name = Config.DEFAULT_WORLD_NAME
		end
		local objects = if type(record.Objects) == "table" then #record.Objects else 0
		return true, { exists = true, name = name, visibility = visibility, objects = objects }
	end

	function self.ensureAccessCode(_self: WorldDirectory, ownerUserId: number): (boolean, string?, string?)
		if not validOwner(ownerUserId) then
			return false, nil, "invalid owner"
		end
		local gotStore, metaStore = pcall(deps.getStore, DataKeys.WORLD_META)
		if not gotStore then
			log(`ensureAccessCode {ownerUserId}: no DataStore access: {metaStore}`)
			return false, nil, "no DataStore access"
		end
		local key = DataKeys.metaKey(ownerUserId)

		local function isValidMeta(m: any): boolean
			return type(m) == "table"
				and m.OwnerUserId == ownerUserId
				and type(m.AccessCode) == "string"
				and #m.AccessCode > 0
				and type(m.PrivateServerId) == "string"
				and #m.PrivateServerId > 0
		end

		local okRead, meta = retry("meta read " .. ownerUserId, function()
			return metaStore:GetAsync(key)
		end)
		if not okRead then
			return false, nil, "couldn't read world travel data"
		end
		if isValidMeta(meta) then
			if not ensureIndex(meta.PrivateServerId, ownerUserId) then
				return false, nil, "couldn't update world index"
			end
			return true, meta.AccessCode, nil
		end

		-- First trip to this world: reserve its server.
		local placeId = deps.worldPlaceId()
		if placeId == nil then
			return false, nil, "World place not found in this experience"
		end
		local okReserve, code, psid = pcall(deps.reserve, placeId)
		if not okReserve or type(code) ~= "string" or type(psid) ~= "string" then
			return false, nil, "couldn't reserve a world server: " .. tostring(code)
		end
		if not ensureIndex(psid, ownerUserId) then
			return false, nil, "couldn't write world index"
		end

		local winner: any = nil
		local okWrite = retry("meta write " .. ownerUserId, function()
			return metaStore:UpdateAsync(key, function(current: any): any
				winner = nil
				if isValidMeta(current) then
					winner = current -- someone else created it first: keep theirs
					return nil
				end
				return {
					Version = 1,
					OwnerUserId = ownerUserId,
					AccessCode = code,
					PrivateServerId = psid,
					CreatedAt = now(),
				}
			end)
		end)
		if not okWrite then
			return false, nil, "couldn't save world travel data"
		end
		if winner ~= nil then
			if not ensureIndex(winner.PrivateServerId, ownerUserId) then
				return false, nil, "couldn't update world index"
			end
			return true, winner.AccessCode, nil
		end
		return true, code, nil
	end

	return self
end

return WorldDirectory
