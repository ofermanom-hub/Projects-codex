class_name Themes
extends RefCounted

# [sky_color, grid_alpha, name, far_pool, mid_pool, ground_color]
# far_pool / mid_pool are pool-name strings (or null) — Main resolves them per run
const BASE: Array = [
	[Color(0.04,0.04,0.12), 1.00, "CYBER",    "abstract", null,     Color(0.04,0.02,0.10)],
	[Color(0.08,0.28,0.08), 0.12, "FOREST",   "nature",   "sky",    Color(0.04,0.18,0.04)],
	[Color(0.55,0.30,0.06), 0.08, "DESERT",   "desert",   null,     Color(0.35,0.18,0.04)],
	[Color(0.00,0.00,0.06), 0.28, "SPACE",    null,        null,    Color(0.01,0.01,0.08)],
	[Color(0.18,0.04,0.28), 0.10, "MUSHROOM", "mushroom", "sky",    Color(0.12,0.02,0.18)],
	[Color(0.30,0.60,0.88), 0.06, "SKY",      "nature",   "sky",    Color(0.10,0.40,0.10)],
	[Color(0.06,0.04,0.18), 0.35, "CASTLE",   "castle",   "sky",    Color(0.04,0.02,0.12)],
	[Color(0.08,0.05,0.05), 0.50, "DUNGEON",  "urban",    "castle", Color(0.06,0.04,0.04)],
	[Color(0.06,0.06,0.08), 0.65, "CITY",     "urban",    "urban",  Color(0.04,0.04,0.06)],
	[Color(0.12,0.30,0.12), 0.10, "JUNGLE",   "nature",   "nature", Color(0.06,0.20,0.06)],
]

const SCORES: Array[int] = [0, 22, 50, 88, 135, 190, 260, 340, 435, 550]

const SUN_CYCLE: Array[Color] = [
	Color(0.00,0.00,0.00,0.00),
	Color(0.80,0.25,0.00,0.28),
	Color(1.00,0.90,0.30,0.12),
	Color(0.55,0.10,0.25,0.25),
]

const SPACE_INDEX: int = 3
