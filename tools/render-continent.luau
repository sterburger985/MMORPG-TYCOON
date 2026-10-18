--!nocheck
-- Renders the Continent heightfield to a PPM image (top-down, north up) so the map can be
-- reviewed and tuned without Studio. Usage:
--   lune run tools/render-continent.luau <world.rbxl> <out.ppm> [studsPerPixel] [overlay]
-- overlay: "regions" draws region borders, roads, landmarks and scenery points.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local placePath, outPath = process.args[1], process.args[2]
local step = tonumber(process.args[3] or "8")
local overlay = process.args[4]

local dm = roblox.deserializePlace(fs.readFile(placePath))
local cache = {}
local function req(module)
	if cache[module] then
		return cache[module]
	end
	local env = setmetatable({ script = module, require = req, game = dm }, { __index = _G })
	local result = luau.load(module.Source, { debugName = module.Name, environment = env })()
	cache[module] = result
	return result
end
local shared = dm:GetService("ReplicatedStorage"):FindFirstChild("Shared")
local t0 = os.clock()
local Continent = req(shared:FindFirstChild("Continent"))
local RegionConfig = req(shared:FindFirstChild("RegionConfig"))
print(("module load %.2fs"):format(os.clock() - t0))

local COLORS = {
	Grass = { 106, 170, 70 },
	LeafyGrass = { 60, 120, 52 },
	Ground = { 140, 112, 78 },
	Mud = { 86, 72, 52 },
	Rock = { 128, 126, 122 },
	Slate = { 70, 72, 80 },
	Sand = { 226, 200, 140 },
	Sandstone = { 196, 140, 90 },
	Snow = { 240, 244, 250 },
	Glacier = { 170, 214, 240 },
	Ice = { 190, 226, 250 },
	Basalt = { 52, 48, 50 },
	Asphalt = { 82, 78, 80 },
	CrackedLava = { 230, 100, 40 },
	Salt = { 222, 214, 240 },
	Limestone = { 206, 200, 170 },
	Cobblestone = { 110, 108, 104 },
	WoodPlanks = { 150, 110, 70 },
}

local b = RegionConfig.BOUNDS
local W = math.floor((b.maxX - b.minX) / step)
local H = math.floor((b.maxZ - b.minZ) / step)
local heights = table.create(W * H)
local cols = table.create(W * H)
t0 = os.clock()
for j = 0, H - 1 do
	for i = 0, W - 1 do
		local x, z = b.minX + i * step, b.minZ + j * step
		local c = Continent.column(x, z)
		heights[j * W + i + 1] = c.h
		cols[j * W + i + 1] = c
	end
end
local elapsed = os.clock() - t0
print(("%d columns in %.2fs (%.1f us/column)"):format(W * H, elapsed, elapsed / (W * H) * 1e6))

local minH, maxH = math.huge, -math.huge
for _, h in heights do
	minH, maxH = math.min(minH, h), math.max(maxH, h)
end
print(("height range %.1f .. %.1f"):format(minH, maxH))

local pixels = table.create(W * H * 3, 0)
local function setPx(i, j, r, g, bb)
	if i < 0 or j < 0 or i >= W or j >= H then
		return
	end
	local k = (j * W + i) * 3
	pixels[k + 1], pixels[k + 2], pixels[k + 3] = r, g, bb
end

for j = 0, H - 1 do
	for i = 0, W - 1 do
		local idx = j * W + i + 1
		local c = cols[idx]
		local h = heights[idx]
		local hx = heights[j * W + math.min(i + 1, W - 1) + 1]
		local hz = heights[math.min(j + 1, H - 1) * W + i + 1]
		local slope = math.max(math.abs(hx - h), math.abs(hz - h)) / step
		local x, z = b.minX + i * step, b.minZ + j * step
		local col
		if c.water > c.h then
			local depth = math.clamp((c.water - c.h) / 20, 0, 1)
			col = { 60 - 30 * depth, 140 - 60 * depth, 200 - 40 * depth }
		else
			local mat = Continent.material(c, slope, x, z)
			col = COLORS[mat] or { 255, 0, 255 }
			-- hillshade (light from north-west)
			local hl = heights[j * W + math.max(i - 1, 0) + 1]
			local hu = heights[math.max(j - 1, 0) * W + i + 1]
			local shade = math.clamp(1 + ((hl - h) + (hu - h)) * 0.06 / step * 4, 0.55, 1.35)
			local lift = 0.85 + 0.25 * math.clamp(h / 200, 0, 1)
			col = { col[1] * shade * lift, col[2] * shade * lift, col[3] * shade * lift }
		end
		setPx(i, j, math.clamp(math.floor(col[1]), 0, 255), math.clamp(math.floor(col[2]), 0, 255), math.clamp(math.floor(col[3]), 0, 255))
	end
end

if overlay == "regions" then
	for j = 1, H - 2 do
		for i = 1, W - 2 do
			local c = cols[j * W + i + 1]
			if c.land > 0.99 and (c.region ~= cols[j * W + i + 2].region or c.region ~= cols[(j + 1) * W + i + 1].region) then
				setPx(i, j, 255, 255, 255)
			end
		end
	end
	local function dot(x, z, r, cr, cg, cb)
		local ci, cj = math.floor((x - b.minX) / step), math.floor((z - b.minZ) / step)
		for dj = -r, r do
			for di = -r, r do
				if di * di + dj * dj <= r * r then
					setPx(ci + di, cj + dj, cr, cg, cb)
				end
			end
		end
	end
	for _, road in Continent.roads do
		for _, p in road.pts do
			dot(p[1], p[2], 0, 255, 230, 90)
		end
	end
	local plan = Continent.planScenery()
	print("scenery items:", #plan)
	local counts = {}
	for _, s in plan do
		counts[s.kind] = (counts[s.kind] or 0) + 1
		dot(s.x, s.z, 0, 20, 40, 20)
	end
	local parts = {}
	for k, v in counts do
		table.insert(parts, k .. "=" .. v)
	end
	table.sort(parts)
	print(table.concat(parts, " "))
	for _, l in Continent.landmarks do
		dot(l.x, l.z, 3, 255, 40, 200)
	end
	for _, s in Continent.planBridges() do
		dot(s.x, s.z, 2, 120, 60, 20)
	end
	for _, s in Continent.planSigns() do
		dot(s.x, s.z, 2, 255, 255, 0)
	end
	print("bridges:", #Continent.planBridges(), "signs:", #Continent.planSigns())
	-- the build plot
	for i = -128, 128, 4 do
		dot(i, -128, 0, 255, 0, 0)
		dot(i, 128, 0, 255, 0, 0)
		dot(-128, i, 0, 255, 0, 0)
		dot(128, i, 0, 255, 0, 0)
	end
end

local header = ("P6\n%d %d\n255\n"):format(W, H)
local bytes = table.create(#pixels)
for k, v in pixels do
	bytes[k] = string.char(v)
end
fs.writeFile(outPath, header .. table.concat(bytes))
print("wrote", outPath, W, H)
