--!strict
-- PlayerDataService: owns each player's session data (Cash and the save-format list of
-- placed objects). Phase 1 keeps it in memory; persistence is added here later and no
-- other service will talk to DataStores.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type PlacedRecord = {
	i: string, -- item id
	x: number,
	z: number,
	r: number,
}

export type Profile = {
	v: number, -- schema version
	cash: number,
	placed: { [string]: PlacedRecord }, -- placedId -> record
	nextId: number,
}

local SCHEMA_VERSION = 1

local profiles: { [Player]: Profile } = {}

local PlayerDataService = {}

function PlayerDataService.Init() end

function PlayerDataService.Start() end

-- Create the player's profile. Phase 1: always a fresh default profile.
function PlayerDataService.load(player: Player): Profile
	local profile: Profile = {
		v = SCHEMA_VERSION,
		cash = Config.START_CASH,
		placed = {},
		nextId = 1,
	}
	profiles[player] = profile
	return profile
end

function PlayerDataService.get(player: Player): Profile?
	return profiles[player]
end

-- Unique (per player) id for a newly placed object.
function PlayerDataService.newPlacedId(profile: Profile): string
	local id = "p" .. profile.nextId
	profile.nextId += 1
	return id
end

function PlayerDataService.release(player: Player)
	profiles[player] = nil
end

return PlayerDataService
