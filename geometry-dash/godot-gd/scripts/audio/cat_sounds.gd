class_name CatSounds
extends Node

const _SFX_CAT_CHIRP: AudioStream = preload("res://assets/audio/sfx/cat_chirp.ogg")
const _SFX_CAT_LAND:  AudioStream = preload("res://assets/audio/sfx/cat_land.ogg")
const _SFX_CAT_ALERT: AudioStream = preload("res://assets/audio/sfx/cat_alert.ogg")
const _SFX_CAT_HISS:  AudioStream = preload("res://assets/audio/sfx/cat_hiss.ogg")
const _SFX_CAT_PURR:  AudioStream = preload("res://assets/audio/sfx/cat_purr.ogg")
const _SFX_CAT_HAPPY: AudioStream = preload("res://assets/audio/sfx/cat_happy.ogg")

# Injected from main.gd before add_child().
var player: CharacterBody2D = null

var _sfx_cat_chirp: AudioStreamPlayer = null
var _sfx_cat_land:  AudioStreamPlayer = null
var _sfx_cat_alert: AudioStreamPlayer = null
var _sfx_cat_hiss:  AudioStreamPlayer = null
var _sfx_cat_purr:  AudioStreamPlayer = null
var _sfx_cat_happy: AudioStreamPlayer = null
var _sfx_cat_web:   AudioStreamPlayer = null
var _cat_sfx_web: Array[AudioStream] = []
var _cat_chirp_timer: float = 8.0

func _ready() -> void:
	_sfx_cat_chirp = _make_sfx(_SFX_CAT_CHIRP, -4.0)
	_sfx_cat_land  = _make_sfx(_SFX_CAT_LAND,  -6.0)
	_sfx_cat_alert = _make_sfx(_SFX_CAT_ALERT, -3.0)
	_sfx_cat_hiss  = _make_sfx(_SFX_CAT_HISS,  -5.0)
	_sfx_cat_purr  = _make_sfx(_SFX_CAT_PURR,  -4.0)
	_sfx_cat_happy = _make_sfx(_SFX_CAT_HAPPY, -3.0)
	_sfx_cat_web = AudioStreamPlayer.new()
	_sfx_cat_web.volume_db = -3.0
	add_child(_sfx_cat_web)

	_load_web_cat_sounds()

	GameManager.died.connect(_on_died)
	GameManager.score_changed.connect(_on_score_changed)
	if player:
		player.landed.connect(_on_player_landed)

func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_cat_chirp_timer -= delta
	if _cat_chirp_timer <= 0.0:
		play_random_chirp()
		_cat_chirp_timer = randf_range(5.0, 12.0)

func reset() -> void:
	_cat_chirp_timer = 8.0

# Public — called externally (e.g. when a monster spawns).
func alert() -> void:
	_sfx_cat_alert.play()

func play_random_chirp() -> void:
	if not _cat_sfx_web.is_empty() and randf() < 0.75:
		var stream: AudioStream = _cat_sfx_web[randi() % _cat_sfx_web.size()]
		_sfx_cat_web.stream = stream
		_sfx_cat_web.play()
	else:
		match randi() % 4:
			0: _sfx_cat_chirp.play()
			1: _sfx_cat_purr.play()
			2: _sfx_cat_happy.play()
			_: _sfx_cat_chirp.play()

func _on_player_landed() -> void:
	_sfx_cat_land.play()

func _on_died() -> void:
	_sfx_cat_hiss.play()

func _on_score_changed(new_score: int) -> void:
	if GameManager.is_milestone(new_score):
		_sfx_cat_happy.play()

func _load_web_cat_sounds() -> void:
	for i in range(1, 15):  # files 1-14 are short clean meows
		var path := "res://assets/audio/sfx/sfx_cat_web_%d.mp3" % i
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream:
				_cat_sfx_web.append(stream)

func _make_sfx(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p
