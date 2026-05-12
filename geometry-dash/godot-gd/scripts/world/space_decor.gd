class_name SpaceDecor
extends Node2D

const Themes: GDScript = preload("res://scripts/data/themes.gd")

const _K_STAR_L: Texture2D = preload("res://assets/sprites/kenney/bg_star_large.png")
const _K_STAR_S: Texture2D = preload("res://assets/sprites/kenney/bg_star_small.png")
const _K_METEOR: Texture2D = preload("res://assets/sprites/kenney/bg_meteor_small.png")

const _NUM_STARS: int = 30
const _NUM_BIG_STARS: int = 10
const _NUM_METEORS: int = 6

var _stars: Array[Sprite2D] = []
var _meteors: Array[Sprite2D] = []
var _visible: bool = false

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(_NUM_STARS):
		var s := Sprite2D.new()
		s.texture = _K_STAR_L if i < _NUM_BIG_STARS else _K_STAR_S
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(0.5, 0.5) if i < _NUM_BIG_STARS else Vector2(0.3, 0.3)
		s.position = Vector2(rng.randf_range(0, GameManager.WINDOW_W), rng.randf_range(20, GameManager.GROUND_Y - 40))
		s.visible = false
		s.z_index = -11
		add_child(s)
		_stars.append(s)
	for _i in range(_NUM_METEORS):
		var m := Sprite2D.new()
		m.texture = _K_METEOR
		m.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		m.scale = Vector2(0.6, 0.6)
		m.position = Vector2(rng.randf_range(200, GameManager.WINDOW_W), rng.randf_range(30, GameManager.GROUND_Y - 80))
		m.visible = false
		m.z_index = -10
		add_child(m)
		_meteors.append(m)

	GameManager.theme_changed.connect(_on_theme_changed)

func _process(delta: float) -> void:
	if not _visible or GameManager.state != GameManager.State.PLAYING:
		return
	var spd: float = GameManager.speed
	for s: Sprite2D in _stars:
		s.position.x -= spd * 0.06 * delta
		if s.position.x < -20.0:
			s.position.x = GameManager.WINDOW_W + 20.0
	for m: Sprite2D in _meteors:
		m.position.x -= spd * 0.18 * delta
		if m.position.x < -30.0:
			m.position.x = GameManager.WINDOW_W + 40.0

func _on_theme_changed(idx: int) -> void:
	_visible = (idx == Themes.SPACE_INDEX)
	for s: Sprite2D in _stars:   s.visible = _visible
	for m: Sprite2D in _meteors: m.visible = _visible
