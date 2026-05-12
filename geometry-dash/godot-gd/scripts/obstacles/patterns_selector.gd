class_name PatternsSelector
extends RefCounted

const Patterns: GDScript = preload("res://scripts/data/patterns.gd")

# Pick one pattern from Patterns.ALL. Score gates higher tiers; the difficulty
# wave can briefly unlock a few extra (or fewer) tiers.
static func pick(score: int, difficulty: float) -> Array:
	var base_max: int
	if   score < 40:  base_max = 4
	elif score < 90:  base_max = 9
	elif score < 160: base_max = 16
	elif score < 250: base_max = 21
	elif score < 360: base_max = 27
	else:             base_max = Patterns.ALL.size()
	var tier_offset: int = int((difficulty - 0.7) * 8.0)
	var max_pat: int = clampi(base_max + tier_offset, 1, Patterns.ALL.size())
	return Patterns.ALL[randi() % max_pat]
