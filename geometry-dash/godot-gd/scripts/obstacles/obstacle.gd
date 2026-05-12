class_name Obstacle
extends Node2D

# Obstacle types (must match scripts/data/patterns.gd entry[0])
const TYPE_SPIKE_UP    := 0
const TYPE_BLOCK       := 1
const TYPE_FLOAT_BLOCK := 2
const TYPE_SPIKE_DOWN  := 3
const TYPE_BOUNCE_PAD  := 4
const TYPE_SAW         := 5
const TYPE_RAIL_UP     := 6
const TYPE_RAIL_DOWN   := 7
const TYPE_BRAINROT    := 8

const _DESPAWN_PARK: Vector2 = Vector2(-300.0, 0.0)

signal hit
signal bounced

var factory: ObstacleFactory = null

var _type: int = -1
var _rail_dir: float = 0.0
var _brainrot_idx: int = 0
var _brainrot_base_y: float = 0.0
var _brainrot_anim: Variant = null

# Cached animation refs — only set when the active variant has them
var _saw_spr: Node2D = null
var _rail_glow: Line2D = null
var _pulse_parts: Node2D = null
var _brain_label: Label = null
var _brain_aura: Line2D = null
var _brain_spr: Sprite2D = null
# GIF stream for non-brainrot variants (spike/saw). When set, animate() pushes
# the current frame into _gif_target_spr each tick.
var _gif_anim: Variant = null
var _gif_target_spr: Sprite2D = null

var _area: Area2D
var _bounce: Area2D
var _rail: Area2D
var _visual: Node2D

func _ready() -> void:
	_area = Area2D.new()
	_area.name = "Area"
	_area.collision_layer = 4; _area.collision_mask = 1
	_area.monitoring = false
	_area.body_entered.connect(_on_area_entered)
	add_child(_area)

	_bounce = Area2D.new()
	_bounce.name = "Bounce"
	_bounce.collision_layer = 0; _bounce.collision_mask = 1
	_bounce.monitoring = false
	_bounce.body_entered.connect(_on_bounce_entered)
	add_child(_bounce)

	_rail = Area2D.new()
	_rail.name = "Rail"
	_rail.collision_layer = 0; _rail.collision_mask = 1
	_rail.monitoring = false
	add_child(_rail)

	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)

	factory.build_variants(_area, _bounce, _rail, _visual)

func configure(type: int, rel_x: float, spawn_x: float, w: float, h: float, y_offset: float, rot_deg: float = 0.0) -> void:
	position = Vector2(spawn_x + rel_x, GameManager.GROUND_Y + y_offset)
	rotation_degrees = rot_deg
	visible = true
	_type = type
	_rail_dir = 0.0
	_saw_spr = null
	_rail_glow = null
	_pulse_parts = null
	_brain_label = null
	_brain_aura = null
	_brain_spr = null
	_brainrot_anim = null
	_gif_anim = null
	_gif_target_spr = null
	_visual.rotation_degrees = 0.0
	_visual.scale = Vector2.ONE

	factory.hide_all_variants(_area, _bounce, _rail, _visual)
	_area.monitoring = false
	_bounce.monitoring = false
	_rail.monitoring = false

	var gp: Node = get_node_or_null("/root/GifPool")

	match type:
		TYPE_SPIKE_UP:
			factory.update_spike_up(_area, _visual, w, h)
			_area.monitoring = true
			_pulse_parts = factory.get_pulse_parts(_visual, "SpikeUp")
			_gif_target_spr = factory.get_gif_target_sprite(_visual, "SpikeUp")
		TYPE_BLOCK:
			factory.update_block(_area, _visual, w, h)
			_area.monitoring = true
			_pulse_parts = factory.get_pulse_parts(_visual, "Block")
		TYPE_FLOAT_BLOCK:
			factory.update_float_block(_area, _visual, w, h)
			_area.monitoring = true
			_pulse_parts = factory.get_pulse_parts(_visual, "FloatBlock")
		TYPE_SPIKE_DOWN:
			factory.update_spike_down(_area, _visual, w, h)
			_area.monitoring = true
			_pulse_parts = factory.get_pulse_parts(_visual, "SpikeDown")
			_gif_target_spr = factory.get_gif_target_sprite(_visual, "SpikeDown")
		TYPE_BOUNCE_PAD:
			factory.update_bounce_pad(_bounce, _visual, w, h)
			_bounce.monitoring = true
			_pulse_parts = factory.get_pulse_parts(_visual, "BouncePad")
		TYPE_SAW:
			factory.update_saw(_area, _visual, w)
			_area.monitoring = true
			_saw_spr = factory.get_saw_sprite(_visual)
			_pulse_parts = factory.get_pulse_parts(_visual, "Saw")
			_gif_target_spr = factory.get_gif_target_sprite(_visual, "Saw")
		TYPE_RAIL_UP, TYPE_RAIL_DOWN:
			_rail_dir = -1.0 if type == TYPE_RAIL_UP else 1.0
			factory.update_rail(_rail, _visual, w, h, _rail_dir)
			_rail.monitoring = true
			_rail_glow = factory.get_rail_glow(_visual)
			_pulse_parts = factory.get_pulse_parts(_visual, "Rail")
		TYPE_BRAINROT:
			_brainrot_idx = randi() % BrainrotLore.NAMES.size()
			_brainrot_base_y = position.y
			factory.update_brainrot(_area, _visual, _brainrot_idx)
			_area.monitoring = true
			_brain_label = factory.get_brain_label(_visual)
			_brain_aura = factory.get_brain_aura(_visual)
			_brain_spr = factory.get_brain_sprite(_visual)
			_pulse_parts = factory.get_pulse_parts(_visual, "Brainrot")
			if gp and gp.has_method("get_obstacle_gif"):
				_brainrot_anim = gp.get_obstacle_gif()

	if _gif_target_spr and gp and gp.has_method("get_obstacle_gif"):
		_gif_anim = gp.get_obstacle_gif()

# Returns true if the player is in contact with this obstacle's rail.
func animate(delta: float, anim_time: float, player: CharacterBody2D) -> bool:
	if _saw_spr:
		_saw_spr.rotation_degrees += delta * 200.0
	if _rail_glow:
		_rail_glow.default_color.a = 0.55 + 0.45 * sin(anim_time * 5.0)
	if _pulse_parts:
		var s: float = 1.0 + 0.04 * sin(anim_time * 6.0)
		_pulse_parts.scale = Vector2(s, s)

	if _type == TYPE_BRAINROT:
		position.y = _brainrot_base_y + sin(anim_time * 2.2 + _brainrot_idx * 1.3) * 26.0
		_visual.rotation_degrees += delta * (50.0 + _brainrot_idx * 14.0)
		if _brain_label:
			_brain_label.modulate = Color.from_hsv(fmod(anim_time * 0.55 + _brainrot_idx * 0.17, 1.0), 1.0, 2.8)
		if _brain_aura:
			_brain_aura.default_color = Color.from_hsv(fmod(anim_time * 0.38 + _brainrot_idx * 0.22, 1.0), 1.0, 2.5)
		if _brainrot_anim and _brain_spr:
			var subj: Texture2D = _brainrot_anim.current_subject()
			var tex: Texture2D = _brainrot_anim.advance(delta)
			if subj == null:
				subj = tex
			if subj:
				_brain_spr.texture = subj
				_brain_spr.modulate = Color(1, 1, 1, 1)

	# Lazy-retry: GifPool fetches async, so configure() may have run before the
	# pool had any GIFs. Pick one as soon as the pool fills.
	if _gif_anim == null and _gif_target_spr:
		var gp: Node = get_node_or_null("/root/GifPool")
		if gp and gp.has_method("get_obstacle_gif"):
			_gif_anim = gp.get_obstacle_gif()
	if _brainrot_anim == null and _type == TYPE_BRAINROT and _brain_spr:
		var gp2: Node = get_node_or_null("/root/GifPool")
		if gp2 and gp2.has_method("get_obstacle_gif"):
			_brainrot_anim = gp2.get_obstacle_gif()

	if _gif_anim and _gif_target_spr:
		var subj: Texture2D = _gif_anim.current_subject()
		var frame: Texture2D = _gif_anim.advance(delta)
		var tex: Texture2D = subj if subj else frame
		if tex:
			_gif_target_spr.texture = tex
			_gif_target_spr.modulate = Color(1, 1, 1, 1)

	if (_type == TYPE_RAIL_UP or _type == TYPE_RAIL_DOWN) and player:
		for b in _rail.get_overlapping_bodies():
			if b == player:
				player.rail_direction = _rail_dir
				return true
	return false

func release() -> void:
	_area.monitoring = false
	_bounce.monitoring = false
	_rail.monitoring = false
	visible = false
	rotation_degrees = 0.0
	position = _DESPAWN_PARK
	_type = -1
	_saw_spr = null
	_rail_glow = null
	_pulse_parts = null
	_brain_label = null
	_brain_aura = null

func bounce_animate_trampoline() -> void:
	var t := _visual.create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	t.tween_property(_visual, "scale", Vector2(1.5, 0.5), 0.07)
	t.tween_property(_visual, "scale", Vector2(0.8, 1.5), 0.12)
	t.tween_property(_visual, "scale", Vector2(1.1, 0.9), 0.1)
	t.tween_property(_visual, "scale", Vector2.ONE, 0.18)
	var flash := _visual.get_node_or_null("BounceFlash")
	if flash == null:
		flash = ColorRect.new()
		flash.name = "BounceFlash"
		flash.color = Color(1.0, 1.0, 1.0, 0.0)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_visual.add_child(flash)
	var ft := flash.create_tween()
	ft.tween_property(flash, "modulate:a", 0.7, 0.05)
	ft.tween_property(flash, "modulate:a", 0.0, 0.15)

func _on_area_entered(body: Node) -> void:
	if body is CharacterBody2D:
		hit.emit()

func _on_bounce_entered(body: Node) -> void:
	if body is CharacterBody2D:
		bounced.emit()
		bounce_animate_trampoline()
