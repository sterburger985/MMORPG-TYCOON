--!strict
-- WorldState: the one mutable record of "this server's world". Shared by the world
-- services so they never disagree about who owns the world or whether it may change.
-- One World server hosts exactly one world, so module-level state is the session state.

local WorldSchema = require(script.Parent.WorldSchema)

export type Status = "loading" | "ready" | "readonly" | "failed"

local WorldState = {
	status = "loading" :: Status,
	ownerUserId = nil :: number?,
	world = nil :: WorldSchema.World?,
	profile = nil :: WorldSchema.Profile?,
	failReason = nil :: string?,
	closing = false,
	changeCount = 0, -- bumped on every change
	savedChangeCount = 0, -- changeCount at the last successful save
	lastSaveTime = 0,
}

function WorldState.isOwner(player: Player): boolean
	return WorldState.ownerUserId ~= nil and player.UserId == WorldState.ownerUserId
end

-- True when changes may be made (and later saved).
function WorldState.canModify(): boolean
	return WorldState.status == "ready" and not WorldState.closing
end

-- True once the world is built and safe to show (ready or view-only).
function WorldState.isLive(): boolean
	return WorldState.status == "ready" or WorldState.status == "readonly"
end

function WorldState.markChanged()
	WorldState.changeCount += 1
end

function WorldState.isDirty(): boolean
	return WorldState.changeCount ~= WorldState.savedChangeCount
end

return WorldState
