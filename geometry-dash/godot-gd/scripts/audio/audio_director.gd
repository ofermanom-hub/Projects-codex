class_name AudioDirector
extends Node

const _SFX_JUMP: AudioStream      = preload("res://assets/audio/sfx/jump.ogg")
const _SFX_DEATH: AudioStream     = preload("res://assets/audio/sfx/death.ogg")
const _SFX_BOUNCE: AudioStream    = preload("res://assets/audio/sfx/bounce.ogg")
const _SFX_MILESTONE: AudioStream = preload("res://assets/audio/sfx/milestone.ogg")

const _NES_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/music/nes_00.ogg"),
	preload("res://assets/audio/music/nes_01.ogg"),
	preload("res://assets/audio/music/nes_02.ogg"),
	preload("res://assets/audio/music/nes_03.ogg"),
	preload("res://assets/audio/music/nes_04.ogg"),
	preload("res://assets/audio/music/nes_05.ogg"),
	preload("res://assets/audio/music/nes_06.ogg"),
	preload("res://assets/audio/music/nes_07.ogg"),
	preload("res://assets/audio/music/nes_08.ogg"),
]
const _SCREAMS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/scream_fight.ogg"),
	preload("res://assets/audio/sfx/scream_combo.ogg"),
	preload("res://assets/audio/sfx/scream_ready.ogg"),
	preload("res://assets/audio/sfx/scream_begin.ogg"),
	preload("res://assets/audio/sfx/scream_winner.ogg"),
	preload("res://assets/audio/sfx/scream_round_1.ogg"),
	preload("res://assets/audio/sfx/scream_prepare_yourself.ogg"),
	preload("res://assets/audio/sfx/scream_sudden_death.ogg"),
	preload("res://assets/audio/sfx/scream_combo_breaker.ogg"),
]
const _SCREAM_TEXTS: Array[String] = [
	"FIGHT!!", "COMBO!!", "READY?!", "BEGIN!!", "WINNER!",
	"ROUND 1!", "PREPARE!", "SUDDEN\nDEATH!", "COMBO\nBREAKER!",
]

# Injected from main.gd before add_child().
var player: CharacterBody2D = null
var pool: Node2D = null

var _sfx_jump: AudioStreamPlayer = null
var _sfx_death: AudioStreamPlayer = null
var _sfx_bounce: AudioStreamPlayer = null
var _sfx_milestone: AudioStreamPlayer = null
var _sfx_scream: AudioStreamPlayer = null
var _music: AudioStreamPlayer = null
var _nes_index: int = 0
var _scream_timer: float = 12.0

func _ready() -> void:
	_sfx_jump      = _make_sfx(_SFX_JUMP,      0.0)
	_sfx_death     = _make_sfx(_SFX_DEATH,     0.0)
	_sfx_bounce    = _make_sfx(_SFX_BOUNCE,    2.0)
	_sfx_milestone = _make_sfx(_SFX_MILESTONE, 0.0)
	_sfx_scream    = _make_sfx(_SCREAMS[0],    0.0)

	_music = AudioStreamPlayer.new()
	_music.volume_db = -5.0
	_music.finished.connect(_on_music_finished)
	add_child(_music)

	GameManager.died.connect(_on_died)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.score_changed.connect(_on_score_changed)
	if player:
		player.jumped.connect(_on_player_jumped)
	if pool and pool.has_signal("player_bounced"):
		pool.player_bounced.connect(_on_player_bounced)

func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_scream_timer -= delta
	if _scream_timer <= 0.0:
		_trigger_scream()
		_scream_timer = randf_range(8.0, 20.0)

func reset() -> void:
	_scream_timer = 12.0

func _trigger_scream() -> void:
	var idx: int = randi() % _SCREAMS.size()
	_sfx_scream.stream = _SCREAMS[idx]
	_sfx_scream.play()
	if player and player.has_method("show_scream"):
		player.show_scream(_SCREAM_TEXTS[idx])

func _on_player_jumped(_n: int) -> void:
	_sfx_jump.play()

func _on_player_bounced() -> void:
	_sfx_bounce.play()

func _on_died() -> void:
	_sfx_death.play()

func _on_state_changed(new_state: int) -> void:
	if new_state == GameManager.State.PLAYING:
		if not _music.playing:
			_nes_index = randi() % _NES_TRACKS.size()
			_music.stream = _NES_TRACKS[_nes_index]
			_music.play()
	elif new_state == GameManager.State.DEAD:
		_music.stop()

func _on_score_changed(new_score: int) -> void:
	if GameManager.is_milestone(new_score):
		_sfx_milestone.play()

func _on_music_finished() -> void:
	_nes_index = (_nes_index + 1) % _NES_TRACKS.size()
	_music.stream = _NES_TRACKS[_nes_index]
	_music.play()

func _make_sfx(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p
