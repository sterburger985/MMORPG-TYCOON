--!strict
-- Config: every gameplay tunable in one place. Shared by server and client.
-- Values marked (proposed) come from GAME_DESIGN §9 and are waiting on Sterling's confirmation.

local Config = {
	-- Grid
	CELL_SIZE = 4, -- studs per grid cell
	PLOT_CELLS = 64, -- plot is PLOT_CELLS x PLOT_CELLS cells (proposed)

	-- Plot layout (plots are built at runtime by PlotService if missing)
	PLOT_COUNT = 6, -- one per player; keep equal to the place's Max Players (proposed)
	PLOT_COLUMNS = 3,
	PLOT_GAP = 48, -- studs of walkway between neighbouring plots
	PLOT_BASE_THICKNESS = 4,
	PLOT_SURFACE_HEIGHT = 2, -- world Y of the plot's top surface

	-- Building
	MAX_PLACED_PER_PLOT = 400,

	-- Economy
	START_CASH = 2000, -- (proposed)
	REFUND_RATE = 1, -- fraction of the price returned on removal (proposed)

	-- Game
	GAME_TITLE = "MMO Tycoon",

	-- Worlds
	DEFAULT_WORLD_NAME = "My MMO",
	MAX_VISITORS = 4, -- visitors per world, on top of the owner (World place Max Players = 5)

	-- Places of the published experience (GameId 10771780924). 0 = find automatically
	-- (the place whose name contains "World" is the World place; the other is the Hub).
	HUB_PLACE_ID = 78195623283467,
	WORLD_PLACE_ID = 86431904123318,

	-- Anti-spam: token bucket per player for build requests
	RATE_LIMIT_PER_SEC = 8,
	RATE_LIMIT_BURST = 12,
}

return table.freeze(Config)
