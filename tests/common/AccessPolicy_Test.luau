--!nonstrict
-- Tests for ReplicatedStorage.Shared.AccessPolicy.
-- Contract: owner always allowed; Public anyone; FriendsOnly only friends; Private nobody
-- else; anything unknown is denied.
return function(t)
	local AccessPolicy = require(game:GetService("ReplicatedStorage").Shared.AccessPolicy)
	local expect = t.expect

	-- The owner can always enter, whatever the setting.
	t.test("owner is always allowed", function()
		for _, v in { "Public", "FriendsOnly", "Private", "garbage" } do
			expect.truthy(AccessPolicy.canVisit(v, true, false))
		end
	end)

	-- Public worlds admit anyone.
	t.test("public admits strangers", function()
		expect.truthy(AccessPolicy.canVisit("Public", false, false))
	end)

	-- FriendsOnly admits friends and refuses strangers.
	t.test("friends only checks friendship", function()
		expect.truthy(AccessPolicy.canVisit("FriendsOnly", false, true))
		expect.equal(AccessPolicy.decide("FriendsOnly", false, false), "friends_only")
	end)

	-- Private refuses everyone but the owner, even friends.
	t.test("private refuses friends too", function()
		expect.equal(AccessPolicy.decide("Private", false, true), "private")
	end)

	-- Unknown or missing values fail closed.
	t.test("unknown visibility is denied", function()
		expect.equal(AccessPolicy.decide("Everyone", false, true), "invalid")
		expect.equal(AccessPolicy.decide(nil, false, true), "invalid")
	end)

	-- Every denial has a message; allowed has none.
	t.test("denials explain themselves", function()
		for _, d in { "private", "friends_only", "invalid" } do
			expect.truthy(#AccessPolicy.message(d) > 0)
		end
		expect.equal(AccessPolicy.message("allowed"), "")
	end)
end
