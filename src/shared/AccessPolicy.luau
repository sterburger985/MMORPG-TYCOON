--!strict
-- AccessPolicy: who may enter a world. Pure, so the hub (before teleporting) and the
-- World server (on arrival, authoritative) apply exactly the same rule.
--
-- The caller must work out isOwner and isFriend on the SERVER (UserId comparison and
-- Player:IsFriendsWithAsync). An unknown friendship (API error) must be passed as false,
-- so FriendsOnly worlds fail closed.

local Net = require(script.Parent.Net)

local Visibility = Net.Visibility

local AccessPolicy = {}

export type Decision = "allowed" | "private" | "friends_only" | "invalid"

function AccessPolicy.decide(visibility: any, isOwner: boolean, isFriend: boolean): string
	if isOwner then
		return "allowed"
	end
	if visibility == Visibility.Public then
		return "allowed"
	elseif visibility == Visibility.FriendsOnly then
		return if isFriend then "allowed" else "friends_only"
	elseif visibility == Visibility.Private then
		return "private"
	end
	return "invalid" -- unknown setting: deny
end

function AccessPolicy.canVisit(visibility: any, isOwner: boolean, isFriend: boolean): boolean
	return AccessPolicy.decide(visibility, isOwner, isFriend) == "allowed"
end

-- Player-facing explanation for a denial.
function AccessPolicy.message(decision: string): string
	if decision == "private" then
		return "That world is private."
	elseif decision == "friends_only" then
		return "That world is open to the owner's friends only."
	elseif decision == "invalid" then
		return "That world can't be visited right now."
	end
	return ""
end

return AccessPolicy
