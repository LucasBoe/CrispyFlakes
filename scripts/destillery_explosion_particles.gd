extends Node2D
class_name DestilleryExplosionParticles

@onready var _explosion_particles: GPUParticles2D = $ExplosionParticles
@onready var _smoke_particles: GPUParticles2D = $SmokeParticles

var _finished_particles := 0

func _ready() -> void:
	_explosion_particles.finished.connect(_on_particles_finished)
	_smoke_particles.finished.connect(_on_particles_finished)
	_explosion_particles.restart()
	_smoke_particles.restart()
	_explosion_particles.emitting = true
	_smoke_particles.emitting = true

func _on_particles_finished() -> void:
	_finished_particles += 1
	if _finished_particles >= 2:
		queue_free()
