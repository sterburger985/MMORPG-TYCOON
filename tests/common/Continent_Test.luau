--!nonstrict
-- Tests for ReplicatedStorage.Shared.RegionConfig and Continent (pure, no terrain).
-- Contract: ten regions with the agreed ids and level ranges; organic, non-rectangular
-- shapes; declared neighbours match the real map; the build plot stays a flat dry
-- Greenhaven meadow; roads are walkable and lead through the regions in order;
-- everything is deterministic.
return function(t)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local RegionConfig = require(Shared.RegionConfig)
	local Continent = require(Shared.Continent)
	local expect = t.expect

	local EXPECTED = {
		{ "Greenhaven", "Greenhaven Grasslands", 1, 10 },
		{ "Whisperwood", "Whisperwood Forest", 11, 20 },
		{ "SunscarDesert", "Sunscar Desert", 21, 30 },
		{ "Mirehollow", "Mirehollow Swamps", 31, 40 },
		{ "Frostpeak", "Frostpeak Mountains", 41, 50 },
		{ "Verdantwild", "Verdantwild Jungle", 51, 60 },
		{ "GlacialExpanse", "Glacial Expanse", 61, 70 },
		{ "Ashenreach", "Ashenreach", 71, 80 },
		{ "StarfallHighlands", "Starfall Highlands", 81, 90 },
		{ "DragonsEnd", "Dragon's End", 91, 100 },
	}

	t.test("ten regions with the agreed ids, names and level ranges", function()
		local regions = RegionConfig.all()
		expect.equal(#regions, 10)
		for i, e in EXPECTED do
			local r = regions[i]
			expect.equal(r.id, e[1])
			expect.equal(r.name, e[2])
			expect.equal(r.minLevel, e[3])
			expect.equal(r.maxLevel, e[4])
			expect.equal(RegionConfig.get(e[1]), r)
		end
	end)

	t.test("every region has landmarks, sites, vegetation and valid neighbours", function()
		for _, r in RegionConfig.all() do
			expect.truthy(#r.landmarks >= 1)
			expect.truthy(#r.sites >= 2)
			expect.truthy(#r.vegetation >= 1)
			for _, n in r.neighbors do
				local other = RegionConfig.get(n)
				expect.truthy(other ~= nil)
				expect.truthy(table.find(other.neighbors, r.id) ~= nil) -- symmetric
				expect.truthy(r.transitions[n] ~= nil) -- every border has a designed transition
			end
		end
	end)

	-- Sample the land on a grid once for the map-level tests.
	local b = RegionConfig.BOUNDS
	local STEP = 32
	local grid = {}
	local function sample()
		if #grid > 0 then
			return grid
		end
		for x = b.minX, b.maxX, STEP do
			local col = {}
			for z = b.minZ, b.maxZ, STEP do
				local c = Continent.column(x, z)
				table.insert(col, if c.land > 0.99 then RegionConfig.regions[c.region].id else false)
			end
			table.insert(grid, col)
		end
		return grid
	end

	t.test("declared neighbours match the real map", function()
		local g = sample()
		local actual = {}
		local function link(a, c)
			if a and c and a ~= c then
				actual[a .. ">" .. c] = true
				actual[c .. ">" .. a] = true
			end
		end
		for i = 1, #g - 1 do
			for k = 1, #g[i] - 1 do
				link(g[i][k], g[i + 1][k])
				link(g[i][k], g[i][k + 1])
			end
		end
		for _, r in RegionConfig.all() do
			for _, n in r.neighbors do
				if not actual[r.id .. ">" .. n] then
					error(r.id .. " declares neighbour " .. n .. " but they don't touch")
				end
			end
		end
		for key in actual do
			local a, c = string.match(key, "(.+)>(.+)")
			if not table.find((RegionConfig.get(a) :: any).neighbors, c) then
				error(a .. " touches " .. c .. " but doesn't declare it")
			end
		end
	end)

	t.test("regions are organic, not rectangles", function()
		local g = sample()
		for _, r in RegionConfig.all() do
			local minI, maxI, minK, maxK, n = math.huge, -1, math.huge, -1, 0
			for i, col in g do
				for k, id in col do
					if id == r.id then
						n += 1
						minI, maxI = math.min(minI, i), math.max(maxI, i)
						minK, maxK = math.min(minK, k), math.max(maxK, k)
					end
				end
			end
			expect.truthy(n > 40) -- big enough to matter
			local fill = n / ((maxI - minI + 1) * (maxK - minK + 1))
			if fill > 0.85 then
				error(("%s fills %.0f%% of its bounding box (too rectangular)"):format(r.id, fill * 100))
			end
		end
	end)

	t.test("the map is deterministic", function()
		for _, p in { { 0, 0 }, { -700, 230 }, { 440, -600 }, { -560, -1640 } } do
			local a, c = Continent.column(p[1], p[2]), Continent.column(p[1], p[2])
			expect.equal(a.h, c.h)
			expect.equal(a.region, c.region)
		end
	end)

	t.test("the build plot is a flat, dry Greenhaven meadow", function()
		for x = -128, 128, 32 do
			for z = -128, 145, 32 do
				local c = Continent.column(x, z)
				expect.near(c.h, 1.4, 0.15)
				expect.truthy(c.water < c.h)
				expect.equal(RegionConfig.regions[c.region].id, "Greenhaven")
			end
		end
	end)

	t.test("landmarks and sites sit inside their own region", function()
		for _, r in RegionConfig.all() do
			for _, l in r.landmarks do
				local id = Continent.regionIdAt(l.x, l.z)
				if id ~= r.id then
					error(("landmark %s is in %s, not %s"):format(l.id, id, r.id))
				end
			end
			for _, s in r.sites do
				local id = Continent.regionIdAt(s.x, s.z)
				if id ~= r.id then
					error(("site %s is in %s, not %s"):format(s.id, id, r.id))
				end
			end
		end
	end)

	t.test("content sites are flat and dry", function()
		for _, s in Continent.sites do
			local c0 = Continent.column(s.x, s.z)
			expect.truthy(c0.water < c0.h)
			for _, o in { { 0.5, 0 }, { -0.5, 0 }, { 0, 0.5 }, { 0, -0.5 } } do
				local c = Continent.column(s.x + o[1] * s.radius, s.z + o[2] * s.radius)
				if math.abs(c.h - c0.h) > 4 and not c.lake and c.river > c.riverWidth then
					error(("site %s is not flat (%.1f vs %.1f)"):format(s.def.id, c.h, c0.h))
				end
			end
		end
	end)

	t.test("roads are walkable (grade, no deep water)", function()
		for _, road in Continent.roads do
			local prev = nil
			for i = 1, #road.pts, 2 do
				local p = road.pts[i]
				local c = Continent.column(p[1], p[2])
				local onRiver = c.river < c.riverWidth + 2 and not c.riverDry
				if not onRiver then
					if c.water > c.h + 1.2 then
						error(("%s point %d is under %.1f studs of water"):format(road.id, i, c.water - c.h))
					end
					if prev and math.abs(c.h - prev) > 16 * 0.55 then
						error(("%s too steep at point %d (%.1f over 16 studs)"):format(road.id, i, math.abs(c.h - prev)))
					end
					prev = c.h
				else
					prev = nil -- bridges span rivers
				end
			end
		end
	end)

	t.test("the main roads lead through all ten regions in order", function()
		local order = {}
		for _, id in { "PilgrimRoad", "Highpass", "AshenTrail" } do
			for _, road in Continent.roads do
				if road.id == id then
					for _, p in road.pts do
						local rid = Continent.regionIdAt(p[1], p[2])
						if order[#order] ~= rid then
							table.insert(order, rid)
						end
					end
				end
			end
		end
		local nextIndex = 1
		for _, rid in order do
			if rid == EXPECTED[nextIndex][1] then
				nextIndex += 1
				if nextIndex > #EXPECTED then
					break
				end
			end
		end
		if nextIndex <= #EXPECTED then
			error("roads never reach " .. EXPECTED[nextIndex][1] .. " in order; visited " .. table.concat(order, ","))
		end
	end)

	t.test("region queries report level ranges and transitions", function()
		local info = Continent.regionAt(0, 0)
		expect.equal(info.id, "Greenhaven")
		expect.equal(info.minLevel, 1)
		expect.equal(info.maxLevel, 10)
		expect.equal(info.site and info.site.id, "StartingMeadow")
		local sawTransition = false
		for x = -900, 900, 60 do
			if Continent.regionAt(x, 100).transition then
				sawTransition = true
			end
		end
		expect.truthy(sawTransition)
	end)

	t.test("scenery budget stays bounded", function()
		local plan = Continent.planScenery()
		expect.truthy(#plan > 500)
		expect.truthy(#plan < 2500)
		for _, item in plan do
			if math.abs(item.x) < 150 and math.abs(item.z) < 160 then
				error("scenery placed on the build plot")
			end
		end
	end)
end
