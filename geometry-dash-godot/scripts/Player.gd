extends Node2D

@onready var spr : Sprite2D = $HeroSprite

var tex_idle       : Texture2D
var tex_jump       : Texture2D
var tex_doublejump : Texture2D
var tex_land       : Texture2D
var tex_dead       : Texture2D

var trail_p  : CPUParticles2D
var jump_p   : CPUParticles2D
var death_p  : CPUParticles2D

var _anim_tween : Tween = null
var gliding     : bool  = false
var rotor_t     : float = 0.0
var rotor_spd   : float = 0.0

func _ready() -> void:
	tex_idle       = load("res://assets/cat_idle.png")
	tex_jump       = load("res://assets/cat_jump.png")
	tex_doublejump = load("res://assets/cat_doublejump.png")
	tex_land       = load("res://assets/cat_land.png")
	tex_dead       = load("res://assets/cat_dead.png")

	spr.texture  = tex_idle
	spr.centered = true

	trail_p = _make_particles(28, 0.35, false)
	trail_p.direction            = Vector2(-1, 0)
	trail_p.spread               = 22.0
	trail_p.gravity              = Vector2(0, 60)
	trail_p.initial_velocity_min = 60.0
	trail_p.initial_velocity_max = 130.0
	trail_p.scale_amount_min     = 3.0
	trail_p.scale_amount_max     = 7.0
	trail_p.color                = Color(2.0, 1.5, 0.4, 0.7)
	trail_p.emitting             = true
	add_child(trail_p)

	jump_p = _make_particles(20, 0.42, true)
	jump_p.direction            = Vector2(0, 1)
	jump_p.spread               = 75.0
	jump_p.gravity              = Vector2(0, 280)
	jump_p.initial_velocity_min = 130.0
	jump_p.initial_velocity_max = 240.0
	jump_p.scale_amount_min     = 4.0
	jump_p.scale_amount_max     = 11.0
	jump_p.color                = Color(1.5, 2.5, 1.0, 1.0)
	add_child(jump_p)

	death_p = _make_particles(45, 0.9, true)
	death_p.direction            = Vector2(0, -1)
	death_p.spread               = 180.0
	death_p.gravity              = Vector2(0, 500)
	death_p.initial_velocity_min = 180.0
	death_p.initial_velocity_max = 560.0
	death_p.scale_amount_min     = 5.0
	death_p.scale_amount_max     = 15.0
	death_p.color                = Color(3.5, 0.8, 0.2, 1.0)
	death_p.local_coords         = false
	add_child(death_p)

func _make_particles(amt: int, life: float, one_shot: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount       = amt
	p.lifetime     = life
	p.one_shot     = one_shot
	p.emitting     = false
	p.local_coords = true
	return p

func update_visual(py: float, tilt_deg: float, spd: float, hue: float, delta: float = 0.016, is_glide: bool = false) -> void:
	position.y       = py + 26.0
	rotation_degrees = tilt_deg
	var tc := Color.from_hsv(fmod(hue + 0.5, 1.0), 0.9, 1.0) * 2.2
	tc.a = 0.7
	trail_p.color                = tc
	trail_p.initial_velocity_min = spd * 0.24
	trail_p.initial_velocity_max = spd * 0.44
	gliding  = is_glide
	var target_spd := 22.0 if is_glide else 0.0
	rotor_spd = lerp(rotor_spd, target_spd, delta * 10.0)
	rotor_t  += rotor_spd * delta
	queue_redraw()

func emit_jump(is_double: bool, _hue: float) -> void:
	_kill_anim()
	if is_double:
		spr.texture = tex_doublejump
		jump_p.color = Color(2.2, 0.9, 3.8, 1.0)
		# Wide squash → tall stretch → settle  (double-jump pop)
		_anim_tween = create_tween().set_trans(Tween.TRANS_BACK)
		_anim_tween.tween_property(spr, "scale", Vector2(1.45, 0.60), 0.07)
		_anim_tween.tween_property(spr, "scale", Vector2(0.70, 1.42), 0.11)
		_anim_tween.tween_property(spr, "scale", Vector2(1.0,  1.0 ), 0.14)
		# Flash gold
		spr.modulate = Color(4.0, 3.0, 0.8, 1.0)
		var flash := create_tween()
		flash.tween_property(spr, "modulate", Color(1, 1, 1, 1), 0.18)
	else:
		spr.texture = tex_jump
		jump_p.color = Color(0.9, 2.8, 1.4, 1.0)
		# Vertical stretch → settle  (single jump)
		_anim_tween = create_tween().set_trans(Tween.TRANS_SINE)
		_anim_tween.tween_property(spr, "scale", Vector2(0.76, 1.32), 0.07)
		_anim_tween.tween_property(spr, "scale", Vector2(1.0,  1.0 ), 0.16)
	jump_p.restart()

func land_squash() -> void:
	_kill_anim()
	spr.texture = tex_land
	_anim_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(spr, "scale", Vector2(1.38, 0.65), 0.05)
	_anim_tween.tween_property(spr, "scale", Vector2(1.0,  1.0 ), 0.18)
	await _anim_tween.finished
	if spr.texture == tex_land:
		spr.texture = tex_idle

func explode() -> void:
	_kill_anim()
	spr.visible     = false
	spr.scale       = Vector2.ONE
	trail_p.emitting = false
	death_p.restart()

func reset_visual() -> void:
	_kill_anim()
	spr.visible      = true
	spr.texture      = tex_idle
	spr.scale        = Vector2.ONE
	spr.modulate     = Color(1, 1, 1, 1)
	spr.flip_v       = false
	trail_p.emitting = true
	rotation_degrees = 0.0
	position.y       = 558.0

func set_gravity(dir: float) -> void:
	spr.flip_v = (dir < 0)

func _draw() -> void:
	if rotor_spd < 0.5:
		return
	var alpha := clampf(rotor_spd / 22.0, 0.0, 1.0)
	var hub   := Vector2(0.0, -40.0)
	# Rotor stick
	draw_line(Vector2(0.0, -30.0), hub, Color(0.85, 0.70, 0.25, alpha * 0.9), 2.5)
	# Two blades (look like spinning cat ears / propeller)
	for i in 2:
		var ang  := rotor_t + float(i) * PI * 0.5
		var tip1 := hub + Vector2(cos(ang) * 28.0, sin(ang) * 10.0)
		var tip2 := hub + Vector2(cos(ang + PI) * 28.0, sin(ang + PI) * 10.0)
		var side := Vector2(-sin(ang) * 5.0, cos(ang) * 5.0)
		# Blade as a quad (ear-shaped: wider at base, narrow at tip)
		draw_colored_polygon(PackedVector2Array([
			hub + side * 0.8,
			hub - side * 0.8,
			tip2 - side * 0.2,
			tip2 + side * 0.2,
		]), Color(1.0, 0.88, 0.30, alpha * 0.92))
		draw_colored_polygon(PackedVector2Array([
			hub + side * 0.8,
			hub - side * 0.8,
			tip1 - side * 0.2,
			tip1 + side * 0.2,
		]), Color(1.0, 0.75, 0.20, alpha * 0.92))
	# Blur circles for speed effect
	if rotor_spd > 18.0:
		var blur_a := clampf((rotor_spd - 18.0) / 4.0, 0.0, 1.0) * 0.18
		draw_arc(hub, 28.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, blur_a), 6.0)
	# Hub cap
	draw_circle(hub, 5.5, Color(0.5, 0.35, 0.05, alpha))
	draw_circle(hub, 3.0, Color(1.0, 0.95, 0.6, alpha))

func _kill_anim() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	spr.scale = Vector2.ONE
