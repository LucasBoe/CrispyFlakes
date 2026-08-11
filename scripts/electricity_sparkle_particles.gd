extends GPUParticles2D
class_name ElectricitySparkleParticles

var _spark_texture: ImageTexture

func _ready() -> void:
	_ensure_pixel_texture()
	emitting = false

func _ensure_pixel_texture() -> void:
	if texture != null:
		return

	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.WHITE)
	_spark_texture = ImageTexture.create_from_image(image)
	texture = _spark_texture
