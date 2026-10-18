--!nonstrict
-- Build mode (World place): the floating dock (Hub button, category tabs, tools), the
-- item tray with 3D previews, the ghost preview with a valid/invalid footprint plate,
-- rotate, place, remove, and touch controls.
--
-- The client only PREVIEWS. Every placement and removal is a request; the server runs
-- the full rule chain (ownership, bounds, overlap, limit, Cash) and is the only one
-- that changes the world. The preview mirrors those rules (PlacementRules) using the
-- placed objects the server replicates, so the tint matches what the server will say.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UI = require(script.Parent:WaitForChild("UI"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GridMath = require(Shared:WaitForChild("GridMath"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local Net = require(Shared:WaitForChild("Net"))
local PlacementRules = require(Shared:WaitForChild("PlacementRules"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild(Net.FolderName)
local placeRemote = remotes:WaitForChild(Net.RequestPlace) :: RemoteFunction
local removeRemote = remotes:WaitForChild(Net.RequestRemove) :: RemoteFunction
local returnRemote = remotes:WaitForChild(Net.RequestReturnToHub) :: RemoteFunction
local itemsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Items")

local worldPlot = Workspace:WaitForChild("WorldPlot")
local base = worldPlot:WaitForChild("Base") :: BasePart
local placedFolder = worldPlot:WaitForChild("Placed")

local CELL = Config.CELL_SIZE
local CELLS = Config.PLOT_CELLS
local CATEGORIES = { "Buildings", "Nature", "Ground", "Decor", "Magic" }
local CATEGORY_ICON = { Buildings = "🏠", Nature = "🌳", Ground = "🧱", Decor = "🏮", Magic = "✨" }
local VALID = Color3.fromRGB(90, 220, 255)
local INVALID = Color3.fromRGB(255, 90, 110)
local REMOVE = Color3.fromRGB(255, 120, 90)

local isTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

---------------------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------------------
type Mode = "none" | "place" | "remove"
local mode: Mode = "none"
local selected: ItemCatalog.Item? = nil
local rot = 0
local busy = false
local cursorScreen: Vector2? = nil -- last pointer position (mouse or touch)

local ghost: Model? = nil
local plate: Part? = nil
local tag: BillboardGui? = nil
local ghostTarget: CFrame? = nil
local highlight: Highlight? = nil
local current = { x = 0, z = 0, valid = false, reason = nil :: string?, onPlot = false }
local removeTarget: Model? = nil

-- Mirror of the server's occupancy, rebuilt from the replicated placed models.
local plotState = PlacementRules.newPlotState()
local stateDirty = true
local function rebuildState()
	plotState = PlacementRules.newPlotState()
	for _, model in placedFolder:GetChildren() do
		local item = ItemCatalog.get(model:GetAttribute("ItemId") or "")
		local x, z, r = model:GetAttribute("CellX"), model:GetAttribute("CellZ"), model:GetAttribute("Rot")
		if item and type(x) == "number" and type(z) == "number" and type(r) == "number" then
			PlacementRules.occupy(plotState, item, x, z, r, CELLS, model.Name) -- also counts it
		end
	end
	stateDirty = false
end
placedFolder.ChildAdded:Connect(function()
	stateDirty = true
end)
placedFolder.ChildRemoved:Connect(function()
	stateDirty = true
end)

local function surface(): CFrame
	return base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)
end

local function cash(): number
	return player:GetAttribute("Cash") or 0
end

local function isOwnerReady(): boolean
	return worldPlot:GetAttribute("OwnerUserId") == player.UserId and worldPlot:GetAttribute("WorldStatus") == "ready"
end

---------------------------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------------------------
local screen = UI.screen("BuildHud", 5)

local dockHolder = UI.new("Frame", {
	Name = "DockHolder",
	Parent = screen,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(860, 250),
	BackgroundTransparency = 1,
})
local dockScale = UI.new("UIScale", { Parent = dockHolder, Scale = 1 })
local function fitDock()
	local vp = Workspace.CurrentCamera.ViewportSize
	-- Keep clear of the mobile thumbstick (left) and jump button (right).
	local share = if isTouch then 0.62 else 0.9
	dockScale.Scale = math.clamp(vp.X * share / 860, 0.45, 1)
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitDock)
fitDock()

local dock = UI.panel({
	Name = "Dock",
	Parent = dockHolder,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 66),
})
UI.new("UIPadding", { Parent = dock, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9) })
UI.new("UIListLayout", {
	Parent = dock,
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

local hubButton = UI.button({ Name = "Hub", Parent = dock, LayoutOrder = 1, Size = UDim2.fromOffset(96, 48), Text = "🏰 HUB", MaxTextSize = 20 }, "dark")

local function separator(order: number)
	UI.new("Frame", { Parent = dock, LayoutOrder = order, Size = UDim2.fromOffset(2, 40), BackgroundColor3 = UI.Colors.glow, BackgroundTransparency = 0.6, BorderSizePixel = 0 })
end
separator(2)

local tabs: { [string]: TextButton } = {}
local tabRow = UI.new("Frame", { Parent = dock, LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.fromOffset(5 * 100 + 4 * 6, 48) }, {
	UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
for order, category in CATEGORIES do
	tabs[category] = UI.button({
		Name = category,
		Parent = tabRow,
		LayoutOrder = order,
		Size = UDim2.fromOffset(100, 48),
		Text = CATEGORY_ICON[category] .. " " .. string.upper(category),
		MaxTextSize = 15,
		CornerRadius = 12,
	}, "ghost")
end
local visitLabel = UI.heading({
	Name = "VisitLabel",
	Parent = dock,
	LayoutOrder = 3,
	Size = UDim2.fromOffset(5 * 100 + 4 * 6, 40),
	Text = "👀  VISITING · LOOK AROUND",
	MaxTextSize = 22,
	TextColor3 = UI.Colors.glow,
	Visible = false,
})
separator(4)

local function toolButton(name: string, text: string, order: number, style: string): TextButton
	return UI.button({ Name = name, Parent = dock, LayoutOrder = order, Size = UDim2.fromOffset(52, 48), Text = text, MaxTextSize = 24, CornerRadius = 12 }, style)
end
local rotateButton = toolButton("Rotate", "🔄", 5, "ghost")
local removeButton = toolButton("Remove", "🗑", 6, "ghost")
local cancelButton = toolButton("Cancel", "❌", 7, "ghost")

-- Hint line above the dock.
local hint = UI.heading({
	Name = "Hint",
	Parent = dockHolder,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -74),
	Size = UDim2.new(1, 0, 0, 24),
	Text = "",
	MaxTextSize = 20,
	TextColor3 = UI.Colors.text,
	Visible = false,
})

-- Item tray (above the dock).
local tray = UI.panel({
	Name = "Tray",
	Parent = dockHolder,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.fromOffset(0, 150),
	AutomaticSize = Enum.AutomaticSize.X,
	Visible = false,
})
UI.new("UIPadding", { Parent = tray, PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) })
UI.new("UIListLayout", { Parent = tray, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center })

-- Touch-only confirm buttons (right side, above the jump button).
local touchPanel = UI.new("Frame", {
	Name = "TouchControls",
	Parent = screen,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -24, 0.55, 0),
	Size = UDim2.fromOffset(120, 132),
	BackgroundTransparency = 1,
	Visible = false,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Right }) })
local confirmButton = UI.button({ Name = "Confirm", Parent = touchPanel, Size = UDim2.fromOffset(120, 60), Text = "✅ PLACE", MaxTextSize = 22 }, "blue")
local touchRotate = UI.button({ Name = "TouchRotate", Parent = touchPanel, Size = UDim2.fromOffset(120, 60), Text = "🔄 ROTATE", MaxTextSize = 20 }, "dark")

---------------------------------------------------------------------------------------
-- Item cards with 3D previews
---------------------------------------------------------------------------------------
local cards: { [string]: TextButton } = {}

local function preview(viewport: ViewportFrame, item: ItemCatalog.Item)
	local template = itemsFolder:FindFirstChild(item.model)
	if not template then
		return
	end
	local model = template:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	local _, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	local focus = Vector3.new(0, size.Y / 2, 0)
	cam.CFrame = CFrame.lookAt(focus + Vector3.new(1, 0.75, -1).Unit * radius * 2.9, focus)
	cam.Parent = viewport
	viewport.CurrentCamera = cam
end

local function makeCard(item: ItemCatalog.Item, order: number): TextButton
	local card = UI.new("TextButton", {
		Name = item.id,
		Parent = tray,
		LayoutOrder = order,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.fromOffset(112, 128),
		BackgroundColor3 = Color3.fromRGB(226, 240, 255),
		BorderSizePixel = 0,
	}, {
		UI.corner(14),
		UI.gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 220, 250)),
		UI.stroke(UI.Colors.glow, 2, 0.6),
	})
	local vp = UI.new("ViewportFrame", {
		Parent = card,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 72),
		BackgroundColor3 = Color3.fromRGB(150, 200, 255),
		BackgroundTransparency = 0.55,
		Ambient = Color3.fromRGB(170, 180, 200),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.5, 0.6),
	}, { UI.corner(10) })
	preview(vp, item)
	UI.new("TextLabel", {
		Parent = card,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 80),
		Size = UDim2.new(1, -8, 0, 20),
		Font = UI.Fonts.title,
		TextScaled = true,
		TextColor3 = UI.Colors.ink,
		Text = item.name,
	}, { UI.new("UITextSizeConstraint", { MaxTextSize = 16 }) })
	UI.new("TextLabel", {
		Name = "Price",
		Parent = card,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 102),
		Size = UDim2.new(1, -8, 0, 18),
		Font = UI.Fonts.title,
		TextScaled = true,
		TextColor3 = UI.Colors.goldDeep,
		Text = "💰 " .. UI.formatNumber(item.price),
	}, { UI.new("UITextSizeConstraint", { MaxTextSize = 16 }) })
	local scale = UI.new("UIScale", { Parent = card, Scale = 1 })
	card.MouseEnter:Connect(function()
		UI.tween(scale, TweenInfo.new(0.12), { Scale = 1.06 })
	end)
	card.MouseLeave:Connect(function()
		UI.tween(scale, TweenInfo.new(0.12), { Scale = 1 })
	end)
	return card
end

local itemsByCategory: { [string]: { ItemCatalog.Item } } = {}
for _, item in ItemCatalog.all() do
	itemsByCategory[item.category] = itemsByCategory[item.category] or {}
	table.insert(itemsByCategory[item.category], item)
end

local function refreshCardStates()
	for id, card in cards do
		local item = ItemCatalog.get(id)
		if item then
			local affordable = cash() >= item.price
			local chosen = selected ~= nil and selected.id == id
			card.BackgroundTransparency = if affordable then 0 else 0.35
			local stroke = card:FindFirstChildOfClass("UIStroke")
			stroke.Color = if chosen then UI.Colors.azure else UI.Colors.glow
			stroke.Transparency = if chosen then 0 else 0.6
			stroke.Thickness = if chosen then 3 else 2
			local price = card:FindFirstChild("Price") :: TextLabel
			price.TextColor3 = if affordable then UI.Colors.goldDeep else UI.Colors.bad
		end
	end
end
player:GetAttributeChangedSignal("Cash"):Connect(refreshCardStates)

---------------------------------------------------------------------------------------
-- Ghost preview
---------------------------------------------------------------------------------------
local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if plate then
		plate:Destroy()
		plate = nil
	end
	if tag then
		tag:Destroy()
		tag = nil
	end
	ghostTarget = nil
end

local function clearRemoveTarget()
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if tag and removeTarget then
		tag:Destroy()
		tag = nil
	end
	removeTarget = nil
end

local function makeTag(adornee: BasePart, offset: number): BillboardGui
	local board = UI.new("BillboardGui", {
		Name = "BuildTag",
		Adornee = adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(220, 40),
		StudsOffsetWorldSpace = Vector3.new(0, offset, 0),
		Parent = screen,
	})
	UI.new("TextLabel", {
		Name = "Text",
		Parent = board,
		BackgroundColor3 = UI.Colors.panel,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
		Font = UI.Fonts.title,
		TextScaled = true,
		TextColor3 = UI.Colors.text,
		TextStrokeColor3 = UI.Colors.ink,
		TextStrokeTransparency = 0.3,
		Text = "",
	}, { UI.corner(12), UI.stroke(UI.Colors.glow, 1.5, 0.2), UI.new("UITextSizeConstraint", { MaxTextSize = 20 }), UI.padding(6) })
	return board
end

local function makeGhost(item: ItemCatalog.Item)
	clearGhost()
	local template = itemsFolder:FindFirstChild(item.model)
	if not template then
		return
	end
	local model = template:Clone()
	model.Name = "BuildGhost"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Name ~= "Hitbox" then
				d.Transparency = 0.35 + 0.65 * d.Transparency
			end
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = VALID
	hl.OutlineColor = VALID
	hl.FillTransparency = 0.7
	hl.OutlineTransparency = 0.1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model
	model.Parent = Workspace

	local p = Instance.new("Part")
	p.Name = "BuildPlate"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Transparency = 0.45
	p.Size = Vector3.new(CELL, 0.12, CELL)
	p.Parent = Workspace

	ghost = model
	plate = p
	tag = makeTag(p, 3)
end

local function setGhostColor(valid: boolean)
	local color = if valid then VALID else INVALID
	if ghost then
		local hl = ghost:FindFirstChildOfClass("Highlight")
		if hl then
			hl.FillColor = color
			hl.OutlineColor = color
		end
	end
	if plate then
		plate.Color = color
	end
end

-- Screen point -> ray. GetMouseLocation and touch positions are viewport coordinates.
local function pointerRay(): (Vector3?, Vector3?)
	local pos = if isTouch then cursorScreen else UserInputService:GetMouseLocation()
	if pos == nil then
		return nil, nil
	end
	local ray = Workspace.CurrentCamera:ViewportPointToRay(pos.X, pos.Y)
	return ray.Origin, ray.Direction * 1000
end

local function updatePlace()
	local item = selected
	if item == nil or ghost == nil or plate == nil then
		return
	end
	if stateDirty then
		rebuildState()
	end
	local origin, dir = pointerRay()
	if origin == nil then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { base }
	local hit = Workspace:Raycast(origin, dir, params)
	current.onPlot = hit ~= nil
	if not hit then
		ghost.Parent = nil
		plate.Parent = nil
		return
	end
	ghost.Parent = Workspace
	plate.Parent = Workspace
	local surf = surface()
	local cx, cz = GridMath.worldToCell(surf, hit.Position, CELL, CELLS)
	local ax, az = GridMath.anchorForCursor(cx, cz, item.size.w, item.size.d, rot)
	-- Keep the footprint inside the plot when the cursor is near an edge.
	local rw, rd = GridMath.rotatedSize(item.size.w, item.size.d, rot)
	ax = math.clamp(ax, 0, CELLS - rw)
	az = math.clamp(az, 0, CELLS - rd)
	local ok, reason = PlacementRules.check(plotState, item, ax, az, rot, cash(), CELLS, Config.MAX_PLACED_PER_PLOT)
	current.x, current.z, current.valid, current.reason = ax, az, ok, reason

	ghostTarget = GridMath.footprintCFrame(surf, ax, az, item.size.w, item.size.d, rot, CELL, CELLS)
	local lx, lz = GridMath.footprintLocalCenter(ax, az, item.size.w, item.size.d, rot, CELL, CELLS)
	plate.Size = Vector3.new(rw * CELL - 0.3, 0.12, rd * CELL - 0.3)
	plate.CFrame = surf * CFrame.new(lx, 0.08, lz)
	setGhostColor(ok)
	if tag then
		local label = tag:FindFirstChild("Text") :: TextLabel
		label.Text = if ok then `💰 {UI.formatNumber(item.price)}` else (Net.Message[reason or ""] or "Can't place here")
		label.TextColor3 = if ok then UI.Colors.gold else UI.Colors.bad
	end
end

local function hoveredPlaced(): Model?
	local origin, dir = pointerRay()
	if origin == nil then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { placedFolder }
	local hit = Workspace:Raycast(origin, dir, params)
	if hit == nil then
		return nil
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	while model and model.Parent ~= placedFolder do
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return model
end

local function updateRemove()
	local target = hoveredPlaced()
	if target == removeTarget then
		return
	end
	clearRemoveTarget()
	if target == nil then
		return
	end
	removeTarget = target
	local hl = Instance.new("Highlight")
	hl.FillColor = REMOVE
	hl.OutlineColor = REMOVE
	hl.FillTransparency = 0.55
	hl.Parent = target
	highlight = hl
	local item = ItemCatalog.get(target:GetAttribute("ItemId") or "")
	local hitbox = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
	if hitbox then
		local board = makeTag(hitbox, 1) -- near the middle: tall objects would push it off-screen
		tag = board
		local label = board:FindFirstChild("Text") :: TextLabel
		local refund = if item then math.floor(item.price * Config.REFUND_RATE) else 0
		label.Text = `🗑 {if item then item.name else "Remove"}  +💰{UI.formatNumber(refund)}`
		label.TextColor3 = UI.Colors.text
	end
end

---------------------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------------------
local function burst(cframe: CFrame, color: Color3, size: number)
	local ring = Instance.new("Part")
	ring.Name = "BuildFx"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, size, size)
	ring.CFrame = cframe * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	ring.Parent = Workspace
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = Vector3.new(0.2, size * 2.2, size * 2.2), Transparency = 1 }):Play()
	local spark = Instance.new("Attachment")
	spark.Parent = ring
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = spark
	emitter:Emit(24)
	task.delay(1, function()
		ring:Destroy()
	end)
end

-- Newly placed objects pop up from slightly smaller (client-side flourish only).
placedFolder.ChildAdded:Connect(function(model)
	if not model:IsA("Model") or mode ~= "place" then
		return
	end
	local pivot = model:GetPivot()
	burst(pivot, VALID, 6)
	local scale = Instance.new("NumberValue")
	scale.Value = 0.75
	local conn = scale.Changed:Connect(function(v)
		if model.Parent then
			model:ScaleTo(v)
		end
	end)
	model:ScaleTo(0.75)
	local tween = TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 })
	tween:Play()
	tween.Completed:Once(function()
		conn:Disconnect()
		if model.Parent then
			model:ScaleTo(1)
			model:PivotTo(pivot)
		end
		scale:Destroy()
	end)
end)

---------------------------------------------------------------------------------------
-- Modes
---------------------------------------------------------------------------------------
local function setHint(text: string?)
	hint.Visible = text ~= nil
	hint.Text = text or ""
end

local function styleTools()
	UI.styleButton(removeButton, if mode == "remove" then "danger" else "ghost")
	UI.styleButton(rotateButton, if mode == "place" then "dark" else "ghost")
	UI.styleButton(cancelButton, if mode ~= "none" then "dark" else "ghost")
	touchPanel.Visible = isTouch and mode ~= "none"
	confirmButton.Text = if mode == "remove" then "🗑 REMOVE" else "✅ PLACE"
end

local openCategory: string? = nil
local function closeTray()
	openCategory = nil
	tray.Visible = false
	for _, tab in tabs do
		UI.styleButton(tab, "ghost")
	end
end

local function exitMode()
	mode = "none"
	selected = nil
	clearGhost()
	clearRemoveTarget()
	setHint(nil)
	styleTools()
	refreshCardStates()
end

local function enterPlace(item: ItemCatalog.Item)
	clearRemoveTarget()
	mode = "place"
	selected = item
	makeGhost(item)
	setHint(if isTouch
		then `{item.name}: tap the ground, then ✅ PLACE`
		else `{item.name} · Click to place · R rotate · Q cancel`)
	styleTools()
	refreshCardStates()
end

local function enterRemove()
	selected = nil
	clearGhost()
	closeTray()
	mode = "remove"
	setHint(if isTouch then "Tap an object, then 🗑 REMOVE" else "Click an object to remove it (full refund) · Q cancel")
	styleTools()
	refreshCardStates()
end

local function openTray(category: string)
	if openCategory == category then
		closeTray()
		return
	end
	openCategory = category
	for name, tab in tabs do
		UI.styleButton(tab, if name == category then "blue" else "ghost")
	end
	for _, card in cards do
		card:Destroy()
	end
	table.clear(cards)
	local list: { ItemCatalog.Item } = itemsByCategory[category] or {}
	for order, item in list do
		local card = makeCard(item, order)
		cards[item.id] = card
		card.Activated:Connect(function()
			enterPlace(item)
		end)
	end
	tray.Visible = true
	refreshCardStates()
end

local function rotate()
	if mode ~= "place" then
		return
	end
	rot = (rot + 1) % 4
	updatePlace()
end

local function tryPlace()
	local item = selected
	if mode ~= "place" or item == nil or busy or not current.onPlot then
		return
	end
	if not current.valid then
		UI.toast(screen, "error", Net.Message[current.reason or ""] or "You can't place that there.")
		return
	end
	busy = true
	local x, z, r = current.x, current.z, rot
	local ok, result = pcall(function()
		return placeRemote:InvokeServer(item.id, x, z, r)
	end)
	busy = false
	if not ok then
		UI.toast(screen, "error", "Couldn't reach the server. Try again.")
	elseif type(result) == "table" and not result.ok then
		UI.toast(screen, "error", Net.Message[result.reason or ""] or "You can't place that there.")
	end
	stateDirty = true
end

local function tryRemove()
	local target = removeTarget
	if mode ~= "remove" or target == nil or busy then
		return
	end
	busy = true
	local pivot = target:GetPivot()
	local ok, result = pcall(function()
		return removeRemote:InvokeServer(target.Name)
	end)
	busy = false
	if ok and type(result) == "table" and result.ok then
		burst(pivot, REMOVE, 5)
		clearRemoveTarget()
	elseif not ok then
		UI.toast(screen, "error", "Couldn't reach the server. Try again.")
	else
		UI.toast(screen, "error", Net.Message[result.reason or ""] or "Couldn't remove that.")
	end
	stateDirty = true
end

---------------------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------------------
for category, tab in tabs do
	tab.Activated:Connect(function()
		openTray(category)
	end)
end
rotateButton.Activated:Connect(rotate)
touchRotate.Activated:Connect(rotate)
removeButton.Activated:Connect(function()
	if mode == "remove" then
		exitMode()
	else
		enterRemove()
	end
end)
cancelButton.Activated:Connect(function()
	exitMode()
	closeTray()
end)
confirmButton.Activated:Connect(function()
	if mode == "remove" then
		tryRemove()
	else
		tryPlace()
	end
end)

local returning = false
hubButton.Activated:Connect(function()
	if returning then
		return
	end
	returning = true
	exitMode()
	pcall(function()
		returnRemote:InvokeServer()
	end)
	task.wait(1.5)
	returning = false
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Touch then
		if not processed then
			cursorScreen = Vector2.new(input.Position.X, input.Position.Y)
		end
		return
	end
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if mode == "place" then
			tryPlace()
		elseif mode == "remove" then
			tryRemove()
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		rotate()
	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
		exitMode()
		closeTray()
	elseif input.KeyCode == Enum.KeyCode.X and isOwnerReady() then
		if mode == "remove" then
			exitMode()
		else
			enterRemove()
		end
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if mode == "place" then
		updatePlace()
		if ghost and ghostTarget then
			local alpha = 1 - math.exp(-dt * 22)
			ghost:PivotTo(ghost:GetPivot():Lerp(ghostTarget, alpha))
		end
	elseif mode == "remove" then
		updateRemove()
	end
end)

-- Owner vs visitor dock.
local function refreshRole()
	local owner = isOwnerReady()
	tabRow.Visible = owner
	rotateButton.Visible = owner
	removeButton.Visible = owner
	cancelButton.Visible = owner
	visitLabel.Visible = not owner and type(worldPlot:GetAttribute("OwnerUserId")) == "number"
	if not owner and mode ~= "none" then
		exitMode()
		closeTray()
	end
end
worldPlot.AttributeChanged:Connect(refreshRole)
refreshRole()
styleTools()
