extends RoomBase
class_name RoomOutsideBase

var _outlined_sprites: Array[Sprite2D] = []

func _on_module_bought(module) -> void:
	if not module.bought:
		return
	current_module = module

func init_room(_x : int, _y : int):
	is_outside_room = true
	_init_outline()
	super.init_room(_x, _y)

func _init_outline() -> void:
	_outlined_sprites.clear()
	var modules_root: Node = get_node_or_null("ModulesRoot")
	if modules_root == null:
		return
	for group in modules_root.get_children():
		for module in group.get_children():
			for child in module.get_children():
				if child is Sprite2D:
					_register_outlined_sprite(child as Sprite2D)

func _register_outlined_sprite(sprite: Sprite2D) -> void:
	if sprite == null or not sprite.material is ShaderMaterial:
		return
	sprite.material = (sprite.material as ShaderMaterial).duplicate(true)
	_outlined_sprites.append(sprite)

func set_outline(state: bool) -> void:
	var color: Color = Color.WHITE if state else Color.BLACK
	for sprite in _outlined_sprites:
		if is_instance_valid(sprite) and sprite.material is ShaderMaterial:
			(sprite.material as ShaderMaterial).set_shader_parameter("outline_color", color)

static func custom_placement_check(location) -> bool:
	return location.y == 0
