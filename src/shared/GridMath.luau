--!strict
-- GridMath: pure grid helpers shared by server (authoritative placement) and client (preview).
--
-- Conventions
--   * Cells are integers 0 .. plotCells-1 on X and Z.
--   * An object's anchor (x, z) is the MIN corner cell of its ROTATED footprint.
--   * rot is a quarter-turn count 0..3 (callers validate the range).
--   * The plot "surface" CFrame sits at the centre of the plot's top face.
--   * Item models pivot at the bottom centre of their footprint.

local GridMath = {}

-- Footprint width/depth after rotation: odd quarter-turns swap the axes.
function GridMath.rotatedSize(w: number, d: number, rot: number): (number, number)
	if rot % 2 == 1 then
		return d, w
	end
	return w, d
end

-- 1-based flat index for a cell, used as the key in occupancy tables.
function GridMath.cellIndex(x: number, z: number, plotCells: number): number
	return z * plotCells + x + 1
end

-- True when every cell of the rotated footprint lies inside the plot.
function GridMath.inBounds(x: number, z: number, w: number, d: number, rot: number, plotCells: number): boolean
	local rw, rd = GridMath.rotatedSize(w, d, rot)
	return x >= 0 and z >= 0 and x + rw <= plotCells and z + rd <= plotCells
end

-- Flat indices of every cell covered by the rotated footprint.
-- Callers must check inBounds first; out-of-range cells produce meaningless indices.
function GridMath.footprintIndices(x: number, z: number, w: number, d: number, rot: number, plotCells: number): { number }
	local rw, rd = GridMath.rotatedSize(w, d, rot)
	local out = table.create(rw * rd)
	for dz = 0, rd - 1 do
		for dx = 0, rw - 1 do
			table.insert(out, GridMath.cellIndex(x + dx, z + dz, plotCells))
		end
	end
	return out
end

-- Offset in studs (X, Z) of the footprint centre from the plot centre.
function GridMath.footprintLocalCenter(
	x: number,
	z: number,
	w: number,
	d: number,
	rot: number,
	cellSize: number,
	plotCells: number
): (number, number)
	local rw, rd = GridMath.rotatedSize(w, d, rot)
	local half = plotCells * cellSize / 2
	return (x + rw / 2) * cellSize - half, (z + rd / 2) * cellSize - half
end

-- World pivot for an item model: footprint centre on the surface, turned rot quarter-turns.
function GridMath.footprintCFrame(
	surface: CFrame,
	x: number,
	z: number,
	w: number,
	d: number,
	rot: number,
	cellSize: number,
	plotCells: number
): CFrame
	local lx, lz = GridMath.footprintLocalCenter(x, z, w, d, rot, cellSize, plotCells)
	return surface * CFrame.new(lx, 0, lz) * CFrame.Angles(0, rot * math.pi / 2, 0)
end

-- Cell under a world position. May return cells outside 0..plotCells-1.
function GridMath.worldToCell(surface: CFrame, position: Vector3, cellSize: number, plotCells: number): (number, number)
	local p = surface:PointToObjectSpace(position)
	local half = plotCells * cellSize / 2
	return math.floor((p.X + half) / cellSize), math.floor((p.Z + half) / cellSize)
end

-- Anchor cell that centres a rotated footprint on the cell under the cursor
-- (for even sizes, the cursor cell is the one just below/left of centre).
function GridMath.anchorForCursor(cursorX: number, cursorZ: number, w: number, d: number, rot: number): (number, number)
	local rw, rd = GridMath.rotatedSize(w, d, rot)
	return cursorX - math.floor((rw - 1) / 2), cursorZ - math.floor((rd - 1) / 2)
end

return GridMath
