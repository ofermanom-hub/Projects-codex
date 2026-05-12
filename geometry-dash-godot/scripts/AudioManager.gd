extends Node

const SR = 22050

var jump_sfx  : AudioStreamPlayer
var death_sfx : AudioStreamPlayer
var music_sfx : AudioStreamPlayer
var _thread   : Thread

func _ready() -> void:
	jump_sfx  = make_sfx_player(_gen_jump(),  -2.0)
	death_sfx = make_sfx_player(_gen_death(), -2.0)
	add_child(jump_sfx)
	add_child(death_sfx)

	music_sfx           = AudioStreamPlayer.new()
	music_sfx.volume_db = -8.0
	add_child(music_sfx)

	# Generate music off the main thread so startup has no freeze
	_thread = Thread.new()
	_thread.start(_gen_music_thread)

func _gen_music_thread() -> void:
	var stream := _gen_music()
	call_deferred("_on_music_ready", stream)

func _on_music_ready(stream: AudioStreamWAV) -> void:
	music_sfx.stream = stream
	_thread.wait_to_finish()

func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()

# ── Public ─────────────────────────────────────────────────────────────────
func play_jump(is_double: bool) -> void:
	jump_sfx.pitch_scale = 1.45 if is_double else 1.0
	jump_sfx.play()

func play_death() -> void:
	death_sfx.play()

func start_music() -> void:
	if music_sfx.stream != null and not music_sfx.playing:
		music_sfx.play()

func stop_music() -> void:
	music_sfx.stop()

# ── Audio helpers ──────────────────────────────────────────────────────────
func make_sfx_player(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p    := AudioStreamPlayer.new()
	p.stream  = stream
	p.volume_db = db
	return p

func _wav(n: int) -> PackedByteArray:
	var d := PackedByteArray()
	d.resize(n * 2)
	return d

func _write(d: PackedByteArray, i: int, v: float) -> void:
	var s : int = clampi(int(v * 32767.0), -32768, 32767)
	d[i * 2]     = s & 0xFF
	d[i * 2 + 1] = (s >> 8) & 0xFF

func _make_wav(data: PackedByteArray, loop_end: int = 0) -> AudioStreamWAV:
	var w         := AudioStreamWAV.new()
	w.format      = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate    = SR
	w.stereo      = false
	w.data        = data
	if loop_end > 0:
		w.loop_mode  = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end   = loop_end
	return w

# ── Jump SFX — rising sine chirp ───────────────────────────────────────────
func _gen_jump() -> AudioStreamWAV:
	var n : int = int(SR * 0.10)
	var d := _wav(n)
	for i in n:
		var t   : float = float(i) / SR
		var env : float = 1.0 - float(i) / float(n)
		var f   : float = lerpf(480.0, 820.0, float(i) / float(n))
		_write(d, i, sin(TAU * f * t) * env * 0.65)
	return _make_wav(d)

# ── Death SFX — falling noise burst ───────────────────────────────────────
func _gen_death() -> AudioStreamWAV:
	var n : int = int(SR * 0.26)
	var d := _wav(n)
	for i in n:
		var t   : float = float(i) / SR
		var env : float = pow(1.0 - float(i) / float(n), 0.5)
		var f   : float = lerpf(380.0, 55.0, float(i) / float(n))
		var s   : float = (sin(TAU * f * t) * 0.5 + (randf()*2.0-1.0)*0.5) * env * 0.8
		_write(d, i, s)
	return _make_wav(d)

# ── Music — 2-bar chiptune loop (fast to generate) ─────────────────────────
func _gen_music() -> AudioStreamWAV:
	var bpm   : float = 140.0
	var beat  : float = 60.0 / bpm           # 0.429 s
	var bars  : int   = 2
	var total : float = beat * bars * 4.0    # 2 bars = 3.43 s
	var n     : int   = int(SR * total)      # ~75 k samples — fast in GDScript
	var d     := _wav(n)

	# C minor pentatonic: C4  Eb4   F4    G4    Bb4   C5
	var freqs   : Array = [261.63, 311.13, 349.23, 392.00, 466.16, 523.25]
	# 8-note melody repeated
	var melody  : Array = [0, 2, 4, 3, 2, 0, 4, 2, 1, 3, 0, 4, 2, 1, 3, 4]
	var bass_p  : Array = [0, 0, 2, 2, 4, 4, 2, 2, 1, 1, 3, 3, 0, 0, 4, 4]

	for i in n:
		var t    : float = float(i) / SR
		var bi   : int   = int(t / (beat * 0.5))    # eighth-note index
		var note : int   = melody[bi % melody.size()]
		var bf   : float = freqs[note % freqs.size()]
		var baf  : float = float(freqs[bass_p[(bi / 2) % bass_p.size()] % freqs.size()]) * 0.5

		# Square melody with quick attack
		var bp  : float = fmod(t / beat, 1.0)
		var mel : float = (1.0 if fmod(t * bf, 1.0) < 0.5 else -1.0) * 0.26
		mel *= clampf(bp * 25.0, 0.0, 1.0) * clampf(1.0 - bp * 0.9, 0.0, 1.0)

		# Triangle bass
		var bas : float = (2.0 * fmod(t * baf, 1.0) - 1.0) * 0.20

		# Kick on beats 1 & 3 of each bar
		var bar_pos : float = fmod(t / (beat * 4.0), 1.0)
		var kick    : float = 0.0
		for kb in [0.0, 0.5]:
			var kd : float = fmod(bar_pos - kb + 1.0, 1.0)
			if kd < beat:
				kick += sin(TAU * 80.0 * kd) * exp(-kd * 14.0) * 0.38

		# Hi-hat on eighth notes
		var hat : float = 0.0
		if fmod(t / (beat * 0.5), 1.0) < 0.055:
			hat = (randf()*2.0-1.0) * 0.10

		_write(d, i, clampf(mel + bas + kick + hat, -1.0, 1.0))

	return _make_wav(d, n)
