class_name Player
extends CharacterBody2D

signal jumped(jump_number: int)
signal landed

@export_group("Physics")
@export var gravity: float = 980.0
@export var jump_velocity: float = -550.0
@export var second_jump_penalty: float = 15.0

@export_group("Feel")
@export var rotation_speed: float = 270.0

const _HERO_TEX: Texture2D = preload("res://assets/sprites/hero.png")
const _CatVisualsScript: GDScript = preload("res://scripts/player/cat_visuals.gd")
const COYOTE_FRAMES: int = 6
const BUFFER_FRAMES: int = 10
const MAX_JUMPS: int = 3
const SPAWN_X: float = 160.0
const PLAYER_SIZE: float = 44.0

var jump_buffer: int = 0
var coyote_timer: int = 0
var jump_count: int = 0
var _was_on_floor: bool = false
var rail_direction: float = 0.0   # -1=push up, +1=push down, 0=none
var _squash_tween: Tween
var _sprite: Sprite2D
var _cat: CatVisuals

func _ready() -> void:
	position = Vector2(SPAWN_X, GameManager.GROUND_Y - PLAYER_SIZE * 0.5)
	collision_layer = 1
	collision_mask = 2

	_sprite = Sprite2D.new()
	_sprite.texture = _HERO_TEX
	_sprite.scale = Vector2(PLAYER_SIZE / 224.0, PLAYER_SIZE / 224.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	_cat = _CatVisualsScript.new()
	add_child(_cat)

func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return

	var on_floor: bool = is_on_floor()

	if not on_floor:
		velocity.y += gravity * delta
		rotation_degrees += rotation_speed * delta
	else:
		# Only stop downward velocity — preserve upward velocity from bounce pads
		if velocity.y > 0.0:
			velocity.y = 0.0
		if not _was_on_floor:
			rotation_degrees = roundf(rotation_degrees / 90.0) * 90.0
			jump_count = 0
			_squash(Vector2(1.35, 0.72))
			landed.emit()

	if on_floor:
		coyote_timer = COYOTE_FRAMES
	elif coyote_timer > 0:
		coyote_timer -= 1

	if jump_buffer > 0:
		jump_buffer -= 1

	var eligible: bool = jump_count < MAX_JUMPS and (jump_count > 0 or on_floor or coyote_timer > 0)
	if jump_buffer > 0 and eligible:
		_execute_jump()

	if position.y < PLAYER_SIZE * 0.5:
		position.y = PLAYER_SIZE * 0.5
		velocity.y = 0.0

	# Rail escalator: override velocity so it visibly lifts/pushes the player
	if rail_direction != 0.0:
		if rail_direction < 0.0:  # UP escalator — fight gravity, lift player
			velocity.y = minf(velocity.y, -220.0)
		else:                      # DOWN escalator — push player toward ground fast
			velocity.y = maxf(velocity.y, 260.0)

	_was_on_floor = on_floor
	move_and_slide()

func request_jump() -> void:
	jump_buffer = BUFFER_FRAMES

func reset() -> void:
	position = Vector2(SPAWN_X, GameManager.GROUND_Y - PLAYER_SIZE * 0.5)
	velocity = Vector2.ZERO
	rotation_degrees = 0.0
	scale = Vector2.ONE
	jump_count = 0
	jump_buffer = 0
	coyote_timer = 0
	rail_direction = 0.0
	_was_on_floor = false
	if _cat: _cat.reset()
	show()

func _execute_jump() -> void:
	if jump_count >= 2:
		# Third jump: mega ceiling-reaching boost
		velocity.y = jump_velocity * 1.65
		_squash(Vector2(0.48, 2.0))
	else:
		velocity.y = jump_velocity - jump_count * second_jump_penalty
		_squash(Vector2(0.72, 1.35))
	jump_count += 1
	coyote_timer = 0
	jump_buffer = 0
	jumped.emit(jump_count)

func bounce_jump() -> void:
	velocity.y = jump_velocity * 1.6
	jump_count = 1
	coyote_timer = 0
	jump_buffer = 0
	_squash(Vector2(0.65, 1.6))
	jumped.emit(0)

func show_scream(text: String) -> void:
	if _cat: _cat.show_scream(text)

func _squash(target: Vector2) -> void:
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(self, "scale", target, 0.12)
	_squash_tween.tween_property(self, "scale", Vector2.ONE, 0.25)
