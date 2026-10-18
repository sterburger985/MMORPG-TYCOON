--!strict
-- EconomyService: the only code allowed to change a player's Cash.
-- Integer amounts only; Cash never goes negative. The balance is mirrored to the
-- player's "Cash" attribute so the client can display it (read-only for the client).

local PlayerDataService = require(script.Parent.PlayerDataService)

local EconomyService = {}

local function isAmount(amount: number): boolean
	return amount == amount and amount >= 0 and amount ~= math.huge and math.floor(amount) == amount
end

local function sync(player: Player, cash: number)
	player:SetAttribute("Cash", cash)
end

function EconomyService.Init() end

function EconomyService.Start() end

-- Publish the starting balance once the profile exists.
function EconomyService.attach(player: Player)
	local profile = PlayerDataService.get(player)
	if profile then
		sync(player, profile.cash)
	end
end

function EconomyService.getCash(player: Player): number
	local profile = PlayerDataService.get(player)
	return if profile then profile.cash else 0
end

function EconomyService.canAfford(player: Player, amount: number): boolean
	return isAmount(amount) and EconomyService.getCash(player) >= amount
end

-- Deduct amount. Returns false (and changes nothing) if it can't be paid.
function EconomyService.charge(player: Player, amount: number): boolean
	assert(isAmount(amount), "charge amount must be a non-negative integer")
	local profile = PlayerDataService.get(player)
	if profile == nil or profile.cash < amount then
		return false
	end
	profile.cash -= amount
	sync(player, profile.cash)
	return true
end

-- Add amount. Returns false if the player has no profile.
function EconomyService.grant(player: Player, amount: number): boolean
	assert(isAmount(amount), "grant amount must be a non-negative integer")
	local profile = PlayerDataService.get(player)
	if profile == nil then
		return false
	end
	profile.cash += amount
	sync(player, profile.cash)
	return true
end

return EconomyService
