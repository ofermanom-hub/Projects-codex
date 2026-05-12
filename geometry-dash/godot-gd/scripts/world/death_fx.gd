class_name DeathFX
extends Node2D

# Injected from main.gd before add_child().
var player: CharacterBody2D = null

var _particles: CPUParticles2D = null

func _ready() -> void:
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = 75
	_particles.lifetime = 1.2
	_particles.explosiveness = 1.0
	_particles.direction = Vector2(0, -1)
	_particles.spread = 180.0
	_particles.gravity = Vector2(0, 280)
	_particles.initial_velocity_min = 190.0
	_particles.initial_velocity_max = 440.0
	_particles.angular_velocity_min = -240.0
	_particles.angular_velocity_max = 240.0
	_particles.scale_amount_min = 5.0
	_particles.scale_amount_max = 16.0
	_particles.color = Color(0, 0.9, 1)
	var grad := Gradient.new()
	grad.add_point(0.0, Color(1, 0.9, 0.3, 1))
	grad.add_point(0.4, Color(1, 0.4, 0.1, 0.9))
	grad.add_point(0.8, Color(0, 0.9, 1, 0.8))
	grad.add_point(1.0, Color(0, 0.9, 1, 0))
	_particles.color_ramp = grad
	add_child(_particles)

	GameManager.died.connect(_on_died)

func _on_died() -> void:
	if player:
		_particles.position = player.position
	_particles.restart()
