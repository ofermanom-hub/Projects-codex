extends Node

signal died
signal restarted
signal score_changed(new_score: int)
signal state_changed(new_state: State)
signal theme_changed(idx: int)

enum State { MENU, PLAYING, DEAD }

const GROUND_Y: float = 410.0
const WINDOW_W: float = 900.0
const WINDOW_H: float = 500.0
const MILESTONES: Array[int] = [50, 100, 200, 500, 1000]

var state: State = State.MENU
var score: int = 0
var best: int = 0
var attempts: int = 0
var speed: float = 320.0
var bg_hue: float = 210.0
var distance_traveled: float = 0.0
var theme_index: int = 0

# ── Per-run roguelike parameters ──────────────────────────────────────────────
var run_seed: int = 0

# Difficulty wave (no upward trend — always oscillates)
var diff_amplitude: float = 1.0
var diff_frequency: float = 1.0
var diff_phase: float = 0.0
var diff_freq2: float = 0.4    # second harmonic frequency
var diff_phase2: float = 0.0   # second harmonic phase
var diff_freq3: float = 1.7    # third harmonic
var diff_phase3: float = 0.0

# Visual randomization per run
var run_start_hue: float = 210.0       # bg hue starting point
var run_grid_size: float = 48.0        # neon grid cell size (24–96)
var run_sun_start: float = 0.5         # position in day/night cycle (0–1)
var run_theme_order: Array[int] = []   # shuffled theme index order
var run_particle_hue_offset: float = 0.0  # extra hue offset for particles
var run_glow_intensity: float = 1.6    # glow strength (1.0–2.4)
var run_sky_saturation: float = 1.25   # sky saturation multiplier
var run_obstacle_tint: Color = Color.WHITE  # extra tint on obstacles

var _prev_milestone: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_load_best()
	_randomize_run()

func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	distance_traveled += speed * delta
	var new_score: int = int(distance_traveled / 7.0)
	if new_score != score:
		score = new_score
		bg_hue = fmod(bg_hue + 0.08, 360.0)
		score_changed.emit(score)

# Pure oscillating difficulty — never permanently rises, always bounces around
func get_difficulty() -> float:
	var t: float = distance_traveled / 1200.0
	var w1: float = diff_amplitude       * sin(t * diff_frequency  + diff_phase)
	var w2: float = diff_amplitude * 0.6 * sin(t * diff_freq2      + diff_phase2)
	var w3: float = diff_amplitude * 0.4 * sin(t * diff_freq3      + diff_phase3)
	return clampf(0.65 + w1 * 0.45 + w2 * 0.3 + w3 * 0.2, 0.1, 2.0)

func start() -> void:
	if state == State.MENU:
		attempts = 1
		_set_state(State.PLAYING)
	elif state == State.DEAD:
		_reset_round()
		_set_state(State.PLAYING)
		restarted.emit()

func die() -> void:
	if state != State.PLAYING:
		return
	if score > best:
		best = score
		_save_best()
	_set_state(State.DEAD)
	died.emit()

func is_milestone(s: int) -> bool:
	return MILESTONES.has(s) and s != _prev_milestone

func mark_milestone() -> void:
	_prev_milestone = score

func _randomize_run() -> void:
	_rng.randomize()
	run_seed = _rng.randi()

	# Difficulty waves — three uncorrelated harmonics
	diff_amplitude = _rng.randf_range(0.7, 1.3)
	diff_frequency = _rng.randf_range(0.6, 1.8)
	diff_phase     = _rng.randf_range(0.0, TAU)
	diff_freq2     = _rng.randf_range(0.25, 0.7)
	diff_phase2    = _rng.randf_range(0.0, TAU)
	diff_freq3     = _rng.randf_range(1.3, 2.2)
	diff_phase3    = _rng.randf_range(0.0, TAU)

	# Visual randomization
	run_start_hue          = _rng.randf_range(0.0, 360.0)
	run_grid_size          = _rng.randf_range(24.0, 96.0)
	run_sun_start          = _rng.randf()
	run_particle_hue_offset = _rng.randf_range(0.0, 1.0)
	run_glow_intensity     = _rng.randf_range(1.0, 2.4)
	run_sky_saturation     = _rng.randf_range(0.9, 1.6)
	var r := _rng.randf_range(0.7, 1.0)
	var g := _rng.randf_range(0.7, 1.0)
	var b := _rng.randf_range(0.7, 1.0)
	run_obstacle_tint = Color(r, g, b)

	# Shuffle theme order so themes appear in a random sequence each run
	run_theme_order.clear()
	for i in range(10):
		run_theme_order.append(i)
	for i in range(run_theme_order.size() - 1, 0, -1):
		var j: int = _rng.randi() % (i + 1)
		var tmp: int = run_theme_order[i]
		run_theme_order[i] = run_theme_order[j]
		run_theme_order[j] = tmp

func _reset_round() -> void:
	distance_traveled = 0.0
	score = 0
	speed = 320.0
	theme_index = 0
	_prev_milestone = -1
	attempts += 1
	_randomize_run()
	bg_hue = run_start_hue

func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)

func _load_best() -> void:
	if FileAccess.file_exists("user://best.dat"):
		var f := FileAccess.open("user://best.dat", FileAccess.READ)
		if f:
			best = f.get_32()
			f.close()

func _save_best() -> void:
	var f := FileAccess.open("user://best.dat", FileAccess.WRITE)
	if f:
		f.store_32(best)
		f.close()
