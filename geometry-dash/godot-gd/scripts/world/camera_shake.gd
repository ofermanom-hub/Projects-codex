class_name CameraShake
extends Camera2D

const _SHAKE_DECAY: float = 1.8
const _SHAKE_AMPLITUDE: float = 32.0
const _NOISE_SPEED: float = 8.0

var _trauma: float = 0.0
var _noise: FastNoiseLite = null
var _noise_t: float = 0.0

func _ready() -> void:
	position = Vector2(GameManager.WINDOW_W * 0.5, GameManager.WINDOW_H * 0.5)
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.seed = 42
	GameManager.died.connect(_on_died)

func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * _SHAKE_DECAY)
		var intensity: float = _trauma * _trauma
		_noise_t += delta * _NOISE_SPEED
		offset = Vector2(
			_noise.get_noise_2d(_noise_t, 0.0) * _SHAKE_AMPLITUDE * intensity,
			_noise.get_noise_2d(0.0, _noise_t) * _SHAKE_AMPLITUDE * intensity)
	else:
		offset = Vector2.ZERO

# Public — for non-death triggers (boss hit, big bounce, etc.).
func shake(intensity: float = 1.0) -> void:
	_trauma = clampf(intensity, 0.0, 1.0)

func _on_died() -> void:
	_trauma = 1.0
