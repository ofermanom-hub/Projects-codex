class_name Background
extends Node2D

const _BG_SHADER: Shader     = preload("res://shaders/background.gdshader")
const _BG_IMG_SHADER: Shader = preload("res://shaders/bg_image.gdshader")

var _grid_rect: ColorRect = null
var _bg_mat: ShaderMaterial = null
var _bg_far_rect: ColorRect = null
var _bg_far_mat: ShaderMaterial = null
var _bg_mid_rect: ColorRect = null
var _bg_mid_mat: ShaderMaterial = null
var _floor_rect: ColorRect = null
var _ground_line: Line2D = null
var _bg_particles: CPUParticles2D = null

var _scroll: float = 0.0
var _scroll_far: float = 0.0
var _scroll_mid: float = 0.0
var _scroll_speed_far: float = 0.28
var _scroll_speed_mid: float = 0.55
var _particle_hue_offset: float = 0.0

# Per-session animated GIF for the far background layer. When set, overrides the
# static theme texture by streaming frames into the same shader parameter.
var _bg_anim: Variant = null

func _ready() -> void:
	_bg_far_mat = ShaderMaterial.new(); _bg_far_mat.shader = _BG_IMG_SHADER
	_bg_far_rect = ColorRect.new()
	_bg_far_rect.size = Vector2(GameManager.WINDOW_W, GameManager.GROUND_Y)
	_bg_far_rect.material = _bg_far_mat
	_bg_far_rect.z_index = -10
	_bg_far_rect.modulate.a = 0.0
	add_child(_bg_far_rect)

	_bg_mid_mat = ShaderMaterial.new(); _bg_mid_mat.shader = _BG_IMG_SHADER
	_bg_mid_rect = ColorRect.new()
	_bg_mid_rect.size = Vector2(GameManager.WINDOW_W, GameManager.GROUND_Y)
	_bg_mid_rect.material = _bg_mid_mat
	_bg_mid_rect.z_index = -9
	_bg_mid_rect.modulate.a = 0.0
	add_child(_bg_mid_rect)

	_bg_mat = ShaderMaterial.new(); _bg_mat.shader = _BG_SHADER
	_bg_mat.set_shader_parameter("bg_hue", GameManager.bg_hue)
	_bg_mat.set_shader_parameter("scroll_x", 0.0)
	_bg_mat.set_shader_parameter("grid_size", GameManager.run_grid_size)
	_bg_mat.set_shader_parameter("grid_alpha", 1.0)
	_grid_rect = ColorRect.new()
	_grid_rect.size = Vector2(GameManager.WINDOW_W, GameManager.GROUND_Y)
	_grid_rect.material = _bg_mat
	_grid_rect.z_index = -8
	add_child(_grid_rect)

	_bg_particles = CPUParticles2D.new()
	_bg_particles.emitting = true; _bg_particles.amount = 45; _bg_particles.lifetime = 5.0
	_bg_particles.randomness = 0.9
	_bg_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bg_particles.emission_rect_extents = Vector2(GameManager.WINDOW_W * 0.5, GameManager.GROUND_Y * 0.5)
	_bg_particles.position = Vector2(GameManager.WINDOW_W * 0.5, GameManager.GROUND_Y * 0.5)
	_bg_particles.direction = Vector2(0, -1); _bg_particles.spread = 50.0
	_bg_particles.gravity = Vector2(0, -18); _bg_particles.initial_velocity_min = 8.0
	_bg_particles.initial_velocity_max = 38.0; _bg_particles.scale_amount_min = 2.0
	_bg_particles.scale_amount_max = 8.0; _bg_particles.color = Color(0.3, 0.5, 1.0, 0.4)
	var pm := CanvasItemMaterial.new(); pm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bg_particles.material = pm; _bg_particles.z_index = -7
	add_child(_bg_particles)

	_floor_rect = ColorRect.new()
	_floor_rect.size = Vector2(GameManager.WINDOW_W, GameManager.WINDOW_H - GameManager.GROUND_Y)
	_floor_rect.position = Vector2(0, GameManager.GROUND_Y)
	_floor_rect.color = Color(0.04, 0.02, 0.10)
	_floor_rect.z_index = -9
	add_child(_floor_rect)

	_ground_line = Line2D.new()
	_ground_line.add_point(Vector2(0, GameManager.GROUND_Y))
	_ground_line.add_point(Vector2(GameManager.WINDOW_W, GameManager.GROUND_Y))
	_ground_line.width = 4.0
	_ground_line.default_color = Color(0, 2.5, 2.2)
	add_child(_ground_line)

func _process(delta: float) -> void:
	if GameManager.state == GameManager.State.PLAYING:
		var spd: float = GameManager.speed
		_scroll     = fmod(_scroll     + spd * delta / 900.0,                       1.0)
		_scroll_far = fmod(_scroll_far + spd * delta / 900.0 * _scroll_speed_far,   1.0)
		_scroll_mid = fmod(_scroll_mid + spd * delta / 900.0 * _scroll_speed_mid,   1.0)
		var phue: float = fmod(GameManager.bg_hue / 360.0 + _particle_hue_offset, 1.0)
		_bg_particles.color = Color.from_hsv(phue, 0.85, 1.0, 0.45)

	_bg_mat.set_shader_parameter("bg_hue", GameManager.bg_hue)
	_bg_mat.set_shader_parameter("scroll_x", _scroll)
	_bg_far_mat.set_shader_parameter("scroll_x", _scroll_far)
	_bg_mid_mat.set_shader_parameter("scroll_x", _scroll_mid)

	# Stream the GifPool's session background frame into the far layer.
	if _bg_anim:
		var tex: Texture2D = _bg_anim.advance(delta)
		if tex:
			_bg_far_mat.set_shader_parameter("bg_tex", tex)
			if _bg_far_rect.modulate.a < 1.0:
				_bg_far_rect.modulate.a = 1.0

	var line_hue: float = fmod(GameManager.bg_hue + 180.0, 360.0)
	_ground_line.default_color = Color.from_hsv(line_hue / 360.0, 1.0, 2.5)

# Called by main.gd after GameManager._randomize_run() refreshes the run.
func apply_run_settings() -> void:
	_bg_mat.set_shader_parameter("grid_size", GameManager.run_grid_size)
	_particle_hue_offset = GameManager.run_particle_hue_offset
	_scroll_speed_far = randf_range(0.18, 0.42)
	_scroll_speed_mid = randf_range(0.45, 0.72)
	# Re-pick a GIF for this run; cycle through the pool so each death/restart
	# varies the visible background. GifPool fetches asynchronously, so the
	# pool may be empty on first call — connect to pool_ready and retry once
	# downloads land.
	var gp: Node = get_node_or_null("/root/GifPool")
	if gp == null:
		return
	_pick_bg_gif(gp)
	if _bg_anim == null and gp.has_signal("pool_ready") and not gp.pool_ready.is_connected(_on_pool_ready):
		gp.pool_ready.connect(_on_pool_ready, CONNECT_ONE_SHOT)

func _on_pool_ready() -> void:
	var gp: Node = get_node_or_null("/root/GifPool")
	if gp:
		_pick_bg_gif(gp)

func _pick_bg_gif(gp: Node) -> void:
	if gp.has_method("cycle_background_gif"):
		_bg_anim = gp.cycle_background_gif()
	elif gp.has_method("get_background_gif"):
		_bg_anim = gp.get_background_gif()
	if _bg_anim:
		# A GIF is now available — the mid Kenney layer would paint over it.
		if _bg_mid_rect:
			_bg_mid_rect.modulate.a = 0.0

func set_grid_alpha(a: float, animated: bool) -> void:
	if animated:
		var cur: float = _bg_mat.get_shader_parameter("grid_alpha") as float
		create_tween().tween_method(func(v: float): _bg_mat.set_shader_parameter("grid_alpha", v), cur, a, 1.4)
	else:
		_bg_mat.set_shader_parameter("grid_alpha", a)

func set_floor_color(col: Color, animated: bool) -> void:
	if animated:
		create_tween().tween_property(_floor_rect, "color", col, 1.4)
	else:
		_floor_rect.color = col

func set_far_texture(tex: Texture2D, animated: bool) -> void:
	# GIF stream overrides the theme far texture; skip the static one entirely.
	if _bg_anim:
		return
	if tex:
		_bg_far_mat.set_shader_parameter("bg_tex", tex)
		if animated:
			create_tween().tween_property(_bg_far_rect, "modulate:a", 1.0, 1.2)
		else:
			_bg_far_rect.modulate.a = 1.0
	else:
		if animated:
			create_tween().tween_property(_bg_far_rect, "modulate:a", 0.0, 0.6)
		else:
			_bg_far_rect.modulate.a = 0.0

func set_mid_texture(tex: Texture2D, animated: bool) -> void:
	# When a GIF background is active the GIF carries the entire backdrop;
	# the Kenney mid layer would just paint blobs on top of it.
	if _bg_anim:
		_bg_mid_rect.modulate.a = 0.0
		return
	if tex:
		_bg_mid_mat.set_shader_parameter("bg_tex", tex)
		if animated:
			create_tween().tween_property(_bg_mid_rect, "modulate:a", 0.72, 1.2)
		else:
			_bg_mid_rect.modulate.a = 0.72
	else:
		if animated:
			create_tween().tween_property(_bg_mid_rect, "modulate:a", 0.0, 0.6)
		else:
			_bg_mid_rect.modulate.a = 0.0
