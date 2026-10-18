--!nonstrict
-- Asset contract tests: every ItemCatalog entry must have a template model in
-- ReplicatedStorage.Assets.Items that GridMath can place correctly.
-- Contract (ItemCatalog / BuildPlaceholderAssets headers):
--   * pivot = bottom centre of the footprint
--   * PrimaryPart "Hitbox" covers exactly size.w x size.d cells and is the only queryable part
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
	local Config = require(ReplicatedStorage.Shared.Config)
	local expect = t.expect
	local items = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Items")

	-- The template folder exists.
	t.test("Assets.Items folder exists", function()
		expect.truthy(items)
	end)

	for _, item in ItemCatalog.all() do
		local function template()
			local m = items and items:FindFirstChild(item.model)
			assert(m and m:IsA("Model"), "missing template model " .. item.model)
			return m
		end

		-- Each catalog item has a Model template.
		t.test(item.id .. " has a template model", function()
			template()
		end)

		-- The Hitbox PrimaryPart matches the catalog footprint.
		t.test(item.id .. " hitbox matches the footprint", function()
			local m = template()
			local hb = m.PrimaryPart
			expect.truthy(hb)
			expect.equal(hb.Name, "Hitbox")
			expect.near(hb.Size.X, item.size.w * Config.CELL_SIZE, 1e-3)
			expect.near(hb.Size.Z, item.size.d * Config.CELL_SIZE, 1e-3)
			expect.truthy(hb.CanQuery)
		end)

		-- The pivot sits at the bottom centre of the hitbox, so placed objects sit on the ground.
		t.test(item.id .. " pivots at the bottom centre", function()
			local m = template()
			local hb = m.PrimaryPart
			local pivot = m:GetPivot()
			local bottomCentre = hb.CFrame * Vector3.new(0, -hb.Size.Y / 2, 0)
			expect.near((pivot.Position - bottomCentre).Magnitude, 0, 1e-3)
			expect.near(pivot.UpVector.Y, 1, 1e-4)
		end)

		-- Only the hitbox answers raycasts; decoration never blocks remove-mode clicks.
		t.test(item.id .. " decorative parts are not queryable", function()
			local m = template()
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and d ~= m.PrimaryPart then
					expect.falsy(d.CanQuery)
				end
			end
		end)
	end
end
