--!nonstrict
-- Tests for ReplicatedStorage.Shared.PlacementRules.
-- Contract: argument validation rejects anything that isn't a sane request; check()
-- reports the first failure in the order bounds -> occupancy -> limit -> funds.
return function(t)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local PlacementRules = require(Shared.PlacementRules)
	local Reason = require(Shared.Net).Reason
	local expect = t.expect
	local CELLS, MAX = 64, 400

	local function item(w, d, layer, price)
		return { price = price or 10, size = { w = w, d = d }, layer = layer or "Object" }
	end

	-- A normal request passes the shape check.
	t.test("validatePlaceArgs accepts a valid request", function()
		local ok, reason = PlacementRules.validatePlaceArgs("oak_tree", 3, 7, 2)
		expect.truthy(ok)
		expect.equal(reason, nil)
	end)

	-- Item ids must be non-empty strings of at most 32 characters.
	t.test("validatePlaceArgs rejects bad item ids", function()
		for _, bad in { 5, nil, "", string.rep("a", 33), {} } do
			local ok, reason = PlacementRules.validatePlaceArgs(bad, 0, 0, 0)
			expect.falsy(ok)
			expect.equal(reason, Reason.BadArgs)
		end
	end)

	-- Coordinates must be finite whole numbers.
	t.test("validatePlaceArgs rejects NaN, infinity, fractions and strings", function()
		for _, bad in { 0 / 0, math.huge, -math.huge, 1.5, "3", true } do
			expect.falsy((PlacementRules.validatePlaceArgs("x", bad, 0, 0)))
			expect.falsy((PlacementRules.validatePlaceArgs("x", 0, bad, 0)))
			expect.falsy((PlacementRules.validatePlaceArgs("x", 0, 0, bad)))
		end
	end)

	-- Rotation is limited to 0..3.
	t.test("validatePlaceArgs rejects rotations outside 0..3", function()
		expect.falsy((PlacementRules.validatePlaceArgs("x", 0, 0, 4)))
		expect.falsy((PlacementRules.validatePlaceArgs("x", 0, 0, -1)))
		expect.truthy((PlacementRules.validatePlaceArgs("x", 0, 0, 3)))
	end)

	-- Removal ids must be short non-empty strings.
	t.test("validateRemoveArgs accepts ids and rejects junk", function()
		expect.truthy((PlacementRules.validateRemoveArgs("p12")))
		for _, bad in { 12, nil, "", string.rep("p", 41), {} } do
			local ok, reason = PlacementRules.validateRemoveArgs(bad)
			expect.falsy(ok)
			expect.equal(reason, Reason.BadArgs)
		end
	end)

	-- An empty plot accepts an in-bounds, affordable item.
	t.test("check passes on an empty plot", function()
		local state = PlacementRules.newPlotState()
		local ok, reason = PlacementRules.check(state, item(2, 2), 5, 5, 0, 100, CELLS, MAX)
		expect.truthy(ok)
		expect.equal(reason, nil)
	end)

	-- Footprints hanging off the plot are rejected.
	t.test("check rejects out-of-bounds footprints", function()
		local state = PlacementRules.newPlotState()
		local _, reason = PlacementRules.check(state, item(4, 3), 61, 0, 0, 100, CELLS, MAX)
		expect.equal(reason, Reason.OutOfBounds)
	end)

	-- Any overlap with an object on the same layer is blocked.
	t.test("check rejects overlap on the same layer", function()
		local state = PlacementRules.newPlotState()
		PlacementRules.occupy(state, item(2, 2), 10, 10, 0, CELLS, "p1")
		local _, reason = PlacementRules.check(state, item(2, 2), 11, 11, 0, 100, CELLS, MAX)
		expect.equal(reason, Reason.Blocked)
	end)

	-- Touching (but not overlapping) footprints are fine.
	t.test("check allows adjacent objects", function()
		local state = PlacementRules.newPlotState()
		PlacementRules.occupy(state, item(2, 2), 10, 10, 0, CELLS, "p1")
		expect.truthy((PlacementRules.check(state, item(2, 2), 12, 10, 0, 100, CELLS, MAX)))
	end)

	-- An Object can stand on a Floor tile and vice versa.
	t.test("check lets Floor and Object layers share cells", function()
		local state = PlacementRules.newPlotState()
		PlacementRules.occupy(state, item(1, 1, "Floor"), 4, 4, 0, CELLS, "p1")
		expect.truthy((PlacementRules.check(state, item(1, 1, "Object"), 4, 4, 0, 100, CELLS, MAX)))
		PlacementRules.occupy(state, item(1, 1, "Object"), 8, 8, 0, CELLS, "p2")
		expect.truthy((PlacementRules.check(state, item(1, 1, "Floor"), 8, 8, 0, 100, CELLS, MAX)))
	end)

	-- Once the plot holds maxPlaced objects, nothing more can go down.
	t.test("check enforces the per-plot limit", function()
		local state = PlacementRules.newPlotState()
		state.count = 3
		local _, reason = PlacementRules.check(state, item(1, 1), 0, 0, 0, 100, CELLS, 3)
		expect.equal(reason, Reason.LimitReached)
	end)

	-- One Cash short fails; exactly enough passes.
	t.test("check requires enough cash, exact amount allowed", function()
		local state = PlacementRules.newPlotState()
		local _, reason = PlacementRules.check(state, item(1, 1, "Object", 250), 0, 0, 0, 249, CELLS, MAX)
		expect.equal(reason, Reason.InsufficientFunds)
		expect.truthy((PlacementRules.check(state, item(1, 1, "Object", 250), 0, 0, 0, 250, CELLS, MAX)))
	end)

	-- With several problems at once, bounds is reported before funds.
	t.test("check reports bounds before funds", function()
		local state = PlacementRules.newPlotState()
		local _, reason = PlacementRules.check(state, item(1, 1, "Object", 999), 64, 0, 0, 0, CELLS, MAX)
		expect.equal(reason, Reason.OutOfBounds)
	end)

	-- Vacating frees the cells and lowers the count.
	t.test("vacate frees the footprint", function()
		local state = PlacementRules.newPlotState()
		local tree = item(2, 2)
		PlacementRules.occupy(state, tree, 10, 10, 0, CELLS, "p1")
		expect.equal(state.count, 1)
		PlacementRules.vacate(state, tree, 10, 10, 0, CELLS)
		expect.equal(state.count, 0)
		expect.truthy((PlacementRules.check(state, tree, 10, 10, 0, 100, CELLS, MAX)))
	end)

	-- Unknown layers are treated as a bad item, not a crash.
	t.test("check rejects an unknown layer", function()
		local state = PlacementRules.newPlotState()
		local _, reason = PlacementRules.check(state, item(1, 1, "Sky"), 0, 0, 0, 100, CELLS, MAX)
		expect.equal(reason, Reason.BadItem)
	end)
end
