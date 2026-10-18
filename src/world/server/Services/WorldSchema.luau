--!strict
-- WorldSchema: the saved-world format (versioned) and its validation.
--
-- Saved record, version 1 (what goes into the DataStore):
--   Version       integer, schema version (1)
--   OwnerUserId   integer, the Roblox UserId that owns the world (the permanent key)
--   WorldName     string, 1..50 characters
--   Settings      { Visibility = "Public" | "FriendsOnly" | "Private" }
--   Economy       { Cash = integer >= 0 }
--   Objects       array of { Id = "p<n>", Type = <ItemCatalog id>, X = cell, Z = cell, Rot = 0..3 }
--   NextObjectId  integer, the next "p<n>" number to hand out
--   CreatedAt     unix seconds
--   Quarantine    array of { Reason, Data } - invalid objects kept but never built
-- Fields written by WorldStore: Session { Id, Time } (lock), SaveCount, UpdatedAt.
--
-- Objects are stored in the grid's own terms (cell + quarter turns), the same data the
-- placement system uses, so a saved world rebuilds exactly and can't be placed off-grid.
-- Anything not listed above is ignored when loading. Unknown item types are never built.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ItemCatalog = require(Shared.ItemCatalog)
local Net = require(Shared.Net)
local PlacementRules = require(Shared.PlacementRules)
local WorldConfig = require(script.Parent.WorldConfig)

local VERSION = 1

export type ObjectRecord = { id: string, type: string, x: number, z: number, rot: number }

export type World = {
	ownerUserId: number,
	name: string,
	visibility: string,
	cash: number,
	nextId: number,
	objects: { ObjectRecord },
	createdAt: number,
	quarantine: { any },
}

export type Report = {
	fatal: string?, -- set when the whole record must not be used
	dropped: { { id: string, reason: string } },
	fixes: { string },
}

-- Same shape PlayerDataService gives PlacementService in the hub.
export type Profile = {
	v: number,
	cash: number,
	placed: { [string]: { i: string, x: number, z: number, r: number } },
	nextId: number,
}

local WorldSchema = {}
WorldSchema.VERSION = VERSION

local function isInteger(v: any): boolean
	return PlacementRules.isInteger(v)
end

function WorldSchema.isValidOwnerId(v: any): boolean
	return isInteger(v) and v > 0 and v < 2 ^ 53
end

function WorldSchema.isValidVisibility(v: any): boolean
	return type(v) == "string" and Net.Visibility[v] == v
end

function WorldSchema.isValidName(v: any): boolean
	return type(v) == "string" and #v >= 1 and #v <= WorldConfig.MAX_WORLD_NAME_LENGTH
end

-- Number part of an object id "p<n>", or nil if the id is malformed.
function WorldSchema.idNumber(id: any): number?
	if type(id) ~= "string" or #id > 12 then
		return nil
	end
	local digits = string.match(id, "^p(%d+)$")
	if digits == nil then
		return nil
	end
	local n = tonumber(digits)
	if n == nil or n < 1 then
		return nil
	end
	return n
end

-- A brand-new world for an owner who has no save.
function WorldSchema.newWorld(ownerUserId: number, now: number): World
	assert(WorldSchema.isValidOwnerId(ownerUserId), "invalid owner id")
	return {
		ownerUserId = ownerUserId,
		name = WorldConfig.DEFAULT_WORLD_NAME,
		visibility = Net.Visibility.Public,
		cash = Config.START_CASH,
		nextId = 1,
		objects = {},
		createdAt = now,
		quarantine = {},
	}
end

-- Keep a bounded, JSON-safe copy of an invalid entry (primitives only).
local function sanitizeForQuarantine(raw: any): { [string]: any }
	local copy = {}
	if type(raw) ~= "table" then
		copy.Value = if type(raw) == "string" then string.sub(raw, 1, 64) else tostring(raw)
		return copy
	end
	local fields = 0
	for k, v in raw do
		if fields >= 8 then
			break
		end
		if type(k) == "string" and #k <= 32 then
			local t = type(v)
			if t == "number" or t == "boolean" then
				copy[k] = v
				fields += 1
			elseif t == "string" then
				copy[k] = string.sub(v, 1, 64)
				fields += 1
			end
		end
	end
	return copy
end

-- Upgrade older records to the current version. Only v1 exists today; each future
-- version adds one step here (e.g. 1 -> 2) so old saves keep loading.
local function migrate(raw: { [string]: any }): ({ [string]: any }?, string?)
	local version = raw.Version
	if version == VERSION then
		return raw, nil
	end
	return nil, "unsupported_version"
end

-- Turn untrusted saved data into a World. Never throws.
-- Returns ok=false with report.fatal when the record must not be used at all
-- (in which case the caller must not save over it).
function WorldSchema.decode(raw: any, expectedOwner: number): (boolean, World?, Report)
	local report: Report = { fatal = nil, dropped = {}, fixes = {} }
	local function fatal(reason: string): (boolean, World?, Report)
		report.fatal = reason
		return false, nil, report
	end

	if not WorldSchema.isValidOwnerId(expectedOwner) then
		return fatal("invalid_expected_owner")
	end
	if type(raw) ~= "table" then
		return fatal("not_a_table")
	end
	if not isInteger(raw.Version) or raw.Version < 1 then
		return fatal("missing_version")
	end
	if raw.Version > VERSION then
		-- Written by newer code: loading and re-saving it here could lose data.
		return fatal("future_version")
	end
	-- Never load one player's world for another player.
	if raw.OwnerUserId ~= expectedOwner then
		return fatal("owner_mismatch")
	end
	local record, migrateError = migrate(raw)
	if record == nil then
		return fatal(migrateError or "migration_failed")
	end

	local world = WorldSchema.newWorld(expectedOwner, 0)

	if WorldSchema.isValidName(record.WorldName) then
		world.name = record.WorldName
	else
		table.insert(report.fixes, "WorldName reset to default")
	end

	local settings = if type(record.Settings) == "table" then record.Settings else {}
	if WorldSchema.isValidVisibility(settings.Visibility) then
		world.visibility = settings.Visibility
	else
		table.insert(report.fixes, "Visibility reset to Public")
	end

	local economy = if type(record.Economy) == "table" then record.Economy else {}
	if isInteger(economy.Cash) and economy.Cash >= 0 and economy.Cash <= 1e12 then
		world.cash = economy.Cash
	else
		table.insert(report.fixes, "Cash reset to starting amount")
	end

	if type(record.CreatedAt) == "number" and record.CreatedAt == record.CreatedAt then
		world.createdAt = record.CreatedAt
	end

	-- Carry over earlier quarantined entries (bounded) so they're never silently lost.
	if type(record.Quarantine) == "table" then
		for _, q in record.Quarantine do
			if #world.quarantine >= WorldConfig.MAX_QUARANTINE then
				break
			end
			if type(q) == "table" and type(q.Reason) == "string" then
				table.insert(world.quarantine, { Reason = string.sub(q.Reason, 1, 32), Data = sanitizeForQuarantine(q.Data) })
			end
		end
	end

	-- Objects: validate each one against the catalog and the placement rules.
	local state = PlacementRules.newPlotState()
	local seenIds: { [string]: boolean } = {}
	local maxIdNumber = 0
	local objects = if type(record.Objects) == "table" then record.Objects else {}
	if type(record.Objects) ~= "table" and record.Objects ~= nil then
		table.insert(report.fixes, "Objects was not a list")
	end

	local function drop(entry: any, id: string, reason: string)
		table.insert(report.dropped, { id = id, reason = reason })
		if #world.quarantine < WorldConfig.MAX_QUARANTINE then
			table.insert(world.quarantine, { Reason = reason, Data = sanitizeForQuarantine(entry) })
		end
	end

	for index, entry in objects do
		local label = "#" .. tostring(index)
		if type(entry) ~= "table" then
			drop(entry, label, "not_a_table")
			continue
		end
		local id = entry.Id
		local idNumber = WorldSchema.idNumber(id)
		if idNumber == nil then
			drop(entry, label, "bad_id")
			continue
		end
		label = id
		if seenIds[id] then
			drop(entry, label, "duplicate_id")
			continue
		end
		local item = if type(entry.Type) == "string" then ItemCatalog.get(entry.Type) else nil
		if item == nil then
			drop(entry, label, "unknown_type")
			continue
		end
		local x, z, rot = entry.X, entry.Z, entry.Rot
		if not (isInteger(x) and isInteger(z) and isInteger(rot)) or rot < 0 or rot > 3 then
			drop(entry, label, "bad_transform")
			continue
		end
		local ok, reason =
			PlacementRules.check(state, item, x, z, rot, math.huge, Config.PLOT_CELLS, Config.MAX_PLACED_PER_PLOT)
		if not ok then
			drop(entry, label, string.lower(reason or "rejected"))
			continue
		end
		PlacementRules.occupy(state, item, x, z, rot, Config.PLOT_CELLS, id)
		seenIds[id] = true
		maxIdNumber = math.max(maxIdNumber, idNumber)
		table.insert(world.objects, { id = id, type = item.id, x = x, z = z, rot = rot })
	end

	local nextId = record.NextObjectId
	world.nextId = math.max(if isInteger(nextId) and nextId >= 1 then nextId else 1, maxIdNumber + 1)

	return true, world, report
end

-- World -> saved record (without the WorldStore-managed Session/SaveCount/UpdatedAt fields).
function WorldSchema.encode(world: World): { [string]: any }
	local objects = table.create(#world.objects)
	for _, o in world.objects do
		table.insert(objects, { Id = o.id, Type = o.type, X = o.x, Z = o.z, Rot = o.rot })
	end
	table.sort(objects, function(a, b)
		return (WorldSchema.idNumber(a.Id) or 0) < (WorldSchema.idNumber(b.Id) or 0)
	end)
	return {
		Version = VERSION,
		OwnerUserId = world.ownerUserId,
		WorldName = world.name,
		Settings = { Visibility = world.visibility },
		Economy = { Cash = world.cash },
		Objects = objects,
		NextObjectId = world.nextId,
		CreatedAt = world.createdAt,
		Quarantine = world.quarantine,
	}
end

-- The in-memory profile PlacementService/EconomyService work with.
function WorldSchema.toProfile(world: World): Profile
	local placed = {}
	for _, o in world.objects do
		placed[o.id] = { i = o.type, x = o.x, z = o.z, r = o.rot }
	end
	return { v = VERSION, cash = world.cash, placed = placed, nextId = world.nextId }
end

-- Copy the live profile back into the world before saving.
function WorldSchema.applyProfile(world: World, profile: Profile)
	local objects = {}
	for id, rec in profile.placed do
		table.insert(objects, { id = id, type = rec.i, x = rec.x, z = rec.z, rot = rec.r })
	end
	world.objects = objects
	world.cash = profile.cash
	world.nextId = profile.nextId
end

return WorldSchema
