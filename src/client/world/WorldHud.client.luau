--!nonstrict
-- World HUD: world name banner, owner/visitor badge, Cash (owner), visibility settings
-- (owner), Return to Hub, toasts and the travel screen. Display only: the server decides
-- everything (ownership, permissions, values).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UI = require(script.Parent:WaitForChild("UI"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild(Net.FolderName)
local notify = remotes:WaitForChild(Net.Notify) :: RemoteEvent
local returnRemote = remotes:WaitForChild(Net.RequestReturnToHub) :: RemoteFunction
local visibilityRemote = remotes:WaitForChild(Net.RequestSetVisibility) :: RemoteFunction

-- The server sends the world's name only to admitted players (kind "worldname");
-- Public worlds also publish it on the plot. Connected before any yield so the
-- message can't arrive before we listen.
local grantedName: string? = nil
local refreshHook: (() -> ())? = nil
notify.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and payload.kind == "worldname" and type(payload.text) == "string" then
		grantedName = payload.text
		if refreshHook then
			task.spawn(refreshHook)
		end
	end
end)

local screen = UI.screen("WorldHud")
UI.listen(screen, notify)

local worldPlot = Workspace:WaitForChild("WorldPlot")

-- Banner (top-centre) ---------------------------------------------------------------
local banner = UI.panel({
	Name = "Banner",
	Parent = screen,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.new(0, 420, 0, 78),
})
local bannerTitle = UI.label({
	Parent = banner,
	Text = "Loading world…",
	Font = UI.Fonts.title,
	TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.new(0, 16, 0, 8),
	Size = UDim2.new(1, -32, 0, 36),
	MaxTextSize = 32,
	TextColor3 = UI.Colors.gold,
})
local bannerSub = UI.label({
	Parent = banner,
	Text = "",
	Font = UI.Fonts.bold,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = UI.Colors.sub,
	Position = UDim2.new(0, 16, 0, 48),
	Size = UDim2.new(1, -32, 0, 18),
	MaxTextSize = 15,
})

-- Return button (bottom-left) --------------------------------------------------------
local returnButton = UI.button({
	Name = "ReturnToHub",
	Parent = screen,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 18, 1, -24),
	Size = UDim2.new(0, 220, 0, 52),
	Text = "⟵  RETURN TO HUB",
	MaxTextSize = 22,
}, "dark")
local returning = false
returnButton.Activated:Connect(function()
	if returning then
		return
	end
	returning = true
	pcall(function()
		returnRemote:InvokeServer()
	end)
	task.wait(1.5)
	returning = false
end)

-- Owner-only widgets ------------------------------------------------------------------
local cashChip: TextLabel? = nil
local settingsPanel: Frame? = nil
local pills: { [string]: TextButton } = {}

local function styleCurrentPill(current: string?)
	for value, pill in pills do
		local active = value == current
		local color = UI.VisibilityColor[value]
		UI.tween(pill, TweenInfo.new(0.2), { BackgroundTransparency = if active then 0.15 else 0.85 })
		pill.BackgroundColor3 = color
		pill.TextColor3 = if active then Color3.fromRGB(24, 18, 34) else UI.Colors.text
		pill:FindFirstChildOfClass("UIStroke").Color = color
	end
end

local function buildOwnerWidgets()
	if settingsPanel then
		return
	end
	cashChip = UI.chip(screen, "💰  " .. UI.formatNumber(player:GetAttribute("Cash") or 0), UI.Colors.gold, {
		Name = "Cash",
		AnchorPoint = Vector2.new(0.5, 0), -- centred under the banner, clear of Roblox's player list
		Position = UDim2.new(0.5, 0, 0, 98),
		Size = UDim2.fromOffset(0, 40),
		TextSize = 22,
		Font = UI.Fonts.title,
	})
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		local chip = cashChip :: TextLabel
		chip.Text = "💰  " .. UI.formatNumber(player:GetAttribute("Cash") or 0)
		local scale = chip:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = chip })
		scale.Scale = 1.12
		UI.tween(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 })
	end)

	local panel = UI.panel({
		Name = "Settings",
		Parent = screen,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 116),
		Size = UDim2.new(0, 230, 0, 150),
	})
	settingsPanel = panel
	UI.padding(14).Parent = panel
	UI.label({ Parent = panel, Text = "WORLD SETTINGS", Font = UI.Fonts.bold, TextColor3 = UI.Colors.gold, Size = UDim2.new(1, 0, 0, 14), MaxTextSize = 13 })
	UI.label({ Parent = panel, Text = "Who can visit?", TextColor3 = UI.Colors.sub, Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 14), MaxTextSize = 13 })
	local list = UI.new("Frame", { Parent = panel, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 1, -38) }, {
		UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for order, value in { Net.Visibility.Public, Net.Visibility.FriendsOnly, Net.Visibility.Private } do
		local pill = UI.new("TextButton", {
			Name = value,
			Parent = list,
			LayoutOrder = order,
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			Font = UI.Fonts.bold,
			TextSize = 15,
			TextColor3 = UI.Colors.text,
			Text = UI.VisibilityText[value],
		}, { UI.corner(13), UI.stroke(UI.VisibilityColor[value], 1, 0.2) })
		pills[value] = pill
		pill.Activated:Connect(function()
			local ok, result = pcall(function()
				return visibilityRemote:InvokeServer(value)
			end)
			if ok and type(result) == "table" and result.ok then
				UI.toast(screen, "success", "Visibility set to " .. (UI.VisibilityText[value] or value):gsub("^%S+%s+", "") .. ".")
			else
				local reason = ok and type(result) == "table" and result.reason
				UI.toast(screen, "error", (reason and Net.Message[reason]) or "Couldn't change visibility.")
			end
		end)
	end
	styleCurrentPill(worldPlot:GetAttribute("Visibility"))
end

local ownerNameCache: { [number]: string } = {}
local function ownerName(userId: number): string
	if ownerNameCache[userId] then
		return ownerNameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	ownerNameCache[userId] = if ok then name else "a builder"
	return ownerNameCache[userId]
end

local function refresh()
	local owner = worldPlot:GetAttribute("OwnerUserId")
	local name = worldPlot:GetAttribute("WorldName") or grantedName
	local status = worldPlot:GetAttribute("WorldStatus")
	local visibility = worldPlot:GetAttribute("Visibility")
	bannerTitle.Text = if type(name) == "string" then name else "Loading world…"
	if type(owner) ~= "number" then
		bannerSub.Text = ""
		return
	end
	local isOwner = owner == player.UserId
	local parts = {}
	table.insert(parts, if isOwner then "★ YOUR WORLD" else "VISITING · by " .. ownerName(owner))
	table.insert(parts, UI.VisibilityText[visibility] or "")
	if status == "readonly" then
		table.insert(parts, "VIEW ONLY")
	end
	bannerSub.Text = table.concat(parts, "   ·   ")
	if isOwner and status == "ready" then
		buildOwnerWidgets()
		styleCurrentPill(visibility)
	end
end

worldPlot.AttributeChanged:Connect(function()
	task.spawn(refresh)
end)
refreshHook = refresh
task.spawn(refresh)
