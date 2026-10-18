--!nonstrict
-- Tests for ServerScriptService.Server.Services.WorldSchema.
-- Contract: decode() never trusts saved data - wrong owner / newer version / corrupt
-- records are fatal; invalid objects are dropped into quarantine; valid ones survive.
return function(t)
	local Services = game:GetService("ServerScriptService").Server.Services
	local WorldSchema = require(Services.WorldSchema)
	local WorldConfig = require(Services.WorldConfig)
	local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
	local expect = t.expect
	local OWNER = 1586031803

	local function record(objects, extra)
		local r = {
			Version = 1,
			OwnerUserId = OWNER,
			WorldName = "Test Realm",
			Settings = { Visibility = "FriendsOnly" },
			Economy = { Cash = 1234 },
			Objects = objects or {},
			NextObjectId = 1,
			CreatedAt = 100,
		}
		for k, v in extra or {} do
			r[k] = v
		end
		return r
	end

	local function obj(id, typ, x, z, rot)
		return { Id = id, Type = typ, X = x, Z = z, Rot = rot }
	end

	-- A new world gets the defaults and the right owner.
	t.test("newWorld uses defaults and the owner id", function()
		local w = WorldSchema.newWorld(OWNER, 50)
		expect.equal(w.ownerUserId, OWNER)
		expect.equal(w.name, WorldConfig.DEFAULT_WORLD_NAME)
		expect.equal(w.visibility, "Public")
		expect.equal(w.cash, Config.START_CASH)
		expect.equal(#w.objects, 0)
		expect.equal(w.nextId, 1)
	end)

	-- newWorld refuses an invalid owner.
	t.test("newWorld rejects invalid owner ids", function()
		expect.throws(function()
			WorldSchema.newWorld(0, 0)
		end)
		expect.throws(function()
			WorldSchema.newWorld(1.5, 0)
		end)
	end)

	-- encode -> decode returns the same world.
	t.test("encode/decode round trip keeps everything", function()
		local w = WorldSchema.newWorld(OWNER, 77)
		w.name = "Round Trip"
		w.visibility = "Private"
		w.cash = 999
		w.objects = { { id = "p1", type = "oak_tree", x = 10, z = 10, rot = 0 }, { id = "p2", type = "cottage", x = 20, z = 20, rot = 1 } }
		w.nextId = 3
		local ok, back = WorldSchema.decode(WorldSchema.encode(w), OWNER)
		expect.truthy(ok)
		expect.equal(back.name, "Round Trip")
		expect.equal(back.visibility, "Private")
		expect.equal(back.cash, 999)
		expect.equal(back.nextId, 3)
		expect.equal(back.createdAt, 77)
		expect.equal(#back.objects, 2)
		expect.deepEqual(back.objects[2], { id = "p2", type = "cottage", x = 20, z = 20, rot = 1 })
	end)

	-- Records that must never be used are fatal.
	t.test("decode rejects unusable records", function()
		local noVersion = record()
		noVersion.Version = nil
		local cases = {
			{ "not a table", "not_a_table" },
			{ noVersion, "missing_version" },
			{ record(nil, { Version = 2 }), "future_version" },
			{ record(nil, { OwnerUserId = 42 }), "owner_mismatch" },
			{ record(nil, { OwnerUserId = tostring(OWNER) }), "owner_mismatch" },
		}
		for _, c in cases do
			local ok, w, report = WorldSchema.decode(c[1], OWNER)
			expect.falsy(ok)
			expect.equal(w, nil)
			expect.equal(report.fatal, c[2])
		end
	end)

	-- The expected owner itself must be valid.
	t.test("decode rejects an invalid expected owner", function()
		local ok, _, report = WorldSchema.decode(record(), -5)
		expect.falsy(ok)
		expect.equal(report.fatal, "invalid_expected_owner")
	end)

	-- Bad objects are dropped (and quarantined); good ones survive.
	t.test("decode drops invalid objects and keeps valid ones", function()
		local ok, w, report = WorldSchema.decode(
			record({
				obj("p1", "oak_tree", 10, 10, 0), -- valid
				obj("p2", "dragon_lair", 5, 5, 0), -- unknown type
				obj("x3", "boulder", 1, 1, 0), -- bad id
				obj("p1", "boulder", 30, 30, 0), -- duplicate id
				obj("p5", "boulder", 1.5, 1, 0), -- fractional cell
				obj("p6", "boulder", 0 / 0, 1, 0), -- NaN
				obj("p7", "boulder", 1, 1, 5), -- bad rotation
				obj("p8", "cottage", 62, 0, 0), -- off the plot
				obj("p9", "oak_tree", 11, 11, 0), -- overlaps p1
				"junk", -- not a table
				obj("p11", "stone_path", 10, 10, 0), -- valid: floor under the tree
			}),
			OWNER
		)
		expect.truthy(ok)
		expect.equal(#w.objects, 2)
		expect.equal(w.objects[1].id, "p1")
		expect.equal(w.objects[2].id, "p11")
		expect.equal(#report.dropped, 9)
		expect.equal(#w.quarantine, 9)
		local reasons = {}
		for _, d in report.dropped do
			reasons[d.reason] = (reasons[d.reason] or 0) + 1
		end
		expect.equal(reasons.unknown_type, 1)
		expect.equal(reasons.bad_id, 1)
		expect.equal(reasons.duplicate_id, 1)
		expect.equal(reasons.bad_transform, 3)
		expect.equal(reasons.outofbounds, 1)
		expect.equal(reasons.blocked, 1)
		expect.equal(reasons.not_a_table, 1)
	end)

	-- Broken settings are repaired instead of failing the whole world.
	t.test("decode repairs invalid name, visibility and cash", function()
		local ok, w, report = WorldSchema.decode(
			record(nil, { WorldName = string.rep("x", 200), Settings = { Visibility = "Everyone" }, Economy = { Cash = -5 } }),
			OWNER
		)
		expect.truthy(ok)
		expect.equal(w.name, WorldConfig.DEFAULT_WORLD_NAME)
		expect.equal(w.visibility, "Public")
		expect.equal(w.cash, Config.START_CASH)
		expect.equal(#report.fixes, 3)
	end)

	-- Ids keep counting up even if NextObjectId was lost or too low.
	t.test("decode keeps nextId above every existing id", function()
		local ok, w = WorldSchema.decode(record({ obj("p40", "boulder", 1, 1, 0) }, { NextObjectId = 2 }), OWNER)
		expect.truthy(ok)
		expect.equal(w.nextId, 41)
	end)

	-- Unknown top-level fields are not carried into the world.
	t.test("decode ignores unsupported fields", function()
		local ok, w = WorldSchema.decode(record(nil, { Script = "print('hi')", AssetId = 123 }), OWNER)
		expect.truthy(ok)
		local encoded = WorldSchema.encode(w)
		expect.equal(encoded.Script, nil)
		expect.equal(encoded.AssetId, nil)
	end)

	-- Quarantine never grows past its limit.
	t.test("quarantine is bounded", function()
		local objects = {}
		for i = 1, WorldConfig.MAX_QUARANTINE + 20 do
			table.insert(objects, obj("p" .. i, "nope", 0, 0, 0))
		end
		local ok, w = WorldSchema.decode(record(objects), OWNER)
		expect.truthy(ok)
		expect.equal(#w.quarantine, WorldConfig.MAX_QUARANTINE)
	end)

	-- More objects than the plot limit are dropped as LimitReached.
	t.test("decode enforces the object limit", function()
		local objects = {}
		local n = 0
		for z = 0, 63 do
			for x = 0, 63 do
				n += 1
				if n > Config.MAX_PLACED_PER_PLOT + 5 then
					break
				end
				table.insert(objects, obj("p" .. n, "stone_path", x, z, 0))
			end
		end
		local ok, w, report = WorldSchema.decode(record(objects), OWNER)
		expect.truthy(ok)
		expect.equal(#w.objects, Config.MAX_PLACED_PER_PLOT)
		expect.equal(#report.dropped, 5)
	end)

	-- Profile conversion is lossless both ways.
	t.test("toProfile/applyProfile round trip", function()
		local w = WorldSchema.newWorld(OWNER, 0)
		w.objects = { { id = "p1", type = "boulder", x = 3, z = 4, rot = 2 } }
		w.nextId = 2
		local profile = WorldSchema.toProfile(w)
		expect.deepEqual(profile.placed.p1, { i = "boulder", x = 3, z = 4, r = 2 })
		profile.placed.p2 = { i = "oak_tree", x = 8, z = 8, r = 0 }
		profile.nextId = 3
		profile.cash = 10
		WorldSchema.applyProfile(w, profile)
		expect.equal(#w.objects, 2)
		expect.equal(w.nextId, 3)
		expect.equal(w.cash, 10)
	end)
end
