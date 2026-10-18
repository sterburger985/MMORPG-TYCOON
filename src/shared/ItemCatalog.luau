--!strict
-- ItemCatalog: every buildable object. The server's copy is authoritative for
-- price, footprint and layer; the client uses it for the catalog UI and preview.
--
-- size.w runs along the model's local X axis, size.d along local Z (in cells).
-- model is the name of a Model in ReplicatedStorage.Assets.Items whose pivot is
-- the bottom centre of its footprint.
--
-- Phase 1 ships four placeholder items; the final art set arrives in Phase 3.

export type Layer = "Floor" | "Object"

export type Item = {
	id: string,
	name: string,
	price: number,
	size: { w: number, d: number },
	layer: Layer,
	category: string,
	model: string,
}

local function item(def: Item): Item
	table.freeze(def.size)
	return table.freeze(def)
end

local items: { [string]: Item } = {
	stone_path = item({
		id = "stone_path",
		name = "Stone Path",
		price = 5,
		size = { w = 1, d = 1 },
		layer = "Floor",
		category = "Ground",
		model = "StonePath",
	}),
	boulder = item({
		id = "boulder",
		name = "Boulder",
		price = 15,
		size = { w = 1, d = 1 },
		layer = "Object",
		category = "Nature",
		model = "Boulder",
	}),
	oak_tree = item({
		id = "oak_tree",
		name = "Oak Tree",
		price = 40,
		size = { w = 2, d = 2 },
		layer = "Object",
		category = "Nature",
		model = "OakTree",
	}),
	cottage = item({
		id = "cottage",
		name = "Cottage",
		price = 250,
		size = { w = 4, d = 3 },
		layer = "Object",
		category = "Buildings",
		model = "Cottage",
	}),
}
table.freeze(items)

local ItemCatalog = {}

function ItemCatalog.get(id: string): Item?
	return items[id]
end

-- All items, sorted by category then price (stable order for UI).
function ItemCatalog.all(): { Item }
	local list = {}
	for _, def in items do
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		if a.category ~= b.category then
			return a.category < b.category
		end
		if a.price ~= b.price then
			return a.price < b.price
		end
		return a.id < b.id
	end)
	return list
end

return table.freeze(ItemCatalog)
