--!nonstrict
-- Tests for ServerScriptService.Server.Services.WorldStore with a fake DataStore.
-- Contract: one key per owner; load never treats an error as "no save"; the session lock
-- stops a second session writing; saves are atomic and refuse oversized/unencodable data.
return function(t)
	local HttpService = game:GetService("HttpService")
	local Services = game:GetService("ServerScriptService").Server.Services
	local WorldStore = require(Services.WorldStore)
	local WorldSchema = require(Services.WorldSchema)
	local expect = t.expect
	local A, B = 111, 222

	local function copy(v)
		if v == nil then
			return nil
		end
		return HttpService:JSONDecode(HttpService:JSONEncode(v))
	end

	-- Fake DataStore: JSON round-trips like the real one; can fail on demand.
	local function fakeStore()
		local fake = { data = {}, calls = 0, failNext = 0, failAll = false }
		function fake:UpdateAsync(key, transform)
			self.calls += 1
			if self.failAll or self.failNext > 0 then
				self.failNext = math.max(0, self.failNext - 1)
				error("fake DataStore failure")
			end
			local new = transform(copy(self.data[key]), nil)
			if new == nil then
				return nil
			end
			self.data[key] = copy(new)
			return copy(new)
		end
		return fake
	end

	local clockValue = 1000
	local function newStore(fake, session, extra)
		local opts = {
			store = fake,
			sessionId = session,
			now = function()
				return clockValue
			end,
			wait = function() end,
			log = function() end,
		}
		for k, v in extra or {} do
			opts[k] = v
		end
		return WorldStore.new(opts)
	end

	local function savedRecord(owner, objects)
		local w = WorldSchema.newWorld(owner, 1)
		w.objects = objects or {}
		w.nextId = #w.objects + 1
		return WorldSchema.encode(w)
	end

	-- Test A: no save -> a default world is created for exactly this owner, with our lock.
	t.test("load creates a new world for an owner with no save", function()
		local fake = fakeStore()
		local result = newStore(fake, "S1"):load(A)
		expect.equal(result.status, "new")
		expect.equal(result.raw.OwnerUserId, A)
		expect.equal(result.raw.Version, 1)
		expect.equal(fake.data["world_111"].Session.Id, "S1")
	end)

	-- Test B: an existing save is returned and locked.
	t.test("load returns an existing save", function()
		local fake = fakeStore()
		fake.data["world_111"] = savedRecord(A, { { id = "p1", type = "boulder", x = 1, z = 1, rot = 0 } })
		local result = newStore(fake, "S1"):load(A)
		expect.equal(result.status, "loaded")
		expect.equal(#result.raw.Objects, 1)
		expect.equal(fake.data["world_111"].Session.Id, "S1")
	end)

	-- Transient failures are retried.
	t.test("load retries transient errors", function()
		local fake = fakeStore()
		fake.data["world_111"] = savedRecord(A)
		fake.failNext = 2
		local result = newStore(fake, "S1"):load(A)
		expect.equal(result.status, "loaded")
		expect.equal(fake.calls, 3)
	end)

	-- Test D: a failed load is an error, never "new", and nothing is written.
	t.test("load failure is reported as error and writes nothing", function()
		local fake = fakeStore()
		fake.data["world_111"] = savedRecord(A, { { id = "p1", type = "boulder", x = 1, z = 1, rot = 0 } })
		local before = HttpService:JSONEncode(fake.data["world_111"])
		fake.failAll = true
		local result = newStore(fake, "S1", { maxAttempts = 3 }):load(A)
		expect.equal(result.status, "error")
		expect.equal(fake.calls, 3)
		expect.equal(HttpService:JSONEncode(fake.data["world_111"]), before)
	end)

	-- A fresh lock from another session blocks us and is left alone.
	t.test("load reports locked when another live session holds the world", function()
		local fake = fakeStore()
		local r = savedRecord(A)
		r.Session = { Id = "OTHER", Time = clockValue - 10 }
		fake.data["world_111"] = r
		local result = newStore(fake, "S1"):load(A)
		expect.equal(result.status, "locked")
		expect.equal(fake.data["world_111"].Session.Id, "OTHER")
	end)

	-- An abandoned (stale) lock can be taken over.
	t.test("load takes over a stale lock", function()
		local fake = fakeStore()
		local r = savedRecord(A)
		r.Session = { Id = "CRASHED", Time = clockValue - 10000 }
		fake.data["world_111"] = r
		local result = newStore(fake, "S1"):load(A)
		expect.equal(result.status, "loaded")
		expect.equal(fake.data["world_111"].Session.Id, "S1")
	end)

	-- A record under this key that belongs to someone else is never touched.
	t.test("load refuses a record with the wrong owner", function()
		local fake = fakeStore()
		fake.data["world_111"] = savedRecord(B)
		local result = newStore(fake, "S1"):load(A)
		expect.equal(result.status, "unsafe")
		expect.equal(fake.data["world_111"].Session, nil)
	end)

	-- A record written by newer code is never touched.
	t.test("load refuses a future-version record", function()
		local fake = fakeStore()
		local r = savedRecord(A)
		r.Version = 99
		fake.data["world_111"] = r
		expect.equal(newStore(fake, "S1"):load(A).status, "unsafe")
		expect.equal(fake.data["world_111"].Session, nil)
	end)

	-- Invalid owner ids never reach the DataStore.
	t.test("load rejects invalid owner ids", function()
		local fake = fakeStore()
		expect.equal(newStore(fake, "S1"):load(-1).status, "error")
		expect.equal(fake.calls, 0)
	end)

	-- Saving refreshes the lock and counts saves; releasing clears the lock.
	t.test("save writes, counts and releases", function()
		local fake = fakeStore()
		local store = newStore(fake, "S1")
		store:load(A)
		local rec = savedRecord(A, { { id = "p1", type = "boulder", x = 2, z = 2, rot = 1 } })
		expect.equal(store:save(A, rec, false).status, "saved")
		expect.equal(fake.data["world_111"].SaveCount, 1)
		expect.equal(fake.data["world_111"].Session.Id, "S1")
		expect.equal(#fake.data["world_111"].Objects, 1)
		expect.equal(store:save(A, rec, true).status, "saved")
		expect.equal(fake.data["world_111"].SaveCount, 2)
		expect.equal(fake.data["world_111"].Session, nil)
	end)

	-- If another session took the world, our save is refused and their data is kept.
	t.test("save refuses when the lock was lost", function()
		local fake = fakeStore()
		local store = newStore(fake, "S1")
		store:load(A)
		fake.data["world_111"].Session = { Id = "S2", Time = clockValue }
		fake.data["world_111"].WorldName = "Theirs"
		local result = store:save(A, savedRecord(A), false)
		expect.equal(result.status, "lock_lost")
		expect.equal(fake.data["world_111"].WorldName, "Theirs")
	end)

	-- A deleted record is not recreated by a save.
	t.test("save refuses when the record is missing", function()
		local fake = fakeStore()
		local store = newStore(fake, "S1")
		expect.equal(store:save(A, savedRecord(A), false).status, "missing")
		expect.equal(fake.data["world_111"], nil)
	end)

	-- Oversized records are refused before any DataStore call.
	t.test("save refuses oversized records", function()
		local fake = fakeStore()
		local store = newStore(fake, "S1", { maxBytes = 50 })
		local result = store:save(A, savedRecord(A), false)
		expect.equal(result.status, "too_large")
		expect.equal(fake.calls, 0)
	end)

	-- Records that can't be serialized are refused before any DataStore call.
	t.test("save refuses records that fail to encode", function()
		local fake = fakeStore()
		local store = newStore(fake, "S1", {
			encode = function()
				error("cannot encode")
			end,
		})
		expect.equal(store:save(A, savedRecord(A), false).status, "encode_error")
		expect.equal(fake.calls, 0)
	end)

	-- A save request whose record names a different owner is refused.
	t.test("save refuses an owner mismatch", function()
		local fake = fakeStore()
		local store = newStore(fake, "S1")
		store:load(A)
		expect.equal(store:save(A, savedRecord(B), false).status, "error")
	end)

	-- Test F: two owners live under separate keys; saving one leaves the other untouched.
	t.test("owners are isolated", function()
		local fake = fakeStore()
		local storeA, storeB = newStore(fake, "SA"), newStore(fake, "SB")
		storeA:load(A)
		storeB:load(B)
		storeA:save(A, savedRecord(A, { { id = "p1", type = "boulder", x = 1, z = 1, rot = 0 } }), false)
		expect.equal(#fake.data["world_111"].Objects, 1)
		expect.equal(#fake.data["world_222"].Objects, 0)
		expect.equal(fake.data["world_222"].OwnerUserId, B)
	end)

	-- releaseLock only removes our lock and changes nothing else.
	t.test("releaseLock leaves data untouched", function()
		local fake = fakeStore()
		local store = newStore(fake, "S1")
		store:load(A)
		fake.data["world_111"].WorldName = "Keep Me"
		expect.truthy(store:releaseLock(A))
		expect.equal(fake.data["world_111"].Session, nil)
		expect.equal(fake.data["world_111"].WorldName, "Keep Me")
	end)
end
