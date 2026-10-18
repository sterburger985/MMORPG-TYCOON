--!strict
-- Decor: small helpers for building scenery in code (both places). Scenery is decoration
-- only: anchored, never queryable, never touchable, so it can't interfere with building
-- or gameplay raycasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Decor = {}

function Decor.part(parent: Instance, props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- A flat disc (cylinder lying on the ground) centred at `position` (its top at position.Y).
function Decor.disc(parent: Instance, position: Vector3, radius: number, height: number, props: { [string]: any }): BasePart
	local p = table.clone(props)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, radius * 2, radius * 2)
	p.CFrame = CFrame.new(position - Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return Decor.part(parent, p)
end

-- Street lamp: dark iron pole, glowing lantern, warm light.
function Decor.lamp(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	local iron = Color3.fromRGB(46, 42, 48)
	Decor.part(model, { Name = "Base", Size = Vector3.new(1.6, 0.6, 1.6), CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)), Material = Enum.Material.Slate, Color = iron })
	Decor.part(model, {
		Name = "Pole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10, 0.5, 0.5),
		CFrame = CFrame.new(position + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = iron,
	})
	Decor.part(model, { Name = "Cap", Size = Vector3.new(1.8, 0.4, 1.8), CFrame = CFrame.new(position + Vector3.new(0, 12.4, 0)), Material = Enum.Material.Metal, Color = iron })
	local lantern = Decor.part(model, {
		Name = "Lantern",
		Size = Vector3.new(1.2, 1.6, 1.2),
		CFrame = CFrame.new(position + Vector3.new(0, 11.4, 0)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 196, 110),
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 120)
	light.Range = 18
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = lantern
	model.Parent = parent
end

-- Clone an approved item model (e.g. "OakTree") as scenery, optionally scaled and turned.
function Decor.prop(parent: Instance, modelName: string, position: Vector3, yaw: number, scale: number): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local items = assets and assets:FindFirstChild("Items")
	local template = items and items:FindFirstChild(modelName)
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw, 0))
	model.Parent = parent
	return model
end

-- A glowing gate arch facing +Z (its local front). Returns the model and its portal part.
function Decor.gate(parent: Instance, cframe: CFrame, glow: Color3, name: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	local stone = Color3.fromRGB(92, 86, 98)
	local trim = Color3.fromRGB(214, 172, 92)
	local function at(offset: Vector3): CFrame
		return cframe * CFrame.new(offset)
	end
	for _, side in { -1, 1 } do
		Decor.part(model, { Name = "Pillar", Size = Vector3.new(2.6, 13, 2.6), CFrame = at(Vector3.new(side * 5.5, 6.5, 0)), Material = Enum.Material.Slate, Color = stone })
		Decor.part(model, { Name = "PillarFoot", Size = Vector3.new(3.4, 1, 3.4), CFrame = at(Vector3.new(side * 5.5, 0.5, 0)), Material = Enum.Material.Slate, Color = stone })
		Decor.part(model, { Name = "Rune", Size = Vector3.new(0.4, 6, 0.3), CFrame = at(Vector3.new(side * 5.5, 7, -1.36)), Material = Enum.Material.Neon, Color = glow, CastShadow = false })
		Decor.part(model, { Name = "Rune", Size = Vector3.new(0.4, 6, 0.3), CFrame = at(Vector3.new(side * 5.5, 7, 1.36)), Material = Enum.Material.Neon, Color = glow, CastShadow = false })
	end
	Decor.part(model, { Name = "Lintel", Size = Vector3.new(15, 2.2, 3.2), CFrame = at(Vector3.new(0, 14, 0)), Material = Enum.Material.Slate, Color = stone })
	Decor.part(model, { Name = "Trim", Size = Vector3.new(15.4, 0.5, 3.4), CFrame = at(Vector3.new(0, 12.8, 0)), Material = Enum.Material.Metal, Color = trim })
	Decor.part(model, { Name = "Crown", Size = Vector3.new(3, 3, 1), CFrame = at(Vector3.new(0, 15.8, 0)) * CFrame.Angles(0, 0, math.rad(45)), Material = Enum.Material.Neon, Color = glow, CastShadow = false })
	local portal = Decor.part(model, {
		Name = "Portal",
		Size = Vector3.new(8.4, 11.4, 0.4),
		CFrame = at(Vector3.new(0, 6.7, 0)),
		Material = Enum.Material.Neon,
		Color = glow,
		Transparency = 0.35,
		CastShadow = false,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 16
	light.Brightness = 2
	light.Shadows = false
	light.Parent = portal
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Rate = 14
	sparkles.Lifetime = NumberRange.new(1.2, 2)
	sparkles.Speed = NumberRange.new(0.6, 1.4)
	sparkles.SpreadAngle = Vector2.new(30, 30)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	sparkles.Color = ColorSequence.new(glow, Color3.fromRGB(255, 255, 255))
	sparkles.Parent = portal
	model.PrimaryPart = portal
	model.Parent = parent
	return model, portal
end

-- Billboard label above a part. Sized in studs (width / 14 studs wide), not pixels, so
-- distant labels shrink with perspective instead of crowding the screen.
function Decor.label(adornee: BasePart, name: string, offsetY: number, width: number): (BillboardGui, TextLabel, TextLabel)
	local board = Instance.new("BillboardGui")
	board.Name = name
	board.Size = UDim2.fromScale(width / 14, 5)
	board.StudsOffset = Vector3.new(0, offsetY, 0)
	board.MaxDistance = 260
	board.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.62, 0)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 240, 205)
	title.TextStrokeTransparency = 0.35
	title.TextStrokeColor3 = Color3.fromRGB(40, 24, 50)
	title.Parent = board
	local sub = Instance.new("TextLabel")
	sub.Name = "Subtitle"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.62)
	sub.Size = UDim2.new(1, 0, 0.38, 0)
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(214, 200, 255)
	sub.TextStrokeTransparency = 0.5
	sub.Parent = board
	board.Adornee = adornee
	board.Parent = adornee
	return board, title, sub
end

return Decor
