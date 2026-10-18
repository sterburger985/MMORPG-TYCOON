--!nonstrict
-- Landmarks (Studio tool): the hand-designed set pieces of each region, plus bridges and
-- region signposts. Built from parts around the origin (ground at y = 0); the builder
-- places them. Like Scenery, nothing here is queryable, so build mode can't touch it.

local Scenery = require(script.Parent.Scenery)
local P = Scenery.part

local Landmarks = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local M = Enum.Material

local function block(m, cf, size, color, material, collide)
	return P(m, { Size = size, CFrame = cf, Color = color, Material = material or M.Rock, CanCollide = collide ~= false })
end
local function cyl(m, cf, height, radius, color, material, collide)
	return P(m, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or M.Rock,
		CanCollide = collide ~= false,
	})
end
local function ball(m, pos, size, color, material, collide)
	return P(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(pos), Color = color, Material = material or M.Grass, CanCollide = collide == true })
end
local function wedge(m, cf, size, color, material, collide)
	return P(m, { ClassName = "WedgePart", Size = size, CFrame = cf, Color = color, Material = material or M.Rock, CanCollide = collide ~= false })
end
local function light(part: BasePart, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = part
end
local function glow(m, pos, size, color)
	local p = ball(m, pos, size, color, M.Neon, false)
	p.CastShadow = false
	light(p, color, size * 4)
	return p
end

-- Floating name label shown when close.
local function nameLabel(m: Model, text: string, height: number)
	local anchor = P(m, { Name = "LabelAnchor", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, height, 0), Transparency = 1, CanCollide = false, CastShadow = false })
	local gui = Instance.new("BillboardGui")
	gui.Name = "LandmarkLabel"
	gui.Size = UDim2.fromScale(28, 5)
	gui.MaxDistance = 260
	gui.LightInfluence = 0
	gui.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = rgb(255, 255, 255)
	t.TextStrokeColor3 = rgb(8, 24, 70)
	t.TextStrokeTransparency = 0.2
	t.Text = text
	t.Parent = gui
end

local L = {}

local STONE = rgb(150, 148, 140)
local MOSS = rgb(86, 140, 70)

-- 1 Greenhaven: an enormous oak inside a ring of standing stones.
L.ElderOak = function(m, rng)
	local bark = rgb(104, 74, 50)
	cyl(m, CFrame.new(0, 24, 0), 48, 5.5, bark, M.Wood)
	for i = 0, 5 do
		local a = i * math.pi / 3 + 0.3
		wedge(m, CFrame.new(math.cos(a) * 6.5, 3, math.sin(a) * 6.5) * CFrame.Angles(0, -a + math.pi / 2, 0), Vector3.new(3, 6, 6), bark, M.Wood)
	end
	cyl(m, CFrame.new(5, 38, 0) * CFrame.Angles(0, 0, math.rad(-35)), 18, 2.2, bark, M.Wood)
	cyl(m, CFrame.new(-5, 36, 3) * CFrame.Angles(0.4, 0, math.rad(35)), 16, 2, bark, M.Wood)
	local leaf = rgb(88, 160, 70)
	ball(m, Vector3.new(0, 54, 0), 40, leaf)
	ball(m, Vector3.new(16, 48, 6), 28, rgb(96, 170, 74))
	ball(m, Vector3.new(-15, 47, -8), 28, rgb(80, 150, 64))
	ball(m, Vector3.new(4, 46, -17), 24, rgb(92, 166, 70))
	ball(m, Vector3.new(-6, 49, 16), 24, rgb(84, 156, 68))
	for i = 0, 9 do
		local a = i * math.pi * 2 / 10
		local r = 30
		local h = rng:NextNumber(8, 12)
		block(m, CFrame.new(math.cos(a) * r, h / 2 - 0.5, math.sin(a) * r) * CFrame.Angles(0, -a, rng:NextNumber(-0.06, 0.06)), Vector3.new(2.5, h, 4), STONE)
		if i % 2 == 0 then
			local a2 = (i + 1) * math.pi * 2 / 10
			local mid = (a + a2) / 2
			block(m, CFrame.new(math.cos(mid) * r, h + 0.5, math.sin(mid) * r) * CFrame.Angles(0, -mid + math.pi / 2, 0), Vector3.new(20, 2, 3), STONE)
		end
	end
	nameLabel(m, "The Elder Oak", 82)
end

-- 2 Whisperwood: Heartroot, a colossal tree with buttress roots and glowing motes.
L.Heartroot = function(m, rng)
	local bark = rgb(78, 58, 44)
	cyl(m, CFrame.new(0, 36, 0), 72, 9, bark, M.Wood)
	for i = 0, 7 do
		local a = i * math.pi / 4 + 0.2
		wedge(m, CFrame.new(math.cos(a) * 11, 6, math.sin(a) * 11) * CFrame.Angles(0, -a + math.pi / 2, 0), Vector3.new(4, 12, 12), bark, M.Wood)
	end
	local leaf = rgb(44, 104, 54)
	ball(m, Vector3.new(0, 82, 0), 56, leaf)
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		ball(m, Vector3.new(math.cos(a) * 24, 70 + rng:NextNumber(-4, 4), math.sin(a) * 24), 36, rgb(40 + i * 4, 98, 52))
	end
	for i = 0, 7 do
		local a = i * 0.8
		P(m, { Size = Vector3.new(0.5, 26, 0.5), CFrame = CFrame.new(math.cos(a) * 26, 56, math.sin(a) * 26), Color = rgb(70, 130, 60), CanCollide = false, CastShadow = false })
	end
	for i = 0, 5 do
		local a = i * 1.05
		glow(m, Vector3.new(math.cos(a) * 18, 14 + i * 3, math.sin(a) * 18), 0.8, rgb(190, 255, 150))
	end
	nameLabel(m, "Heartroot", 116)
end

L.ForestRuins = function(m, rng)
	for i = 0, 6 do
		local a = i * math.pi * 2 / 7
		local h = rng:NextNumber(6, 18)
		local p = cyl(m, CFrame.new(math.cos(a) * 16, h / 2, math.sin(a) * 16), h, 1.8, rgb(140, 140, 130), M.Cobblestone)
		block(m, CFrame.new(math.cos(a) * 16, h + 0.3, math.sin(a) * 16), Vector3.new(4.5, 0.6, 4.5), MOSS, M.Grass, false)
		p.Name = "Pillar"
	end
	block(m, CFrame.new(-8, 9, 0), Vector3.new(3, 18, 3), STONE, M.Cobblestone)
	block(m, CFrame.new(8, 9, 0), Vector3.new(3, 18, 3), STONE, M.Cobblestone)
	block(m, CFrame.new(0, 19, 0), Vector3.new(21, 3, 4), STONE, M.Cobblestone)
	block(m, CFrame.new(0, 20.7, 0), Vector3.new(19, 0.6, 4.4), MOSS, M.Grass, false)
	cyl(m, CFrame.new(5, 1.8, 11) * CFrame.Angles(0, 0.6, math.rad(90)), 14, 1.8, rgb(140, 140, 130), M.Cobblestone)
	block(m, CFrame.new(0, 0.3, 0), Vector3.new(30, 0.6, 30), rgb(120, 118, 110), M.Cobblestone)
	nameLabel(m, "Overgrown Ruins", 28)
end

-- 3 Sunscar: a huge natural sandstone arch.
L.SandstoneArch = function(m, rng)
	local sand = rgb(204, 146, 92)
	for side = -1, 1, 2 do
		for i = 0, 5 do
			local w = 16 - i * 1.2
			block(m, CFrame.new(side * 34 + rng:NextNumber(-1.5, 1.5), 4 + i * 8, rng:NextNumber(-1.5, 1.5)) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), Vector3.new(w, 9, 14 - i * 0.6), sand, M.Sandstone)
		end
	end
	local segs = 10
	for i = 0, segs do
		local t = i / segs
		local a = math.pi * t
		local x = -math.cos(a) * 31
		local y = 48 + math.sin(a) * 16
		block(m, CFrame.new(x, y, 0) * CFrame.Angles(0, 0, -(a - math.pi / 2)), Vector3.new(9, 9, 12), sand, M.Sandstone)
	end
	block(m, CFrame.new(-36, 2, 18) * CFrame.Angles(0.3, 0.5, 0.2), Vector3.new(10, 6, 8), sand, M.Sandstone)
	nameLabel(m, "The Sunscar Arch", 74)
end

L.DesertRuins = function(m, rng)
	local c = rgb(214, 180, 120)
	block(m, CFrame.new(0, 1.5, 0), Vector3.new(44, 3, 30), c, M.Sandstone)
	block(m, CFrame.new(0, 3.5, -6), Vector3.new(36, 1, 16), c, M.Sandstone)
	for i = 0, 5 do
		for side = -1, 1, 2 do
			local h = rng:NextNumber(4, 16)
			cyl(m, CFrame.new(-17 + i * 6.8, 3 + h / 2, side * 11), h, 1.5, c, M.Sandstone)
		end
	end
	for s = 0, 3 do
		block(m, CFrame.new(0, 0.4 + s * 0.8, 15 + 3 + s * -1.5), Vector3.new(12, 0.8, 3), c, M.Sandstone)
	end
	ball(m, Vector3.new(0, 7, -10), 7, rgb(190, 150, 100), M.Sandstone, true)
	nameLabel(m, "Sunken Temple", 26)
end

-- 4 Mirehollow: a leaning ruined tower with a boardwalk.
L.DrownedTower = function(m, rng)
	local stone = rgb(104, 110, 100)
	local lean = CFrame.Angles(0, 0, math.rad(6))
	for i = 0, 6 do
		local h = 7
		local cf = lean * CFrame.new(0, 3.5 + i * h, 0)
		if i < 6 then
			cyl(m, cf, h, 8 - i * 0.3, i % 2 == 0 and stone or rgb(94, 102, 92), M.Cobblestone)
		else
			for k = 0, 4 do
				local a = k * 1.26
				block(m, cf * CFrame.new(math.cos(a) * 6, rng:NextNumber(-2, 2), math.sin(a) * 6), Vector3.new(3, rng:NextNumber(4, 8), 3), stone, M.Cobblestone)
			end
		end
		if i > 0 and i < 6 then
			block(m, cf * CFrame.new(0, 0, -7.8), Vector3.new(2, 3, 0.6), rgb(20, 24, 22), M.SmoothPlastic, false)
		end
	end
	glow(m, (lean * CFrame.new(0, 40, -8)).Position, 1.2, rgb(150, 255, 170))
	for i = 0, 7 do
		local a = i * math.pi / 4
		block(m, CFrame.new(math.cos(a) * 13, 0.8, math.sin(a) * 13) * CFrame.Angles(0, -a, 0), Vector3.new(4, 0.5, 9), rgb(120, 92, 62), M.WoodPlanks)
		block(m, CFrame.new(math.cos(a) * 15, -1, math.sin(a) * 15), Vector3.new(0.8, 4, 0.8), rgb(90, 70, 50), M.Wood)
	end
	block(m, CFrame.new(0, 1.2, 22), Vector3.new(4, 0.5, 18), rgb(120, 92, 62), M.WoodPlanks)
	nameLabel(m, "The Drowned Tower", 56)
end

-- 5 Frostpeak: a stone shrine on a high plateau with a sacred brazier.
L.MountainShrine = function(m, rng)
	local stone = rgb(170, 172, 180)
	block(m, CFrame.new(0, 1, 0), Vector3.new(30, 2, 30), stone, M.Slate)
	block(m, CFrame.new(0, 2.5, 0), Vector3.new(22, 1, 22), rgb(150, 150, 160), M.Slate)
	for _, p in { { -9, -9 }, { 9, -9 }, { -9, 9 }, { 9, 9 } } do
		block(m, CFrame.new(p[1], 9, p[2]), Vector3.new(2.5, 14, 2.5), stone, M.Slate)
	end
	block(m, CFrame.new(0, 16.5, 0), Vector3.new(24, 1.5, 24), rgb(120, 70, 60), M.Slate)
	wedge(m, CFrame.new(0, 19.5, -6), Vector3.new(24, 5, 12), rgb(150, 60, 50), M.Slate)
	wedge(m, CFrame.new(0, 19.5, 6) * CFrame.Angles(0, math.pi, 0), Vector3.new(24, 5, 12), rgb(150, 60, 50), M.Slate)
	cyl(m, CFrame.new(0, 4, 0), 3, 2.5, rgb(80, 80, 90), M.Metal)
	local fire = glow(m, Vector3.new(0, 6.5, 0), 2.6, rgb(120, 200, 255))
	fire.Name = "SkyFlame"
	for i = 0, 5 do
		P(m, { Size = Vector3.new(2, 1.4, 0.1), CFrame = CFrame.new(-10 + i * 4, 13, 12.5), Color = ({ rgb(255, 90, 90), rgb(255, 210, 90), rgb(90, 200, 255) })[i % 3 + 1], CanCollide = false, CastShadow = false })
	end
	nameLabel(m, "Skyward Shrine", 30)
end

-- Waterfall set piece: cliff face, falling water sheet, foam and mist.
L.Waterfall = function(m, rng)
	local rock = rgb(110, 112, 118)
	for i = 0, 5 do
		block(m, CFrame.new(rng:NextNumber(-14, 14), 6 + i * 5, -6 + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), Vector3.new(rng:NextNumber(10, 16), 8, 10), rock)
	end
	block(m, CFrame.new(-12, 18, -2), Vector3.new(8, 36, 10), rock)
	block(m, CFrame.new(12, 18, -2), Vector3.new(8, 36, 10), rock)
	local sheet = P(m, { Name = "Water", Size = Vector3.new(14, 34, 1), CFrame = CFrame.new(0, 18, 3.6), Color = rgb(150, 210, 240), Material = M.Glass, Transparency = 0.25, CanCollide = false, CastShadow = false })
	local foam = P(m, { Size = Vector3.new(18, 1, 8), CFrame = CFrame.new(0, 0.5, 7), Color = rgb(240, 250, 255), Material = M.Neon, Transparency = 0.5, CanCollide = false, CastShadow = false })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(rgb(255, 255, 255))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	e.Lifetime = NumberRange.new(2, 3)
	e.Rate = 8
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Parent = foam
	local tex = Instance.new("Texture")
	tex.Texture = "rbxasset://textures/water_Normal.dds"
	tex.Face = Enum.NormalId.Front
	tex.StudsPerTileU = 8
	tex.StudsPerTileV = 8
	tex.Transparency = 0.4
	tex.Parent = sheet
end

-- 6 Verdantwild: stepped temple with a stair and shrine.
L.JungleTemple = function(m, rng)
	local stone = rgb(170, 160, 128)
	local tiers = 5
	for t = 0, tiers - 1 do
		local w = 64 - t * 11
		block(m, CFrame.new(0, 4 + t * 8, 0), Vector3.new(w, 8, w), t % 2 == 0 and stone or rgb(156, 148, 118), M.Limestone)
		block(m, CFrame.new(0, 8.3 + t * 8, 0), Vector3.new(w - 1, 0.6, w - 1), MOSS, M.Grass, false)
	end
	for s = 0, 19 do
		block(m, CFrame.new(0, 1 + s * 2, 33 - s * 2.2), Vector3.new(12, 2, 3), rgb(160, 150, 120), M.Limestone)
	end
	block(m, CFrame.new(0, 48, 0), Vector3.new(16, 12, 16), stone, M.Limestone)
	block(m, CFrame.new(0, 46, 8.1), Vector3.new(5, 8, 0.4), rgb(20, 18, 14), M.SmoothPlastic, false)
	wedge(m, CFrame.new(0, 56, -4), Vector3.new(18, 4, 8), rgb(140, 130, 100), M.Limestone)
	wedge(m, CFrame.new(0, 56, 4) * CFrame.Angles(0, math.pi, 0), Vector3.new(18, 4, 8), rgb(140, 130, 100), M.Limestone)
	glow(m, Vector3.new(0, 47, 4), 1.6, rgb(120, 255, 170))
	for i = 0, 9 do
		local a = i * 0.63
		P(m, { Size = Vector3.new(0.4, rng:NextNumber(10, 22), 0.4), CFrame = CFrame.new(math.cos(a) * 26, 26, math.sin(a) * 26), Color = rgb(60, 130, 56), CanCollide = false, CastShadow = false })
	end
	nameLabel(m, "Temple of the Canopy", 66)
end

-- 7 Glacial: towering translucent ice spires and a frozen fall.
L.IceSpires = function(m, rng)
	for i = 0, 8 do
		local a = i * math.pi * 2 / 9 + rng:NextNumber(-0.2, 0.2)
		local r = if i == 0 then 0 else rng:NextNumber(14, 30)
		local h = if i == 0 then 80 else rng:NextNumber(26, 56)
		local p = wedge(m, CFrame.new(math.cos(a) * r, h / 2, math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, 6), 0), Vector3.new(h * 0.16, h, h * 0.2), rgb(170, 222, 252), M.Ice)
		p.Transparency = 0.12
		local q = wedge(m, CFrame.new(math.cos(a) * r, h / 2, math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, 6) + math.pi, 0), Vector3.new(h * 0.14, h * 0.9, h * 0.18), rgb(200, 236, 255), M.Glacier)
		q.Transparency = 0.1
	end
	glow(m, Vector3.new(0, 12, 0), 3, rgb(160, 230, 255))
	nameLabel(m, "The Frozen Spires", 90)
end

L.IceCave = function(m, rng)
	local ice = rgb(180, 226, 250)
	for i = 0, 8 do
		local a = math.pi * i / 8
		block(m, CFrame.new(math.cos(a) * 14, math.sin(a) * 14, 0) * CFrame.Angles(0, 0, a), Vector3.new(6, 7, 18), ice, M.Glacier)
	end
	block(m, CFrame.new(0, 0, -10), Vector3.new(30, 26, 4), rgb(140, 190, 220), M.Glacier)
	for i = 0, 4 do
		local s = wedge(m, CFrame.new(-8 + i * 4, 9, 5) * CFrame.Angles(math.pi, 0, 0), Vector3.new(1.2, 5, 1.2), rgb(220, 244, 255), M.Ice, false)
		s.Transparency = 0.2
	end
	glow(m, Vector3.new(0, 4, -6), 1.5, rgb(140, 220, 255))
	nameLabel(m, "Rime Cave", 26)
end

-- 8 Ashenreach: the crater's details (the bowl itself is terrain).
L.Crater = function(m, rng)
	for i = 0, 5 do
		local a = i * 1.05
		local p = glow(m, Vector3.new(math.cos(a) * rng:NextNumber(10, 50), 1, math.sin(a) * rng:NextNumber(10, 50)), 3, rgb(255, 110, 40))
		p.Transparency = 0.2
	end
	local core = P(m, { Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(0, 0.5, 0), Transparency = 1, CanCollide = false })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(rgb(120, 110, 110))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 30) })
	e.Lifetime = NumberRange.new(6, 9)
	e.Rate = 3
	e.Speed = NumberRange.new(6, 10)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Parent = core
	nameLabel(m, "The Cinder Maw", 40)
end

L.AshFortress = function(m, rng)
	local c = rgb(66, 60, 62)
	local s = 26
	for side = 0, 3 do
		local a = side * math.pi / 2
		for k = -2, 2 do
			if not (side == 0 and k == 0) and rng:NextNumber() > 0.2 then
				local h = rng:NextNumber(6, 16)
				local cf = CFrame.Angles(0, a, 0) * CFrame.new(k * 10, h / 2, s)
				block(m, cf, Vector3.new(10, h, 4), c, M.Cobblestone)
			end
		end
		local tower = CFrame.Angles(0, a, 0) * CFrame.new(s, 0, s)
		local th = rng:NextNumber(14, 26)
		cyl(m, tower * CFrame.new(0, th / 2, 0), th, 5, rgb(58, 52, 54), M.Cobblestone)
	end
	glow(m, Vector3.new(0, 3, 0), 2, rgb(255, 120, 60))
	nameLabel(m, "Ruins of Ash Keep", 32)
end

-- 9 Starfall: observatory and the giant crystal with floating rocks.
L.Observatory = function(m, rng)
	local marble = rgb(232, 228, 242)
	cyl(m, CFrame.new(0, 7, 0), 14, 15, marble, M.Marble)
	cyl(m, CFrame.new(0, 14.4, 0), 1, 16, rgb(140, 120, 220), M.Neon, true).CastShadow = false
	local dome = ball(m, Vector3.new(0, 15, 0), 28, rgb(120, 110, 180), M.Glass, true)
	dome.Transparency = 0.15
	cyl(m, CFrame.new(6, 26, 0) * CFrame.Angles(0, 0, math.rad(-50)), 22, 2.2, rgb(200, 180, 120), M.Metal)
	for s = 0, 6 do
		block(m, CFrame.new(0, 0.5 + s, 17 + 6 - s * 1.2), Vector3.new(8, 1, 2), marble, M.Marble)
	end
	for i = 0, 5 do
		local a = i * 1.05
		cyl(m, CFrame.new(math.cos(a) * 24, 5, math.sin(a) * 24), 10, 1.2, marble, M.Marble)
		glow(m, Vector3.new(math.cos(a) * 24, 10.8, math.sin(a) * 24), 1.4, rgb(170, 140, 255))
	end
	nameLabel(m, "Starfall Observatory", 44)
end

L.GiantCrystal = function(m, rng)
	local c = rgb(150, 120, 255)
	local main = wedge(m, CFrame.new(0, 22, 0) * CFrame.Angles(0, 0.4, 0.05), Vector3.new(9, 44, 10), c, M.Neon, true)
	main.CastShadow = false
	light(main, c, 60, 2.5)
	wedge(m, CFrame.new(0, 20, 0) * CFrame.Angles(0, 0.4 + math.pi, -0.05), Vector3.new(9, 40, 10), rgb(170, 140, 255), M.Neon, true).CastShadow = false
	for i = 0, 6 do
		local a = i * math.pi * 2 / 7
		local h = rng:NextNumber(10, 22)
		wedge(m, CFrame.new(math.cos(a) * 9, h / 2, math.sin(a) * 9) * CFrame.Angles(math.sin(a) * 0.35, a, -math.cos(a) * 0.35), Vector3.new(3.5, h, 4), ({ c, rgb(110, 200, 255), rgb(230, 140, 255) })[i % 3 + 1], M.Neon, true).CastShadow = false
	end
	for i = 0, 2 do
		local a = i * 2.1
		local pos = Vector3.new(math.cos(a) * 26, 34 + i * 6, math.sin(a) * 26)
		block(m, CFrame.new(pos) * CFrame.Angles(0.2, a, 0.1), Vector3.new(10, 6, 9), rgb(200, 194, 214), M.Limestone)
		wedge(m, CFrame.new(pos + Vector3.new(0, -5, 0)) * CFrame.Angles(math.pi, a, 0), Vector3.new(8, 6, 7), rgb(180, 172, 200), M.Limestone)
		wedge(m, CFrame.new(pos + Vector3.new(0, 5, 0)), Vector3.new(2, 5, 2.4), c, M.Neon, false).CastShadow = false
	end
	nameLabel(m, "The Starheart Crystal", 56)
end

-- 10 Dragon's End: the citadel and a pass through a dragon's ribcage.
L.Citadel = function(m, rng)
	local stone = rgb(70, 66, 76)
	local dark = rgb(50, 46, 56)
	local R = 52
	block(m, CFrame.new(0, 1.5, 0), Vector3.new(R * 2 + 30, 3, R * 2 + 30), rgb(60, 58, 64), M.Slate)
	for side = 0, 3 do
		local a = side * math.pi / 2
		for k = -4, 4 do
			if not (side == 0 and math.abs(k) <= 1) then
				block(m, CFrame.Angles(0, a, 0) * CFrame.new(k * 12, 14, R), Vector3.new(12, 24, 7), stone, M.Slate)
				if k % 2 == 0 then
					block(m, CFrame.Angles(0, a, 0) * CFrame.new(k * 12, 28, R), Vector3.new(5, 4, 7), stone, M.Slate)
				end
			end
		end
		local tower = CFrame.Angles(0, a, 0) * CFrame.new(R, 0, R)
		cyl(m, tower * CFrame.new(0, 24, 0), 48, 10, dark, M.Slate)
		wedge(m, tower * CFrame.new(0, 54, -5), Vector3.new(22, 12, 10), rgb(120, 30, 40), M.Slate)
		wedge(m, tower * CFrame.new(0, 54, 5) * CFrame.Angles(0, math.pi, 0), Vector3.new(22, 12, 10), rgb(120, 30, 40), M.Slate)
		glow(m, (tower * CFrame.new(0, 49, 10.5)).Position, 1.6, rgb(255, 120, 60))
	end
	-- gatehouse (faces +Z, towards the approach road)
	block(m, CFrame.new(-14, 18, R), Vector3.new(10, 36, 12), dark, M.Slate)
	block(m, CFrame.new(14, 18, R), Vector3.new(10, 36, 12), dark, M.Slate)
	block(m, CFrame.new(0, 31, R), Vector3.new(18, 10, 12), dark, M.Slate)
	P(m, { Size = Vector3.new(16, 0.6, 30), CFrame = CFrame.new(0, 3.3, R + 14), Color = rgb(80, 76, 84), Material = M.Cobblestone })
	-- keep and the great tower
	block(m, CFrame.new(0, 22, -8), Vector3.new(44, 40, 40), stone, M.Slate)
	block(m, CFrame.new(0, 43, -8), Vector3.new(46, 2, 42), dark, M.Slate)
	cyl(m, CFrame.new(0, 66, -8), 50, 9, dark, M.Slate)
	wedge(m, CFrame.new(0, 97, -12), Vector3.new(20, 14, 8), rgb(130, 30, 40), M.Slate)
	wedge(m, CFrame.new(0, 97, -4) * CFrame.Angles(0, math.pi, 0), Vector3.new(20, 14, 8), rgb(130, 30, 40), M.Slate)
	block(m, CFrame.new(0, 16, 12.2), Vector3.new(10, 16, 0.6), rgb(20, 16, 22), M.SmoothPlastic, false)
	for i = -1, 1, 2 do
		P(m, { Size = Vector3.new(6, 18, 0.2), CFrame = CFrame.new(i * 15, 32, 12.4), Color = rgb(150, 30, 40), Material = M.Fabric, CanCollide = false })
	end
	glow(m, Vector3.new(0, 86, 1.5), 3, rgb(255, 100, 60))
	nameLabel(m, "The Dragon Citadel", 116)
end

L.Dragonbones = function(m, rng)
	local bone = rgb(232, 224, 204)
	for i = 0, 5 do
		local z = -20 + i * 8
		for side = -1, 1, 2 do
			for s = 0, 3 do
				local a = s * 0.42
				local x = side * (14 - s * 1.5 - math.sin(a) * 4)
				local y = 4 + s * 7
				P(m, { Size = Vector3.new(2.2, 8, 2.2), CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, side * (0.15 + s * 0.35)), Color = bone, Material = M.Marble })
			end
		end
	end
	P(m, { Size = Vector3.new(3, 3, 52), CFrame = CFrame.new(0, 29, 0), Color = bone, Material = M.Marble })
	-- skull
	block(m, CFrame.new(0, 6, 34), Vector3.new(14, 10, 16), bone, M.Marble)
	wedge(m, CFrame.new(0, 4, 46) * CFrame.Angles(0, math.pi, 0), Vector3.new(12, 6, 10), bone, M.Marble)
	for side = -1, 1, 2 do
		block(m, CFrame.new(side * 4, 8, 42), Vector3.new(3, 2.5, 0.6), rgb(30, 20, 20), M.SmoothPlastic, false)
		wedge(m, CFrame.new(side * 6, 14, 28) * CFrame.Angles(-0.5, 0, 0), Vector3.new(2, 10, 3), bone, M.Marble)
	end
	nameLabel(m, "Dragonbone Pass", 38)
end

Landmarks.kinds = L

function Landmarks.build(kind: string, cf: CFrame, seed: number): Model?
	local fn = L[kind]
	if not fn then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = kind
	fn(m, Random.new(seed))
	m.WorldPivot = CFrame.new()
	m:PivotTo(cf)
	return m
end

-- Wooden bridge along local Z, deck top at y = 0.
function Landmarks.bridge(cf: CFrame, length: number): Model
	local m = Instance.new("Model")
	m.Name = "Bridge"
	local wood = rgb(130, 96, 62)
	P(m, { Size = Vector3.new(12, 1, length), CFrame = CFrame.new(0, -0.5, 0), Color = wood, Material = M.WoodPlanks })
	for side = -1, 1, 2 do
		P(m, { Size = Vector3.new(0.6, 0.6, length), CFrame = CFrame.new(side * 5.7, 3, 0), Color = rgb(110, 80, 52), Material = M.Wood })
		for k = 0, math.floor(length / 8) do
			local z = -length / 2 + k * (length / math.max(1, math.floor(length / 8)))
			P(m, { Size = Vector3.new(0.8, 3.4, 0.8), CFrame = CFrame.new(side * 5.7, 1.4, z), Color = rgb(100, 72, 48), Material = M.Wood })
			P(m, { Size = Vector3.new(1.2, 10, 1.2), CFrame = CFrame.new(side * 5.2, -6, z), Color = rgb(90, 66, 44), Material = M.Wood })
		end
	end
	m.WorldPivot = CFrame.new()
	m:PivotTo(cf)
	return m
end

-- Signpost naming the region (and its level range) on both faces.
function Landmarks.sign(cf: CFrame, title: string, subtitle: string, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "RegionSign"
	local wood = rgb(110, 80, 54)
	P(m, { Size = Vector3.new(1, 9, 1), CFrame = CFrame.new(-4.5, 4.5, 0), Color = wood, Material = M.Wood })
	P(m, { Size = Vector3.new(1, 9, 1), CFrame = CFrame.new(4.5, 4.5, 0), Color = wood, Material = M.Wood })
	local board = P(m, { Name = "Board", Size = Vector3.new(11, 4, 0.6), CFrame = CFrame.new(0, 7, 0), Color = rgb(70, 50, 36), Material = M.WoodPlanks })
	P(m, { Size = Vector3.new(11.6, 0.5, 0.8), CFrame = CFrame.new(0, 9.1, 0), Color = color, Material = M.SmoothPlastic })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		gui.Parent = board
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 0.62)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = rgb(255, 255, 255)
		t.TextStrokeColor3 = rgb(8, 24, 70)
		t.TextStrokeTransparency = 0.3
		t.Text = title
		t.Parent = gui
		local s = t:Clone()
		s.Position = UDim2.fromScale(0, 0.6)
		s.Size = UDim2.fromScale(1, 0.36)
		s.TextColor3 = color
		s.Text = subtitle
		s.Parent = gui
	end
	m.WorldPivot = CFrame.new()
	m:PivotTo(cf)
	return m
end

return Landmarks
