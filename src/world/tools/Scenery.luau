--!nonstrict
-- Scenery (Studio tool): low-poly, Roblox-style vegetation and rocks built from parts.
-- Every builder makes a Model at the origin (ground at y = 0); the caller pivots and
-- scales it. All parts are anchored, never queryable or touchable (so build-mode
-- raycasts and remove mode ignore them), and only trunks/rocks collide.

local Scenery = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function vary(c: Color3, rng: Random, amount: number): Color3
	local k = 1 + (rng:NextNumber() - 0.5) * amount
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

function Scenery.part(model: Instance, props: { [string]: any }): BasePart
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = props.CastShadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "ClassName" and k ~= "CastShadow" then
			p[k] = v
		end
	end
	p.Parent = model
	return p
end
local P = Scenery.part

local function cyl(model, pos: Vector3, height: number, radius: number, color: Color3, material, props)
	local t = {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.Wood,
	}
	for k, v in props or {} do
		t[k] = v
	end
	return P(model, t)
end

local function ball(model, pos: Vector3, size: number, color: Color3, material, collide)
	return P(model, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(pos),
		Color = color,
		Material = material or Enum.Material.Grass,
		CanCollide = collide == true,
		CastShadow = true,
	})
end

local function block(model, cf: CFrame, size: Vector3, color: Color3, material, collide)
	return P(model, { Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.Rock, CanCollide = collide ~= false })
end

local function wedge(model, cf: CFrame, size: Vector3, color: Color3, material, collide)
	return P(model, { ClassName = "WedgePart", Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.Grass, CanCollide = collide == true })
end

local BARK = rgb(108, 76, 50)
local LEAF = rgb(84, 156, 66)

local K = {}

K.Oak = function(m, rng)
	local h = rng:NextNumber(9, 13)
	cyl(m, Vector3.new(0, h / 2, 0), h, 1.1, vary(BARK, rng, 0.2))
	local c = vary(LEAF, rng, 0.25)
	ball(m, Vector3.new(0, h + 2, 0), 11, c)
	ball(m, Vector3.new(3, h, 1.5), 8, vary(c, rng, 0.1))
	ball(m, Vector3.new(-2.5, h + 0.5, -2), 8, vary(c, rng, 0.1))
end

K.ForestTree = function(m, rng)
	local h = rng:NextNumber(14, 20)
	cyl(m, Vector3.new(0, h / 2, 0), h, 1.3, vary(rgb(86, 62, 44), rng, 0.2))
	local c = vary(rgb(52, 112, 56), rng, 0.25)
	ball(m, Vector3.new(0, h + 1, 0), 12, c)
	ball(m, Vector3.new(2.5, h - 3, 2), 9, vary(c, rng, 0.15))
	ball(m, Vector3.new(-3, h - 2, -1), 9, vary(c, rng, 0.15))
end

K.GiantTree = function(m, rng)
	local h = rng:NextNumber(28, 36)
	local bark = vary(rgb(80, 58, 42), rng, 0.15)
	cyl(m, Vector3.new(0, h / 2, 0), h, 3.2, bark)
	for i = 0, 3 do
		local a = i * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		wedge(m, CFrame.new(math.cos(a) * 4, 2, math.sin(a) * 4) * CFrame.Angles(0, -a + math.pi / 2, 0), Vector3.new(2, 4, 4), bark, Enum.Material.Wood, true)
	end
	local c = vary(rgb(46, 104, 52), rng, 0.2)
	ball(m, Vector3.new(0, h + 3, 0), 22, c)
	ball(m, Vector3.new(7, h - 2, 4), 15, vary(c, rng, 0.1))
	ball(m, Vector3.new(-6, h - 1, -5), 15, vary(c, rng, 0.1))
	ball(m, Vector3.new(2, h - 4, -8), 13, vary(c, rng, 0.1))
end

K.Shrub = function(m, rng)
	local c = vary(rgb(76, 140, 62), rng, 0.3)
	ball(m, Vector3.new(0, 1.5, 0), rng:NextNumber(3.5, 5), c)
	ball(m, Vector3.new(1.6, 1.1, 0.8), 3, vary(c, rng, 0.15))
end

local FLOWER = { rgb(255, 214, 90), rgb(255, 130, 170), rgb(170, 140, 255), rgb(255, 255, 255), rgb(255, 120, 90) }
K.Flowers = function(m, rng)
	for _ = 1, 4 do
		local x, z = rng:NextNumber(-3, 3), rng:NextNumber(-3, 3)
		P(m, { Size = Vector3.new(0.2, 1, 0.2), CFrame = CFrame.new(x, 0.5, z), Color = rgb(70, 140, 60), CanCollide = false, CastShadow = false })
		ball(m, Vector3.new(x, 1.1, z), 0.8, FLOWER[rng:NextInteger(1, #FLOWER)], Enum.Material.SmoothPlastic)
	end
end

local function rockLump(m, rng, color, material, size)
	local s = size or rng:NextNumber(3, 6)
	block(m, CFrame.new(0, s * 0.3, 0) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), Vector3.new(s, s * 0.8, s * 0.9), vary(color, rng, 0.15), material)
	block(m, CFrame.new(s * 0.45, s * 0.2, s * 0.2) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), 0.3), Vector3.new(s * 0.6, s * 0.5, s * 0.6), vary(color, rng, 0.15), material)
end

K.Rock = function(m, rng)
	rockLump(m, rng, rgb(126, 124, 120), Enum.Material.Rock)
end
K.MossyRock = function(m, rng)
	local s = rng:NextNumber(3.5, 6.5)
	rockLump(m, rng, rgb(110, 112, 104), Enum.Material.Rock, s)
	block(m, CFrame.new(0, s * 0.68, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(s * 0.8, 0.5, s * 0.7), rgb(70, 130, 60), Enum.Material.Grass, false)
end
K.SandRock = function(m, rng)
	rockLump(m, rng, rgb(196, 146, 96), Enum.Material.Sandstone)
end
K.SnowRock = function(m, rng)
	local s = rng:NextNumber(3.5, 7)
	rockLump(m, rng, rgb(120, 126, 136), Enum.Material.Rock, s)
	block(m, CFrame.new(0, s * 0.66, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(s * 0.9, 0.7, s * 0.8), rgb(246, 248, 252), Enum.Material.Snow, false)
end
K.AshRock = function(m, rng)
	rockLump(m, rng, rgb(54, 50, 52), Enum.Material.Basalt)
end
K.PaleRock = function(m, rng)
	rockLump(m, rng, rgb(214, 208, 226), Enum.Material.Limestone)
end
K.JaggedRock = function(m, rng)
	local h = rng:NextNumber(10, 20)
	local c = vary(rgb(62, 62, 72), rng, 0.15)
	wedge(m, CFrame.new(0, h / 2, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(4, h, 6), c, Enum.Material.Slate, true)
	wedge(m, CFrame.new(2, h / 3, 1) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.2), Vector3.new(3, h * 0.65, 4), vary(c, rng, 0.1), Enum.Material.Slate, true)
end

K.Log = function(m, rng)
	local l = rng:NextNumber(8, 14)
	P(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(l, 2.2, 2.2), CFrame = CFrame.new(0, 1, 0), Color = vary(rgb(98, 72, 50), rng, 0.2), Material = Enum.Material.Wood })
	block(m, CFrame.new(l * 0.2, 2.15, 0), Vector3.new(l * 0.4, 0.3, 1.4), rgb(80, 140, 64), Enum.Material.Grass, false)
end

K.Cactus = function(m, rng)
	local h = rng:NextNumber(6, 10)
	local c = vary(rgb(84, 140, 70), rng, 0.15)
	cyl(m, Vector3.new(0, h / 2, 0), h, 0.9, c, Enum.Material.Grass)
	cyl(m, Vector3.new(1.6, h * 0.55, 0), 1.6, 0.6, c, Enum.Material.Grass, { CFrame = CFrame.new(1.2, h * 0.5, 0) })
	cyl(m, Vector3.new(1.9, h * 0.65, 0), h * 0.35, 0.6, c, Enum.Material.Grass)
	cyl(m, Vector3.new(-1.7, h * 0.45, 0), h * 0.3, 0.55, c, Enum.Material.Grass)
end
K.DesertShrub = function(m, rng)
	ball(m, Vector3.new(0, 1, 0), rng:NextNumber(2.5, 4), vary(rgb(150, 140, 80), rng, 0.2))
end
K.DeadTree = function(m, rng)
	local h = rng:NextNumber(8, 13)
	local c = vary(rgb(96, 84, 74), rng, 0.2)
	cyl(m, Vector3.new(0, h / 2, 0), h, 0.7, c)
	cyl(m, Vector3.new(0, 0, 0), h * 0.4, 0.4, c, nil, { CFrame = CFrame.new(1.2, h * 0.75, 0) * CFrame.Angles(0, 0, math.rad(40)) })
	cyl(m, Vector3.new(0, 0, 0), h * 0.35, 0.35, c, nil, { CFrame = CFrame.new(-1, h * 0.6, 0.5) * CFrame.Angles(0.3, 0, math.rad(135)) })
end

K.SwampTree = function(m, rng)
	local h = rng:NextNumber(10, 15)
	local bark = vary(rgb(70, 60, 46), rng, 0.2)
	cyl(m, Vector3.new(0, 0, 0), h, 1.1, bark, nil, { CFrame = CFrame.new(0.8, h / 2, 0) * CFrame.Angles(0, 0, math.rad(84)) })
	for i = 0, 2 do
		local a = i * 2.1
		wedge(m, CFrame.new(math.cos(a) * 1.8, 1, math.sin(a) * 1.8) * CFrame.Angles(0, -a + math.pi / 2, 0), Vector3.new(1, 2.5, 2.5), bark, Enum.Material.Wood, true)
	end
	local c = vary(rgb(86, 110, 60), rng, 0.2)
	ball(m, Vector3.new(1.5, h, 0), 10, c, Enum.Material.Grass)
	P(m, { Size = Vector3.new(0.3, 5, 6), CFrame = CFrame.new(1.5, h - 4.5, 0), Color = rgb(110, 130, 80), Material = Enum.Material.Grass, CanCollide = false, Transparency = 0.2 })
end
K.Reeds = function(m, rng)
	for _ = 1, 5 do
		local x, z = rng:NextNumber(-2, 2), rng:NextNumber(-2, 2)
		local h = rng:NextNumber(3, 5)
		P(m, { Size = Vector3.new(0.25, h, 0.25), CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), Color = vary(rgb(120, 140, 70), rng, 0.2), CanCollide = false, CastShadow = false })
		P(m, { Size = Vector3.new(0.45, 1, 0.45), CFrame = CFrame.new(x, h, z), Color = rgb(110, 76, 48), CanCollide = false, CastShadow = false })
	end
end

local function pineTiers(m, rng, h, leaf, snow)
	cyl(m, Vector3.new(0, h * 0.25, 0), h * 0.5, 0.8, vary(rgb(90, 64, 46), rng, 0.2))
	local tiers = 4
	for t = 0, tiers - 1 do
		local w = (1 - t / tiers) * h * 0.55 + 2
		local y = h * 0.25 + t * h * 0.18
		block(m, CFrame.new(0, y + 1.5, 0) * CFrame.Angles(0, math.rad(45 * (t % 2)), 0), Vector3.new(w, 3, w), vary(leaf, rng, 0.12), Enum.Material.Grass, false)
		if snow then
			block(m, CFrame.new(0, y + 3.1, 0) * CFrame.Angles(0, math.rad(45 * (t % 2)), 0), Vector3.new(w * 0.8, 0.4, w * 0.8), rgb(246, 248, 252), Enum.Material.Snow, false)
		end
	end
end
K.Pine = function(m, rng)
	pineTiers(m, rng, rng:NextNumber(14, 22), rgb(44, 96, 62), false)
end
K.SnowPine = function(m, rng)
	pineTiers(m, rng, rng:NextNumber(12, 18), rgb(52, 98, 74), true)
end

K.JungleTree = function(m, rng)
	local h = rng:NextNumber(22, 30)
	cyl(m, Vector3.new(0, h / 2, 0), h, 1.4, vary(rgb(120, 96, 70), rng, 0.15))
	local c = vary(rgb(36, 132, 58), rng, 0.2)
	P(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 20, 20), CFrame = CFrame.new(0, h, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = c, Material = Enum.Material.Grass, CanCollide = false })
	P(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 13, 13), CFrame = CFrame.new(1, h + 3, 1) * CFrame.Angles(0, 0, math.rad(90)), Color = vary(c, rng, 0.1), Material = Enum.Material.Grass, CanCollide = false })
	P(m, { Size = Vector3.new(0.3, h * 0.6, 0.3), CFrame = CFrame.new(4, h * 0.7, 0), Color = rgb(70, 130, 60), CanCollide = false, CastShadow = false })
	P(m, { Size = Vector3.new(0.3, h * 0.5, 0.3), CFrame = CFrame.new(-3, h * 0.75, 3), Color = rgb(70, 130, 60), CanCollide = false, CastShadow = false })
end
K.Palm = function(m, rng)
	local h = rng:NextNumber(14, 20)
	local bark = vary(rgb(150, 120, 80), rng, 0.15)
	local lean = rng:NextNumber(0.05, 0.18)
	local top = Vector3.new(0, 0, 0)
	for i = 0, 3 do
		local seg = h / 4
		local cf = CFrame.new(i * seg * lean * 4, i * seg + seg / 2, 0) * CFrame.Angles(0, 0, -lean * i)
		P(m, { Size = Vector3.new(1.4 - i * 0.15, seg + 0.4, 1.4 - i * 0.15), CFrame = cf, Color = bark, Material = Enum.Material.Wood })
		top = (cf * CFrame.new(0, seg / 2, 0)).Position
	end
	local leaf = vary(rgb(60, 150, 60), rng, 0.15)
	for i = 0, 5 do
		local a = i * math.pi / 3
		wedge(m, CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.new(0, -0.5, -4) * CFrame.Angles(math.rad(-15), 0, 0), Vector3.new(2.4, 1, 8), leaf)
	end
end
K.Fern = function(m, rng)
	local c = vary(rgb(56, 140, 64), rng, 0.2)
	for i = 0, 4 do
		local a = i * 1.26 + rng:NextNumber(-0.2, 0.2)
		wedge(m, CFrame.new(0, 1, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.6, -1.8) * CFrame.Angles(math.rad(30), 0, 0), Vector3.new(1.2, 0.4, 4), c)
	end
end
K.BigLeaf = function(m, rng)
	local c = vary(rgb(40, 120, 60), rng, 0.2)
	P(m, { Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(0, 2, 0), Color = rgb(60, 110, 50), CanCollide = false, CastShadow = false })
	for i = 0, 2 do
		local a = i * 2.1
		P(m, { Size = Vector3.new(3, 0.3, 5), CFrame = CFrame.new(0, 3.8, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -2) * CFrame.Angles(math.rad(20), 0, 0), Color = c, Material = Enum.Material.Grass, CanCollide = false })
	end
end

K.IceSpike = function(m, rng)
	local h = rng:NextNumber(6, 14)
	local c = rgb(170, 220, 250)
	wedge(m, CFrame.new(0, h / 2, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(2.5, h, 3), c, Enum.Material.Ice, true).Transparency = 0.15
	wedge(m, CFrame.new(1.5, h / 3, 0.5) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.25), Vector3.new(2, h * 0.6, 2.4), c, Enum.Material.Ice, true).Transparency = 0.15
end

K.BasaltSpire = function(m, rng)
	local h = rng:NextNumber(8, 18)
	local c = vary(rgb(48, 44, 48), rng, 0.15)
	for i = 0, 2 do
		local a = i * 2.1
		block(m, CFrame.new(math.cos(a) * 1.2, (h - i * 3) / 2, math.sin(a) * 1.2), Vector3.new(2, h - i * 3, 2), vary(c, rng, 0.1), Enum.Material.Basalt)
	end
end
K.SteamVent = function(m, rng)
	for i = 0, 4 do
		local a = i * 1.26
		block(m, CFrame.new(math.cos(a) * 2.2, 0.5, math.sin(a) * 2.2) * CFrame.Angles(0, a, 0.3), Vector3.new(2, 1.4, 1.4), rgb(60, 56, 56), Enum.Material.Basalt)
	end
	local core = P(m, { Size = Vector3.new(2, 0.3, 2), CFrame = CFrame.new(0, 0.2, 0), Color = rgb(255, 120, 60), Material = Enum.Material.Neon, CanCollide = false })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(rgb(200, 200, 200))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) })
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = 4
	e.Speed = NumberRange.new(4, 7)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Parent = core
end

local CRYSTAL = { rgb(150, 120, 255), rgb(110, 200, 255), rgb(230, 140, 255) }
K.Crystal = function(m, rng)
	local c = CRYSTAL[rng:NextInteger(1, #CRYSTAL)]
	for i = 0, 2 do
		local h = rng:NextNumber(3, 8) * (1 - i * 0.25)
		local p = wedge(m, CFrame.new(rng:NextNumber(-1.5, 1.5), h / 2, rng:NextNumber(-1.5, 1.5)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Vector3.new(1.4, h, 1.6), c, Enum.Material.Neon, true)
		p.Transparency = 0.1
		p.CastShadow = false
	end
end
K.GlowShroom = function(m, rng)
	for _ = 1, 3 do
		local x, z = rng:NextNumber(-2.5, 2.5), rng:NextNumber(-2.5, 2.5)
		local h = rng:NextNumber(1.5, 3.5)
		P(m, { Size = Vector3.new(0.5, h, 0.5), CFrame = CFrame.new(x, h / 2, z), Color = rgb(230, 226, 240), CanCollide = false, CastShadow = false })
		P(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, h * 0.9, h * 0.9), CFrame = CFrame.new(x, h, z) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(120, 220, 255), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	end
end
K.StarTree = function(m, rng)
	local h = rng:NextNumber(10, 15)
	cyl(m, Vector3.new(0, h / 2, 0), h, 0.8, rgb(220, 214, 236), Enum.Material.Marble)
	local c = CRYSTAL[rng:NextInteger(1, #CRYSTAL)]
	local crown = ball(m, Vector3.new(0, h + 2, 0), 9, c, Enum.Material.Glass)
	crown.Transparency = 0.25
	ball(m, Vector3.new(0, h + 2, 0), 3, rgb(255, 255, 255), Enum.Material.Neon)
end

Scenery.kinds = K

-- Build one item. Returns the model (unparented) or nil for unknown kinds.
function Scenery.build(kind: string, cf: CFrame, scale: number, seed: number): Model?
	local fn = K[kind]
	if not fn then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = kind
	fn(m, Random.new(seed))
	m.WorldPivot = CFrame.new() -- built around the origin with the ground at y = 0
	m:PivotTo(cf)
	if scale ~= 1 then
		m:ScaleTo(scale)
	end
	return m
end

return Scenery
