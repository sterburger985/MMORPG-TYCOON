--!strict
-- StudioDevStore (STUDIO ONLY): a stand-in for a DataStore so world saving can be tested
-- in Studio without publishing. Each key is a StringValue holding JSON under
-- ServerStorage.WorldDevStore. Values created in Edit mode carry into Play, so a save can
-- be copied back in Edit and "reloaded" in a brand-new session.
--
-- Test switches (attributes on ServerStorage.WorldDevStore, server-only):
--   FailMode = "all"   every call throws, like a DataStore outage
--   OwnerOverride = n  OwnerResolver loads world n instead of the first player's
--
-- It refuses to run outside Studio, so it can never replace real storage in a live game.

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local StudioDevStore = {}

function StudioDevStore.folder(): Folder
	local folder = ServerStorage:FindFirstChild("WorldDevStore")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "WorldDevStore"
		folder.Parent = ServerStorage
	end
	return folder :: Folder
end

function StudioDevStore.new(): any
	assert(RunService:IsStudio(), "StudioDevStore is Studio-only")
	local folder = StudioDevStore.folder()
	local store = {}

	function store.UpdateAsync(_self: any, key: string, transform: (any, any) -> any): any
		task.wait() -- behave like a yielding network call
		if folder:GetAttribute("FailMode") == "all" then
			error("StudioDevStore: simulated DataStore failure (FailMode=all)")
		end
		local value = folder:FindFirstChild(key) :: StringValue?
		local current = nil
		if value and value.Value ~= "" then
			current = HttpService:JSONDecode(value.Value)
		end
		local new = transform(current, nil)
		if new == nil then
			return nil
		end
		local encoded = HttpService:JSONEncode(new)
		if value == nil then
			local created = Instance.new("StringValue")
			created.Name = key
			created.Parent = folder
			value = created
		end
		(value :: StringValue).Value = encoded
		return HttpService:JSONDecode(encoded)
	end

	return store
end

return StudioDevStore
