--!nonstrict
-- Tests for ServerScriptService.Server.Services.WorldLoader (Phase 2 tests A-F end to end
-- through WorldStore + WorldSchema, with a fake DataStore).
return function(t)
	local HttpService = game:GetService("HttpService")
	local Services = game:GetService("ServerScriptService").Server.Services
	local WorldLoader = require(Services.WorldLoader)
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

	local function fakeStore()
		local fake = { data = {}, failAll = false }
		function fake:UpdateAsync(key, transform)
			if self.failAll then
				error("fake outage")
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

	local function session(fake, id)
		return WorldStore.new({
			store = fake,
			sessionId = id,
			now = function()
				return 5000
			end,
			wait = function() end,
			log = function() end,
			maxAttempts = 2,
		})
	end

	local NO_WAIT = { lockWaitSeconds = 10, lockPollSeconds = 5, wait = function() end }

	-- Test A: a player with no save gets a default world they own.
	t.test("A: new world is created and owned by the right player", function()
		local outcome = WorldLoader.load(session(fakeStore(), "S1"), A, NO_WAIT)
		expect.equal(outcome.state, "ready")
		expect.truthy(outcome.isNew)
		expect.truthy(outcome.lockHeld)
		expect.equal(outcome.world.ownerUserId, A)
		expect.equal(#outcome.world.objects, 0)
	end)

	-- Test B + E: save in one session, load in a brand-new session, everything comes back.
	t.test("B/E: saved world reloads identically in a new session", function()
		local fake = fakeStore()
		local s1 = session(fake, "S1")
		local first = WorldLoader.load(s1, A, NO_WAIT)
		local world = first.world
		world.name = "Persisted"
		world.visibility = "Private"
		world.objects = {
			{ id = "p1", type = "oak_tree", x = 10, z = 10, rot = 0 },
			{ id = "p2", type = "cottage", x = 30, z = 30, rot = 3 },
		}
		world.nextId = 3
		expect.equal(s1:save(A, WorldSchema.encode(world), true).status, "saved")

		local second = WorldLoader.load(session(fake, "S2"), A, NO_WAIT)
		expect.equal(second.state, "ready")
		expect.falsy(second.isNew)
		expect.equal(second.world.name, "Persisted")
		expect.equal(second.world.visibility, "Private")
		expect.equal(#second.world.objects, 2)
		expect.deepEqual(second.world.objects[2], { id = "p2", type = "cottage", x = 30, z = 30, rot = 3 })
		expect.equal(second.world.nextId, 3)
	end)

	-- Test C: invalid entries are rejected, valid ones kept, nothing unknown is built.
	t.test("C: invalid saved objects are dropped, valid ones kept", function()
		local fake = fakeStore()
		local w = WorldSchema.newWorld(A, 1)
		local rec = WorldSchema.encode(w)
		rec.Objects = {
			{ Id = "p1", Type = "boulder", X = 4, Z = 4, Rot = 0 },
			{ Id = "p2", Type = "rbxassetid://123", X = 5, Z = 5, Rot = 0 },
			{ Id = "p3", Type = "boulder", X = "five", Z = 5, Rot = 0 },
		}
		fake.data["world_111"] = rec
		local outcome = WorldLoader.load(session(fake, "S1"), A, NO_WAIT)
		expect.equal(outcome.state, "ready")
		expect.equal(#outcome.world.objects, 1)
		expect.equal(#outcome.report.dropped, 2)
	end)

	-- Test D: a DataStore outage fails the load and leaves the save untouched.
	t.test("D: failed load is not treated as a new world", function()
		local fake = fakeStore()
		local w = WorldSchema.newWorld(A, 1)
		w.objects = { { id = "p1", type = "boulder", x = 1, z = 1, rot = 0 } }
		fake.data["world_111"] = WorldSchema.encode(w)
		local before = HttpService:JSONEncode(fake.data["world_111"])
		fake.failAll = true
		local outcome = WorldLoader.load(session(fake, "S1"), A, NO_WAIT)
		expect.equal(outcome.state, "failed")
		expect.equal(outcome.reason, "load_error")
		expect.falsy(outcome.isNew)
		expect.equal(outcome.world, nil)
		fake.failAll = false
		expect.equal(HttpService:JSONEncode(fake.data["world_111"]), before)
	end)

	-- Test F: two owners each get their own world; neither sees the other's objects.
	t.test("F: two owners stay isolated", function()
		local fake = fakeStore()
		local sa = session(fake, "SA")
		local oa = WorldLoader.load(sa, A, NO_WAIT)
		oa.world.objects = { { id = "p1", type = "oak_tree", x = 2, z = 2, rot = 0 } }
		sa:save(A, WorldSchema.encode(oa.world), true)
		local ob = WorldLoader.load(session(fake, "SB"), B, NO_WAIT)
		expect.equal(ob.world.ownerUserId, B)
		expect.equal(#ob.world.objects, 0)
		local again = WorldLoader.load(session(fake, "SA2"), A, NO_WAIT)
		expect.equal(#again.world.objects, 1)
	end)

	-- A second live session for the same world gets a view-only copy, never write access.
	t.test("second live session is read-only", function()
		local fake = fakeStore()
		WorldLoader.load(session(fake, "S1"), A, NO_WAIT)
		local other = WorldLoader.load(session(fake, "S2"), A, NO_WAIT)
		expect.equal(other.state, "readonly")
		expect.falsy(other.lockHeld)
		expect.equal(fake.data["world_111"].Session.Id, "S1")
	end)

	-- A record belonging to someone else is never loaded or modified.
	t.test("wrong-owner record fails and is untouched", function()
		local fake = fakeStore()
		fake.data["world_111"] = WorldSchema.encode(WorldSchema.newWorld(B, 1))
		local before = HttpService:JSONEncode(fake.data["world_111"])
		local outcome = WorldLoader.load(session(fake, "S1"), A, NO_WAIT)
		expect.equal(outcome.state, "failed")
		expect.equal(outcome.reason, "owner_mismatch")
		expect.equal(HttpService:JSONEncode(fake.data["world_111"]), before)
	end)

	-- A corrupt record for the right owner fails and our temporary lock is released.
	t.test("corrupt record fails and the lock is released", function()
		local fake = fakeStore()
		fake.data["world_111"] = { OwnerUserId = A, Objects = "garbage" }
		local outcome = WorldLoader.load(session(fake, "S1"), A, NO_WAIT)
		expect.equal(outcome.state, "failed")
		expect.equal(outcome.reason, "missing_version")
		expect.equal(fake.data["world_111"].Session, nil)
		expect.equal(fake.data["world_111"].Objects, "garbage")
	end)

	-- Invalid owner ids are refused outright.
	t.test("invalid owner is refused", function()
		local outcome = WorldLoader.load(session(fakeStore(), "S1"), 0, NO_WAIT)
		expect.equal(outcome.state, "failed")
		expect.equal(outcome.reason, "invalid_owner")
	end)
end
