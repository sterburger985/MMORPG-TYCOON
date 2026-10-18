--!strict
-- SafeTeleport: TeleportAsync with bounded retries, plus handling of teleports that
-- start but fail later (TeleportInitFailed). Callers get a clear success/failure and
-- players get a message instead of silently staying put.

local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local ATTEMPTS = 3
local RETRY_DELAY = 2

local SafeTeleport = {}

local failureListener: ((Player, string) -> ())? = nil

-- Called with (player, message) when a teleport fails after it began.
function SafeTeleport.onFailure(listener: (Player, string) -> ())
	failureListener = listener
end

function SafeTeleport.isAvailable(): boolean
	-- TeleportService doesn't work in Studio playtests (Roblox limitation).
	return not RunService:IsStudio() and game.PlaceId ~= 0
end

function SafeTeleport.teleport(placeId: number, players: { Player }, options: TeleportOptions?): (boolean, string?)
	if not SafeTeleport.isAvailable() then
		return false, "Travel between places only works in the live game, not in Studio."
	end
	local lastError: any = nil
	for attempt = 1, ATTEMPTS do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(placeId, players, options)
		end)
		if ok then
			return true, nil
		end
		lastError = err
		warn(`[SafeTeleport] attempt {attempt}/{ATTEMPTS} failed: {err}`)
		if attempt < ATTEMPTS then
			task.wait(RETRY_DELAY)
		end
	end
	return false, "Travel failed. Please try again. (" .. tostring(lastError) .. ")"
end

TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
	local text = if result == Enum.TeleportResult.GameFull
		then "That world is full right now (4 visitors max). Try again soon!"
		elseif result == Enum.TeleportResult.Flooded then "Too many travel requests. Wait a moment and try again."
		else "Travel failed. Please try again."
	warn(`[SafeTeleport] {player.Name} teleport failed after starting: {result.Name} {message}`)
	if failureListener then
		failureListener(player, text)
	end
end)

return SafeTeleport
