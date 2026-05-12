class_name CatVisuals
extends Node2D

const _PLAYER_SIZE: float = 44.0

var _player: CharacterBody2D = null
var _meow_label: Label = null
var _scream_label: Label = null
var _jump_particles: CPUParticles2D = null

var _anim_time: float = 0.0
var _tail_angle: float = 0.0
var _meow_timer: float = randf_range(2.0, 5.0)
var _meow_show: float = 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	_build_meow_label()
	_build_scream_label()
	_build_jump_particles()
	if _player and _player.has_signal("jumped"):
		_player.jumped.connect(_on_jumped)

func _build_meow_label() -> void:
	_meow_label = Label.new()
	_meow_label.text = "MEOW!!"
	_meow_label.add_theme_font_size_override("font_size", 15)
	_meow_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	_meow_label.position = Vector2(-28.0, -54.0)
	_meow_label.modulate.a = 0.0
	_meow_label.z_index = 10
	add_child(_meow_label)

func _build_scream_label() -> void:
	_scream_label = Label.new()
	_scream_label.text = ""
	_scream_label.add_theme_font_size_override("font_size", 18)
	_scream_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))
	_scream_label.position = Vector2(-55.0, -76.0)
	_scream_label.modulate.a = 0.0
	_scream_label.z_index = 11
	add_child(_scream_label)

func _build_jump_particles() -> void:
	_jump_particles = CPUParticles2D.new()
	_jump_particles.emitting = false
	_jump_particles.one_shot = true
	_jump_particles.amount = 6
	_jump_particles.lifetime = 0.35
	_jump_particles.explosiveness = 0.9
	_jump_particles.direction = Vector2(0.0, 1.0)
	_jump_particles.spread = 40.0
	_jump_particles.gravity = Vector2(0.0, 200.0)
	_jump_particles.initial_velocity_min = 60.0
	_jump_particles.initial_velocity_max = 120.0
	_jump_particles.scale_amount_min = 3.0
	_jump_particles.scale_amount_max = 6.0
	_jump_particles.color = Color(0.9, 0.45, 0.1, 0.85)
	_jump_particles.position = Vector2(0.0, _PLAYER_SIZE * 0.5)
	add_child(_jump_particles)

func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_anim_time += delta

	# Tail: wag on ground, spin in air
	if _player and _player.is_on_floor():
		_tail_angle = sin(_anim_time * 4.0) * 0.7
	else:
		_tail_angle += delta * TAU * 1.8

	# Meow timer + fade
	_meow_timer -= delta
	if _meow_timer <= 0.0:
		_meow_show = 0.9
		_meow_timer = randf_range(3.0, 7.0)
	if _meow_show > 0.0:
		_meow_show -= delta * 1.4
		_meow_label.modulate.a = clampf(_meow_show, 0.0, 1.0)
		_meow_label.rotation = -_player.rotation if _player else 0.0
	else:
		_meow_label.modulate.a = 0.0

	# Scream bubble fade
	if _scream_label.modulate.a > 0.0:
		_scream_label.modulate.a = maxf(0.0, _scream_label.modulate.a - delta * 0.9)
		_scream_label.rotation = -_player.rotation if _player else 0.0

	queue_redraw()

func _draw() -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return

	var H: float = _PLAYER_SIZE * 0.5
	var leg_color   := Color(0.88, 0.43, 0.10)
	var foot_color  := Color(0.60, 0.25, 0.05)
	var tail_color  := Color(0.72, 0.30, 0.05)
	var tail_tip    := Color(1.00, 0.70, 0.25)

	# Legs (4 dangling)
	var leg_xs := [-14.0, -4.0, 4.0, 14.0]
	for i in range(4):
		var phase := _anim_time * 14.0 + i * PI * 0.5
		var swing := sin(phase) * 0.55
		var lx: float = leg_xs[i]
		var top   := Vector2(lx, H - 6.0)
		var knee  := Vector2(lx + sin(swing) * 8.0, H + 7.0)
		var foot  := Vector2(lx + sin(swing) * 14.0 + sin(phase * 0.5) * 3.0, H + 16.0)
		draw_line(top, knee, leg_color, 3.5, true)
		draw_line(knee, foot, leg_color, 3.0, true)
		draw_circle(foot, 3.2, foot_color)

	# Tail (3 segments curling out right)
	var tail_base := Vector2(H, 2.0)
	var seg1 := tail_base + Vector2(cos(_tail_angle) * 14.0, sin(_tail_angle) * 14.0)
	var seg2 := seg1      + Vector2(cos(_tail_angle + 0.9) * 10.0, sin(_tail_angle + 0.9) * 10.0)
	var tip  := seg2      + Vector2(cos(_tail_angle + 1.7) * 7.0,  sin(_tail_angle + 1.7) * 7.0)
	draw_line(tail_base, seg1, tail_color, 5.0, true)
	draw_line(seg1, seg2, tail_color, 4.0, true)
	draw_line(seg2, tip, tail_tip, 3.0, true)
	draw_circle(tip, 3.5, tail_tip)

# Player emits jumped(n): n=1..3 are normal jumps (3 = mega), n=0 is a bounce-pad
# bounce. Bounce keeps whatever the last jump's particle config was.
func _on_jumped(jump_number: int) -> void:
	if jump_number >= 3:
		_jump_particles.color = Color(3.0, 2.0, 0.1, 1.0)
		_jump_particles.scale_amount_min = 6.0
		_jump_particles.scale_amount_max = 14.0
	elif jump_number > 0:
		_jump_particles.color = Color(0.9, 0.45, 0.1, 0.85)
		_jump_particles.scale_amount_min = 3.0
		_jump_particles.scale_amount_max = 6.0
	_jump_particles.restart()

func show_scream(text: String) -> void:
	_scream_label.text = text
	_scream_label.modulate.a = 1.0
	var t := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_scream_label, "scale", Vector2(1.4, 1.4), 0.12)
	t.tween_property(_scream_label, "scale", Vector2.ONE, 0.2)

func reset() -> void:
	_meow_label.modulate.a = 0.0
	_scream_label.modulate.a = 0.0
