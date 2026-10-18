--!nonstrict
-- Continent: the pure, deterministic description of the World place's landscape.
--
-- The same functions are used by
--   * the Studio-only builder (WorldTools.ContinentBuilder), which writes the terrain
--     and scenery ONCE into the place, and
--   * gameplay code at runtime (region queries), without touching terrain.
-- Nothing here creates instances. Same inputs -> same outputs on every machine
-- (math.noise is deterministic), so the map never changes between sessions.
--
-- Pipeline for one column (x, z):
--   domain-warped point -> weighted distance to each region seed -> blend weights
--   -> region height profiles -> flattened sites -> crater -> road corridors (with
--   grade-limited heights) -> lakes -> rivers -> coastline -> water level + material.

local RegionConfig = require(script.Parent.RegionConfig)

local Continent = {}

local noise = math.noise
local sqrt, abs, floor, max, min, exp = math.sqrt, math.abs, math.floor, math.max, math.min, math.exp

local REGIONS = RegionConfig.regions
local NREG = #REGIONS
local SEA = RegionConfig.SEA_LEVEL
local SEABED = RegionConfig.SEABED
local BLEND = RegionConfig.BLEND
local COAST = RegionConfig.COAST

Continent.SEA_LEVEL = SEA

---------------------------------------------------------------------------------------
-- Noise helpers
---------------------------------------------------------------------------------------
local function fbm(x: number, z: number, seed: number, freq: number, oct: number): number
	local sum, amp, f, norm = 0, 1, freq, 0
	for _ = 1, oct do
		sum += noise(x * f + seed * 17.13, z * f - seed * 9.71, seed * 0.613) * amp
		norm += amp
		amp *= 0.5
		f *= 2.03
	end
	return sum / norm * 1.6 -- roughly -1..1
end

local function ridged(x: number, z: number, seed: number, freq: number, oct: number): number
	local sum, amp, f, norm = 0, 1, freq, 0
	for _ = 1, oct do
		local n = 1 - abs(noise(x * f + seed * 11.3, z * f + seed * 5.9, seed * 0.37)) * 2.2
		n = max(n, 0)
		sum += n * n * amp
		norm += amp
		amp *= 0.5
		f *= 2.07
	end
	return sum / norm -- 0..1
end

local function smoothstep(e0: number, e1: number, v: number): number
	local t = (v - e0) / (e1 - e0)
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Deterministic hash -> 0..1
local function hash(a: number, b: number, s: number): number
	local h = math.sin(a * 127.1 + b * 311.7 + s * 74.7) * 43758.5453
	return h - floor(h)
end
Continent.hash = hash

---------------------------------------------------------------------------------------
-- Polylines (roads, rivers, lava) with a spatial bucket index
---------------------------------------------------------------------------------------
local BUCKET = 128

local function densify(points: { { number } }, step: number): { { number } }
	local out = {}
	for i = 1, #points - 1 do
		local ax, az = points[i][1], points[i][2]
		local bx, bz = points[i + 1][1], points[i + 1][2]
		local len = sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local n = max(1, floor(len / step))
		for k = 0, n - 1 do
			local t = k / n
			-- gentle meander so lines never look ruler-straight
			local px, pz = lerp(ax, bx, t), lerp(az, bz, t)
			local nx, nz = -(bz - az) / len, (bx - ax) / len
			local wob = noise(px / 160, pz / 160, 3.3) * 22 * math.sin(t * math.pi)
			table.insert(out, { px + nx * wob, pz + nz * wob })
		end
	end
	table.insert(out, { points[#points][1], points[#points][2] })
	return out
end

type Line = { pts: { { number } }, h: { number }?, width: number, id: string, kind: string, data: any }

local function newIndex(): { [number]: { [number]: { any } } }
	return {}
end

local function indexSegments(index, line: Line, reach: number)
	for i = 1, #line.pts - 1 do
		local a, b = line.pts[i], line.pts[i + 1]
		local x0 = floor((min(a[1], b[1]) - reach) / BUCKET)
		local x1 = floor((max(a[1], b[1]) + reach) / BUCKET)
		local z0 = floor((min(a[2], b[2]) - reach) / BUCKET)
		local z1 = floor((max(a[2], b[2]) + reach) / BUCKET)
		for bx = x0, x1 do
			local col = index[bx]
			if not col then
				col = {}
				index[bx] = col
			end
			for bz = z0, z1 do
				local list = col[bz]
				if not list then
					list = {}
					col[bz] = list
				end
				table.insert(list, { line, i })
			end
		end
	end
end

-- Nearest segment in an index: distance, line, segment index, t along segment.
local function nearest(index, x: number, z: number)
	local col = index[floor(x / BUCKET)]
	local list = col and col[floor(z / BUCKET)]
	if not list then
		return math.huge, nil, 0, 0
	end
	local best, bestLine, bestI, bestT = math.huge, nil, 0, 0
	for _, e in list do
		local line, i = e[1], e[2]
		local a, b = line.pts[i], line.pts[i + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local l2 = dx * dx + dz * dz
		local t = if l2 > 0 then ((x - a[1]) * dx + (z - a[2]) * dz) / l2 else 0
		t = if t < 0 then 0 elseif t > 1 then 1 else t
		local px, pz = a[1] + dx * t - x, a[2] + dz * t - z
		local d = px * px + pz * pz
		if d < best then
			best, bestLine, bestI, bestT = d, line, i, t
		end
	end
	return sqrt(best), bestLine, bestI, bestT
end

---------------------------------------------------------------------------------------
-- Regions
---------------------------------------------------------------------------------------
local seedX, seedZ, seedW = table.create(NREG), table.create(NREG), table.create(NREG)
for i, r in REGIONS do
	seedX[i], seedZ[i], seedW[i] = r.seed.x, r.seed.z, r.weight
end

local function warp(x: number, z: number): (number, number)
	local wx = x + 270 * fbm(x, z, 11, 1 / 620, 3) + 125 * fbm(x, z, 31, 1 / 230, 2)
	local wz = z + 270 * fbm(x, z, 23, 1 / 620, 3) + 125 * fbm(x, z, 37, 1 / 230, 2)
	return wx, wz
end

-- Fills dist[] (weighted distances) and returns nearest and second-nearest indices.
local dist = table.create(NREG, 0)
local function regionDistances(x: number, z: number): (number, number)
	local wx, wz = warp(x, z)
	local b1, b2 = 1, 2
	for i = 1, NREG do
		local dx, dz = wx - seedX[i], wz - seedZ[i]
		dist[i] = sqrt(dx * dx + dz * dz) - seedW[i]
	end
	-- The starting region always owns the build plot and its surroundings.
	local r0 = sqrt(x * x + z * z)
	if r0 < 520 then
		dist[1] -= 260 * (1 - smoothstep(260, 520, r0))
	end
	if dist[2] < dist[1] then
		b1, b2 = 2, 1
	end
	for i = 3, NREG do
		if dist[i] < dist[b1] then
			b2, b1 = b1, i
		elseif dist[i] < dist[b2] then
			b2 = i
		end
	end
	return b1, b2
end

---------------------------------------------------------------------------------------
-- Height profiles (one per terrain kind)
---------------------------------------------------------------------------------------
local roadIndex = newIndex() -- filled below
local riverIndex = newIndex()
local lavaIndex = newIndex()

local function roadDistance(x: number, z: number): number
	local d = nearest(roadIndex, x, z)
	return d
end

local profiles = {}

profiles.rolling = function(x, z)
	return 6 + 9 * fbm(x, z, 101, 1 / 240, 3) + 4 * fbm(x, z, 102, 1 / 80, 2)
end

profiles.woodland = function(x, z)
	return 11 + 14 * fbm(x, z, 201, 1 / 210, 3) + 6 * fbm(x, z, 202, 1 / 55, 2)
end

profiles.desert = function(x, z)
	local base = 16 + 5 * fbm(x, z, 301, 1 / 400, 2)
	local dunes = 5.5 * math.sin((x * 0.72 + z * 0.31) / 34 + 5 * fbm(x, z, 302, 1 / 300, 2))
	local m = fbm(x, z, 303, 1 / 230, 3)
	local mesa = smoothstep(0.22, 0.3, m)
	return base + dunes * (1 - mesa) * smoothstep(-0.2, 0.3, fbm(x, z, 304, 1 / 200, 2)) + 44 * mesa
end

profiles.swamp = function(x, z)
	return 2.5 + 3.4 * fbm(x, z, 401, 1 / 110, 3) + 1.6 * fbm(x, z, 402, 1 / 35, 2)
end

local function valleyMask(x: number, z: number, inner: number, outer: number): number
	return smoothstep(inner, outer, roadDistance(x, z))
end

profiles.mountains = function(x, z)
	local r = ridged(x, z, 501, 1 / 430, 4)
	local v = valleyMask(x, z, 28, 150)
	return 30 + 14 * fbm(x, z, 502, 1 / 150, 2) + 270 * (r ^ 1.25) * v
end

profiles.jungle = function(x, z)
	local hills = 12 + 18 * fbm(x, z, 601, 1 / 220, 3)
	return hills + 26 * ridged(x, z, 602, 1 / 160, 2) * valleyMask(x, z, 30, 160)
end

profiles.glacier = function(x, z)
	return 48 + 26 * fbm(x, z, 701, 1 / 260, 3) + 34 * ridged(x, z, 702, 1 / 200, 3) * valleyMask(x, z, 30, 180)
end

profiles.volcanic = function(x, z)
	local r = ridged(x, z, 801, 1 / 230, 3)
	return 24 + 8 * fbm(x, z, 802, 1 / 90, 2) + 70 * (r * r) * valleyMask(x, z, 30, 180)
end

profiles.highlands = function(x, z)
	local t = 80 * (fbm(x, z, 901, 1 / 320, 3) + 0.9)
	local step = 18
	local k = floor(t / step)
	local frac = t / step - k
	return 34 + step * (k + smoothstep(0.7, 1, frac)) + 3 * fbm(x, z, 902, 1 / 40, 1)
end

profiles.dragon = function(x, z)
	local r = ridged(x, z, 1001, 1 / 300, 4)
	return 58 + 12 * fbm(x, z, 1002, 1 / 120, 2) + 270 * (r ^ 1.2) * valleyMask(x, z, 32, 160)
end

local profileOf = table.create(NREG)
for i, r in REGIONS do
	profileOf[i] = profiles[r.terrain] or profiles.rolling
end

---------------------------------------------------------------------------------------
-- Sites (flattened clearings) and landmarks
---------------------------------------------------------------------------------------
local weights = table.create(NREG, 0)

-- Region blend weights (compact support, continuous). Returns nearest index.
local function regionWeights(x: number, z: number): (number, number, number)
	local b1, b2 = regionDistances(x, z)
	local d1 = dist[b1]
	local total = 0
	for i = 1, NREG do
		local w = 1 - (dist[i] - d1) / BLEND
		if w > 0 then
			w = w * w
			weights[i] = w
			total += w
		else
			weights[i] = 0
		end
	end
	for i = 1, NREG do
		weights[i] /= total
	end
	return b1, b2, (dist[b2] - d1)
end

local function regionHeight(x: number, z: number): number
	regionWeights(x, z)
	local h = 0
	for i = 1, NREG do
		local w = weights[i]
		if w > 0 then
			h += w * profileOf[i](x, z)
		end
	end
	return h
end

local SITES = {}
for _, r in REGIONS do
	for _, s in r.sites do
		table.insert(SITES, { def = s, region = r.id, x = s.x, z = s.z, radius = s.radius })
	end
end

-- Crater (Ashenreach): rim + bowl.
local CRATER = { x = -230, z = -1210, radius = 120 }

local function applyCrater(x: number, z: number, h: number): (number, boolean)
	local d = sqrt((x - CRATER.x) ^ 2 + (z - CRATER.z) ^ 2)
	if d > CRATER.radius + 120 then
		return h, false
	end
	local rim = 52 * exp(-((d - CRATER.radius) / 34) ^ 2)
	local bowl = CRATER.floor - 6 * fbm(x, z, 1201, 1 / 40, 1)
	local inside = 1 - smoothstep(CRATER.radius - 50, CRATER.radius - 5, d)
	local hh = h + rim
	hh = lerp(hh, min(hh, bowl), inside)
	return hh, d < CRATER.radius - 35
end

local siteHeightsReady = false
local siteInfluence = 0 -- strongest site flattening at the last applySites call
local function applySites(x: number, z: number, h: number): (number, any)
	local inSite = nil
	siteInfluence = 0
	for _, s in SITES do
		local dx, dz = x - s.x, z - s.z
		local r = s.radius
		local d2 = dx * dx + dz * dz
		local outer = r + 45
		if d2 < outer * outer then
			local d = sqrt(d2)
			local t = 1 - smoothstep(r * 0.8, outer, d)
			h = lerp(h, s.height, t)
			siteInfluence = max(siteInfluence, t)
			if d < r then
				inSite = s
			end
		end
	end
	return h, inSite
end

---------------------------------------------------------------------------------------
-- Build the line data (needs raw heights, which need the road index for valleys)
---------------------------------------------------------------------------------------
local ROADS, RIVERS, LAVA = {}, {}, {}

for _, r in RegionConfig.ROADS do
	local line: Line = { pts = densify(r.points, 8), width = 9, id = r.id, kind = "road", data = r }
	table.insert(ROADS, line)
	indexSegments(roadIndex, line, 280)
end

-- Raw height = regions + sites + crater (no roads, water or coast).
CRATER.floor = 0
local function rawHeight(x: number, z: number): number
	local h = regionHeight(x, z)
	if siteHeightsReady then
		h = applySites(x, z, h)
	end
	h = applyCrater(x, z, h)
	return h
end

-- Site heights from the natural terrain at their centres (averaged).
for _, s in SITES do
	if s.def.height then
		s.height = s.def.height
	else
		local sum = 0
		for _, o in { { 0, 0 }, { 20, 0 }, { -20, 0 }, { 0, 20 }, { 0, -20 } } do
			sum += regionHeight(s.x + o[1], s.z + o[2])
		end
		s.height = sum / 5
	end
end
siteHeightsReady = true
CRATER.floor = regionHeight(CRATER.x, CRATER.z) - 18

local MAX_GRADE = 0.32 -- rise per stud along roads (~18 degrees)

local function gradeLimit(h: { number }, step: number, grade: number)
	local lim = grade * step
	for i = 2, #h do
		h[i] = max(min(h[i], h[i - 1] + lim), h[i - 1] - lim)
	end
	for i = #h - 1, 1, -1 do
		h[i] = max(min(h[i], h[i + 1] + lim), h[i + 1] - lim)
	end
end

local function smoothArray(h: { number }, radius: number): { number }
	local out = table.create(#h)
	for i = 1, #h do
		local s, n = 0, 0
		for k = max(1, i - radius), min(#h, i + radius) do
			s += h[k]
			n += 1
		end
		out[i] = s / n
	end
	return out
end

-- Lakes: levels from the terrain at their centre.
local LAKES = {}
for _, l in RegionConfig.LAKES do
	local level = rawHeight(l.x, l.z) - 1.5
	table.insert(LAKES, { def = l, x = l.x, z = l.z, radius = l.radius, level = level, ice = l.ice == true })
end

-- Rivers: water level follows the smoothed valley, never rising downstream.
for _, rv in RegionConfig.RIVERS do
	local pts = densify(rv.points, 8)
	local h = table.create(#pts)
	for i, p in pts do
		h[i] = rawHeight(p[1], p[2])
	end
	h = smoothArray(h, 6)
	for i = 1, #h do
		h[i] = max(h[i] - 2, SEA)
		if i > 1 then
			h[i] = min(h[i], h[i - 1])
		end
	end
	local line: Line = { pts = pts, h = h, width = rv.width, id = rv.id, kind = "river", data = rv }
	table.insert(RIVERS, line)
	indexSegments(riverIndex, line, rv.width + 30)
end

-- Swamp water table.
local SWAMP_LEVEL = 1.6
local swampIndex = 0
for i, r in REGIONS do
	if r.terrain == "swamp" then
		swampIndex = i
	end
end

-- Roads: sample, smooth, keep above water, limit the grade.
for _, line in ROADS do
	local h = table.create(#line.pts)
	for i, p in line.pts do
		local x, z = p[1], p[2]
		local v = rawHeight(x, z)
		regionWeights(x, z)
		if swampIndex > 0 and weights[swampIndex] > 0.2 then
			v = max(v, SWAMP_LEVEL + 1.2) -- raised causeway through the marsh
		end
		h[i] = v
	end
	h = smoothArray(h, 5)
	gradeLimit(h, 8, MAX_GRADE)
	line.h = h
end

for _, lv in RegionConfig.LAVA do
	local line: Line = { pts = densify(lv.points, 8), width = lv.width, id = "lava", kind = "lava", data = lv }
	table.insert(LAVA, line)
	indexSegments(lavaIndex, line, lv.width + 4)
end

Continent.roads = ROADS
Continent.rivers = RIVERS
Continent.lakes = LAKES
Continent.sites = SITES
Continent.crater = CRATER

---------------------------------------------------------------------------------------
-- The column function
---------------------------------------------------------------------------------------
local coastSeed = 5

local function landFactor(x: number, z: number): number
	local nx, nz = (x - COAST.cx) / COAST.rx, (z - COAST.cz) / COAST.rz
	local r = sqrt(nx * nx + nz * nz) + 0.22 * fbm(x, z, coastSeed, 1 / 460, 3) + 0.07 * fbm(x, z, 6, 1 / 130, 2)
	return 1 - smoothstep(0.93, 1.0, r)
end

export type Column = {
	h: number, -- ground height (studs)
	water: number, -- water surface height, or -math.huge when dry
	region: number, -- index of the dominant region
	region2: number, -- second region (for transitions)
	edge: number, -- weighted distance gap to region2 (small = transition zone)
	road: number, -- distance to nearest road centre
	roadId: string?,
	river: number, -- distance to nearest river centre
	riverWidth: number,
	riverDry: boolean,
	lake: any?,
	site: any?,
	land: number, -- 1 inland, 0 open sea
	crater: boolean,
	lava: boolean,
	ice: boolean,
}

function Continent.column(x: number, z: number): Column
	local b1, b2, edge = regionWeights(x, z)
	local h = 0
	for i = 1, NREG do
		local w = weights[i]
		if w > 0 then
			h += w * profileOf[i](x, z)
		end
	end
	local site
	h, site = applySites(x, z, h)
	local inCrater
	h, inCrater = applyCrater(x, z, h)
	local water = -math.huge
	local ice = false

	-- Swamp pools: the water table shows wherever ground dips below it.
	if swampIndex > 0 then
		local sw = weights[swampIndex]
		if sw > 0.35 and siteInfluence < 0.2 then -- clearings stay dry
			water = SWAMP_LEVEL
		end
	end

	-- Roads
	local rd, rline, ri, rt = nearest(roadIndex, x, z)
	if rline and rd < 34 then
		local ph = lerp(rline.h[ri], rline.h[ri + 1], rt)
		local t = 1 - smoothstep(rline.width, 34, rd)
		h = lerp(h, ph, t)
	end

	-- Lakes
	local lake = nil
	for _, l in LAKES do
		local dx, dz = x - l.x, z - l.z
		local d = sqrt(dx * dx + dz * dz)
		local r = l.radius * (1 + 0.18 * noise(x / 40, z / 40, 7.7))
		if d < r + 22 then
			if d < r then
				local bowl = l.level - 7 * (1 - (d / r) ^ 2) - 0.6
				h = min(h, bowl)
				lake = l
				if l.ice then
					ice = true
				else
					water = max(water, l.level)
				end
			else
				h = max(h, l.level + 0.6 + (d - r) * 0.15) -- shore never below the surface
			end
		end
	end

	-- Rivers
	local vd, vline, vi, vt = nearest(riverIndex, x, z)
	local riverWidth, riverDry = 0, false
	if vline then
		riverWidth = vline.width
		riverDry = vline.data.dry == true
		local level = lerp(vline.h[vi], vline.h[vi + 1], vt)
		local w = vline.width
		if vd < w then
			local bed = level - vline.data.depth * (1 - (vd / w) ^ 2)
			h = min(h, bed)
			if not riverDry then
				water = max(water, level)
			end
		elseif vd < w + 14 and not riverDry then
			h = max(h, level + 0.5) -- banks keep the water in
		end
	end

	-- Lava channels (visual): sunken a little
	local ld = nearest(lavaIndex, x, z)
	local lava = ld < 7
	if lava then
		h -= 1.2
	end

	-- Coast
	local land = landFactor(x, z)
	if land < 1 then
		local seabed = SEABED + 4 * fbm(x, z, 9, 1 / 200, 2)
		h = lerp(seabed, h, land)
		water = max(water, SEA)
	end

	if water <= h then
		water = -math.huge
	end

	return {
		h = h,
		water = water,
		region = b1,
		region2 = b2,
		edge = edge,
		road = rd,
		roadId = rline and rline.id,
		river = vd,
		riverWidth = riverWidth,
		riverDry = riverDry,
		lake = lake,
		site = site,
		land = land,
		crater = inCrater,
		lava = lava,
		ice = ice,
	}
end

-- Height only (convenience).
function Continent.height(x: number, z: number): number
	return Continent.column(x, z).h
end

---------------------------------------------------------------------------------------
-- Materials
---------------------------------------------------------------------------------------
local NO_BEACH = { dragon = true, glacier = true } -- rocky or icy shores

-- slope = rise per stud (|gradient|). Returns Enum.Material name.
function Continent.material(c: Column, slope: number, x: number, z: number): string
	local regionIndex = c.region
	-- Dithered transition: in the blend band, patches of the neighbour's ground.
	if c.edge < BLEND * 0.7 then
		local t = c.edge / (BLEND * 0.7) -- 0 at the border, 1 inside
		local n = (noise(x / 26, z / 26, 4.2) + noise(x / 9, z / 9, 8.1) * 0.35) * 0.9 + 0.5
		if n > 0.5 + 0.5 * t then
			regionIndex = c.region2
		end
	end
	local r = REGIONS[regionIndex]
	local m = r.materials
	local h = c.h
	local kind: string = r.terrain

	if c.lava then
		return "CrackedLava"
	end
	if c.ice then
		return "Ice"
	end
	if c.crater then
		return if noise(x / 30, z / 30, 2.2) > 0.05 then "CrackedLava" else "Basalt"
	end
	if c.land < 0.995 and h < SEA + 5 and not NO_BEACH[kind] then
		return if slope > 0.9 then m.cliff else "Sand"
	end
	if c.river < c.riverWidth + 3 then
		if c.riverDry then
			return if noise(x / 12, z / 12, 1.1) > 0 then "Ground" else "Sandstone"
		end
		return if kind == "glacier" then "Glacier" else "Mud"
	end
	if c.lake then
		return if kind == "desert" then "Sand" else "Mud"
	end
	if c.road < 7 then
		if kind == "desert" then
			return "Sandstone"
		elseif kind == "glacier" then
			return "Snow"
		elseif kind == "volcanic" or kind == "dragon" then
			return "Cobblestone"
		elseif kind == "highlands" then
			return "Limestone"
		elseif kind == "swamp" then
			return "WoodPlanks"
		end
		return "Ground"
	end
	if slope > 1.15 then
		return m.cliff
	end

	local terrain = kind
	if terrain == "mountains" then
		if h > 150 + 25 * noise(x / 60, z / 60, 3.1) then
			return "Snow"
		elseif h > 95 or slope > 0.7 then
			return if noise(x / 20, z / 20, 1.7) > 0.15 then "Rock" else "Slate"
		end
		return if noise(x / 35, z / 35, 4.4) > 0.3 then "Ground" else "Grass"
	elseif terrain == "dragon" then
		if h > 230 + 20 * noise(x / 50, z / 50, 9.9) then
			return "Snow"
		end
		return if noise(x / 24, z / 24, 5.5) > 0.1 then "Slate" else "Basalt"
	elseif terrain == "glacier" then
		local n = noise(x / 70, z / 70, 6.6)
		if slope > 0.55 then
			return "Glacier"
		end
		return if n > 0.22 then "Glacier" elseif n < -0.3 then "Rock" else "Snow"
	elseif terrain == "volcanic" then
		return if noise(x / 28, z / 28, 7.3) > 0.1 then "Basalt" else "Asphalt"
	elseif terrain == "desert" then
		if slope > 0.5 or h > 50 then
			return "Sandstone"
		end
		return if noise(x / 50, z / 50, 2.9) > 0.42 then "Ground" else "Sand"
	elseif terrain == "swamp" then
		if c.water > -math.huge then
			return "Mud"
		end
		return if noise(x / 18, z / 18, 6.1) > 0.05 then "Mud" else "LeafyGrass"
	elseif terrain == "highlands" then
		if slope > 0.45 then
			return "Limestone"
		end
		return if noise(x / 40, z / 40, 3.8) > 0.35 then "Limestone" else "Salt"
	elseif terrain == "jungle" then
		if slope > 0.6 then
			return "Limestone"
		end
		return if noise(x / 22, z / 22, 2.4) > 0.3 then "Mud" else "LeafyGrass"
	elseif terrain == "woodland" then
		return if noise(x / 20, z / 20, 1.9) > 0.38 then "Mud" else "LeafyGrass"
	end
	-- rolling grassland
	if slope > 0.6 then
		return "Rock"
	end
	return if noise(x / 45, z / 45, 2.6) > 0.48 then "Ground" else "Grass"
end

---------------------------------------------------------------------------------------
-- Region queries (for gameplay systems)
---------------------------------------------------------------------------------------
export type RegionInfo = {
	id: string,
	name: string,
	minLevel: number,
	maxLevel: number,
	transition: boolean, -- inside a blend band
	neighborId: string?, -- the other region in a transition zone
	onRoad: boolean,
	inWater: boolean,
	site: any?, -- content site under the point, if any
	buildable: boolean, -- suitable for future content placement
}

function Continent.regionAt(x: number, z: number): RegionInfo
	local c = Continent.column(x, z)
	local r = REGIONS[c.region]
	local transition = c.edge < BLEND * 0.5
	local s = 6
	local slope = max(abs(Continent.height(x + s, z) - c.h), abs(Continent.height(x, z + s) - c.h)) / s
	local inWater = c.water > c.h
	return {
		id = r.id,
		name = r.name,
		minLevel = r.minLevel,
		maxLevel = r.maxLevel,
		transition = transition,
		neighborId = if transition then REGIONS[c.region2].id else nil,
		onRoad = c.road < 9,
		inWater = inWater,
		site = c.site and c.site.def,
		buildable = (not inWater) and slope < 0.35 and c.road > 12 and not c.lava and not c.crater and c.land > 0.99,
	}
end

-- Cheap region id only (no slope samples).
function Continent.regionIdAt(x: number, z: number): string
	local b1 = regionDistances(x, z)
	return REGIONS[b1].id
end

---------------------------------------------------------------------------------------
-- Scenery plan (deterministic). The builder turns this into models.
---------------------------------------------------------------------------------------
local CELL = 24

local landmarkList = {}
for _, r in REGIONS do
	for _, l in r.landmarks do
		table.insert(landmarkList, l)
	end
end
Continent.landmarks = landmarkList

local function pickKind(veg, roll: number): string
	local total = 0
	for _, v in veg do
		total += v.weight
	end
	local acc = 0
	for _, v in veg do
		acc += v.weight / total
		if roll <= acc then
			return v.kind
		end
	end
	return veg[#veg].kind
end

local PLOT_CLEAR = 175 -- keep the build plot and its surroundings open

function Continent.planScenery(bounds: any?): { { kind: string, x: number, y: number, z: number, rot: number, scale: number, region: string } }
	local b = bounds or RegionConfig.BOUNDS
	local out = {}
	for gx = floor(b.minX / CELL), floor(b.maxX / CELL) do
		for gz = floor(b.minZ / CELL), floor(b.maxZ / CELL) do
			local x = (gx + 0.15 + 0.7 * hash(gx, gz, 1)) * CELL
			local z = (gz + 0.15 + 0.7 * hash(gx, gz, 2)) * CELL
			if abs(x) < PLOT_CLEAR and abs(z) < PLOT_CLEAR + 20 then
				continue
			end
			local land = landFactor(x, z)
			if land < 0.99 then
				continue
			end
			local c = Continent.column(x, z)
			local r = REGIONS[c.region]
			local w = weights[c.region] -- set by column()
			-- clumps and clearings
			local clump = smoothstep(-0.35, 0.35, fbm(x, z, 77, 1 / 180, 2))
			local density = r.density * (0.35 + 0.65 * clump) * (0.5 + 0.5 * w)
			if r.terrain == "woodland" or r.terrain == "jungle" then
				density *= 0.6 + 0.8 * w -- thicker towards the interior
			end
			if hash(gx, gz, 3) > density then
				continue
			end
			if c.water > c.h - 0.5 and r.terrain ~= "swamp" then
				continue
			end
			if c.road < 20 or c.river < c.riverWidth + 8 or c.site or c.lava or c.crater or c.ice then
				continue
			end
			local blocked = false
			for _, l in landmarkList do
				if (x - l.x) ^ 2 + (z - l.z) ^ 2 < l.clear * l.clear then
					blocked = true
					break
				end
			end
			if blocked then
				continue
			end
			local hx = Continent.height(x + 4, z)
			local hz = Continent.height(x, z + 4)
			local slope = max(abs(hx - c.h), abs(hz - c.h)) / 4
			if slope > 0.9 then
				continue
			end
			local kind = pickKind(r.vegetation, hash(gx, gz, 4))
			if r.terrain == "swamp" and c.water > c.h and kind ~= "Reeds" and kind ~= "SwampTree" then
				continue
			end
			table.insert(out, {
				kind = kind,
				x = x,
				y = c.h,
				z = z,
				rot = hash(gx, gz, 5) * math.pi * 2,
				scale = 0.8 + 0.5 * hash(gx, gz, 6),
				region = r.id,
			})
		end
	end
	return out
end

-- Where a road crosses a river: bridge positions.
function Continent.planBridges(): { { x: number, z: number, y: number, angle: number, length: number, river: string } }
	local out = {}
	for _, road in ROADS do
		local lastCross = -math.huge
		for i = 1, #road.pts - 1 do
			local p = road.pts[i]
			local d, line = nearest(riverIndex, p[1], p[2])
			if line and not line.data.dry and d < 3 and i - lastCross > 10 then
				lastCross = i
				local q = road.pts[min(i + 1, #road.pts)]
				local level = line.h[1]
				local _, _, vi, vt = nearest(riverIndex, p[1], p[2])
				level = lerp(line.h[vi], line.h[vi + 1], vt)
				table.insert(out, {
					x = p[1],
					z = p[2],
					y = max(level + 1.5, road.h[i]),
					angle = math.atan2(q[1] - p[1], q[2] - p[2]),
					length = line.width * 2 + 16,
					river = line.id,
				})
			end
		end
	end
	return out
end

-- Region signposts where roads enter a new region.
function Continent.planSigns(): { { x: number, z: number, y: number, angle: number, region: string, from: string } }
	local out = {}
	for _, road in ROADS do
		local prev = nil
		local lastSign = -math.huge
		for i = 1, #road.pts, 3 do
			local p = road.pts[i]
			local id = Continent.regionIdAt(p[1], p[2])
			if prev and id ~= prev and i - lastSign > 25 then
				lastSign = i
				local q = road.pts[min(i + 3, #road.pts)]
				local angle = math.atan2(q[1] - p[1], q[2] - p[2])
				-- set the sign beside the road
				local ox, oz = math.cos(angle) * 12, -math.sin(angle) * 12
				local x, z = p[1] + ox, p[2] + oz
				table.insert(out, { x = x, z = z, y = Continent.height(x, z), angle = angle, region = id, from = prev })
			end
			prev = id
		end
	end
	return out
end

return Continent
