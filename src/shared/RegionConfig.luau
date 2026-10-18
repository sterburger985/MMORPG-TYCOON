--!strict
-- RegionConfig: the single source of truth for the continent's ten regions.
--
-- Every gameplay system that needs region names, level ranges, neighbours, landmarks
-- or content sites reads them from here (via Continent.luau for position queries).
-- Coordinates are world studs on the X/Z plane; north is -Z. The player build plot
-- sits at the origin (Greenhaven) and is never moved, so saved buildings keep their
-- coordinates.
--
-- To add a region later: append an entry (unique id, level range, seed, terrain
-- profile), give it neighbours, and re-run the Continent builder in Studio.

export type Site = {
	id: string,
	x: number,
	z: number,
	radius: number,
	height: number?, -- fixed ground height; nil = taken from the natural terrain
	kind: string, -- "Build" (player building area) | "Village" | "Landmark" | "Camp"
	note: string?,
}

export type Landmark = {
	id: string,
	name: string,
	kind: string, -- builder id in WorldTools.Landmarks
	x: number,
	z: number,
	clear: number, -- radius kept free of random scenery
}

export type Region = {
	id: string,
	name: string,
	minLevel: number,
	maxLevel: number,
	kind: string,
	seed: { x: number, z: number }, -- centre of influence (the visible shape is organic)
	weight: number, -- bigger = larger region
	terrain: string, -- terrain profile id (Continent.luau)
	materials: { top: string, accent: string, cliff: string, deep: string },
	neighbors: { string },
	transitions: { [string]: string }, -- neighbour id -> how the border is designed
	landmarks: { Landmark },
	sites: { Site },
	vegetation: { { kind: string, weight: number } },
	density: number, -- scenery per 24 x 24 stud cell, 0..1
	atmosphere: { color: { number }, decay: { number }, density: number, haze: number },
	signColor: { number },
}

local RegionConfig = {}

RegionConfig.VERSION = 1
RegionConfig.SEA_LEVEL = -2
RegionConfig.SEABED = -24
-- Area the builder writes (sea margin included).
RegionConfig.BOUNDS = { minX = -1680, maxX = 1520, minZ = -2120, maxZ = 920 }
-- Coastline: a noisy ellipse.
RegionConfig.COAST = { cx = -80, cz = -620, rx = 1400, rz = 1340 }
-- Width (studs) over which neighbouring regions blend.
RegionConfig.BLEND = 150

local regions: { Region } = {
	{
		id = "Greenhaven",
		name = "Greenhaven Grasslands",
		minLevel = 1,
		maxLevel = 10,
		kind = "Grassland",
		seed = { x = 40, z = 130 },
		weight = 150,
		terrain = "rolling",
		materials = { top = "Grass", accent = "Ground", cliff = "Rock", deep = "Ground" },
		neighbors = { "Whisperwood", "Mirehollow", "Frostpeak", "Verdantwild" },
		transitions = {
			Whisperwood = "Meadow gives way to scattered oaks, then the forest edge thickens.",
			Mirehollow = "The northern meadows dip into a wet hollow where a stream spreads into reeds.",
			Frostpeak = "Grassy foothills climb into rocky slopes along the Silverrun valley.",
			Verdantwild = "The eastern road crosses the Silverrun; warm hills sprout ferns and palms.",
		},
		landmarks = {
			{ id = "ElderOak", name = "The Elder Oak", kind = "ElderOak", x = 110, z = 330, clear = 60 },
		},
		sites = {
			{ id = "StartingMeadow", x = 0, z = 10, radius = 235, height = 1.4, kind = "Build", note = "Player build plot (64 x 64 cells)" },
			{ id = "MillbrookMeadow", x = -150, z = 230, radius = 60, kind = "Village", note = "Open meadow west of the plot" },
			{ id = "ElderHill", x = 110, z = 330, radius = 55, kind = "Landmark" },
		},
		vegetation = { { kind = "Oak", weight = 5 }, { kind = "Flowers", weight = 5 }, { kind = "Shrub", weight = 3 }, { kind = "Rock", weight = 2 } },
		density = 0.16,
		atmosphere = { color = { 199, 216, 236 }, decay = { 106, 124, 155 }, density = 0.3, haze = 1 },
		signColor = { 116, 214, 120 },
	},
	{
		id = "Whisperwood",
		name = "Whisperwood Forest",
		minLevel = 11,
		maxLevel = 20,
		kind = "Forest",
		seed = { x = -640, z = 170 },
		weight = 125,
		terrain = "woodland",
		materials = { top = "LeafyGrass", accent = "Mud", cliff = "Rock", deep = "Ground" },
		neighbors = { "Greenhaven", "SunscarDesert", "Mirehollow" },
		transitions = {
			Greenhaven = "Scattered oaks thicken into old forest.",
			SunscarDesert = "The northern woods dry out: bare stone, dead trees, then sandstone.",
			Mirehollow = "Forest floor turns to mud and moss towards the swamp.",
		},
		landmarks = {
			{ id = "Heartroot", name = "Heartroot, the Great Tree", kind = "Heartroot", x = -700, z = 230, clear = 70 },
			{ id = "OvergrownRuins", name = "Overgrown Ruins", kind = "ForestRuins", x = -520, z = 40, clear = 45 },
		},
		sites = {
			{ id = "HeartrootGlade", x = -700, z = 230, radius = 75, kind = "Landmark" },
			{ id = "MossbrookClearing", x = -560, z = 420, radius = 65, kind = "Village", note = "Clearing by the Mossbrook" },
			{ id = "RuinGlade", x = -520, z = 40, radius = 50, kind = "Camp" },
		},
		vegetation = {
			{ kind = "ForestTree", weight = 6 },
			{ kind = "Oak", weight = 2 },
			{ kind = "GiantTree", weight = 1 },
			{ kind = "MossyRock", weight = 2 },
			{ kind = "Log", weight = 1 },
			{ kind = "Shrub", weight = 3 },
		},
		density = 0.62,
		atmosphere = { color = { 172, 204, 178 }, decay = { 70, 104, 86 }, density = 0.36, haze = 1.4 },
		signColor = { 70, 170, 96 },
	},
	{
		id = "SunscarDesert",
		name = "Sunscar Desert",
		minLevel = 21,
		maxLevel = 30,
		kind = "Desert",
		seed = { x = -780, z = -450 },
		weight = 125,
		terrain = "desert",
		materials = { top = "Sand", accent = "Ground", cliff = "Sandstone", deep = "Sandstone" },
		neighbors = { "Whisperwood", "Mirehollow", "Ashenreach", "StarfallHighlands" },
		transitions = {
			Whisperwood = "Dry woodland and exposed stone break into sandstone and sand.",
			Mirehollow = "A rocky basin with an oasis spring feeds the first marsh pools.",
			Ashenreach = "Sandstone darkens to scorched rock and ash dunes.",
			StarfallHighlands = "Wind-carved sandstone pillars rise into pale crystal plateaus.",
		},
		landmarks = {
			{ id = "SunscarArch", name = "The Sunscar Arch", kind = "SandstoneArch", x = -860, z = -520, clear = 70 },
			{ id = "SunkenTemple", name = "Sunken Temple", kind = "DesertRuins", x = -640, z = -300, clear = 50 },
		},
		sites = {
			{ id = "ArchFlats", x = -860, z = -520, radius = 80, kind = "Landmark" },
			{ id = "DuneSea", x = -620, z = -600, radius = 70, kind = "Village", note = "Flat basin near the oasis" },
			{ id = "TempleSands", x = -640, z = -300, radius = 55, kind = "Camp" },
		},
		vegetation = { { kind = "Cactus", weight = 4 }, { kind = "DesertShrub", weight = 4 }, { kind = "SandRock", weight = 3 }, { kind = "DeadTree", weight = 1 } },
		density = 0.11,
		atmosphere = { color = { 238, 214, 170 }, decay = { 196, 140, 86 }, density = 0.34, haze = 2.2 },
		signColor = { 232, 186, 96 },
	},
	{
		id = "Mirehollow",
		name = "Mirehollow Swamps",
		minLevel = 31,
		maxLevel = 40,
		kind = "Swamp",
		seed = { x = -200, z = -560 },
		weight = 85,
		terrain = "swamp",
		materials = { top = "Mud", accent = "LeafyGrass", cliff = "Rock", deep = "Mud" },
		neighbors = { "Greenhaven", "Whisperwood", "SunscarDesert", "Frostpeak", "Ashenreach" },
		transitions = {
			Greenhaven = "Meadow streams spread into reed beds and pools.",
			Whisperwood = "Forest mud deepens into marsh.",
			SunscarDesert = "The oasis spring soaks the sand into dark wet soil.",
			Frostpeak = "Wet lowlands rise into rocky, pine-covered foothills.",
			Ashenreach = "Bog water turns sulphurous; the ground darkens to ash.",
		},
		landmarks = {
			{ id = "DrownedTower", name = "The Drowned Tower", kind = "DrownedTower", x = -150, z = -620, clear = 45 },
		},
		sites = {
			{ id = "TowerIsle", x = -150, z = -620, radius = 50, kind = "Landmark" },
			{ id = "ReedbankClearing", x = -300, z = -470, radius = 55, kind = "Village", note = "Dry raised ground among the pools" },
			{ id = "BogLanding", x = -40, z = -480, radius = 45, kind = "Camp" },
		},
		vegetation = { { kind = "SwampTree", weight = 5 }, { kind = "Reeds", weight = 6 }, { kind = "MossyRock", weight = 1 }, { kind = "Log", weight = 2 } },
		density = 0.3,
		atmosphere = { color = { 168, 188, 150 }, decay = { 86, 104, 70 }, density = 0.45, haze = 2.4 },
		signColor = { 128, 160, 96 },
	},
	{
		id = "Frostpeak",
		name = "Frostpeak Mountains",
		minLevel = 41,
		maxLevel = 50,
		kind = "Mountains",
		seed = { x = 440, z = -600 },
		weight = 120,
		terrain = "mountains",
		materials = { top = "Grass", accent = "Ground", cliff = "Rock", deep = "Rock" },
		neighbors = { "Greenhaven", "Mirehollow", "Verdantwild", "GlacialExpanse", "Ashenreach" },
		transitions = {
			Greenhaven = "Foothills along the Silverrun valley.",
			Mirehollow = "Rocky foothills and pines rise out of the marsh.",
			Verdantwild = "South-facing valleys grow warm and lush.",
			GlacialExpanse = "Above the passes the snow line drops until everything is ice.",
			Ashenreach = "Bare grey rock turns black where old lava flowed.",
		},
		landmarks = {
			{ id = "SkywardShrine", name = "Skyward Shrine", kind = "MountainShrine", x = 560, z = -760, clear = 50 },
			{ id = "SilverFalls", name = "Silver Falls", kind = "Waterfall", x = 300, z = -640, clear = 30 },
		},
		sites = {
			{ id = "ShrinePlateau", x = 560, z = -760, radius = 60, kind = "Landmark" },
			{ id = "PineHollow", x = 320, z = -470, radius = 65, kind = "Village", note = "Alpine meadow below the lake" },
			{ id = "PassCamp", x = 640, z = -480, radius = 45, kind = "Camp" },
		},
		vegetation = { { kind = "Pine", weight = 7 }, { kind = "Rock", weight = 3 }, { kind = "SnowPine", weight = 2 } },
		density = 0.28,
		atmosphere = { color = { 200, 216, 236 }, decay = { 120, 140, 170 }, density = 0.32, haze = 0.8 },
		signColor = { 170, 196, 230 },
	},
	{
		id = "Verdantwild",
		name = "Verdantwild Jungle",
		minLevel = 51,
		maxLevel = 60,
		kind = "Jungle",
		seed = { x = 760, z = 170 },
		weight = 120,
		terrain = "jungle",
		materials = { top = "LeafyGrass", accent = "Mud", cliff = "Limestone", deep = "Ground" },
		neighbors = { "Greenhaven", "Frostpeak" },
		transitions = {
			Greenhaven = "Across the Silverrun the hills turn humid; palms and ferns crowd in.",
			Frostpeak = "Warm valleys climb into pine forest.",
			-- The jungle never touches the ice: the Highpass climbs over Frostpeak's eastern ridge.
		},
		landmarks = {
			{ id = "CanopyTemple", name = "Temple of the Canopy", kind = "JungleTemple", x = 800, z = 260, clear = 70 },
			{ id = "JadeFalls", name = "Jade Falls", kind = "Waterfall", x = 960, z = -150, clear = 35 },
		},
		sites = {
			{ id = "TempleClearing", x = 800, z = 260, radius = 80, kind = "Landmark" },
			{ id = "VineHollow", x = 620, z = 40, radius = 60, kind = "Village", note = "Clearing on the jungle edge" },
			{ id = "RiverCamp", x = 640, z = 270, radius = 45, kind = "Camp" },
		},
		vegetation = { { kind = "JungleTree", weight = 5 }, { kind = "Palm", weight = 3 }, { kind = "Fern", weight = 5 }, { kind = "BigLeaf", weight = 3 } },
		density = 0.6,
		atmosphere = { color = { 186, 224, 196 }, decay = { 90, 130, 100 }, density = 0.3, haze = 1.3 },
		signColor = { 60, 200, 120 },
	},
	{
		id = "GlacialExpanse",
		name = "Glacial Expanse",
		minLevel = 61,
		maxLevel = 70,
		kind = "Glacier",
		seed = { x = 450, z = -1200 },
		weight = 120,
		terrain = "glacier",
		materials = { top = "Snow", accent = "Glacier", cliff = "Glacier", deep = "Rock" },
		neighbors = { "Frostpeak", "Ashenreach", "DragonsEnd" },
		transitions = {
			Frostpeak = "Snowfields above the treeline flatten into the glacier plain.",
			DragonsEnd = "Along the north coast a glacier tongue grinds into the dark peaks.",
			Ashenreach = "Snow melts off warm black rock; steam rises where ice meets ash.",
		},
		landmarks = {
			{ id = "FrozenSpires", name = "The Frozen Spires", kind = "IceSpires", x = 600, z = -1320, clear = 70 },
			{ id = "RimeCave", name = "Rime Cave", kind = "IceCave", x = 300, z = -1100, clear = 40 },
		},
		sites = {
			{ id = "SpireField", x = 600, z = -1320, radius = 70, kind = "Landmark" },
			{ id = "WhiteHollow", x = 420, z = -1180, radius = 70, kind = "Village", note = "Sheltered snow plain" },
			{ id = "IceCamp", x = 300, z = -1100, radius = 45, kind = "Camp" },
		},
		vegetation = { { kind = "SnowPine", weight = 2 }, { kind = "IceSpike", weight = 3 }, { kind = "SnowRock", weight = 4 } },
		density = 0.1,
		atmosphere = { color = { 214, 232, 255 }, decay = { 150, 180, 220 }, density = 0.42, haze = 1.6 },
		signColor = { 160, 220, 255 },
	},
	{
		id = "Ashenreach",
		name = "Ashenreach",
		minLevel = 71,
		maxLevel = 80,
		kind = "Volcanic",
		seed = { x = -260, z = -1160 },
		weight = 100,
		terrain = "volcanic",
		materials = { top = "Basalt", accent = "Asphalt", cliff = "Basalt", deep = "Basalt" },
		neighbors = { "SunscarDesert", "Mirehollow", "Frostpeak", "GlacialExpanse", "StarfallHighlands", "DragonsEnd" },
		transitions = {
			SunscarDesert = "Scorched sandstone and ash dunes.",
			Mirehollow = "Sulphur pools and blackened reeds.",
			Frostpeak = "Grey mountain rock turns to old black lava.",
			GlacialExpanse = "Ice gives way to bare stone, then dark rock and steam vents.",
			StarfallHighlands = "Black rock cracks open around the first glowing crystals.",
			DragonsEnd = "Jagged volcanic ridges grow into the dark mountains of Dragon's End.",
		},
		landmarks = {
			{ id = "CinderMaw", name = "The Cinder Maw", kind = "Crater", x = -230, z = -1210, clear = 150 },
			{ id = "AshKeep", name = "Ruins of Ash Keep", kind = "AshFortress", x = -60, z = -1020, clear = 55 },
		},
		sites = {
			{ id = "KeepTerrace", x = -60, z = -1020, radius = 60, kind = "Landmark" },
			{ id = "EmberFlats", x = -420, z = -1000, radius = 60, kind = "Village", note = "Safe, cooled lava plain" },
		},
		vegetation = { { kind = "BasaltSpire", weight = 3 }, { kind = "DeadTree", weight = 2 }, { kind = "SteamVent", weight = 1 }, { kind = "AshRock", weight = 3 } },
		density = 0.12,
		atmosphere = { color = { 220, 170, 150 }, decay = { 120, 60, 50 }, density = 0.42, haze = 2.6 },
		signColor = { 255, 120, 80 },
	},
	{
		id = "StarfallHighlands",
		name = "Starfall Highlands",
		minLevel = 81,
		maxLevel = 90,
		kind = "Arcane",
		seed = { x = -920, z = -1080 },
		weight = 100,
		terrain = "highlands",
		materials = { top = "Salt", accent = "Limestone", cliff = "Limestone", deep = "Limestone" },
		neighbors = { "SunscarDesert", "Ashenreach", "DragonsEnd" },
		transitions = {
			SunscarDesert = "Sandstone pillars give way to pale terraces.",
			Ashenreach = "Cracked black rock with crystals pushing through.",
			DragonsEnd = "The terraces break into jagged dark cliffs.",
		},
		landmarks = {
			{ id = "Observatory", name = "Starfall Observatory", kind = "Observatory", x = -1000, z = -1150, clear = 60 },
			{ id = "Starheart", name = "The Starheart Crystal", kind = "GiantCrystal", x = -820, z = -960, clear = 55 },
		},
		sites = {
			{ id = "ObservatoryPlateau", x = -1000, z = -1150, radius = 65, kind = "Landmark" },
			{ id = "CrystalTerrace", x = -820, z = -960, radius = 60, kind = "Landmark" },
			{ id = "MoonlitFlats", x = -1100, z = -900, radius = 60, kind = "Village", note = "Open terrace" },
		},
		vegetation = { { kind = "Crystal", weight = 5 }, { kind = "GlowShroom", weight = 3 }, { kind = "StarTree", weight = 2 }, { kind = "PaleRock", weight = 2 } },
		density = 0.24,
		atmosphere = { color = { 210, 200, 255 }, decay = { 120, 100, 200 }, density = 0.36, haze = 1.6 },
		signColor = { 190, 150, 255 },
	},
	{
		id = "DragonsEnd",
		name = "Dragon's End",
		minLevel = 91,
		maxLevel = 100,
		kind = "Endgame",
		seed = { x = -560, z = -1620 },
		weight = 125,
		terrain = "dragon",
		materials = { top = "Slate", accent = "Rock", cliff = "Slate", deep = "Slate" },
		neighbors = { "Ashenreach", "StarfallHighlands", "GlacialExpanse" },
		transitions = {
			GlacialExpanse = "Ice gives way to snow-capped black slate.",
			Ashenreach = "Volcanic ridges grow into the dark peaks.",
			StarfallHighlands = "Crystal terraces end at black cliffs.",
		},
		landmarks = {
			{ id = "DragonCitadel", name = "The Dragon Citadel", kind = "Citadel", x = -560, z = -1640, clear = 110 },
			{ id = "Dragonbones", name = "Dragonbone Pass", kind = "Dragonbones", x = -640, z = -1515, clear = 45 },
		},
		sites = {
			{ id = "CitadelPlateau", x = -560, z = -1640, radius = 110, kind = "Landmark" },
			{ id = "BonePass", x = -640, z = -1515, radius = 40, kind = "Landmark" },
			{ id = "WatchCamp", x = -440, z = -1720, radius = 40, kind = "Camp" },
		},
		vegetation = { { kind = "JaggedRock", weight = 4 }, { kind = "DeadTree", weight = 2 }, { kind = "AshRock", weight = 2 } },
		density = 0.1,
		atmosphere = { color = { 176, 166, 190 }, decay = { 80, 70, 100 }, density = 0.38, haze = 2 },
		signColor = { 200, 80, 90 },
	},
}

RegionConfig.regions = regions

local byId: { [string]: Region } = {}
for index, region in regions do
	byId[region.id] = region
	;(region :: any).index = index
end

function RegionConfig.get(id: string): Region?
	return byId[id]
end

function RegionConfig.all(): { Region }
	return regions
end

-- Roads, in progression order plus shortcuts. Points are rough waypoints; the builder
-- smooths heights along them and keeps grades walkable.
RegionConfig.ROADS = {
	{
		id = "PilgrimRoad",
		name = "Pilgrim's Road",
		points = {
			{ -150, 0 }, { -290, 40 }, { -440, 120 }, { -610, 150 }, -- Greenhaven -> Whisperwood
			{ -720, 40 }, { -780, -160 }, { -800, -340 }, { -760, -450 }, -- -> Sunscar
			{ -600, -500 }, { -420, -520 }, { -260, -540 }, -- -> Mirehollow
			{ -80, -580 }, { 120, -560 }, { 300, -540 }, { 440, -600 }, -- -> Frostpeak
			{ 560, -460 }, { 650, -260 }, { 700, -60 }, { 740, 140 }, -- -> Verdantwild
		},
	},
	{
		id = "Highpass",
		name = "The Highpass",
		points = { { 740, 140 }, { 900, -60 }, { 920, -360 }, { 820, -700 }, { 660, -980 }, { 470, -1180 } },
	},
	{
		id = "AshenTrail",
		name = "Ashen Trail",
		points = {
			{ 470, -1180 }, { 260, -1220 }, { 60, -1140 }, { -100, -1060 }, -- Glacial -> Ashenreach
			{ -400, -1020 }, { -640, -1000 }, { -900, -1060 }, -- -> Starfall
			{ -980, -1260 }, { -860, -1420 }, { -700, -1470 }, { -580, -1560 }, -- -> Dragon's End
		},
	},
	{ id = "MarshPath", name = "Marsh Path", points = { { 0, -150 }, { -40, -320 }, { -150, -460 }, { -260, -540 } } },
	{ id = "EastRoad", name = "East Road", points = { { 150, 0 }, { 360, 70 }, { 560, 140 }, { 740, 140 } } },
	{ id = "CoastPath", name = "Coast Path", points = { { -20, 150 }, { -120, 320 }, { -330, 300 }, { -520, 380 } } },
}

-- Rivers flow from the first point to the last. dry = a dry riverbed (no water).
RegionConfig.RIVERS = {
	{ id = "Silverrun", name = "Silverrun", width = 14, depth = 5, points = { { 300, -660 }, { 230, -520 }, { 150, -380 }, { 210, -220 }, { 235, -40 }, { 250, 180 }, { 300, 420 }, { 340, 800 } } },
	{ id = "JadeRiver", name = "Jade River", width = 12, depth = 5, points = { { 960, -160 }, { 880, 60 }, { 930, 380 }, { 1040, 760 } } },
	{ id = "Mossbrook", name = "Mossbrook", width = 8, depth = 3, points = { { -540, -40 }, { -600, 180 }, { -520, 420 }, { -460, 800 } } },
	{ id = "SunscarWash", name = "Sunscar Wash", width = 12, depth = 4, dry = true, points = { { -1000, -700 }, { -780, -620 }, { -560, -560 }, { -380, -540 } } },
}

-- Lakes and pools. ice = frozen surface (walkable Ice).
RegionConfig.LAKES = {
	{ id = "Mirrormere", name = "Mirrormere Pond", x = -230, z = 420, radius = 48 },
	{ id = "Oasis", name = "Sunscar Oasis", x = -470, z = -600, radius = 34 },
	{ id = "Coldwater", name = "Coldwater Lake", x = 300, z = -700, radius = 68 },
	{ id = "JadePool", name = "Jade Pool", x = 960, z = -170, radius = 44 },
	{ id = "Frostmere", name = "Frostmere", x = 560, z = -1460, radius = 90, ice = true },
}

-- Lava-like channels (solid CrackedLava, walkable, purely visual).
RegionConfig.LAVA = {
	{ points = { { -230, -1210 }, { -120, -1300 }, { 0, -1340 } }, width = 7 },
	{ points = { { -230, -1210 }, { -380, -1260 }, { -470, -1340 } }, width = 6 },
}

return RegionConfig
