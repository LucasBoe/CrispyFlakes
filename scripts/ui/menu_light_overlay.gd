extends Node2D
class_name MenuLightOverlay

# menu stand-in for RoomTemperatureOverlayHandler, which needs real rooms; the origin is the lit area's bottom-left
const OVERLAY_TEXTURE := preload("res://assets/sprites/room_temperature_overlay.png")
const OVERLAY_MATERIAL := preload("res://assets/materials/mat_room_temperature_overlay.tres")
const TILE_SIZE := 48.0
const OVERLAY_Z_INDEX := 1000
const MAX_LIGHT_INPUTS := 4

@export var room_tiles := Vector2i(1, 1)
@export var lights: Array[MenuLightInput] = []

var _overlay: Sprite2D
var _material: ShaderMaterial

func _ready() -> void:
	# the overlay shader reads the screen, so it needs a copy just below it
	var back_buffer_copy := BackBufferCopy.new()
	back_buffer_copy.z_as_relative = false
	back_buffer_copy.z_index = OVERLAY_Z_INDEX - 1
	back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(back_buffer_copy)

	_overlay = Sprite2D.new()
	_overlay.centered = false
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.z_as_relative = false
	_overlay.z_index = OVERLAY_Z_INDEX
	_overlay.texture = OVERLAY_TEXTURE
	# not 0: the renderer skips fully transparent items, so the shader would never run
	_overlay.modulate = Color(1.0, 1.0, 1.0, 0.01)
	_material = OVERLAY_MATERIAL.duplicate() as ShaderMaterial
	_overlay.material = _material
	_overlay.position = Vector2(0.0, -room_tiles.y * TILE_SIZE)
	_overlay.scale = Vector2(room_tiles)
	add_child(_overlay)

	_material.set_shader_parameter("room_size", Vector2(room_tiles) * TILE_SIZE)

func _process(_delta: float) -> void:
	var room_top_left := global_position + Vector2(0.0, -room_tiles.y * TILE_SIZE)
	for index in MAX_LIGHT_INPUTS:
		var texture_parameter := "aura_texture_%d" % index
		var rect_parameter := "aura_rect_%d" % index
		var color_parameter := "aura_color_%d" % index
		if index >= lights.size() or lights[index] == null or lights[index].texture == null:
			_material.set_shader_parameter(texture_parameter, OVERLAY_TEXTURE)
			_material.set_shader_parameter(rect_parameter, Vector4(-1.0, -1.0, 0.0, 0.0))
			_material.set_shader_parameter(color_parameter, Color.TRANSPARENT)
			continue

		var light := lights[index]
		var light_global := to_global(light.position)
		if not light.follow.is_empty():
			light_global = (get_node(light.follow) as Node2D).global_position
		var texture_size := Vector2(light.texture.get_size()) * light.scale.abs()
		var top_left := light_global + light.offset - texture_size * 0.5 - room_top_left
		var tint := light.tint
		tint.a *= clampf(light.intensity, 0.0, 4.0)
		_material.set_shader_parameter(texture_parameter, light.texture)
		_material.set_shader_parameter(rect_parameter, Vector4(top_left.x, top_left.y, texture_size.x, texture_size.y))
		_material.set_shader_parameter(color_parameter, tint)
