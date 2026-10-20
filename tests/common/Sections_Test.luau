--!nonstrict
-- Tests for ReplicatedStorage.Shared.Sections (buildable sections and their borders).
-- Contract: the continent itself is unchanged; every region holds several irregular
-- sections of different sizes; the build plot sits deep inside one section; borders
-- avoid the plot, landmarks and water and stay low; every pair of neighbouring
-- sections is connected (road gateway, trail entrance or open pass); the prop budget
-- stays bounded; everything is deterministic.
return function(t)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local RegionConfig = require(Shared.RegionConfig)
	local Continent = require(Shared.Continent)
	local Sections = require(Shared.Sections)
	local expect = t.expect

	t.test("the continent's terrain is unchanged (fingerprint)", function()
		local sum = 0
		for i = -10, 10 do
			for k = -10, 10 do
				sum += Continent.height(i * 131.7, -600 + k * 117.3)
			end
		end
		expect.near(math.floor(sum * 1000 + 0.5) / 1000, 13736.985, 0.01)
	end)

	t.test("every region has several named sections with stable ids", function()
		local seen = {}
		for _, r in RegionConfig.all() do
			local list = Sections.ofRegion(r.id)
			if #list < 4 then
				error(r.id .. " has only " .. #list .. " sections")
			end
			for _, s in list do
				expect.truthy(not seen[s.id])
				seen[s.id] = true
				expect.truthy(#s.name > 0)
				expect.equal(Sections.get(s.id), s)
			end
		end
		expect.truthy(#Sections.all() >= 45)
	end)

	t.test("each seed lies on land inside its own region and section", function()
		for _, s in Sections.all() do
			local c = Continent.column(s.x, s.z)
			if c.land < 0.99 then
				error(s.id .. " seed is in the sea")
			end
			if Continent.regionIdAt(s.x, s.z) ~= s.region then
				error(("%s seed lies in %s"):format(s.id, Continent.regionIdAt(s.x, s.z)))
			end
			local at = Sections.at(s.x, s.z)
			if at ~= s then
				error(("%s seed falls in %s"):format(s.id, at and at.id or "nothing"))
			end
		end
	end)

	t.test("the build plot sits deep inside the Starting Meadow", function()
		for x = -168, 168, 24 do
			for z = -168, 168, 24 do
				local s = Sections.at(x, z)
				expect.equal(s and s.id, "GH_StartingMeadow")
			end
		end
	end)

	local plan = Sections.plan()
	local R = plan.raster

	-- Land cells per section on a 16-stud lattice (from the 4-stud raster).
	local stats = nil
	local function sectionStats()
		if stats then
			return stats
		end
		stats = {}
		for k = 0, R.H - 1, 4 do
			for i = 0, R.W - 1, 4 do
				local id = R.ids[k * R.W + i + 1]
				if id > 0 then
					local x, z = R.minX + i * R.G, R.minZ + k * R.G
					if Continent.column(x, z).land > 0.99 then
						local st = stats[id]
						if not st then
							st = { n = 0, minI = math.huge, maxI = -1, minK = math.huge, maxK = -1 }
							stats[id] = st
						end
						st.n += 1
						st.minI, st.maxI = math.min(st.minI, i), math.max(st.maxI, i)
						st.minK, st.maxK = math.min(st.minK, k), math.max(st.maxK, k)
					end
				end
			end
		end
		return stats
	end

	t.test("sections are irregular, roomy and of different sizes", function()
		local st = sectionStats()
		local smallest, largest = math.huge, 0
		for _, s in Sections.all() do
			local a = st[s.index]
			if not a or a.n < 40 then
				error(("%s is too small (%d samples of 16x16 studs)"):format(s.id, a and a.n or 0))
			end
			local box = ((a.maxI - a.minI) / 4 + 1) * ((a.maxK - a.minK) / 4 + 1)
			local fill = a.n / box
			if fill > 0.85 then
				error(("%s fills %.0f%% of its bounding box (too square)"):format(s.id, fill * 100))
			end
			smallest, largest = math.min(smallest, a.n), math.max(largest, a.n)
		end
		expect.truthy(largest / smallest > 2.5) -- some big open areas, some small clearings
	end)

	t.test("each section is one connected piece of land (no stray fragments)", function()
		-- flood fill on a 16-stud lattice of land cells
		local step = 4
		local W, H = math.floor((R.W - 1) / step) + 1, math.floor((R.H - 1) / step) + 1
		local grid = table.create(W * H, 0)
		for k = 0, H - 1 do
			for i = 0, W - 1 do
				local id = R.ids[(k * step) * R.W + i * step + 1]
				local x, z = R.minX + i * step * R.G, R.minZ + k * step * R.G
				if id > 0 and Continent.column(x, z).land > 0.99 then
					grid[k * W + i + 1] = id
				end
			end
		end
		local seen = table.create(W * H, false)
		local biggest, total = {}, {}
		for start = 1, W * H do
			local id = grid[start]
			if id > 0 and not seen[start] then
				local stack, size = { start }, 0
				seen[start] = true
				while #stack > 0 do
					local c = table.remove(stack)
					size += 1
					local ci, ck = (c - 1) % W, (c - 1) // W
					for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
						local ni, nk = ci + d[1], ck + d[2]
						if ni >= 0 and ni < W and nk >= 0 and nk < H then
							local n = nk * W + ni + 1
							if not seen[n] and grid[n] == id then
								seen[n] = true
								table.insert(stack, n)
							end
						end
					end
				end
				biggest[id] = math.max(biggest[id] or 0, size)
				total[id] = (total[id] or 0) + size
			end
		end
		for _, s in Sections.all() do
			local share = (biggest[s.index] or 0) / math.max(total[s.index] or 1, 1)
			if share < 0.9 then
				error(("%s is split: its largest piece is only %.0f%%"):format(s.id, share * 100))
			end
		end
	end)

	t.test("borders keep off the plot, landmarks and water, and stay low", function()
		local styles = RegionConfig.BORDER_STYLES
		for id, st in styles do
			expect.truthy(RegionConfig.get(id) ~= nil)
			expect.truthy(st.height[2] <= 9) -- never a prison wall
		end
		local ridge = 0
		for _, p in plan.points do
			if p.kind == "ridge" then
				ridge += 1
				if p.x * p.x + p.z * p.z < Sections.PLOT_KEEP ^ 2 then
					error("embankment on the plot meadow")
				end
				for _, l in Continent.landmarks do
					if (p.x - l.x) ^ 2 + (p.z - l.z) ^ 2 < l.clear ^ 2 then
						error("embankment through landmark " .. l.id)
					end
				end
				local c = Continent.column(p.x, p.z)
				expect.truthy(c.water < c.h)
				expect.truthy(c.road >= Sections.ROAD_GAP)
				expect.truthy(p.height <= styles[p.style].height[2] + 1e-6)
			end
		end
		expect.truthy(ridge > 1500)
	end)

	t.test("every pair of neighbouring sections is connected", function()
		local roads, trails = 0, 0
		for _, pk in plan.pairOrder do
			local cn = plan.connections[pk]
			if cn then
				local ok = cn.via == "road" or cn.via == "trail" or cn.via == "pass" or cn.via == "open"
				if not ok then
					error(("%s and %s are not connected (%s)"):format(Sections.all()[cn.a].id, Sections.all()[cn.b].id, tostring(cn.via)))
				end
				if cn.via == "road" then
					roads += 1
				elseif cn.via == "trail" then
					trails += 1
				end
			end
		end
		expect.truthy(roads > 10)
		expect.truthy(trails > 30)
		-- entrances are real gaps in the embankment
		for _, tr in plan.trails do
			for _, p in plan.points do
				if p.kind == "ridge" and (p.x - tr.x) ^ 2 + (p.z - tr.z) ^ 2 < (Sections.TRAIL_GAP - 1) ^ 2 then
					error("trail entrance still blocked by an embankment")
				end
			end
		end
	end)

	t.test("border props stay within budget and vary by region", function()
		expect.truthy(#plan.decor < 3000) -- items; the real budget is parts (below)
		local parts = 0
		local kindsByStyle = {}
		for _, d in plan.decor do
			parts += Sections.PART_ESTIMATE[d.kind] or 4
			kindsByStyle[d.style] = kindsByStyle[d.style] or {}
			kindsByStyle[d.style][d.kind] = true
			expect.truthy(math.abs(d.x) > 150 or math.abs(d.z) > 150) -- nothing on the plot
		end
		parts += (#plan.gates + #plan.trails) * 2 * 3
		if parts > 6500 then
			error("estimated border parts " .. parts)
		end
		local styleCount = 0
		for _ in kindsByStyle do
			styleCount += 1
		end
		expect.equal(styleCount, 10)
	end)

	t.test("section queries are deterministic", function()
		for _, p in { { 0, 0 }, { -700, 230 }, { 440, -600 }, { -560, -1640 }, { 900, -1100 } } do
			expect.equal(Sections.indexAt(p[1], p[2]), Sections.indexAt(p[1], p[2]))
		end
	end)
end
