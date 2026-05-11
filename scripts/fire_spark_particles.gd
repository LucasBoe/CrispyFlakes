extends GPUParticles2D
class_name FireSparkParticles

@export var min_lifetime := 1.4
@export var max_lifetime := 2.8
@export var extinguish_size_power := 1.5

var _spark_texture: ImageTexture

func _ready() -> void:
	_ensure_pixel_texture()
	emitting = false

func set_fire_state(propagation_ratio: float, extinguish_ratio: float) -> void:
	var propagation_size := lerpf(0.15, 1.0, clampf(propagation_ratio, 0.0, 1.0))
	var extinguish_size := pow(clampf(extinguish_ratio, 0.0, 1.0), extinguish_size_power)
	var intensity := clampf(propagation_size * extinguish_size, 0.0, 1.0)

	emitting = intensity > 0.03
	lifetime = lerpf(min_lifetime, max_lifetime, intensity)

func _ensure_pixel_texture() -> void:
	if texture != null:
		return

	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.WHITE)
	_spark_texture = ImageTexture.create_from_image(image)
	texture = _spark_texture
