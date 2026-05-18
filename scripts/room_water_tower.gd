extends RoomOutsideBase
class_name RoomWaterTower

const MAX_WATER := 96.0
const PUMP_AMOUNT := 8.0
const PUMP_DURATION := 3.0
const RAISE_COST := 25
const _WATER_LAYER := &"water"
const _PIPE_TILE_TEXTURE_PATH := "res://assets/sprites/water_pipe_tiles.png"
const _PIPE_TILE_SIZE := 48.0
const _PIPE_OUTPUTS_Z_INDEX := 2050
const _PIPE_OUTPUTS_ROOT_OFFSET := Vector2(-24, -49)
const _PIPE_MATERIAL := preload("res://assets/shaders/water_sytem.tres")
const _OUTLINE_MATERIAL := preload("res://assets/materials/mat_outline_outside_rooms.tres")

const _EXTENSION_REGION := Rect2(0, 45, 46, 48)
const _EXTENSION_LEFT_X := 1.0

@onready var fill_rect: ColorRect = $ModulesRoot/Tower/Basic/WaterTower/ColorRectFill
@onready var tower_sprite: Sprite2D = $ModulesRoot/Tower/Basic/WaterTower

var current_water := 0.0
var extra_height: int = 0
var _pipe_outputs_root: Node2D = null
var _extension_sprites: Array[Node2D] = []
static var _pipe_tile_texture: Texture2D = null

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.WATER_TOWER
	_update_visual()

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func is_full() -> bool:
	return current_water >= MAX_WATER

func has_water() -> bool:
	return current_water >= 1.0

func pump():
	current_water = minf(current_water + PUMP_AMOUNT, MAX_WATER)
	_update_visual()

func consume_water():
	current_water = maxf(0.0, current_water - 1.0)
	_update_visual()

func can_raise() -> bool:
	var new_y_idx: int = y + data.height
	return not (Building.floors.has(new_y_idx) and Building.floors[new_y_idx].has(x))

func raise_tower() -> bool:
	if not ResourceHandler.has_money(RAISE_COST):
		return false
	await ResourceHandler.spend_animated(RAISE_COST, global_position)
	SoundPlayer.play_construction_placed()
	if extra_height == 0:
		data = data.duplicate()
	extra_height += 1
	data.height += 1
	var new_y_idx: int = y + data.height - 1
	if not Building.floors.has(new_y_idx):
		Building.floors[new_y_idx] = {}
	Building.floors[new_y_idx][x] = self
	_rebuild_tower_visual()
	Building.update_foreground_tiles()
	return true

func _rebuild_tower_visual() -> void:
	for sprite in _extension_sprites:
		if is_instance_valid(sprite):
			sprite.free()
	_extension_sprites.clear()

	tower_sprite.position = Vector2(24, 1 - extra_height * _PIPE_TILE_SIZE)

	if is_instance_valid(_pipe_outputs_root):
		_pipe_outputs_root.position = Vector2(_PIPE_OUTPUTS_ROOT_OFFSET.x, _PIPE_OUTPUTS_ROOT_OFFSET.y + extra_height * _PIPE_TILE_SIZE)

	var parent := tower_sprite.get_parent() as Node2D
	for i in range(extra_height):
		var scaffold := _make_scaffold_sprite()
		scaffold.position.y = -(extra_height - i) * _PIPE_TILE_SIZE
		parent.add_child(scaffold)
		_extension_sprites.append(scaffold)
		_register_outlined_sprite(scaffold)

func _make_scaffold_sprite() -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = tower_sprite.texture
	atlas.region = _EXTENSION_REGION
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.centered = false
	sprite.position.x = _EXTENSION_LEFT_X
	sprite.z_index = -200
	sprite.material = _OUTLINE_MATERIAL
	return sprite

func get_provided_infrastructure_layers() -> Array[StringName]:
	return [&"water"]

func clear_infrastructure_output_tiles(layer_name: StringName) -> void:
	if layer_name != _WATER_LAYER:
		return
	var outputs_root := _ensure_pipe_outputs_root()
	for child in outputs_root.get_children():
		child.free()

func add_infrastructure_output_tile(layer_name: StringName, room_index: Vector2i, tile_index: int) -> void:
	if layer_name != _WATER_LAYER:
		return

	var outputs_root := _ensure_pipe_outputs_root()
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = _create_pipe_tile_texture(tile_index)
	sprite.material = _PIPE_MATERIAL
	sprite.position = Vector2((room_index.x - x) * _PIPE_TILE_SIZE, (room_index.y - y) * -_PIPE_TILE_SIZE)
	outputs_root.add_child(sprite)

func _update_visual():
	if not is_instance_valid(fill_rect):
		return
	var ratio = current_water / MAX_WATER
	# offset_bottom fixed at -58 (bottom of tank), offset_top slides up as water fills
	fill_rect.offset_top = -58.0 - 26.0 * ratio

func _ensure_pipe_outputs_root() -> Node2D:
	if is_instance_valid(_pipe_outputs_root):
		return _pipe_outputs_root

	_pipe_outputs_root = tower_sprite.get_node_or_null("PipeOutputs") as Node2D
	if _pipe_outputs_root == null:
		_pipe_outputs_root = Node2D.new()
		_pipe_outputs_root.name = "PipeOutputs"
		_pipe_outputs_root.position = Vector2(_PIPE_OUTPUTS_ROOT_OFFSET.x, _PIPE_OUTPUTS_ROOT_OFFSET.y + extra_height * _PIPE_TILE_SIZE)
		_pipe_outputs_root.z_as_relative = false
		_pipe_outputs_root.z_index = _PIPE_OUTPUTS_Z_INDEX
		tower_sprite.add_child(_pipe_outputs_root)

	return _pipe_outputs_root

func _create_pipe_tile_texture(tile_index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = _get_pipe_tile_texture()
	texture.region = Rect2(tile_index * _PIPE_TILE_SIZE, 0, _PIPE_TILE_SIZE, _PIPE_TILE_SIZE)
	return texture

func _get_pipe_tile_texture() -> Texture2D:
	if _pipe_tile_texture != null:
		return _pipe_tile_texture

	var image := Image.load_from_file(ProjectSettings.globalize_path(_PIPE_TILE_TEXTURE_PATH))
	_pipe_tile_texture = ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
	return _pipe_tile_texture
