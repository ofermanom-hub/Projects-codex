class_name MonsterPool
extends Node2D

const _MonsterScript: GDScript = preload("res://scripts/entities/monster.gd")
const _K_MONSTERS: Array[Texture2D] = [
	preload("res://assets/sprites/kenney/monster_bear.png"),
	preload("res://assets/sprites/kenney/monster_gorilla.png"),
	preload("res://assets/sprites/kenney/monster_crocodile.png"),
	preload("res://assets/sprites/kenney/monster_sloth.png"),
	preload("res://assets/sprites/kenney/monster_rhino.png"),
	preload("res://assets/sprites/kenney/monster_parrot.png"),
]
const POOL_SIZE: int = 4

signal monster_spawned

# Injected from main.gd before add_child().
var player: CharacterBody2D = null

var _monsters: Array[Monster] = []
var _spawn_timer: float = 18.0
var _anim_t: float = 0.0

func _ready() -> void:
	for i in POOL_SIZE:
		var m: Monster = _MonsterScript.new()
		m.player = player
		m.texture = _K_MONSTERS[i % _K_MONSTERS.size()]
		add_child(m)
		_monsters.append(m)

func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_spawn_timer -= delta
	_anim_t += delta
	if _spawn_timer <= 0.0:
		_try_spawn()
		_spawn_timer = randf_range(12.0, 24.0)
	for m: Monster in _monsters:
		m.update(delta, _anim_t)

func reset() -> void:
	_spawn_timer = 18.0
	for m: Monster in _monsters:
		m.hide_and_idle()

func _try_spawn() -> void:
	for m: Monster in _monsters:
		if m.is_idle():
			m.spawn_at(Vector2(randf_range(60, GameManager.WINDOW_W - 60), -50.0))
			monster_spawned.emit()
			return
