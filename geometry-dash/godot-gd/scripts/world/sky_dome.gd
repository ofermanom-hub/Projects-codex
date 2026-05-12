class_name SkyDome
extends Node2D

const Themes: GDScript = preload("res://scripts/data/themes.gd")

var _sky_rect: ColorRect = null
var _sun_overlay: ColorRect = null
var _sun_cycle_t: float = 0.5

func _ready() -> void:
	_sky_rect = ColorRect.new()
	_sky_rect.size = Vector2(GameManager.WINDOW_W, GameManager.GROUND_Y)
	_sky_rect.color = Color(0.04, 0.04, 0.12)
	_sky_rect.z_index = -12
	add_child(_sky_rect)

	_sun_overlay = ColorRect.new()
	_sun_overlay.size = Vector2(GameManager.WINDOW_W, GameManager.GROUND_Y)
	_sun_overlay.color = Color(0, 0, 0, 0)
	_sun_overlay.z_index = -11
	var sun_mat := CanvasItemMaterial.new()
	sun_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sun_overlay.material = sun_mat
	add_child(_sun_overlay)

func _process(delta: float) -> void:
	if GameManager.state == GameManager.State.PLAYING:
		_sun_cycle_t = fmod(_sun_cycle_t + delta / 90.0, 1.0)
		var t4: float = _sun_cycle_t * 4.0
		var ci: int = int(t4) % 4
		var cf: float = fmod(t4, 1.0)
		_sun_overlay.color = Themes.SUN_CYCLE[ci].lerp(Themes.SUN_CYCLE[(ci + 1) % 4], cf)

	# Sky continuously cycles through all hues — smooth spectrum gradient
	var sky_hue: float = fmod(GameManager.bg_hue, 360.0) / 360.0
	var target_sky: Color = Color.from_hsv(sky_hue, 0.62, 0.11)
	_sky_rect.color = _sky_rect.color.lerp(target_sky, 0.04)

func apply_run_settings() -> void:
	_sun_cycle_t = GameManager.run_sun_start

func set_sky_color(col: Color, animated: bool) -> void:
	if animated:
		create_tween().tween_property(_sky_rect, "color", col, 1.4)
	else:
		_sky_rect.color = col
