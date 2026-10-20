--!nonstrict
-- Region HUD (World place): announces the region you walk into ("Whisperwood Forest ·
-- Recommended Lv 11–20") and eases the sky haze towards that region's mood. Display
-- only; uses Continent's region query (pure math, no terrain reads).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent:WaitForChild("UI"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Continent = require(Shared:WaitForChild("Continent"))
local RegionConfig = require(Shared:WaitForChild("RegionConfig"))
local Sections = require(Shared:WaitForChild("Sections"))

local player = Players.LocalPlayer
local screen = UI.screen("RegionHud", 3)

local banner = UI.new("Frame", {
	Name = "RegionBanner",
	Parent = screen,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.2, 0),
	Size = UDim2.fromOffset(560, 96),
	BackgroundTransparency = 1,
})
local title = UI.heading({ Parent = banner, Size = UDim2.new(1, 0, 0, 56), Text = "", MaxTextSize = 52, TextTransparency = 1, TextStrokeTransparency = 1 })
local sub = UI.heading({
	Parent = banner,
	Position = UDim2.new(0, 0, 0, 58),
	Size = UDim2.new(1, 0, 0, 26),
	Text = "",
	MaxTextSize = 22,
	TextColor3 = UI.Colors.glow,
	TextTransparency = 1,
	TextStrokeTransparency = 1,
})

-- Smaller line for the section (the piece of land) you are standing in.
local place = UI.heading({
	Parent = banner,
	Position = UDim2.new(0, 0, 0, 86),
	Size = UDim2.new(1, 0, 0, 22),
	Text = "",
	MaxTextSize = 18,
	TextTransparency = 1,
	TextStrokeTransparency = 1,
})

local FADE = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local showToken = 0

local function show(region)
	showToken += 1
	local token = showToken
	title.Text = region.name
	sub.Text = ("Recommended Lv %d–%d"):format(region.minLevel, region.maxLevel)
	local color = Color3.fromRGB(region.signColor[1], region.signColor[2], region.signColor[3])
	sub.TextColor3 = color
	for _, label in { title, sub } do
		TweenService:Create(label, FADE, { TextTransparency = 0, TextStrokeTransparency = 0.15 }):Play()
	end
	task.delay(4, function()
		if token ~= showToken then
			return
		end
		for _, label in { title, sub } do
			TweenService:Create(label, FADE, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local placeToken = 0
local function showPlace(section, alone: boolean)
	placeToken += 1
	local token = placeToken
	place.Text = "◆ " .. section.name .. " ◆"
	TweenService:Create(place, FADE, { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
	task.delay(if alone then 3 else 4, function()
		if token ~= placeToken then
			return
		end
		TweenService:Create(place, FADE, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local function mood(region)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		return
	end
	local a = region.atmosphere
	TweenService:Create(atmosphere, TweenInfo.new(4, Enum.EasingStyle.Sine), {
		Color = Color3.fromRGB(a.color[1], a.color[2], a.color[3]),
		Decay = Color3.fromRGB(a.decay[1], a.decay[2], a.decay[3]),
		Density = a.density,
		Haze = a.haze,
	}):Play()
end

local current: string? = nil
local currentSection = 0
local lastPos: Vector3? = nil
while true do
	task.wait(0.5)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local pos = root.Position
		if lastPos == nil or (pos - lastPos).Magnitude > 6 then
			lastPos = pos
			local id = Continent.regionIdAt(pos.X, pos.Z)
			local sectionIndex = Sections.indexAt(pos.X, pos.Z)
			local section = Sections.all()[sectionIndex]
			if id ~= current then
				local region = RegionConfig.get(id)
				if region then
					current = id
					mood(region)
					show(region) -- also the welcome banner on arrival
					if section then
						showPlace(section, false)
					end
				end
			elseif sectionIndex ~= currentSection and section then
				showPlace(section, true)
			end
			currentSection = sectionIndex
		end
	end
end
