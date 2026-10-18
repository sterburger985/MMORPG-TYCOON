--!strict
-- WorldDecor (World place): scenery around the build area so a fresh world already looks
-- like a place: a seeded ring of trees and rocks on the terrain outside the rim, plus the
-- shared lighting preset. Decoration only (not saved, not buildable, never queryable).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Decor = require(script.Parent.Parent.Util.Decor)
local LightingPreset = require(script.Parent.Parent.Util.LightingPreset)

local WorldDecor = {}

local HALF = Config.PLOT_CELLS * Config.CELL_SIZE / 2

-- Height of the ground (terrain or any part) under x/z, or nil if there's nothing there.
local function groundY(x: number, z: number, ignore: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	return if hit then hit.Position.Y else nil
end

function WorldDecor.build()
	local old = Workspace:FindFirstChild("WorldDecor")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "WorldDecor"
	folder.Parent = Workspace

	local ignore: { Instance } = { folder }
	local plotModel = Workspace:FindFirstChild("WorldPlot")
	if plotModel then
		table.insert(ignore, plotModel)
	end

	local rng = Random.new(777)
	local inner, outer = HALF + 26, HALF + 140
	local placed, tries = 0, 0
	while placed < 70 and tries < 1500 do
		tries += 1
		local x = rng:NextNumber(-outer, outer)
		local z = rng:NextNumber(-outer, outer)
		local nearGate = math.abs(x) < 30 and z > HALF and z < HALF + 60 -- keep the Hub Gate path clear
		if (math.abs(x) > inner or math.abs(z) > inner) and not nearGate then
			local y = groundY(x, z, ignore)
			if y then
				local rock = rng:NextNumber() < 0.25
				local model = if rock
					then Decor.prop(folder, "Boulder", Vector3.new(x, y - 0.3, z), rng:NextNumber(0, math.pi * 2), rng:NextNumber(1.3, 2.4))
					else Decor.prop(folder, "OakTree", Vector3.new(x, y - 0.2, z), rng:NextNumber(0, math.pi * 2), rng:NextNumber(1.1, 1.9))
				if model == nil then
					break -- item models missing; skip scenery
				end
				placed += 1
			end
		end
	end

	LightingPreset.apply()
end

function WorldDecor.Init()
	WorldDecor.build()
end

function WorldDecor.Start() end

return WorldDecor
