class_name ThemeDirector
extends Node

const Themes: GDScript = preload("res://scripts/data/themes.gd")

# ── Background texture pools ─────────────────────────────────────────────────
const _BG_NATURE: Array[Texture2D] = [
	preload("res://assets/sprites/kenney/bg_trees.png"),
	preload("res://assets/sprites/kenney/bg_trees2.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_remastered_backgroundColorForest.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_remastered_backgroundForest.png"),
	preload("res://assets/sprites/kenney/bg_platformer_art_mushrooms_bg_grasslands.png"),
	preload("res://assets/sprites/kenney/bg_hills.png"),
	preload("res://assets/sprites/kenney/bg_hills2.png"),
	preload("res://assets/sprites/kenney/bg_grass.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_remastered_backgroundColorGrass.png"),
]
const _BG_DESERT: Array[Texture2D] = [
	preload("res://assets/sprites/kenney/bg_desert.png"),
	preload("res://assets/sprites/kenney/bg_desert2.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_remastered_backgroundColorDesert.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_remastered_backgroundDesert.png"),
	preload("res://assets/sprites/kenney/bg_platformer_art_mushrooms_bg_desert.png"),
]
const _BG_SKY: Array[Texture2D] = [
	preload("res://assets/sprites/kenney/bg_sky.png"),
	preload("res://assets/sprites/kenney/bg_clouds.png"),
	preload("res://assets/sprites/kenney/bg_clouds2.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_remastered_backgroundColorFall.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_cloud1.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_cloud2.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_cloud3.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_cloud4.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_cloud5.png"),
]
const _BG_CASTLE: Array[Texture2D] = [
	preload("res://assets/sprites/kenney/bg_castle.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_remastered_backgroundCastles.png"),
	preload("res://assets/sprites/kenney/bg_platformer_art_mushrooms_bg_castle.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_castle_beige.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_castle_grey.png"),
	preload("res://assets/sprites/kenney/bg_background_elements_castle_wall.png"),
]
const _BG_MUSHROOM: Array[Texture2D] = [
	preload("res://assets/sprites/kenney/bg_mushroom.png"),
	preload("res://assets/sprites/kenney/bg_mushroom2.png"),
	preload("res://assets/sprites/kenney/bg_platformer_art_mushrooms_bg_shroom.png"),
]
const _BG_ABSTRACT: Array[Texture2D] = [
	preload("res://assets/sprites/kenney/bg_abstract_platformer_set1_background.png"),
	preload("res://assets/sprites/kenney/bg_abstract_platformer_set2_background.png"),
	preload("res://assets/sprites/kenney/bg_abstract_platformer_set3_background.png"),
]
const _BG_URBAN: Array[Texture2D] = [
	preload("res://assets/sprites/kenney/bg_asphalt.png"),
	preload("res://assets/sprites/kenney/bg_metalwall.png"),
	preload("res://assets/sprites/kenney/bg_concrete.png"),
	preload("res://assets/sprites/kenney/bg_dungeon.png"),
	preload("res://assets/sprites/kenney/bg_pico_8_city_tilemap.png"),
	preload("res://assets/sprites/kenney/bg_platformer_art_buildings_sheet.png"),
]

# Injected from main.gd before add_child().
var background: Background = null
var sky_dome: SkyDome = null

var _theme_label: Label = null
var _theme_tween: Tween = null
var _current_theme: int = 0

# Per-run texture assignments (one slot per theme index).
var _run_far_textures: Array = []
var _run_mid_textures: Array = []

# Dynamically loaded web-sourced backgrounds.
var _WEB_BG_POOL: Array[Texture2D] = []

func _ready() -> void:
	_load_web_bgs()
	_build_theme_label()

func _build_theme_label() -> void:
	_theme_label = Label.new()
	_theme_label.add_theme_font_size_override("font_size", 26)
	_theme_label.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	_theme_label.position = Vector2(GameManager.WINDOW_W * 0.5 - 80.0, 18.0)
	_theme_label.z_index = 8
	add_child(_theme_label)

func _load_web_bgs() -> void:
	var dir := DirAccess.open("res://assets/sprites/kenney/")
	if not dir:
		return
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		if f.begins_with("bg_web_") and f.ends_with(".png"):
			var path := "res://assets/sprites/kenney/" + f
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				if tex:
					_WEB_BG_POOL.append(tex)
		f = dir.get_next()
	dir.list_dir_end()

# Called after GameManager._randomize_run() rolls a new run.
func apply_run_settings() -> void:
	_run_far_textures.clear()
	_run_mid_textures.clear()
	# Match the SHUFFLED theme order — use run_theme_order[i] to pick pool.
	for i in range(Themes.BASE.size()):
		var mapped: int = GameManager.run_theme_order[i] if i < GameManager.run_theme_order.size() else i
		var td: Array = Themes.BASE[mapped]
		_run_far_textures.append(_pick_pool_tex(td[3]))
		_run_mid_textures.append(_pick_pool_tex(td[4]))

func _pick_pool_tex(pool_name) -> Texture2D:
	# 60% chance to pull from the web background pool when available.
	if not _WEB_BG_POOL.is_empty() and randf() < 0.60:
		return _WEB_BG_POOL[randi() % _WEB_BG_POOL.size()]
	if pool_name == null:
		return null
	var pool: Array
	match pool_name:
		"nature":   pool = _BG_NATURE
		"desert":   pool = _BG_DESERT
		"sky":      pool = _BG_SKY
		"castle":   pool = _BG_CASTLE
		"mushroom": pool = _BG_MUSHROOM
		"abstract": pool = _BG_ABSTRACT
		"urban":    pool = _BG_URBAN
		_:          return null
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

# Apply the theme at slot `raw_idx` (an index into the shuffled run order, not
# into Themes.BASE). Pokes background/sky_dome with the resolved parameters and
# emits GameManager.theme_changed(idx) for downstream observers.
func apply_theme(raw_idx: int, animated: bool) -> void:
	var idx: int = raw_idx
	if GameManager.run_theme_order.size() > raw_idx:
		idx = GameManager.run_theme_order[raw_idx]
	idx = clampi(idx, 0, Themes.BASE.size() - 1)
	_current_theme = raw_idx
	GameManager.theme_index = idx

	var td: Array = Themes.BASE[idx]
	var sky_col: Color    = td[0]
	var grid_a: float     = td[1]
	var name: String      = td[2]
	var ground_col: Color = td[5]
	var far_tex: Texture2D = _run_far_textures[raw_idx] if raw_idx < _run_far_textures.size() else null
	var mid_tex: Texture2D = _run_mid_textures[raw_idx] if raw_idx < _run_mid_textures.size() else null

	if sky_dome:
		sky_dome.set_sky_color(sky_col, animated)
	if background:
		background.set_grid_alpha(grid_a, animated)
		background.set_floor_color(ground_col, animated)
		background.set_far_texture(far_tex, animated)
		background.set_mid_texture(mid_tex, animated)

	if animated:
		_theme_label.text = "— " + name + " —"
		if _theme_tween:
			_theme_tween.kill()
		_theme_tween = create_tween()
		_theme_tween.tween_property(_theme_label, "modulate:a", 1.0, 0.3)
		_theme_tween.tween_interval(1.8)
		_theme_tween.tween_property(_theme_label, "modulate:a", 0.0, 0.6)

	GameManager.theme_changed.emit(idx)

# Call from main._process during PLAYING. Returns true if a switch happened.
func update_from_score(score: int) -> bool:
	var wanted: int = 0
	for i in range(Themes.SCORES.size() - 1, -1, -1):
		if score >= Themes.SCORES[i]:
			wanted = i
			break
	if wanted != _current_theme:
		apply_theme(wanted, true)
		return true
	return false

func current_raw_index() -> int:
	return _current_theme
