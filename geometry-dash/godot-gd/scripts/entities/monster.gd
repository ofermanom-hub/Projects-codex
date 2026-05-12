class_name Monster
extends Node2D

enum State { IDLE, FALLING, HUNTING }

const SCALE: float = 0.28

# Injected from monster_pool before add_child().
var player: CharacterBody2D = null
var texture: Texture2D = null

var _state: int = State.IDLE
var _vx: float = 0.0
var _sprite: Sprite2D = null

func _ready() -> void:
	visible = false
	z_index = 5

	_sprite = Sprite2D.new()
	_sprite.name = "Spr"
	_sprite.texture = texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(SCALE, SCALE)
	add_child(_sprite)

	var p := CPUParticles2D.new()
	p.emitting = true; p.amount = 8; p.lifetime = 0.6; p.randomness = 0.7
	p.direction = Vector2(0, -1); p.spread = 80.0; p.gravity = Vector2.ZERO
	p.initial_velocity_min = 20.0; p.initial_velocity_max = 45.0
	p.scale_amount_min = 3.0; p.scale_amount_max = 7.0
	p.color = Color(2.5, 0.2, 0.8, 0.6)
	var pm := CanvasItemMaterial.new()
	pm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = pm
	add_child(p)

	var area := Area2D.new()
	area.collision_layer = 0; area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new(); circ.radius = 22.0
	cs.shape = circ
	area.add_child(cs)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

func is_idle() -> bool:
	return not visible or _state == State.IDLE

func spawn_at(pos: Vector2) -> void:
	position = pos
	_state = State.FALLING
	_vx = 0.0
	visible = true

func hide_and_idle() -> void:
	visible = false
	_state = State.IDLE
	_vx = 0.0

func update(delta: float, anim_t: float) -> void:
	if not visible:
		return
	_sprite.scale = Vector2(
		SCALE * (1.0 + 0.08 * sin(anim_t * 5.0 + position.x * 0.01)),
		SCALE * (1.0 + 0.06 * sin(anim_t * 4.0 + position.y * 0.01)))
	match _state:
		State.FALLING:
			position.y += 70.0 * delta
			if player and abs(position.y - player.position.y) < 80.0:
				_state = State.HUNTING
				_vx = sign(player.position.x - position.x) * 95.0
		State.HUNTING:
			position.x += _vx * delta
			position.y += 35.0 * delta
			_sprite.flip_h = _vx < 0.0
			if player:
				_vx = lerpf(_vx, sign(player.position.x - position.x) * 110.0, delta * 2.0)
	if position.y > GameManager.GROUND_Y + 50.0 \
			or position.x < -60.0 \
			or position.x > GameManager.WINDOW_W + 60.0:
		hide_and_idle()

func _on_body_entered(body: Node) -> void:
	if body == player:
		GameManager.die()
