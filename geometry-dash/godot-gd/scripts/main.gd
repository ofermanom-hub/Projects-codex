extends Node2D

const _PlayerScript: GDScript        = preload("res://scripts/player/player.gd")
const _PoolScript: GDScript          = preload("res://scripts/obstacles/obstacle_pool.gd")
const _HUDScript: GDScript           = preload("res://scripts/hud.gd")
const _BackgroundScript: GDScript    = preload("res://scripts/world/background.gd")
const _SkyDomeScript: GDScript       = preload("res://scripts/world/sky_dome.gd")
const _ThemeDirectorScript: GDScript = preload("res://scripts/world/theme_director.gd")
const _CameraShakeScript: GDScript   = preload("res://scripts/world/camera_shake.gd")
const _SpaceDecorScript: GDScript    = preload("res://scripts/world/space_decor.gd")
const _DeathFXScript: GDScript       = preload("res://scripts/world/death_fx.gd")
const _AudioDirectorScript: GDScript = preload("res://scripts/audio/audio_director.gd")
const _CatSoundsScript: GDScript     = preload("res://scripts/audio/cat_sounds.gd")
const _MonsterPoolScript: GDScript   = preload("res://scripts/entities/monster_pool.gd")

var _player: Player
var _pool: ObstaclePool
var _hud: CanvasLayer
var _background: Background
var _sky_dome: SkyDome
var _theme_director: ThemeDirector
var _env_node: WorldEnvironment
var _camera: CameraShake
var _audio_director: AudioDirector
var _cat_sounds: CatSounds
var _monster_pool: MonsterPool
var _death_fx: DeathFX

func _ready() -> void:
	_build_world()
	_connect_signals()
	_apply_run_settings()
	_theme_director.apply_theme(0, false)

func _build_world() -> void:
	_env_node = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.12)
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_bloom = 0.55
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.adjustment_enabled = true
	_env_node.environment = env
	add_child(_env_node)

	_camera = _CameraShakeScript.new();  add_child(_camera)
	_sky_dome = _SkyDomeScript.new();    add_child(_sky_dome)
	_background = _BackgroundScript.new(); add_child(_background)
	_theme_director = _ThemeDirectorScript.new()
	_theme_director.background = _background
	_theme_director.sky_dome = _sky_dome
	add_child(_theme_director)
	add_child(_SpaceDecorScript.new())

	var ground := StaticBody2D.new(); ground.collision_layer = 2; ground.collision_mask = 0
	var gs := CollisionShape2D.new(); var gr := RectangleShape2D.new(); gr.size = Vector2(2000, 100)
	gs.shape = gr; ground.add_child(gs)
	ground.position = Vector2(450, GameManager.GROUND_Y + 50)
	add_child(ground)

	_player = _PlayerScript.new()
	var ps := CollisionShape2D.new(); var pr := RectangleShape2D.new(); pr.size = Vector2(44, 44)
	ps.shape = pr; _player.add_child(ps); add_child(_player)

	_pool = _PoolScript.new()
	_pool._player_ref = _player
	add_child(_pool)

	_monster_pool = _MonsterPoolScript.new()
	_monster_pool.player = _player
	add_child(_monster_pool)

	_death_fx = _DeathFXScript.new()
	_death_fx.player = _player
	add_child(_death_fx)

	_hud = _HUDScript.new(); add_child(_hud)

	_audio_director = _AudioDirectorScript.new()
	_audio_director.player = _player
	_audio_director.pool = _pool
	add_child(_audio_director)

	_cat_sounds = _CatSoundsScript.new()
	_cat_sounds.player = _player
	add_child(_cat_sounds)

	_monster_pool.monster_spawned.connect(_cat_sounds.alert)

func _apply_run_settings() -> void:
	var env := _env_node.environment
	env.glow_intensity = GameManager.run_glow_intensity
	env.adjustment_saturation = GameManager.run_sky_saturation
	GameManager.bg_hue = GameManager.run_start_hue
	_background.apply_run_settings()
	_sky_dome.apply_run_settings()
	_theme_director.apply_run_settings()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		match GameManager.state:
			GameManager.State.MENU:    GameManager.start()
			GameManager.State.DEAD:    GameManager.start()
			GameManager.State.PLAYING: _player.request_jump()
	if GameManager.state == GameManager.State.PLAYING:
		_theme_director.update_from_score(GameManager.score)

func _connect_signals() -> void:
	_pool.player_hit.connect(_on_player_hit)
	_pool.player_bounced.connect(_on_player_bounced)
	GameManager.restarted.connect(_on_restarted)
	GameManager.died.connect(_on_died)

func _on_player_hit() -> void:
	GameManager.die()

func _on_player_bounced() -> void:
	if GameManager.state == GameManager.State.PLAYING:
		_player.bounce_jump()

func _on_died() -> void:
	# CameraShake, AudioDirector, CatSounds, DeathFX all listen to GameManager.died.
	_player.hide()
	_monster_pool.reset()

func _on_restarted() -> void:
	_player.reset(); _pool.reset()
	_apply_run_settings()
	_theme_director.apply_theme(0, false)
	_audio_director.reset()
	_cat_sounds.reset()
	_monster_pool.reset()
