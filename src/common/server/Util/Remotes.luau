--!strict
-- Remotes: creates (once) and returns the remotes in ReplicatedStorage.Remotes, and
-- sends player notifications (toasts / travel screen) through the shared Notify event.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Remotes = {}

function Remotes.folder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(Net.FolderName)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = Net.FolderName
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

function Remotes.func(name: string): RemoteFunction
	local folder = Remotes.folder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: RemoteFunction
	end
	local created = Instance.new("RemoteFunction")
	created.Name = name
	created.Parent = folder
	return created
end

function Remotes.event(name: string): RemoteEvent
	local folder = Remotes.folder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: RemoteEvent
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = folder
	return created
end

-- kind: "info" | "success" | "error" | "travel"
function Remotes.notify(player: Player, kind: string, text: string, title: string?)
	if player.Parent == nil then
		return
	end
	Remotes.event(Net.Notify):FireClient(player, { kind = kind, text = text, title = title })
end

return Remotes
