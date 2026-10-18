--!nonstrict
-- Tests for ReplicatedStorage.Shared.GridMath.
-- Contract (from the module header): anchor = min corner of the ROTATED footprint,
-- rot = quarter turns, surface CFrame = centre of the plot's top face.
return function(t)
	local GridMath = require(game:GetService("ReplicatedStorage").Shared.GridMath)
	local expect = t.expect
	local CELLS, CELL = 64, 4

	-- Odd quarter-turns swap width and depth.
	t.test("rotatedSize swaps axes on odd rotations", function()
		local w1, d1 = GridMath.rotatedSize(4, 3, 1)
		local w3, d3 = GridMath.rotatedSize(4, 3, 3)
		expect.equal(w1, 3)
		expect.equal(d1, 4)
		expect.equal(w3, 3)
		expect.equal(d3, 4)
	end)

	-- Even quarter-turns keep width and depth.
	t.test("rotatedSize keeps axes on even rotations", function()
		local w0, d0 = GridMath.rotatedSize(4, 3, 0)
		local w2, d2 = GridMath.rotatedSize(4, 3, 2)
		expect.equal(w0, 4)
		expect.equal(d0, 3)
		expect.equal(w2, 4)
		expect.equal(d2, 3)
	end)

	-- Corner cells are inside; one past the edge is outside.
	t.test("inBounds accepts corners and rejects cells past the edge", function()
		expect.truthy(GridMath.inBounds(0, 0, 1, 1, 0, CELLS))
		expect.truthy(GridMath.inBounds(63, 63, 1, 1, 0, CELLS))
		expect.falsy(GridMath.inBounds(64, 0, 1, 1, 0, CELLS))
		expect.falsy(GridMath.inBounds(0, 64, 1, 1, 0, CELLS))
		expect.falsy(GridMath.inBounds(-1, 0, 1, 1, 0, CELLS))
		expect.falsy(GridMath.inBounds(0, -1, 1, 1, 0, CELLS))
	end)

	-- A 4x3 footprint fits flush against the far edge but not one cell further.
	t.test("inBounds uses the full footprint", function()
		expect.truthy(GridMath.inBounds(60, 61, 4, 3, 0, CELLS))
		expect.falsy(GridMath.inBounds(61, 61, 4, 3, 0, CELLS))
		expect.falsy(GridMath.inBounds(60, 62, 4, 3, 0, CELLS))
	end)

	-- Rotating a 4x3 makes it 3 wide and 4 deep for the bounds check.
	t.test("inBounds respects rotation", function()
		expect.truthy(GridMath.inBounds(61, 60, 4, 3, 1, CELLS))
		expect.falsy(GridMath.inBounds(61, 61, 4, 3, 1, CELLS))
	end)

	-- Covers exactly w*d distinct cells.
	t.test("footprintIndices covers every cell exactly once", function()
		local cells = GridMath.footprintIndices(10, 20, 4, 3, 1, CELLS)
		expect.equal(#cells, 12)
		local seen = {}
		for _, i in cells do
			expect.falsy(seen[i])
			seen[i] = true
		end
	end)

	-- A 2x1 at the origin covers cells (0,0),(1,0); rotated it covers (0,0),(0,1).
	t.test("footprintIndices maps to the right cells", function()
		expect.deepEqual(GridMath.footprintIndices(0, 0, 2, 1, 0, CELLS), { 1, 2 })
		expect.deepEqual(GridMath.footprintIndices(0, 0, 2, 1, 1, CELLS), { 1, 65 })
	end)

	-- The corner cell's centre is half a cell in from the plot edge.
	t.test("footprintLocalCenter for the corner cell", function()
		local x, z = GridMath.footprintLocalCenter(0, 0, 1, 1, 0, CELL, CELLS)
		expect.near(x, -126)
		expect.near(z, -126)
	end)

	-- A 2x2 anchored at (31,31) is centred on the plot.
	t.test("footprintLocalCenter centres an even footprint", function()
		local x, z = GridMath.footprintLocalCenter(31, 31, 2, 2, 0, CELL, CELLS)
		expect.near(x, 0)
		expect.near(z, 0)
	end)

	-- Rotation changes where a non-square footprint's centre falls.
	t.test("footprintLocalCenter uses the rotated size", function()
		local x0, z0 = GridMath.footprintLocalCenter(0, 0, 4, 3, 0, CELL, CELLS)
		local x1, z1 = GridMath.footprintLocalCenter(0, 0, 4, 3, 1, CELL, CELLS)
		expect.near(x0, -120)
		expect.near(z0, -122)
		expect.near(x1, -122)
		expect.near(z1, -120)
	end)

	-- Positions are relative to a moved surface, and rot 1 turns the model 90 degrees.
	t.test("footprintCFrame places relative to the surface and rotates", function()
		local surface = CFrame.new(100, 2, 50)
		local cf = GridMath.footprintCFrame(surface, 0, 0, 1, 1, 1, CELL, CELLS)
		expect.near(cf.Position.X, -26)
		expect.near(cf.Position.Y, 2)
		expect.near(cf.Position.Z, -76)
		expect.near(cf.RightVector.Z, -1, 1e-5)
	end)

	-- worldToCell is the inverse of the cell layout, including just-outside points.
	t.test("worldToCell maps positions to cells", function()
		local surface = CFrame.new(100, 2, 50)
		local ax, az = GridMath.worldToCell(surface, surface * Vector3.new(-126, 0, -126), CELL, CELLS)
		expect.equal(ax, 0)
		expect.equal(az, 0)
		local bx, bz = GridMath.worldToCell(surface, surface * Vector3.new(127.9, 0, 127.9), CELL, CELLS)
		expect.equal(bx, 63)
		expect.equal(bz, 63)
		local cx = GridMath.worldToCell(surface, surface * Vector3.new(-128.1, 0, 0), CELL, CELLS)
		expect.equal(cx, -1)
	end)

	-- The cursor cell sits at the centre (or just below centre) of the footprint.
	t.test("anchorForCursor centres the footprint on the cursor", function()
		local x1, z1 = GridMath.anchorForCursor(10, 10, 1, 1, 0)
		local x3, z3 = GridMath.anchorForCursor(10, 10, 3, 3, 0)
		local x4, z4 = GridMath.anchorForCursor(10, 10, 4, 3, 0)
		local x4r, z4r = GridMath.anchorForCursor(10, 10, 4, 3, 1)
		expect.equal(x1, 10)
		expect.equal(z1, 10)
		expect.equal(x3, 9)
		expect.equal(z3, 9)
		expect.equal(x4, 9)
		expect.equal(z4, 9)
		expect.equal(x4r, 9)
		expect.equal(z4r, 9)
	end)
end
