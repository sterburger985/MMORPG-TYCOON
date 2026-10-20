--!nonstrict
-- BorderKit (Studio tool): props for section borders. Same rules as Scenery: each
-- builder makes a Model around the origin with the ground at y = 0, every part is
-- anchored, never queryable or touchable (build-mode raycasts and remove mode ignore
-- them). Linear pieces (fences, walls, edging) run along local +Z and are 9 studs long
-- so neighbouring segments 8 studs apart overlap without gaps; their feet go below
-- y = 0 so they never float on uneven ground.

local Scenery = require(script.Parent.Scenery)
local P = Scenery.part

local BorderKit = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function vary(c: Color3, rng: Random, amount: number): Color3
	local k = 1 + (rng:NextNumber() - 0.5) * amount
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local M = Enum.Material
local WOOD = rgb(122, 86, 56)
local MOSS = rgb(86, 132, 66)

local function block(m, cf: CFrame, size: Vector3, color: Color3, material, collide)
	return P(m, { Size = size, CFrame = cf, Color = color, Material = material or M.Rock, CanCollide = collide ~= false })
end

local K = {}

-- Wooden fence: two posts and two rails (Greenhaven).
K.FenceRun = function(m, rng, o)
	local tilt = rng:NextNumber(-0.06, 0.06)
	for _, z in { -4.5, 4.5 } do
		block(m, CFrame.new(0, 1, z) * CFrame.Angles(tilt, 0, rng:NextNumber(-0.05, 0.05)), Vector3.new(0.7, 5, 0.7), vary(WOOD, rng, 0.2), M.Wood)
	end
	for _, y in { 1.6, 3 } do
		block(m, CFrame.new(0, y, 0) * CFrame.Angles(rng:NextNumber(-0.03, 0.03), 0, 0), Vector3.new(0.35, 0.45, 9.6), vary(WOOD, rng, 0.15), M.Wood)
	end
end

-- Dry-stone wall: three irregular courses (Frostpeak).
K.StoneWall = function(m, rng, o)
	local c = o.stone
	local h = rng:NextNumber(2.4, 3.4)
	block(m, CFrame.new(0, h / 2 - 1, 0) * CFrame.Angles(0, rng:NextNumber(-0.04, 0.04), 0), Vector3.new(2.8, h + 2, 9.4), vary(c, rng, 0.12), M.Slate)
	block(m, CFrame.new(rng:NextNumber(-0.2, 0.2), h + 0.25, -2.2) * CFrame.Angles(0.05, 0, rng:NextNumber(-0.08, 0.08)), Vector3.new(2.4, 0.9, 4.2), vary(c, rng, 0.18), M.Slate)
	block(m, CFrame.new(rng:NextNumber(-0.2, 0.2), h + 0.2, 2.3) * CFrame.Angles(-0.04, 0, rng:NextNumber(-0.08, 0.08)), Vector3.new(2.3, 0.8, 3.9), vary(c, rng, 0.18), M.Slate)
	block(m, CFrame.new(1.4, 0.4, rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.3), Vector3.new(1.6, 1.4, 1.8), vary(c, rng, 0.2), M.Rock)
end

-- Eroded sandstone blocks of uneven height (Sunscar).
K.SandstoneWall = function(m, rng, o)
	local c = o.stone
	local z = -4.5
	for i = 1, 3 do
		local len = if i == 3 then 4.5 - z else rng:NextNumber(2.6, 3.4)
		local h = rng:NextNumber(2.5, 5.5)
		block(m, CFrame.new(rng:NextNumber(-0.3, 0.3), h / 2 - 1.2, z + len / 2) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.06, 0.06)), Vector3.new(rng:NextNumber(2.6, 3.4), h + 1.2, len + 0.3), vary(c, rng, 0.14), M.Sandstone)
		z += len
	end
	block(m, CFrame.new(1.5, 0.3, rng:NextNumber(-3, 3)) * CFrame.Angles(0.3, rng:NextNumber(0, 6), 0.2), Vector3.new(1.4, 1.2, 1.6), vary(c, rng, 0.2), M.Sandstone)
end

-- Monumental jagged slabs (Dragon's End).
K.DarkWall = function(m, rng, o)
	local c = o.stone
	local h1, h2 = rng:NextNumber(6.5, 10), rng:NextNumber(5, 8.5)
	block(m, CFrame.new(0, h1 / 2 - 1.5, -2.3) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.08, 0.08)), Vector3.new(3.8, h1 + 1.5, 5), vary(c, rng, 0.12), M.Slate)
	block(m, CFrame.new(0.2, h2 / 2 - 1.5, 2.4) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.08, 0.08)), Vector3.new(3.4, h2 + 1.5, 4.8), vary(c, rng, 0.12), M.Basalt)
	P(m, { ClassName = "WedgePart", Size = Vector3.new(3.2, 2.6, 4.4), CFrame = CFrame.new(0, h1 + 1.1, -2.3) * CFrame.Angles(0, if rng:NextNumber() < 0.5 then 0 else math.pi, 0), Color = vary(c, rng, 0.1), Material = M.Slate, CanCollide = true })
	block(m, CFrame.new(-1.9, 0.5, rng:NextNumber(-3, 3)) * CFrame.Angles(0.2, rng:NextNumber(0, 6), 0.4), Vector3.new(2, 2.2, 2.2), vary(c, rng, 0.15), M.Basalt)
end

-- Low mossy stone edging with leaves spilling over (Verdantwild).
K.OvergrownEdge = function(m, rng, o)
	local c = o.stone
	block(m, CFrame.new(0, 0.4, -2.3) * CFrame.Angles(0, rng:NextNumber(-0.08, 0.08), 0), Vector3.new(2.4, 2.8, 4.8), vary(c, rng, 0.12), M.Slate)
	block(m, CFrame.new(0.1, 0.2, 2.3) * CFrame.Angles(0, rng:NextNumber(-0.08, 0.08), 0), Vector3.new(2.2, 2.4, 4.8), vary(c, rng, 0.12), M.Slate)
	for _ = 1, 2 do
		local p = P(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(2.2, 3.4), CFrame = CFrame.new(rng:NextNumber(-0.6, 0.6), 2, rng:NextNumber(-3.5, 3.5)), Color = vary(MOSS, rng, 0.25), Material = M.Grass, CanCollide = false })
		p.CastShadow = true
	end
	P(m, { ClassName = "WedgePart", Size = Vector3.new(0.3, 2.2, 3), CFrame = CFrame.new(1.4, 2.3, rng:NextNumber(-3, 3)) * CFrame.Angles(0.5, rng:NextNumber(0, 6), 0), Color = vary(rgb(60, 150, 70), rng, 0.2), Material = M.Grass, CanCollide = false })
end

-- One half-buried, irregular stone along the crest of a bank (one part).
K.EdgeStone = function(m, rng, o)
	local len, h, w = rng:NextNumber(6.5, 8.5), rng:NextNumber(2.2, 3.4), rng:NextNumber(2.2, 3.2)
	block(m, CFrame.new(0, h / 2 - 1.3, 0) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.12, 0.12)), Vector3.new(w, h + 1.3, len), vary(o.stone, rng, 0.14), o.edgeMaterial or M.Rock)
end

-- Stacked, wind-worn sandstone formation (Sunscar).
K.SandstoneStack = function(m, rng, o)
	local c = o.stone
	local y = -0.8
	local s = rng:NextNumber(3.6, 4.6)
	for i = 1, 3 do
		local h = rng:NextNumber(1.6, 2.6)
		block(m, CFrame.new(rng:NextNumber(-0.4, 0.4), y + h / 2, rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, rng:NextNumber(0, 6), rng:NextNumber(-0.08, 0.08)), Vector3.new(s, h, s * 0.85), vary(c, rng, 0.15), M.Sandstone)
		y += h
		s *= 0.72
	end
end

-- Exposed roots arching out of the bank (Whisperwood, Verdantwild, Mirehollow).
K.RootTangle = function(m, rng, o)
	local bark = rgb(92, 66, 46)
	for _ = 1, 3 do
		local len = rng:NextNumber(5, 8)
		local yaw = rng:NextNumber(0, math.pi * 2)
		P(m, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(len, rng:NextNumber(0.8, 1.3), rng:NextNumber(0.8, 1.3)),
			CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, rng:NextNumber(0.15, 0.45)),
			Color = vary(bark, rng, 0.2),
			Material = M.Wood,
			CanCollide = false,
		})
	end
end

-- A small leaning arch of pale stone (Starfall: unusual, restrained).
K.StoneArchlet = function(m, rng, o)
	local c = o.stone
	local h = rng:NextNumber(5, 7)
	block(m, CFrame.new(0, h / 2 - 0.5, -1.8) * CFrame.Angles(0.18, 0, rng:NextNumber(-0.05, 0.05)), Vector3.new(1.6, h, 1.6), vary(c, rng, 0.1), M.Limestone)
	block(m, CFrame.new(0, h / 2 - 0.5, 1.8) * CFrame.Angles(-0.18, 0, rng:NextNumber(-0.05, 0.05)), Vector3.new(1.6, h, 1.6), vary(c, rng, 0.1), M.Limestone)
	block(m, CFrame.new(0, h - 0.3, 0) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), Vector3.new(2, 1.1, 4.6), vary(c, rng, 0.1), M.Limestone)
end

-- The entrance language shared by every region: a carved waystone with a glowing gem in
-- the region's colour. Road gateways use a taller pair with lanterns.
K.Waystone = function(m, rng, o)
	local c = o.stone
	local h = 5.5
	block(m, CFrame.new(0, h / 2 - 1, 0) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0), Vector3.new(2, h + 2, 2), vary(c, rng, 0.08), M.Slate)
	block(m, CFrame.new(0, h + 0.4, 0) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(2.6, 0.8, 2.6), vary(c, rng, 0.08), M.Slate)
	local gem = P(m, { Size = Vector3.new(0.9, 1.4, 0.9), CFrame = CFrame.new(0, h + 1.5, 0) * CFrame.Angles(0, math.rad(45), 0), Color = o.glow, Material = M.Neon, CanCollide = false, CastShadow = false })
	if o.lantern then
		local light = Instance.new("PointLight")
		light.Color = o.glow
		light.Range = 14
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = gem
	end
end

-- Plank walkway across a swamp entrance (runs along local +Z, 26 studs).
K.Walkway = function(m, rng, o)
	for i = -2, 2 do
		block(m, CFrame.new(0, 0.6, i * 5.2) * CFrame.Angles(rng:NextNumber(-0.03, 0.03), rng:NextNumber(-0.05, 0.05), 0), Vector3.new(6, 0.5, 5), vary(WOOD, rng, 0.2), M.WoodPlanks)
	end
	for _, x in { -3.2, 3.2 } do
		block(m, CFrame.new(x, -0.4, 0), Vector3.new(0.6, 2.4, 26), vary(rgb(96, 70, 46), rng, 0.15), M.Wood)
	end
end

BorderKit.kinds = K

-- opts: { stone: Color3, glow: Color3, lantern: boolean? }
function BorderKit.build(kind: string, cf: CFrame, scale: number, seed: number, opts): Model?
	local fn = K[kind]
	if not fn then
		return Scenery.build(kind, cf, scale, seed)
	end
	local m = Instance.new("Model")
	m.Name = kind
	fn(m, Random.new(seed), opts or { stone = Color3.fromRGB(140, 138, 130), glow = Color3.fromRGB(120, 220, 255) })
	m.WorldPivot = CFrame.new()
	m:PivotTo(cf)
	if scale ~= 1 then
		m:ScaleTo(scale)
	end
	return m
end

return BorderKit
