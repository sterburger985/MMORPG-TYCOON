--!nonstrict
-- Hub HUD: your world card (name, visibility, size), the big ENTER MY WORLD button,
-- toasts and the travel screen. Also personalises World Gate prompts ("Enter Your World"
-- on yours, "Visit World" on others). Display only: every action is decided by the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UI = require(script.Parent:WaitForChild("UI"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild(Net.FolderName)
local enterRemote = remotes:WaitForChild(Net.RequestEnterMyWorld) :: RemoteFunction
local notify = remotes:WaitForChild(Net.Notify) :: RemoteEvent

local screen = UI.screen("HubHud")
UI.listen(screen, notify)

-- World card (top-left) -----------------------------------------------------------
local card = UI.panel({
	Name = "WorldCard",
	Parent = screen,
	Position = UDim2.new(0, 18, 0, 64),
	Size = UDim2.new(0, 300, 0, 128),
})
UI.padding(14).Parent = card
UI.heading({ Parent = card, Text = "YOUR WORLD", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.glow, Size = UDim2.new(1, 0, 0, 16), MaxTextSize = 15 })
local nameLabel = UI.heading({
	Parent = card,
	Text = "Loading...",
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.new(0, 0, 0, 18),
	Size = UDim2.new(1, 0, 0, 34),
	MaxTextSize = 30,
})
local chipRow = UI.new("Frame", { Parent = card, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 60), Size = UDim2.new(1, 0, 0, 24) }, {
	UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }),
})
local visibilityChip = UI.chip(chipRow, "…", UI.Colors.sub)
local sizeChip = UI.chip(chipRow, "0 objects", UI.Colors.accent)
UI.label({
	Parent = card,
	Text = "Walk through your World Gate or press the button below.",
	TextColor3 = UI.Colors.sub,
	Position = UDim2.new(0, 0, 0, 90),
	Size = UDim2.new(1, 0, 0, 14),
	MaxTextSize = 12,
})

-- Enter button (bottom-centre) ------------------------------------------------------
local enterButton = UI.button({
	Name = "EnterMyWorld",
	Parent = screen,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -28),
	Size = UDim2.new(0, 300, 0, 62),
	Text = "⚔  ENTER MY WORLD",
	MaxTextSize = 28,
}, "blue")

local travelling = false
enterButton.Activated:Connect(function()
	if travelling then
		return
	end
	travelling = true
	local original = enterButton.Text
	enterButton.Text = "OPENING…"
	local ok, result = pcall(function()
		return enterRemote:InvokeServer()
	end)
	if not ok then
		UI.toast(screen, "error", "Couldn't reach the server. Try again.")
	elseif type(result) == "table" and not result.ok and result.reason == nil then
		UI.toast(screen, "error", "Couldn't open your world.")
	end
	-- (server sends its own toast/travel screen for every outcome)
	task.wait(1.5)
	enterButton.Text = original
	travelling = false
end)

-- Keep the card in sync with your plot's world info ----------------------------------
local function myPlot(): Model?
	local id = player:GetAttribute("PlotId")
	local plots = Workspace:FindFirstChild("Plots")
	if id == nil or plots == nil then
		return nil
	end
	return plots:FindFirstChild("Plot_" .. tostring(id))
end

local plotConnections = {}
local function refreshCard()
	local plot = myPlot()
	if plot == nil then
		return
	end
	local visibility = plot:GetAttribute("Visibility")
	local name = plot:GetAttribute("WorldName")
	if visibility == Net.Visibility.Private then
		nameLabel.Text = "Private World"
	elseif type(name) == "string" then
		nameLabel.Text = name
	else
		nameLabel.Text = player.DisplayName .. "'s World"
	end
	visibilityChip.Text = UI.VisibilityText[visibility]
		or if plot:GetAttribute("WorldInfo") == "unavailable" then "Info unavailable" else "World info loading…"
	local color = UI.VisibilityColor[visibility] or UI.Colors.sub
	visibilityChip.BackgroundColor3 = color
	visibilityChip:FindFirstChildOfClass("UIStroke").Color = color
	local count = plot:GetAttribute("ObjectCount")
	sizeChip.Text = if type(count) == "number" then `{UI.formatNumber(count)} objects` else "— objects"
end

local function watchPlot()
	for _, c in plotConnections do
		c:Disconnect()
	end
	table.clear(plotConnections)
	local plot = myPlot()
	if plot then
		table.insert(plotConnections, plot.AttributeChanged:Connect(refreshCard))
	end
	refreshCard()
end
player:GetAttributeChangedSignal("PlotId"):Connect(watchPlot)
watchPlot()

-- Personalise World Gate prompts --------------------------------------------------------
local function personalise(prompt: ProximityPrompt, plot: Model)
	local function update()
		local owner = plot:GetAttribute("OwnerUserId")
		if owner == player.UserId then
			prompt.ActionText = "Enter Your World"
		elseif type(owner) == "number" and owner ~= 0 then
			prompt.ActionText = "Visit World"
		else
			prompt.ActionText = "Unclaimed"
		end
		local name = plot:GetAttribute("WorldName")
		prompt.ObjectText = if type(name) == "string" then name else "World Gate"
	end
	plot.AttributeChanged:Connect(update)
	update()
end

local plots = Workspace:WaitForChild("Plots")
local function hookPlot(plot: Instance)
	if not plot:IsA("Model") then
		return
	end
	local gate = plot:WaitForChild("WorldGate", 10)
	local portal = gate and gate:WaitForChild("Portal", 10)
	local prompt = portal and portal:WaitForChild("TravelPrompt", 10)
	if prompt then
		personalise(prompt, plot)
	end
end
for _, plot in plots:GetChildren() do
	task.spawn(hookPlot, plot)
end
plots.ChildAdded:Connect(hookPlot)

task.delay(2, function()
	UI.toast(screen, "info", "Welcome to the World Hub! Step through your glowing World Gate to enter your world.")
end)
