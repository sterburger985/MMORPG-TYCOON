--!strict
-- PlacementRules: pure placement validation shared by server and client.
-- The server's result is authoritative; the client only uses it to tint the preview.
--
-- Check order (first failure wins), matching TECHNICAL_ARCHITECTURE §7:
--   bounds -> occupancy -> per-plot limit -> funds

local GridMath = require(script.Parent.GridMath)
local Net = require(script.Parent.Net)

local Reason = Net.Reason

export type Layer = "Floor" | "Object"

export type PlotState = {
	layers: { [string]: { [number]: string } }, -- layer name -> cell index -> placedId
	count: number, -- objects placed on the plot
}

-- The parts of an item definition the rules care about.
export type Footprint = {
	price: number,
	size: { w: number, d: number },
	layer: Layer,
}

local PlacementRules = {}

function PlacementRules.newPlotState(): PlotState
	return { layers = { Floor = {}, Object = {} }, count = 0 }
end

-- True for finite whole numbers only (rejects NaN, ±inf, fractions, non-numbers).
function PlacementRules.isInteger(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and math.floor(v) == v
end

-- Shape/type check for untrusted RequestPlace arguments.
function PlacementRules.validatePlaceArgs(itemId: any, x: any, z: any, rot: any): (boolean, string?)
	if type(itemId) ~= "string" or #itemId == 0 or #itemId > 32 then
		return false, Reason.BadArgs
	end
	if not (PlacementRules.isInteger(x) and PlacementRules.isInteger(z) and PlacementRules.isInteger(rot)) then
		return false, Reason.BadArgs
	end
	if rot < 0 or rot > 3 then
		return false, Reason.BadArgs
	end
	return true, nil
end

-- Shape/type check for untrusted RequestRemove arguments.
function PlacementRules.validateRemoveArgs(placedId: any): (boolean, string?)
	if type(placedId) ~= "string" or #placedId == 0 or #placedId > 40 then
		return false, Reason.BadArgs
	end
	return true, nil
end

-- Can this item go at (x, z, rot) on this plot with this much cash?
function PlacementRules.check(
	state: PlotState,
	item: Footprint,
	x: number,
	z: number,
	rot: number,
	cash: number,
	plotCells: number,
	maxPlaced: number
): (boolean, string?)
	local w, d = item.size.w, item.size.d
	if not GridMath.inBounds(x, z, w, d, rot, plotCells) then
		return false, Reason.OutOfBounds
	end
	local layer = state.layers[item.layer]
	if layer == nil then
		return false, Reason.BadItem
	end
	for _, index in GridMath.footprintIndices(x, z, w, d, rot, plotCells) do
		if layer[index] ~= nil then
			return false, Reason.Blocked
		end
	end
	if state.count >= maxPlaced then
		return false, Reason.LimitReached
	end
	if cash < item.price then
		return false, Reason.InsufficientFunds
	end
	return true, nil
end

-- Mark the footprint as taken by placedId. Call only after check() passed.
function PlacementRules.occupy(state: PlotState, item: Footprint, x: number, z: number, rot: number, plotCells: number, placedId: string)
	local layer = state.layers[item.layer]
	for _, index in GridMath.footprintIndices(x, z, item.size.w, item.size.d, rot, plotCells) do
		layer[index] = placedId
	end
	state.count += 1
end

-- Free the footprint previously taken by occupy().
function PlacementRules.vacate(state: PlotState, item: Footprint, x: number, z: number, rot: number, plotCells: number)
	local layer = state.layers[item.layer]
	for _, index in GridMath.footprintIndices(x, z, item.size.w, item.size.d, rot, plotCells) do
		layer[index] = nil
	end
	state.count = math.max(0, state.count - 1)
end

return PlacementRules
