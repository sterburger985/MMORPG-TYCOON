--!nonstrict
-- UI: the game's shared interface kit (both places). Dark-violet panels with warm gold
-- trim, rounded corners, soft gradients, smooth hover/press motion, toasts and a travel
-- screen. Every screen uses these helpers so the whole game looks like one product.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	panel = Color3.fromRGB(26, 20, 44),
	panel2 = Color3.fromRGB(44, 34, 74),
	gold = Color3.fromRGB(240, 192, 96),
	goldDeep = Color3.fromRGB(196, 132, 52),
	text = Color3.fromRGB(255, 246, 228),
	sub = Color3.fromRGB(196, 184, 230),
	accent = Color3.fromRGB(150, 110, 255),
	good = Color3.fromRGB(116, 214, 146),
	bad = Color3.fromRGB(244, 108, 108),
	info = Color3.fromRGB(120, 190, 255),
}

UI.Fonts = {
	title = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
}

local FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SMOOTH = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

function UI.tween(instance: Instance, info: TweenInfo, goal: { [string]: any })
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

-- new("Frame", { props }, { children })
function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in (props or {}) :: { [string]: any } do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in (children or {}) :: { Instance } do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function UI.corner(radius: number): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function UI.stroke(color: Color3, thickness: number, transparency: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.gradient(top: Color3, bottom: Color3): UIGradient
	return UI.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 })
end

function UI.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return UI.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UI.label(props: { [string]: any }): TextLabel
	local p = {
		BackgroundTransparency = 1,
		Font = UI.Fonts.body,
		TextColor3 = UI.Colors.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
	}
	for k, v in props do
		if k ~= "MaxTextSize" then -- not a TextLabel property; goes on the size constraint
			p[k] = v
		end
	end
	return UI.new("TextLabel", p, { UI.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28 }) })
end

function UI.screen(name: string, displayOrder: number?): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	return UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = playerGui,
	})
end

-- A rounded panel with a subtle gradient and gold hairline border.
function UI.panel(props: { [string]: any }): Frame
	local p = { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.08, BorderSizePixel = 0 }
	for k, v in props do
		p[k] = v
	end
	return UI.new("Frame", p, {
		UI.corner(16),
		UI.gradient(UI.Colors.panel2, UI.Colors.panel),
		UI.stroke(UI.Colors.gold, 1.5, 0.45),
	})
end

-- A small pill with text, e.g. "🌍 Public".
function UI.chip(parent: Instance, text: string, color: Color3, props: { [string]: any }?): TextLabel
	local p = {
		Parent = parent,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.78,
		Font = UI.Fonts.bold,
		Text = text,
		TextSize = 14,
		TextColor3 = UI.Colors.text,
	}
	for k, v in (props or {}) :: { [string]: any } do
		p[k] = v
	end
	return UI.new("TextLabel", p, {
		UI.corner(12),
		UI.stroke(color, 1, 0.2),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
end

-- A button with hover lift and press squish. style: "gold" | "dark" | "ghost".
function UI.button(props: { [string]: any }, style: string?): TextButton
	style = style or "gold"
	local isGold = style == "gold"
	-- A UIGradient tints the text as well as the background, so the colour lives in
	-- BackgroundColor3 and the gradient is a neutral white-to-grey shade (which only
	-- darkens the text very slightly).
	local p = {
		AutoButtonColor = false,
		BackgroundColor3 = if isGold then Color3.fromRGB(255, 206, 110) else UI.Colors.panel2,
		BorderSizePixel = 0,
		Font = UI.Fonts.title,
		TextScaled = true,
		TextColor3 = if isGold then Color3.fromRGB(58, 30, 10) else UI.Colors.text,
	}
	for k, v in props do
		if k ~= "MaxTextSize" then
			p[k] = v
		end
	end
	local scale = UI.new("UIScale", { Scale = 1 })
	local button = UI.new("TextButton", p, {
		UI.corner(14),
		UI.gradient(Color3.new(1, 1, 1), if isGold then Color3.fromRGB(205, 175, 150) else Color3.fromRGB(190, 190, 200)),
		UI.stroke(if isGold then Color3.fromRGB(255, 240, 200) else UI.Colors.gold, if isGold then 2 else 1.5, if style == "ghost" then 0.6 else 0.15),
		UI.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 26 }),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
		scale,
	})
	button.MouseEnter:Connect(function()
		UI.tween(scale, FAST, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		UI.tween(scale, FAST, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UI.tween(scale, FAST, { Scale = 0.95 })
	end)
	button.MouseButton1Up:Connect(function()
		UI.tween(scale, FAST, { Scale = 1.05 })
	end)
	return button
end

-- Toasts stack under the top edge and fade out on their own.
local toastHolders: { [ScreenGui]: Frame } = {}
function UI.toast(screen: ScreenGui, kind: string, text: string)
	local holder = toastHolders[screen]
	if holder == nil or holder.Parent == nil then
		holder = UI.new("Frame", {
			Name = "Toasts",
			Parent = screen,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 150), -- below the banner and Cash chip
			Size = UDim2.new(0, 460, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			ZIndex = 50,
		}, {
			UI.new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
			UI.new("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge) }),
		})
		toastHolders[screen] = holder
	end
	local color = if kind == "error" then UI.Colors.bad elseif kind == "success" then UI.Colors.good else UI.Colors.info
	local icon = if kind == "error" then "⚠" elseif kind == "success" then "✔" else "✦"
	local toast = UI.panel({
		Parent = holder,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 50,
		LayoutOrder = os.clock() * 1000,
	})
	local stroke = toast:FindFirstChildOfClass("UIStroke")
	stroke.Color = color
	stroke.Transparency = 1
	UI.padding(12).Parent = toast
	local text_ = UI.new("TextLabel", {
		Parent = toast,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = UI.Fonts.bold,
		TextSize = 17,
		TextWrapped = true,
		TextColor3 = UI.Colors.text,
		TextTransparency = 1,
		RichText = true,
		Text = `<font color="#{color:ToHex()}">{icon}</font>  {text}`,
		ZIndex = 51,
	})
	UI.tween(toast, SMOOTH, { BackgroundTransparency = 0.08 })
	UI.tween(stroke, SMOOTH, { Transparency = 0.1 })
	UI.tween(text_, SMOOTH, { TextTransparency = 0 })
	task.delay(4, function()
		if toast.Parent == nil then
			return
		end
		UI.tween(toast, SMOOTH, { BackgroundTransparency = 1 })
		UI.tween(stroke, SMOOTH, { Transparency = 1 })
		UI.tween(text_, SMOOTH, { TextTransparency = 1 }).Completed:Wait()
		toast:Destroy()
	end)
end

local function buildTravelScreen(title: string, text: string): ScreenGui
	local gui = UI.new("ScreenGui", { Name = "TravelScreen", IgnoreGuiInset = true, DisplayOrder = 100, ResetOnSpawn = false })
	local bg = UI.new("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, {
		UI.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 18, 64)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(16, 12, 34)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 6, 18)),
			}),
			Rotation = 90,
		}),
	})
	UI.new("TextLabel", {
		Parent = bg,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.new(0.8, 0, 0, 64),
		Font = UI.Fonts.title,
		TextScaled = true,
		TextColor3 = UI.Colors.gold,
		Text = title,
	}, { UI.new("UITextSizeConstraint", { MaxTextSize = 56 }) })
	UI.new("TextLabel", {
		Parent = bg,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(0.8, 0, 0, 28),
		Font = UI.Fonts.bold,
		TextScaled = true,
		TextColor3 = UI.Colors.sub,
		Text = text,
	}, { UI.new("UITextSizeConstraint", { MaxTextSize = 22 }) })
	UI.new("TextLabel", {
		Parent = bg,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.new(0.8, 0, 0, 22),
		Font = UI.Fonts.title,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(150, 130, 200),
		Text = "✦  MMORPG TYCOON  ✦",
	}, { UI.new("UITextSizeConstraint", { MaxTextSize = 18 }) })
	return gui
end

-- Full-screen "travelling" screen; also handed to Roblox so it stays up during the teleport.
function UI.travel(title: string, text: string)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("TravelScreen")
	if old then
		old:Destroy()
	end
	local gui = buildTravelScreen(title, text)
	pcall(function()
		TeleportService:SetTeleportGui(buildTravelScreen(title, text))
	end)
	local bg = gui:FindFirstChildOfClass("Frame")
	bg.BackgroundTransparency = 1
	for _, d in bg:GetDescendants() do
		if d:IsA("TextLabel") then
			d.TextTransparency = 1
			UI.tween(d, SMOOTH, { TextTransparency = 0 })
		end
	end
	gui.Parent = playerGui
	UI.tween(bg, SMOOTH, { BackgroundTransparency = 0 })
	-- If the teleport fails we'd be stuck behind the screen: remove it after a while.
	task.delay(12, function()
		if gui.Parent then
			UI.tween(bg, SMOOTH, { BackgroundTransparency = 1 })
			task.wait(0.35)
			gui:Destroy()
		end
	end)
end

-- Remove the travel screen early (e.g. when travel fails).
function UI.clearTravel()
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local gui = playerGui and playerGui:FindFirstChild("TravelScreen")
	if gui then
		gui:Destroy()
	end
end

-- Wire the server's Notify event to toasts and the travel screen.
function UI.listen(screen: ScreenGui, notify: RemoteEvent)
	notify.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.text) ~= "string" then
			return
		end
		if payload.kind == "worldname" then
			return -- data for the world HUD, not a toast
		elseif payload.kind == "travel" then
			UI.travel(if type(payload.title) == "string" then payload.title else "Travelling", payload.text)
		else
			if payload.kind == "error" then
				UI.clearTravel()
			end
			UI.toast(screen, payload.kind, payload.text)
		end
	end)
end

function UI.formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

UI.VisibilityText = {
	Public = "🌍  Public",
	FriendsOnly = "👥  Friends",
	Private = "🔒  Private",
}
UI.VisibilityColor = {
	Public = Color3.fromRGB(116, 214, 146),
	FriendsOnly = Color3.fromRGB(120, 190, 255),
	Private = Color3.fromRGB(244, 150, 108),
}

return UI
