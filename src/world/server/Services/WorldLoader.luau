--!strict
-- WorldLoader: turns "load owner X's world" into a decision the session can act on.
-- Pure apart from the injected WorldStore and wait function, so it is unit-tested.
--
-- Outcomes
--   ready     loaded (or newly created) and validated; we hold the session lock; may modify and save
--   readonly  data is valid but another live session holds the lock; view only, never save
--   failed    nothing safe to show: DataStore error, or the record is unusable (wrong owner,
--             newer version, corrupt). The record is never overwritten.

local WorldConfig = require(script.Parent.WorldConfig)
local WorldSchema = require(script.Parent.WorldSchema)
local WorldStore = require(script.Parent.WorldStore)

export type Outcome = {
	state: "ready" | "readonly" | "failed",
	reason: string, -- "new", "loaded", "locked", "load_error", or a WorldSchema fatal reason
	isNew: boolean,
	lockHeld: boolean,
	world: WorldSchema.World?,
	report: WorldSchema.Report?,
}

export type Options = {
	lockWaitSeconds: number?,
	lockPollSeconds: number?,
	wait: ((number) -> ())?,
}

local WorldLoader = {}

function WorldLoader.load(store: WorldStore.WorldStore, ownerUserId: number, opts: Options?): Outcome
	local options: Options = opts or {}
	local lockWait = options.lockWaitSeconds or WorldConfig.LOCK_WAIT_SECONDS
	local poll = options.lockPollSeconds or 5
	local wait: (number) -> () = options.wait or function(seconds: number)
		task.wait(seconds)
	end

	if not WorldSchema.isValidOwnerId(ownerUserId) then
		return { state = "failed", reason = "invalid_owner", isNew = false, lockHeld = false }
	end

	-- An old session may still be saving (shutdown overlap); give it time to release the lock.
	local result = store:load(ownerUserId)
	local waited = 0
	while result.status == "locked" and waited < lockWait do
		wait(poll)
		waited += poll
		result = store:load(ownerUserId)
	end

	if result.status == "error" then
		-- A failed read is NOT "no save": never create or save a default world here.
		return { state = "failed", reason = "load_error", isNew = false, lockHeld = false }
	end

	local ok, world, report = WorldSchema.decode(result.raw, ownerUserId)

	if result.status == "unsafe" then
		return {
			state = "failed",
			reason = report.fatal or "unsafe_record",
			isNew = false,
			lockHeld = false,
			report = report,
		}
	end

	if result.status == "locked" then
		if ok then
			return { state = "readonly", reason = "locked", isNew = false, lockHeld = false, world = world, report = report }
		end
		return { state = "failed", reason = report.fatal or "invalid", isNew = false, lockHeld = false, report = report }
	end

	-- new or loaded: we hold the lock.
	if not ok then
		store:releaseLock(ownerUserId) -- leave the record exactly as it was
		return { state = "failed", reason = report.fatal or "invalid", isNew = false, lockHeld = false, report = report }
	end
	return {
		state = "ready",
		reason = result.status,
		isNew = result.status == "new",
		lockHeld = true,
		world = world,
		report = report,
	}
end

return WorldLoader
