--!nonstrict
-- Tests for ServerScriptService.Server.Travel.WorldDirectory and Places.pick (fakes only).
-- Contract: peek is read-only and refuses foreign records; each world gets exactly one
-- access code; the index is written before the code is stored; a lost race keeps the
-- first code; failures are reported, not hidden.
return function(t)
	local HttpService = game:GetService("HttpService")
	local Travel = game:GetService("ServerScriptService").Server.Travel
	local WorldDirectory = require(Travel.WorldDirectory)
	local DataKeys = require(Travel.DataKeys)
	local Places = require(Travel.Places)
	local expect = t.expect
	local OWNER = 555

	local function copy(v)
		if v == nil then
			return nil
		end
		return HttpService:JSONDecode(HttpService:JSONEncode(v))
	end

	local function fakeStores(log)
		local stores = {}
		local function get(name)
			if stores[name] == nil then
				local s = { data = {}, failAll = false, writes = 0 }
				function s:GetAsync(key)
					if self.failAll then
						error("fake outage")
					end
					return copy(self.data[key])
				end
				function s:UpdateAsync(key, fn)
					if self.failAll then
						error("fake outage")
					end
					local new = fn(copy(self.data[key]), nil)
					if new == nil then
						return nil
					end
					self.writes += 1
					self.data[key] = copy(new)
					if log then
						table.insert(log, name .. ":" .. key)
					end
					return copy(new)
				end
				stores[name] = s
			end
			return stores[name]
		end
		return get, stores
	end

	local function directory(getStore, opts)
		opts = opts or {}
		local reserves = 0
		local dir = WorldDirectory.new({
			getStore = getStore,
			reserve = opts.reserve or function()
				reserves += 1
				return "code" .. reserves, "ps" .. reserves
			end,
			worldPlaceId = function()
				return if opts.noPlace then nil else 999
			end,
			wait = function() end,
			log = function() end,
			now = function()
				return 1
			end,
		})
		return dir, function()
			return reserves
		end
	end

	-- A world that was never opened peeks as a default Public world.
	t.test("peek of a missing world returns defaults", function()
		local get = fakeStores()
		local ok, summary = directory(get):peek(OWNER)
		expect.truthy(ok)
		expect.falsy(summary.exists)
		expect.equal(summary.visibility, "Public")
		expect.equal(summary.objects, 0)
	end)

	-- peek reads name, visibility and object count from the save.
	t.test("peek summarises an existing world", function()
		local get = fakeStores()
		get(DataKeys.WORLDS).data[DataKeys.worldKey(OWNER)] = {
			OwnerUserId = OWNER,
			WorldName = "Dragonspire",
			Settings = { Visibility = "FriendsOnly" },
			Objects = { {}, {}, {} },
		}
		local ok, summary = directory(get):peek(OWNER)
		expect.truthy(ok)
		expect.equal(summary.name, "Dragonspire")
		expect.equal(summary.visibility, "FriendsOnly")
		expect.equal(summary.objects, 3)
	end)

	-- A record belonging to someone else is never trusted.
	t.test("peek refuses another owner's record", function()
		local get = fakeStores()
		get(DataKeys.WORLDS).data[DataKeys.worldKey(OWNER)] = { OwnerUserId = 1 }
		local ok = directory(get):peek(OWNER)
		expect.falsy(ok)
	end)

	-- peek never writes.
	t.test("peek is read-only", function()
		local get, stores = fakeStores()
		directory(get):peek(OWNER)
		expect.equal(stores[DataKeys.WORLDS].writes, 0)
	end)

	-- The first trip reserves a server and stores the code; later trips reuse it.
	t.test("ensureAccessCode creates once, then reuses", function()
		local get = fakeStores()
		local dir, reserves = directory(get)
		local ok1, code1 = dir:ensureAccessCode(OWNER)
		local ok2, code2 = dir:ensureAccessCode(OWNER)
		expect.truthy(ok1)
		expect.truthy(ok2)
		expect.equal(code1, "code1")
		expect.equal(code2, "code1")
		expect.equal(reserves(), 1)
		expect.equal(get(DataKeys.WORLD_INDEX).data[DataKeys.indexKey("ps1")], OWNER)
	end)

	-- The index entry is written before the meta record.
	t.test("index is written before the code is stored", function()
		local log = {}
		local get = fakeStores(log)
		directory(get):ensureAccessCode(OWNER)
		expect.equal(log[1], DataKeys.WORLD_INDEX .. ":" .. DataKeys.indexKey("ps1"))
		expect.equal(log[2], DataKeys.WORLD_META .. ":" .. DataKeys.metaKey(OWNER))
	end)

	-- If another server stored a code first, its code wins and ours is discarded.
	t.test("a lost race keeps the first code", function()
		local get = fakeStores()
		local dir = directory(get, {
			reserve = function()
				-- Simulate another hub writing the meta while we were reserving.
				get(DataKeys.WORLD_META).data[DataKeys.metaKey(OWNER)] =
					{ OwnerUserId = OWNER, AccessCode = "theirs", PrivateServerId = "psT" }
				return "ours", "psO"
			end,
		})
		local ok, code = dir:ensureAccessCode(OWNER)
		expect.truthy(ok)
		expect.equal(code, "theirs")
		expect.equal(get(DataKeys.WORLD_INDEX).data[DataKeys.indexKey("psT")], OWNER)
	end)

	-- A missing index entry for an existing code is repaired.
	t.test("existing code gets its index repaired", function()
		local get = fakeStores()
		get(DataKeys.WORLD_META).data[DataKeys.metaKey(OWNER)] = { OwnerUserId = OWNER, AccessCode = "c", PrivateServerId = "psX" }
		local ok, code = directory(get):ensureAccessCode(OWNER)
		expect.truthy(ok)
		expect.equal(code, "c")
		expect.equal(get(DataKeys.WORLD_INDEX).data[DataKeys.indexKey("psX")], OWNER)
	end)

	-- Failures are reported, never turned into a fake code.
	t.test("failures are reported", function()
		local get = fakeStores()
		get(DataKeys.WORLD_META).failAll = true
		local ok, code = directory(get):ensureAccessCode(OWNER)
		expect.falsy(ok)
		expect.equal(code, nil)
		local get2 = fakeStores()
		local ok2 = directory(get2, { noPlace = true }):ensureAccessCode(OWNER)
		expect.falsy(ok2)
		local ok3 = directory(fakeStores()):ensureAccessCode(-3)
		expect.falsy(ok3)
	end)

	-- GetDataStore itself throwing (unpublished place) is a reported failure, not a crash.
	t.test("store access errors are reported, not thrown", function()
		local dir = WorldDirectory.new({
			getStore = function()
				error("You must publish this place to the web to access DataStore.")
			end,
			reserve = function()
				return "c", "ps"
			end,
			worldPlaceId = function()
				return 999
			end,
			wait = function() end,
			log = function() end,
			now = function()
				return 1
			end,
		})
		local ok1 = dir:peek(OWNER)
		local ok2, code = dir:ensureAccessCode(OWNER)
		expect.falsy(ok1)
		expect.falsy(ok2)
		expect.equal(code, nil)
	end)

	-- Places.pick finds the World place by name and the Hub as the other place.
	t.test("Places.pick identifies hub and world", function()
		local hub, world = Places.pick({ { Name = "MMORPG Tycoon", PlaceId = 1 }, { Name = "World", PlaceId = 2 } }, 1)
		expect.equal(hub, 1)
		expect.equal(world, 2)
		local hub2, world2 = Places.pick({ { Name = "MMORPG TYCOON WORLD", PlaceId = 7 } }, 3)
		expect.equal(world2, 7)
		expect.equal(hub2, 3)
	end)
end
