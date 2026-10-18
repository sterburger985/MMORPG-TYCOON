--!strict
-- Net: remote names and the reason codes shared by client and server,
-- so both sides always agree on what a rejection means.

local Reason = table.freeze({
	RateLimited = "RateLimited",
	BadArgs = "BadArgs",
	BadItem = "BadItem",
	NoPlot = "NoPlot",
	NotOwner = "NotOwner",
	NotFound = "NotFound",
	OutOfBounds = "OutOfBounds",
	Blocked = "Blocked",
	LimitReached = "LimitReached",
	InsufficientFunds = "InsufficientFunds",
	Internal = "Internal",
	NotReady = "NotReady",
	ReadOnly = "ReadOnly",
})

-- World visibility values (stored in world saves; enforced by servers in the travel phase).
local Visibility = table.freeze({
	Public = "Public",
	FriendsOnly = "FriendsOnly",
	Private = "Private",
})

-- Player-facing text for each reason (used by the build UI's error toasts).
local Message = table.freeze({
	RateLimited = "Slow down a little!",
	BadArgs = "That request didn't make sense.",
	BadItem = "That object isn't available.",
	NoPlot = "You don't have a world yet.",
	NotOwner = "You can only build in your own world.",
	NotFound = "That object is already gone.",
	OutOfBounds = "That's outside your world.",
	Blocked = "Something is already there.",
	LimitReached = "Your world is full. Remove something first.",
	InsufficientFunds = "Not enough Cash.",
	Internal = "Something went wrong. Please try again.",
	NotReady = "Your world is still loading.",
	ReadOnly = "This world can't be changed right now.",
})

export type PlaceResult = {
	ok: boolean,
	reason: string?,
	placedId: string?,
}

export type SettingsResult = {
	ok: boolean,
	reason: string?,
}

export type RemoveResult = {
	ok: boolean,
	reason: string?,
	refund: number?,
}

local Net = table.freeze({
	FolderName = "Remotes",
	RequestPlace = "RequestPlace",
	RequestRemove = "RequestRemove",
	RequestSetVisibility = "RequestSetVisibility", -- World place: owner changes visibility
	RequestEnterMyWorld = "RequestEnterMyWorld", -- Hub: travel to your own world
	RequestReturnToHub = "RequestReturnToHub", -- World: travel back to the hub
	Notify = "Notify", -- RemoteEvent, server -> client: { kind, text, title? }
	Reason = Reason,
	Visibility = Visibility,
	Message = Message,
})

return Net
