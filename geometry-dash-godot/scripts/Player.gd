extends Node2D

@onready var spr : Sprite2D = $HeroSprite

# ── Animation state machine ──────────────────────────────────────────────────
# State -> Array[Texture2D] (loaded once in _ready())
var frames : Dictionary = {}
var state            : String = "idle"
var _state_t         : float  = 0.0
var _state_lock      : float  = 0.0   # if > 0, state can't auto-change

const STATE_FPS := {
	"idle":       2.0,
	"run":        12.0,
	"jump_prep":  10.0,
	"jump_up":    10.0,
	"jump_apex":  8.0,
	"jump_fall":  10.0,
	"doublejump": 18.0,
	"land":       12.0,
	"glide":      6.0,
	"dead":       4.0,
}

# ── Glide rotor (drawn live in _draw()) ──────────────────────────────────────
var gliding   : bool  = false
var rotor_t   : float = 0.0
var rotor_spd : float = 0.0

# ── Particles ────────────────────────────────────────────────────────────────
var trail_p  : CPUParticles2D
var jump_p   : CPUParticles2D
var death_p  : CPUParticles2D

# ── Physics-derived state ────────────────────────────────────────────────────
var _prev_py     : float = INF
var _grounded_t  : float = 0.0   # how long py has been stationary (run vs apex)

func _ready() -> void:
	frames = {
		"idle":       [load("res://assets/cat_idle_0.png"),
		               load("res://assets/cat_idle_1.png")],
		"run":        [load("res://assets/cat_run_0.png"),
		               load("res://assets/cat_run_1.png"),
		               load("res://assets/cat_run_2.png"),
		               load("res://assets/cat_run_3.png")],
		"jump_prep":  [load("res://assets/cat_jump_prep_0.png")],
		"jump_up":    [load("res://assets/cat_jump_up_0.png"),
		               load("res://assets/cat_jump_up_1.png")],
		"jump_apex":  [load("res://assets/cat_jump_apex_0.png")],
		"jump_fall":  [load("res://assets/cat_jump_fall_0.png"),
		               load("res://assets/cat_jump_fall_1.png")],
		"doublejump": [load("res://assets/cat_doublejump_0.png"),
		               load("res://assets/cat_doublejump_1.png"),
		               load("res://assets/cat_doublejump_2.png")],
		"land":       [load("res://assets/cat_land_0.png"),
		               load("res://assets/cat_land_1.png")],
		"glide":      [load("res://assets/cat_glide_0.png"),
		               load("res://assets/cat_glide_1.png")],
		"dead":       [load("res://assets/cat_dead_0.png")],
	}
	spr.centered = true
	_apply_state("idle")

	trail_p = _make_particles(20, 0.30, false)
	trail_p.direction            = Vector2(-1, 0)
	trail_p.spread               = 22.0
	trail_p.gravity              = Vector2(0, 50)
	trail_p.initial_velocity_min = 40.0
	trail_p.initial_velocity_max = 90.0
	trail_p.scale_amount_min     = 2.0
	trail_p.scale_amount_max     = 5.0
	trail_p.color                = Color(2.0, 1.5, 0.4, 0.7)
	trail_p.emitting             = true
	add_child(trail_p)

	jump_p = _make_particles(16, 0.38, true)
	jump_p.direction            = Vector2(0, 1)
	jump_p.spread               = 60.0
	jump_p.gravity              = Vector2(0, 280)
	jump_p.initial_velocity_min = 130.0
	jump_p.initial_velocity_max = 220.0
	jump_p.scale_amount_min     = 3.0
	jump_p.scale_amount_max     = 9.0
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

# ── State machine ────────────────────────────────────────────────────────────
func _apply_state(s: String) -> void:
	state = s
	_state_t = 0.0
	var arr : Array = frames.get(state, [])
	if not arr.is_empty():
		spr.texture = arr[0]

func _advance_frame(delta: float) -> void:
	var arr : Array = frames.get(state, [])
	if arr.is_empty():
		return
	_state_t += delta
	var fps : float = STATE_FPS.get(state, 10.0)
	var idx : int   = int(_state_t * fps) % arr.size()
	spr.texture = arr[idx]

func _derive_state(py: float, delta: float) -> String:
	# Vertical velocity from py delta. First frame after reset uses INF guard.
	var vy : float = 0.0
	if _prev_py != INF:
		vy = (py - _prev_py) / maxf(delta, 0.001)

	if gliding:
		_grounded_t = 0.0
		return "glide"

	# Grounded heuristic: py barely changed for >=2 frames AND vy near zero.
	if absf(vy) < 5.0:
		_grounded_t += delta
		if _grounded_t > 0.05:
			return "run"
	else:
		_grounded_t = 0.0

	if vy < -120.0:
		return "jump_up"
	if vy > 120.0:
		return "jump_fall"
	return "jump_apex"

# ── Per-frame from Main.gd ──────────────────────────────────────────────────
func update_visual(py: float, tilt_deg: float, spd: float, hue: float,
                   delta: float = 0.016, is_glide: bool = false) -> void:
	position.y       = py + 26.0
	rotation_degrees = tilt_deg
	var tc := Color.from_hsv(fmod(hue + 0.5, 1.0), 0.9, 1.0) * 2.2
	tc.a = 0.7
	trail_p.color                = tc
	trail_p.initial_velocity_min = spd * 0.18
	trail_p.initial_velocity_max = spd * 0.36
	gliding = is_glide
	var target_spd := 22.0 if is_glide else 0.0
	rotor_spd = lerp(rotor_spd, target_spd, delta * 10.0)
	rotor_t  += rotor_spd * delta

	# State machine: locked states (jump_prep / doublejump / land / dead)
	# play through to completion, then derived state takes over.
	if _state_lock > 0.0:
		_state_lock -= delta
		if _state_lock <= 0.0:
			# Lock just expired — derive next state immediately
			var next := _derive_state(py, delta)
			if state != "dead":   # dead is permanent until reset_visual
				_apply_state(next)
	else:
		# Not locked — auto-derive
		if state != "dead":
			var next := _derive_state(py, delta)
			if next != state:
				_apply_state(next)

	_advance_frame(delta)
	_prev_py = py
	queue_redraw()

# ── Events from Main.gd ──────────────────────────────────────────────────────
func emit_jump(is_double: bool, _hue: float) -> void:
	if is_double:
		_apply_state("doublejump")
		_state_lock = 0.30                  # 3 frames at 18 fps + buffer
		jump_p.color = Color(2.2, 0.9, 3.8, 1.0)
		spr.modulate = Color(4.0, 3.0, 0.8, 1.0)
		var flash := create_tween()
		flash.tween_property(spr, "modulate", Color(1, 1, 1, 1), 0.20)
	else:
		_apply_state("jump_prep")
		_state_lock = 0.08
		jump_p.color = Color(0.9, 2.8, 1.4, 1.0)
	jump_p.restart()

func land_squash() -> void:
	_apply_state("land")
	_state_lock = 0.18                       # 2 frames + tail

func explode() -> void:
	_apply_state("dead")
	_state_lock = 9999.0
	spr.modulate     = Color(1, 1, 1, 1)
	trail_p.emitting = false
	death_p.restart()

func reset_visual() -> void:
	_state_lock = 0.0
	_prev_py    = INF
	_grounded_t = 0.0
	_apply_state("idle")
	spr.visible      = true
	spr.modulate     = Color(1, 1, 1, 1)
	spr.flip_v       = false
	trail_p.emitting = true
	rotation_degrees = 0.0
	position.y       = 558.0

func set_gravity(dir: float) -> void:
	spr.flip_v = (dir < 0)

# ── Glide rotor (procedural, drawn above the head) ──────────────────────────
func _draw() -> void:
	if rotor_spd < 0.5:
		return
	var alpha := clampf(rotor_spd / 22.0, 0.0, 1.0)
	var hub   := Vector2(0.0, -56.0)        # raised for the bigger 90 px cat
	# Rotor stick
	draw_line(Vector2(0.0, -42.0), hub, Color(0.85, 0.70, 0.25, alpha * 0.9), 2.5)
	# Two blades
	for i in 2:
		var ang  := rotor_t + float(i) * PI * 0.5
		var tip1 := hub + Vector2(cos(ang) * 32.0, sin(ang) * 11.0)
		var tip2 := hub + Vector2(cos(ang + PI) * 32.0, sin(ang + PI) * 11.0)
		var side := Vector2(-sin(ang) * 5.5, cos(ang) * 5.5)
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
	# Blur ring for speed
	if rotor_spd > 18.0:
		var blur_a := clampf((rotor_spd - 18.0) / 4.0, 0.0, 1.0) * 0.18
		draw_arc(hub, 32.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, blur_a), 6.0)
	# Hub cap
	draw_circle(hub, 5.5, Color(0.5, 0.35, 0.05, alpha))
	draw_circle(hub, 3.0, Color(1.0, 0.95, 0.6, alpha))
