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
})

export type PlaceResult = {
	ok: boolean,
	reason: string?,
	placedId: string?,
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
	Reason = Reason,
	Message = Message,
})

return Net
