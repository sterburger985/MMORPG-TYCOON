--!nonstrict
-- Sections: the buildable sections inside each region, and the plan for their borders.
--
-- * A region (biome) is split into named sections (RegionConfig.SECTIONS). A point
--   belongs to the section of its own region whose seed is nearest in a gently warped
--   space (minus the seed's weight), so borders wind instead of running straight.
-- * Section ids are stable; saved player data never refers to them (yet).
-- * plan() rasterises the sections on a 4-stud grid, finds the edges, and returns
--   everything WorldTools.BorderBuilder needs: ridge points (with tangent and style),
--   road gateways, trail entrances between neighbouring sections, and border props.
--   It is pure and deterministic; it creates no instances and never changes the
--   continent's terrain maths (Continent.luau is read, not modified).

local RegionConfig = require(script.Parent.RegionConfig)
local Continent = require(script.Parent.Continent)

local Sections = {}

local noise = math.noise
local sqrt, floor, abs, max, min = math.sqrt, math.floor, math.abs, math.max, math.min
local hash = Continent.hash

Sections.GRID = 4 -- raster step (studs)
Sections.ROAD_GAP = 16 -- ridge stays this far from road centres (the road is the entrance)
Sections.TRAIL_GAP = 13 -- half-width of a trail entrance gap
Sections.NATURAL_SLOPE = 0.7 -- steeper ground is already a border: no embankment
Sections.PLOT_KEEP = 230 -- no border within this radius of the plot centre
Sections.SIDE_SLOPE = 0.5 -- hillside steeper than this across the border: the slope is the edge
Sections.MIN_RUN = 4 -- shorter embankment runs (broken up by water, roads...) become props only

---------------------------------------------------------------------------------------
-- Section list
---------------------------------------------------------------------------------------
export type Section = {
	id: string,
	name: string,
	index: number,
	region: string,
	regionName: string,
	minLevel: number,
	maxLevel: number,
	x: number,
	z: number,
	weight: number,
}

local list: { Section } = {}
local byRegion: { [string]: { Section } } = {}
local byId: { [string]: Section } = {}
for _, r in RegionConfig.regions do
	local defs = RegionConfig.SECTIONS[r.id] or {}
	local group = {}
	for _, d in defs do
		local s: Section = {
			id = d.id,
			name = d.name,
			index = #list + 1,
			region = r.id,
			regionName = r.name,
			minLevel = r.minLevel,
			maxLevel = r.maxLevel,
			x = d.x,
			z = d.z,
			weight = d.weight or 0,
		}
		table.insert(list, s)
		table.insert(group, s)
		assert(byId[s.id] == nil, "duplicate section id " .. s.id)
		byId[s.id] = s
	end
	byRegion[r.id] = group
end

function Sections.all(): { Section }
	return list
end

function Sections.get(id: string): Section?
	return byId[id]
end

function Sections.ofRegion(regionId: string): { Section }
	return byRegion[regionId] or {}
end

---------------------------------------------------------------------------------------
-- Point query
---------------------------------------------------------------------------------------
local function fbm(x: number, z: number, seed: number, freq: number, oct: number): number
	local sum, amp, f, norm = 0, 1, freq, 0
	for _ = 1, oct do
		sum += noise(x * f + seed * 17.13, z * f - seed * 9.71, seed * 0.613) * amp
		norm += amp
		amp *= 0.5
		f *= 2.03
	end
	return sum / norm * 1.6
end

local function warp(x: number, z: number): (number, number)
	return x + 46 * fbm(x, z, 401, 1 / 300, 3) + 16 * fbm(x, z, 409, 1 / 85, 2),
		z + 46 * fbm(x, z, 433, 1 / 300, 3) + 16 * fbm(x, z, 437, 1 / 85, 2)
end

-- Section index at a point (0 if the point's region has no sections).
function Sections.indexAt(x: number, z: number): number
	local seeds = byRegion[Continent.regionIdAt(x, z)]
	if not seeds or #seeds == 0 then
		return 0
	end
	local wx, wz = warp(x, z)
	local best, bd = 0, math.huge
	for _, s in seeds do
		local dx, dz = wx - s.x, wz - s.z
		local d = sqrt(dx * dx + dz * dz) - s.weight
		if d < bd then
			best, bd = s.index, d
		end
	end
	return best
end

function Sections.at(x: number, z: number): Section?
	return list[Sections.indexAt(x, z)]
end

---------------------------------------------------------------------------------------
-- Border plan
---------------------------------------------------------------------------------------
export type RidgePoint = {
	x: number,
	z: number,
	y: number,
	a: number, -- section indices on each side (a < b)
	b: number,
	tx: number, -- unit tangent along the border
	tz: number,
	kind: string, -- "ridge" (embankment) | "low" (props only) | "gap" | "natural" | "water" | "blocked" | "sea"
	style: string, -- region id whose border style applies
	height: number, -- embankment height (ridge only)
	radius: number,
	crest: boolean, -- the biome ground grows over this bit of crest
}

local function pairKey(a: number, b: number): number
	return min(a, b) * 1000 + max(a, b)
end
Sections.pairKey = pairKey

local function pickWeighted(items: { { kind: string, weight: number } }, roll: number): string
	local total = 0
	for _, v in items do
		total += v.weight
	end
	local acc = 0
	for _, v in items do
		acc += v.weight / total
		if roll <= acc then
			return v.kind
		end
	end
	return items[#items].kind
end

local function slopeAt(x: number, z: number, h: number): number
	local s = 4
	return max(abs(Continent.height(x + s, z) - h), abs(Continent.height(x, z + s) - h)) / s
end

local cached = nil

-- yieldEvery: optional function called every few raster rows (Studio passes task.wait).
function Sections.plan(yieldEvery: (() -> ())?)
	if cached then
		return cached
	end
	local G = Sections.GRID
	local B = RegionConfig.BOUNDS
	local minX, minZ = floor(B.minX / G) * G, floor(B.minZ / G) * G
	local W = floor((B.maxX - minX) / G) + 1
	local H = floor((B.maxZ - minZ) / G) + 1

	-- 1. Raster
	local ids = table.create(W * H, 0)
	for k = 0, H - 1 do
		local z = minZ + k * G
		for i = 0, W - 1 do
			ids[k * W + i + 1] = Sections.indexAt(minX + i * G, z)
		end
		if yieldEvery and k % 24 == 0 then
			yieldEvery()
		end
	end

	-- 2. Border cells grouped into 8-stud super-cells per section pair.
	local cells = {} -- key -> { sx, sz, n, a, b }
	local order = {}
	local function addCell(x: number, z: number, a: number, b: number)
		if a == 0 or b == 0 then
			return
		end
		local pk = pairKey(a, b)
		local key = floor(x / 8) * 100000 + floor(z / 8) + pk * 1e10
		local c = cells[key]
		if not c then
			c = { sx = 0, sz = 0, n = 0, a = min(a, b), b = max(a, b) }
			cells[key] = c
			table.insert(order, key)
		end
		c.sx += x
		c.sz += z
		c.n += 1
	end
	for k = 0, H - 2 do
		for i = 0, W - 2 do
			local a = ids[k * W + i + 1]
			local r = ids[k * W + i + 2]
			local d = ids[(k + 1) * W + i + 1]
			local x, z = minX + i * G, minZ + k * G
			if r ~= a then
				addCell(x + G / 2, z, a, r)
			end
			if d ~= a then
				addCell(x, z + G / 2, a, d)
			end
		end
	end

	-- 3. Points + spatial buckets (16 studs) for tangents.
	local points: { RidgePoint } = {}
	local buckets = {}
	for _, key in order do
		local c = cells[key]
		local p = { x = c.sx / c.n, z = c.sz / c.n, a = c.a, b = c.b } :: any
		table.insert(points, p)
		local bk = floor(p.x / 16) * 100000 + floor(p.z / 16)
		local bl = buckets[bk]
		if not bl then
			bl = {}
			buckets[bk] = bl
		end
		table.insert(bl, p)
	end
	local function neighbours(p, radius: number)
		local out = {}
		local r2 = radius * radius
		for bx = floor((p.x - radius) / 16), floor((p.x + radius) / 16) do
			for bz = floor((p.z - radius) / 16), floor((p.z + radius) / 16) do
				local bl = buckets[bx * 100000 + bz]
				if bl then
					for _, q in bl do
						if q.a == p.a and q.b == p.b and (q.x - p.x) ^ 2 + (q.z - p.z) ^ 2 <= r2 then
							table.insert(out, q)
						end
					end
				end
			end
		end
		return out
	end
	for _, p in points do
		local nb = neighbours(p, 14)
		local mx, mz = 0, 0
		for _, q in nb do
			mx += q.x
			mz += q.z
		end
		mx /= #nb
		mz /= #nb
		local sxx, szz, sxz = 0, 0, 0
		for _, q in nb do
			local dx, dz = q.x - mx, q.z - mz
			sxx += dx * dx
			szz += dz * dz
			sxz += dx * dz
		end
		local angle = 0.5 * math.atan2(2 * sxz, sxx - szz)
		p.tx, p.tz = math.cos(angle), math.sin(angle)
	end

	-- 4. Classify each point against the existing landscape.
	local signs = Continent.planSigns()
	local landmarks = Continent.landmarks
	local styles = RegionConfig.BORDER_STYLES
	for n, p in points do
		local c = Continent.column(p.x, p.z)
		p.y = c.h
		local region = RegionConfig.regions[c.region]
		p.style = if styles[region.id] then region.id else list[p.a].region
		local kind = "ridge"
		if c.land < 0.995 then
			kind = "sea" -- coastline and open sea: never walled
		elseif c.water > c.h - 0.5 or c.lake or (c.river < c.riverWidth + 6 and not c.riverDry) then
			kind = "water" -- rivers and ponds already divide the land
		elseif c.lava or c.crater then
			kind = "blocked"
		elseif c.road < Sections.ROAD_GAP then
			kind = "gap" -- the road itself is the entrance
		elseif p.x * p.x + p.z * p.z < Sections.PLOT_KEEP ^ 2 then
			kind = "blocked"
		else
			for _, l in landmarks do
				if (p.x - l.x) ^ 2 + (p.z - l.z) ^ 2 < (l.clear + 6) ^ 2 then
					kind = "blocked"
					break
				end
			end
			if kind == "ridge" then
				for _, s in signs do
					if (p.x - s.x) ^ 2 + (p.z - s.z) ^ 2 < 100 then
						kind = "gap"
						break
					end
				end
			end
			if kind == "ridge" and slopeAt(p.x, p.z, c.h) > Sections.NATURAL_SLOPE then
				kind = "natural" -- an existing slope or cliff already marks the edge
			end
			if kind == "ridge" then
				-- look across the border: a natural crest (both sides drop away) or a steep
				-- hillside already reads as an edge, so it gets no extra embankment
				local nx, nz = -p.tz, p.tx
				local hl = Continent.height(p.x + nx * 16, p.z + nz * 16)
				local hr = Continent.height(p.x - nx * 16, p.z - nz * 16)
				if (c.h - hl > 6 and c.h - hr > 6) or math.abs(hl - hr) / 32 > Sections.SIDE_SLOPE then
					kind = "natural"
				end
			end
		end
		p.kind = kind
		local st = styles[p.style]
		local hn = (noise(p.x / 37, p.z / 37, 5.1) + 0.5)
		hn = math.clamp(hn, 0, 1)
		p.height = st.height[1] + (st.height[2] - st.height[1]) * hn
		p.radius = st.radius[1] + (st.radius[2] - st.radius[1]) * hash(p.x, p.z, 21)
		p.crest = noise(p.x / 23, p.z / 23, 2.7) > st.crestAbove
		if yieldEvery and n % 400 == 0 then
			yieldEvery()
		end
	end

	-- 4b. Short, broken runs of embankment look like lumps, not borders: keep their props
	-- (edge stones, rocks) but build no terrain bank there ("low").
	local seen = {}
	for _, p in points do
		if p.kind == "ridge" and not seen[p] then
			local comp, stack = {}, { p }
			seen[p] = true
			while #stack > 0 do
				local q = table.remove(stack)
				table.insert(comp, q)
				for _, r in neighbours(q, 12) do
					if r.kind == "ridge" and not seen[r] then
						seen[r] = true
						table.insert(stack, r)
					end
				end
			end
			if #comp < Sections.MIN_RUN then
				for _, q in comp do
					q.kind = "low"
				end
			end
		end
	end

	-- 5. Road gateways: where a road passes from one section to another.
	local gates = {}
	local gatePairs = {}
	for _, road in Continent.roads do
		local prev = nil
		for i, pt in road.pts do
			local idx = Sections.indexAt(pt[1], pt[2])
			if prev and idx ~= prev and idx ~= 0 and prev ~= 0 then
				local q = road.pts[min(i + 1, #road.pts)]
				local o = road.pts[max(i - 1, 1)]
				local dx, dz = q[1] - o[1], q[2] - o[2]
				local len = sqrt(dx * dx + dz * dz)
				local tooClose = false
				for _, g in gates do
					if (g.x - pt[1]) ^ 2 + (g.z - pt[2]) ^ 2 < 40 * 40 then
						tooClose = true
						break
					end
				end
				gatePairs[pairKey(idx, prev)] = true
				if not tooClose then
					local c = Continent.column(pt[1], pt[2])
					table.insert(gates, {
						x = pt[1],
						z = pt[2],
						y = road.h[i],
						dx = dx / len,
						dz = dz / len,
						a = min(idx, prev),
						b = max(idx, prev),
						road = road.id,
						style = if styles[RegionConfig.regions[c.region].id] then RegionConfig.regions[c.region].id else list[idx].region,
						wet = c.water > c.h - 1,
					})
				end
			end
			prev = idx
		end
	end

	-- 6. Trail entrances for neighbouring sections that no road connects.
	local byPair = {}
	local pairOrder = {}
	for _, p in points do
		local pk = pairKey(p.a, p.b)
		local g = byPair[pk]
		if not g then
			g = { a = p.a, b = p.b, pts = {}, ridge = 0, natural = 0, water = 0, gap = 0, land = 0 }
			byPair[pk] = g
			table.insert(pairOrder, pk)
		end
		table.insert(g.pts, p)
		if p.kind == "ridge" then
			g.ridge += 1
		elseif p.kind == "natural" then
			g.natural += 1
		elseif p.kind == "water" then
			g.water += 1
		elseif p.kind == "gap" then
			g.gap += 1
		end
		if p.kind ~= "sea" then
			g.land += 1
		end
	end
	table.sort(pairOrder)
	local trails = {}
	local connections = {}
	for _, pk in pairOrder do
		local g = byPair[pk]
		if g.land == 0 then
			continue -- they only meet out at sea: not neighbours
		end
		local conn = { a = g.a, b = g.b, via = nil, ridge = g.ridge, natural = g.natural, water = g.water, length = #g.pts * 8 }
		connections[pk] = conn
		if gatePairs[pk] then
			conn.via = "road"
		end
		-- Centre of the shared border; the entrance goes at the flattest ridge point near it.
		local cx, cz = 0, 0
		for _, p in g.pts do
			cx += p.x
			cz += p.z
		end
		cx /= #g.pts
		cz /= #g.pts
		local wantTrail = conn.via == nil or (g.ridge >= 60) -- long borders get a second way through
		if wantTrail and g.ridge >= 1 then
			local best, bestScore = nil, math.huge
			for _, p in g.pts do
				if p.kind == "ridge" then
					local s = slopeAt(p.x, p.z, p.y)
					local d = sqrt((p.x - cx) ^ 2 + (p.z - cz) ^ 2)
					local nearGate = false
					for _, gt in gates do
						if (gt.x - p.x) ^ 2 + (gt.z - p.z) ^ 2 < 120 * 120 then
							nearGate = true
							break
						end
					end
					local score = d + s * 300 + (if nearGate then 1000 else 0)
					if score < bestScore then
						best, bestScore = p, score
					end
				end
			end
			if best and (conn.via == nil or bestScore < 1000) then
				-- open the gap through every embankment there (three sections can meet)
				local gapR2 = Sections.TRAIL_GAP ^ 2
				for _, p in points do
					if p.kind == "ridge" and (p.x - best.x) ^ 2 + (p.z - best.z) ^ 2 < gapR2 then
						p.kind = "gap"
					end
				end
				table.insert(trails, {
					x = best.x,
					z = best.z,
					y = best.y,
					tx = best.tx,
					tz = best.tz,
					a = g.a,
					b = g.b,
					style = best.style,
					walkway = best.style == "Mirehollow",
				})
				conn.via = conn.via or "trail"
			end
		end
		if conn.via == nil then
			for _, p in g.pts do
				if p.kind == "gap" then
					conn.via = "trail" -- a neighbouring entrance already opens this short edge
					break
				end
			end
		end
		if conn.via == nil then
			for _, p in g.pts do
				if p.kind == "low" then
					conn.via = "open" -- only stones and props mark this edge: walk straight through
					break
				end
			end
		end
		if conn.via == nil and g.gap > 0 and g.ridge == 0 then
			conn.via = "road" -- the whole shared edge is road corridor
		end
		if conn.via == nil and g.natural > 0 then
			conn.via = "pass" -- open slope: walkable around/over the natural edge
		end
		if conn.via == nil and g.ridge == 0 then
			conn.via = if g.water > 0 then "water" else "none"
		end
	end

	-- 7. Border props. Keep clear of the trees and rocks already standing there.
	local occupied = {}
	for _, item in Continent.planScenery() do
		local k = floor(item.x / 8) * 100000 + floor(item.z / 8)
		occupied[k] = true
	end
	local function crowded(x: number, z: number): boolean
		local cx, cz = floor(x / 8), floor(z / 8)
		for dx = -1, 1 do
			for dz = -1, 1 do
				if occupied[(cx + dx) * 100000 + cz + dz] then
					return true
				end
			end
		end
		return false
	end
	local decor = {}
	for _, p in points do
		if p.kind == "natural" then
			-- the slope is the border; a few boulders keep the line readable
			local st = styles[p.style]
			if hash(p.x, p.z, 39) < (st.naturalChance or 0.18) and not crowded(p.x, p.z) then
				local kind = if st.naturalDecor then pickWeighted(st.naturalDecor, hash(p.x, p.z, 43)) else st.decor[1].kind
				table.insert(decor, { kind = kind, x = p.x, z = p.z, rot = hash(p.x, p.z, 33) * math.pi * 2, scale = 1.1 + 0.6 * hash(p.x, p.z, 34), style = p.style, ridge = false })
			end
			continue
		end
		if p.kind ~= "ridge" and p.kind ~= "low" then
			continue
		end
		local st = styles[p.style]
		-- Tree lines (forest and jungle): a dense row of trees on the bank's shoulders,
		-- allowed among the existing trees (only the exact spot must be free).
		if st.trees and hash(p.x, p.z, 35) < st.trees.chance then
			local side = if hash(p.x, p.z, 36) < 0.5 then -1 else 1
			local off = p.radius * 0.9
			local x, z = p.x - p.tz * off * side, p.z + p.tx * off * side
			if not occupied[floor(x / 8) * 100000 + floor(z / 8)] then
				table.insert(decor, { kind = st.trees.kind, x = x, z = z, rot = hash(p.x, p.z, 37) * math.pi * 2, scale = 0.85 + 0.4 * hash(p.x, p.z, 38), style = p.style, ridge = false })
			end
		end
		if crowded(p.x, p.z) then
			continue
		end
		local rot = math.atan2(p.tx, p.tz) -- yaw that faces along the border
		local run = st.runs and (noise(p.x / 150, p.z / 150, 6.4) + 0.5) > 1 - st.runs.above
		if run then
			table.insert(decor, { kind = st.runs.kind, x = p.x, z = p.z, rot = rot, scale = 1, style = p.style, ridge = true })
		elseif hash(p.x, p.z, 31) < st.decorChance then
			local kind = pickWeighted(st.decor, hash(p.x, p.z, 32))
			table.insert(decor, { kind = kind, x = p.x, z = p.z, rot = hash(p.x, p.z, 33) * math.pi * 2, scale = 0.8 + 0.5 * hash(p.x, p.z, 34), style = p.style, ridge = true })
		elseif hash(p.x, p.z, 40) < st.edgeChance then
			-- half-buried edge stone along the crest
			local jitter = (hash(p.x, p.z, 41) - 0.5) * 0.5
			table.insert(decor, { kind = "EdgeStone", x = p.x, z = p.z, rot = rot + jitter, scale = 0.85 + 0.35 * hash(p.x, p.z, 42), style = p.style, ridge = true })
		end
	end

	-- Stats
	local counts = { ridge = 0, gap = 0, natural = 0, water = 0, blocked = 0, sea = 0, low = 0 }
	for _, p in points do
		counts[p.kind] += 1
	end

	cached = {
		raster = { ids = ids, W = W, H = H, minX = minX, minZ = minZ, G = G },
		points = points,
		gates = gates,
		trails = trails,
		decor = decor,
		connections = connections,
		pairOrder = pairOrder,
		counts = counts,
	}
	return cached
end

-- Estimated parts per border prop (checked against the real count in Studio).
Sections.PART_ESTIMATE = {
	EdgeStone = 1,
	FenceRun = 4,
	StoneWall = 4,
	SandstoneWall = 4,
	DarkWall = 4,
	OvergrownEdge = 5,
	SandstoneStack = 3,
	RootTangle = 3,
	StoneArchlet = 3,
	Waystone = 3,
	Rock = 2,
	MossyRock = 3,
	SandRock = 2,
	SnowRock = 3,
	AshRock = 2,
	PaleRock = 2,
	JaggedRock = 3,
	Shrub = 2,
	Flowers = 8,
	Fern = 4,
	BigLeaf = 3,
	Log = 2,
	Reeds = 6,
	SwampTree = 6,
	DesertShrub = 3,
	Cactus = 3,
	Pine = 4,
	SnowPine = 6,
	IceSpike = 3,
	BasaltSpire = 3,
	Crystal = 3,
	ForestTree = 4,
	JungleTree = 5,
}

return Sections
