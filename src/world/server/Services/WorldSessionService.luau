--!strict
-- WorldSessionService (World place): runs this server's world from start to shutdown.
--
-- Start-up (runs once per server):
--   1. resolve the owner (OwnerResolver; never from the client)
--   2. load + validate the save (WorldLoader -> WorldStore -> WorldSchema)
--   3. rebuild saved objects on the starter plot (PlacementService.restore)
--   4. mark the world live, then let characters spawn
-- Players never get a character before step 4, and never at all if loading failed.
--
-- Saving: autosave every AUTOSAVE_INTERVAL seconds when something changed (or when the
-- session lock needs refreshing), when the owner leaves, and on shutdown (releasing the lock).
-- Read-only and failed worlds are never saved.

local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)

local EconomyService = require(script.Parent.EconomyService)
local OwnerResolver = require(script.Parent.OwnerResolver)
local PlacementService = require(script.Parent.PlacementService)
local PlotService = require(script.Parent.PlotService)
local StudioDevStore = require(script.Parent.StudioDevStore)
local WorldConfig = require(script.Parent.WorldConfig)
local WorldLoader = require(script.Parent.WorldLoader)
local WorldSchema = require(script.Parent.WorldSchema)
local WorldState = require(script.Parent.WorldState)
local WorldStore = require(script.Parent.WorldStore)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local Reason = Net.Reason

local sessionId = HttpService:GenerateGUID(false)
local store: WorldStore.WorldStore? = nil
local settingsLimiter = RateLimiter.new(2, 4)
local decided = Instance.new("BindableEvent") -- fires once the world is live or failed
local saving = false

local WorldSessionService = {}

local function log(message: string)
	print("[World] " .. message)
end

local function failMessage(): string
	if WorldState.failReason == "load_error" then
		return "Your world couldn't be loaded right now. Nothing was lost - please try again in a minute."
	end
	return "This world couldn't be opened safely. Nothing was changed - please try again later."
end

-- Pick the backing store: real DataStore live; Studio uses the dev store unless configured otherwise.
local function makeStore(): WorldStore.WorldStore
	local backing: any
	if RunService:IsStudio() and WorldConfig.STUDIO_STORE_MODE == "Dev" then
		backing = StudioDevStore.new()
		log("using Studio dev store (ServerStorage.WorldDevStore)")
	else
		-- GetDataStore throws in unpublished places; WorldLoader turns that into load_error.
		local proxy = {}
		function proxy.UpdateAsync(_self: any, key: string, transform: (any, any) -> any): any
			local ds = DataStoreService:GetDataStore(WorldConfig.WORLD_STORE_NAME)
			return ds:UpdateAsync(key, transform)
		end
		backing = proxy
		log("using DataStore " .. WorldConfig.WORLD_STORE_NAME)
	end
	return WorldStore.new({ store = backing, sessionId = sessionId })
end

local function waitUntilDecided()
	if WorldState.status == "loading" then
		decided.Event:Wait()
	end
end

-- Save the world if allowed and needed. Returns true if the save is done (or not needed).
local function saveNow(release: boolean, why: string): boolean
	while saving do
		task.wait(0.1)
	end
	local s, world, profile, owner = store, WorldState.world, WorldState.profile, WorldState.ownerUserId
	if WorldState.status ~= "ready" or s == nil or world == nil or profile == nil or owner == nil then
		return false
	end
	local lockDue = os.time() - WorldState.lastSaveTime >= WorldConfig.LOCK_REFRESH_INTERVAL
	if not release and not WorldState.isDirty() and not lockDue then
		return true
	end

	saving = true
	local snapshot = WorldState.changeCount
	WorldSchema.applyProfile(world, profile)
	local record = WorldSchema.encode(world)
	local started = os.clock()
	local ok, result = pcall(s.save, s, owner, record, release)
	saving = false
	local ms = math.floor((os.clock() - started) * 1000)

	if not ok then
		warn(`[World] save ({why}) threw: {result}`)
		return false
	end
	if result.status == "saved" then
		WorldState.savedChangeCount = snapshot
		WorldState.lastSaveTime = os.time()
		log(`saved ({why}) {#world.objects} objects, {result.bytes} bytes, {ms} ms{if release then ", lock released" else ""}`)
		return true
	end
	if result.status == "lock_lost" or result.status == "missing" then
		-- Another session owns the world now (or it was deleted): stop writing, stop changes.
		WorldState.status = "readonly"
		PlotService.showWorldInfo(world.name, world.visibility, owner, WorldState.status)
		warn(`[World] save ({why}) refused: {result.status}. World is now read-only.`)
		return false
	end
	warn(`[World] save ({why}) failed: {result.status} {result.message or ""} - will retry`)
	return false
end

local function spawnPlayer(player: Player)
	if player.Parent ~= Players then
		return
	end
	if WorldState.status == "failed" then
		player:Kick(failMessage())
		return
	end
	if WorldState.isOwner(player) then
		EconomyService.attach(player)
	elseif not RunService:IsStudio() then
		-- Visiting is the next phase; until access checks exist, only the owner may enter.
		player:Kick("Visiting other worlds arrives in a later update.")
		return
	else
		log(`{player.Name} is not the owner: Studio test visitor, view only`)
	end
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok then
		warn(`[World] could not spawn {player.Name}: {err}`)
	end
end

local function onPlayerAdded(player: Player)
	local spawnConn = player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and character.Parent then
			character:PivotTo(PlotService.getWorldPlot().spawnPad.CFrame + Vector3.new(0, 4, 0))
		end
		-- CharacterAutoLoads is off, so respawning after death is our job.
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Once(function()
				task.delay(Players.RespawnTime, function()
					if player.Parent == Players and WorldState.isLive() then
						pcall(function()
							player:LoadCharacterAsync()
						end)
					end
				end)
			end)
		end
	end)
	player.AncestryChanged:Connect(function()
		if player.Parent == nil then
			spawnConn:Disconnect()
		end
	end)
	waitUntilDecided()
	spawnPlayer(player)
end

local function onPlayerRemoving(player: Player)
	settingsLimiter:forget(player)
	if WorldState.isOwner(player) then
		task.spawn(saveNow, false, "owner_left")
	end
end

-- Owner-only, validated server-side. Visibility is stored now; enforcement on entry
-- arrives with world travel.
local function setVisibility(player: Player, value: any): Net.SettingsResult
	if not settingsLimiter:tryConsume(player) then
		return { ok = false, reason = Reason.RateLimited }
	end
	if not WorldState.isLive() then
		return { ok = false, reason = Reason.NotReady }
	end
	if not WorldState.isOwner(player) then
		return { ok = false, reason = Reason.NotOwner }
	end
	if not WorldState.canModify() then
		return { ok = false, reason = Reason.ReadOnly }
	end
	if not WorldSchema.isValidVisibility(value) then
		return { ok = false, reason = Reason.BadArgs }
	end
	local world = WorldState.world :: WorldSchema.World
	if world.visibility ~= value then
		world.visibility = value
		WorldState.markChanged()
		PlotService.showWorldInfo(world.name, world.visibility, world.ownerUserId, WorldState.status)
	end
	return { ok = true }
end

-- Resolve, load, rebuild. Runs once.
local function startWorld()
	local started = os.clock()
	local owner, source = OwnerResolver.resolve()
	if owner == nil or not WorldSchema.isValidOwnerId(owner) then
		WorldState.status = "failed"
		WorldState.failReason = "no_owner:" .. source
		warn(`[World] no valid owner ({source}); this server will not load a world`)
		decided:Fire()
		return
	end
	WorldState.ownerUserId = owner
	log(`owner {owner} (from {source}), session {sessionId}`)

	local s = makeStore()
	store = s
	local outcome = WorldLoader.load(s, owner)
	local report = outcome.report
	if report then
		for _, d in report.dropped do
			warn(`[World] dropped saved object {d.id}: {d.reason} (kept in quarantine, not built)`)
		end
		for _, fix in report.fixes do
			warn(`[World] repaired saved field: {fix}`)
		end
	end

	if outcome.state == "failed" or outcome.world == nil then
		WorldState.status = "failed"
		WorldState.failReason = outcome.reason
		warn(`[World] load FAILED for owner {owner}: {outcome.reason}. Nothing will be saved.`)
		decided:Fire()
		return
	end

	local world = outcome.world :: WorldSchema.World
	WorldState.world = world
	WorldState.profile = WorldSchema.toProfile(world)

	-- Rebuild saved objects onto the starter plot (validated twice: schema + placement rules).
	local plot = PlotService.getWorldPlot()
	local restored, rejected = 0, 0
	for _, o in world.objects do
		local ok, reason = PlacementService.restore(plot, o.type, o.x, o.z, o.rot, o.id)
		if ok then
			restored += 1
		else
			rejected += 1
			local profile = WorldState.profile :: WorldSchema.Profile
			profile.placed[o.id] = nil
			if #world.quarantine < WorldConfig.MAX_QUARANTINE then
				table.insert(world.quarantine, { Reason = "restore_" .. tostring(reason), Data = { Id = o.id, Type = o.type } })
			end
			warn(`[World] could not rebuild {o.id} ({o.type}): {reason}`)
		end
	end

	WorldState.status = if outcome.state == "ready" then "ready" else "readonly"
	WorldState.lastSaveTime = os.time()
	if outcome.isNew or rejected > 0 or (report and (#report.dropped > 0 or #report.fixes > 0)) then
		WorldState.markChanged() -- persist repairs / first save of the cleaned record
	end
	PlotService.showWorldInfo(world.name, world.visibility, owner, WorldState.status)
	log(
		`world {WorldState.status} ({outcome.reason}): "{world.name}" {restored} objects rebuilt, `
			.. `{if report then #report.dropped else 0} dropped, {rejected} rejected, `
			.. `{math.floor((os.clock() - started) * 1000)} ms`
	)
	decided:Fire()
end

function WorldSessionService.Init()
	Players.CharacterAutoLoads = false -- no one spawns until the world is decided

	local folder = ReplicatedStorage:FindFirstChild(Net.FolderName)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = Net.FolderName
		folder.Parent = ReplicatedStorage
	end
	assert(folder ~= nil)
	if folder:FindFirstChild(Net.RequestSetVisibility) == nil then
		local remote = Instance.new("RemoteFunction")
		remote.Name = Net.RequestSetVisibility
		remote.Parent = folder
	end

	PlacementService.onChanged(function()
		WorldState.markChanged()
	end)
end

function WorldSessionService.Start()
	local folder = ReplicatedStorage:FindFirstChild(Net.FolderName) :: Folder
	local remote = folder:FindFirstChild(Net.RequestSetVisibility) :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, value: any)
		local ok, result = pcall(setVisibility, player, value)
		if ok then
			return result
		end
		warn(`[World] setVisibility error: {result}`)
		return { ok = false, reason = Reason.Internal }
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(startWorld)

	-- Autosave loop: cheap check every interval; writes only when needed.
	task.spawn(function()
		while not WorldState.closing do
			task.wait(WorldConfig.AUTOSAVE_INTERVAL)
			if WorldState.status == "ready" and not WorldState.closing then
				saveNow(false, "autosave")
			end
		end
	end)

	game:BindToClose(function()
		WorldState.closing = true -- no more changes; then one final save that releases the lock
		if WorldState.status == "ready" then
			local ok = saveNow(true, "shutdown")
			if not ok then
				warn("[World] final save on shutdown did not complete; the last good save is kept")
			end
		end
	end)
end

-- For tests and future admin tools: force a save now (server-side only).
function WorldSessionService.saveNow(why: string?): boolean
	return saveNow(false, why or "manual")
end

return WorldSessionService
