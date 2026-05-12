class_name ObstaclePool
extends Node2D

const _Factory: GDScript  = preload("res://scripts/obstacles/obstacle_factory.gd")
const _Selector: GDScript = preload("res://scripts/obstacles/patterns_selector.gd")
const _ObstacleScript: GDScript = preload("res://scripts/obstacles/obstacle.gd")

signal player_hit
signal player_bounced
signal player_rail(direction: float)
signal player_off_rail

const POOL_SIZE: int = 60
const SPAWN_X: float = 960.0
const DESPAWN_X: float = -100.0

var _pool: Array[Obstacle] = []
var _next_spawn_dist: float = 700.0
var _player_ref: CharacterBody2D = null
var _anim_time: float = 0.0
var _factory: ObstacleFactory = null

func _ready() -> void:
	_factory = _Factory.new()
	for _i: int in POOL_SIZE:
		var obs: Obstacle = _ObstacleScript.new()
		obs.factory = _factory
		obs.hit.connect(_on_obstacle_hit)
		obs.bounced.connect(_on_obstacle_bounced)
		obs.visible = false
		obs.position.x = DESPAWN_X - 200.0
		_pool.append(obs)
		add_child(obs)

func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_anim_time += delta

	var any_rail: bool = false
	for obs: Obstacle in _pool:
		if not obs.visible:
			continue
		obs.position.x -= GameManager.speed * delta
		if obs.animate(delta, _anim_time, _player_ref):
			any_rail = true
		if obs.position.x < DESPAWN_X:
			obs.release()

	if not any_rail and _player_ref:
		_player_ref.rail_direction = 0.0

	if GameManager.distance_traveled >= _next_spawn_dist:
		_spawn_pattern()

func _spawn_pattern() -> void:
	var pat: Array = _Selector.pick(GameManager.score, GameManager.get_difficulty())
	for entry: Array in pat:
		var obs: Obstacle = _get_free()
		if obs == null:
			break
		var rot: float = float(entry[5]) if entry.size() > 5 else 0.0
		obs.configure(int(entry[0]), float(entry[1]), SPAWN_X, float(entry[2]), float(entry[3]), float(entry[4]), rot)
	# Gap shrinks when difficulty is high, grows when low
	var diff: float = GameManager.get_difficulty()
	var base_gap: float = maxf(40.0, 105.0 - diff * 22.0)
	var gap: float = base_gap + randf() * 50.0
	_next_spawn_dist = GameManager.distance_traveled + gap * 7.5

func _get_free() -> Obstacle:
	for obs: Obstacle in _pool:
		if not obs.visible:
			return obs
	return null

func reset() -> void:
	for obs: Obstacle in _pool:
		obs.release()
	_next_spawn_dist = GameManager.distance_traveled + 700.0
	if _player_ref:
		_player_ref.rail_direction = 0.0

func _on_obstacle_hit() -> void:
	player_hit.emit()

func _on_obstacle_bounced() -> void:
	player_bounced.emit()
