class_name BuildingInfrastructureWater
extends RefCounted

const _PIPE_SOURCE_ID := 0
const _PIPE_TEXTURE_PATH := "res://assets/sprites/water_pipe_tiles.png"
const _PIPE_TILE_COUNT := 18

enum PipeTile {
	TOWER_OUTPUT_RIGHT = 0,
	INDOOR_COMPLETE = 1,
	OUTDOOR_COMPLETE = 2,
	TOWER_OUTPUT_LEFT = 3,
	OUTDOOR_LEFT_END = 4,
	OUTDOOR_RIGHT_END = 5,
	INDOOR_LEFT_END = 6,
	INDOOR_RIGHT_END = 7,
	FAUCET_LEFT = 8,
	FAUCET_COMPLETE = 9,
	FAUCET_RIGHT = 10,
	OUTDOOR_TOWER_OUTPUT_DOUBLE = 11,
	INDOOR_TOWER_OUTPUT_DOUBLE = 12,
	OUTDOOR_TOWER_OUTPUT_DOUBLE_AND_BELOW = 13,
	INDOOR_TOWER_OUTPUT_DOUBLE_AND_BELOW = 14,
	OUTDOOR_LEFT_END_IF_ABOVE = 15,
	OUTDOOR_COMPLETE_IF_ABOVE = 16,
	OUTDOOR_RIGHT_END_IF_ABOVE = 17,
}

const _HORIZONTAL_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT]
const _GRID_ABOVE_OFFSET := Vector2i(0, 1)
const _GRID_BELOW_OFFSET := Vector2i(0, -1)
const _NETWORK_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, _GRID_BELOW_OFFSET]
const _SUPPORT_BELOW_OFFSET := _GRID_BELOW_OFFSET

var _infra
var _tilemap: TileMapLayer
var _pipe_texture: Texture2D = null
var _info_highlights: Array = []
var _info_active: bool = false

func setup(infra: BuildingInfrastructure, tilemap: TileMapLayer) -> void:
	_infra = infra
	_tilemap = tilemap
	infra.on_infrastructure_changed_signal.connect(_on_infrastructure_changed)

func _on_infrastructure_changed(layer_name: StringName) -> void:
	if _info_active and layer_name == BuildingInfrastructure.WATER_LAYER:
		show_info()

func show_info() -> void:
	_info_active = true
	_clear_display()

	_tilemap.z_index = Enum.ZLayer.INFO_LAYER
	var mat := _tilemap.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"enabled", true)
		var has_tower_water := false
		for provider in _infra.get_provider_rooms(BuildingInfrastructure.WATER_LAYER):
			var tower := provider as RoomWaterTower
			if tower != null and tower.has_water():
				has_tower_water = true
				break
		var shader_color := Color(0.2, 0.5, 1.0, 1.0) if has_tower_water else Color(0.5, 0.05, 0.05, 1.0)
		mat.set_shader_parameter(&"highlight_color", shader_color)

	for floor_dict in Building.floors.values():
		for room in floor_dict.values():
			var room_base := room as RoomBase
			if room_base == null:
				continue
			var color := _get_room_water_color(room_base)
			if color == Color.TRANSPARENT:
				continue
			_info_highlights.append(RoomHighlighter.request_rect(room_base, color, 2, RoomHighlighter.Priority.TEMP_INFO_OVERLAY))

func hide_info() -> void:
	_info_active = false
	_tilemap.z_index = Enum.ZLayer.INFRASTRUCTURE_PIPES
	var mat := _tilemap.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"enabled", false)
	_clear_display()

func _clear_display() -> void:
	for highlight in _info_highlights:
		RoomHighlighter.dispose(highlight)
	_info_highlights.clear()

func _get_room_water_color(room: RoomBase) -> Color:
	var wants: bool = room.wants_infrastructure_layer(BuildingInfrastructure.WATER_LAYER)
	var requires: bool = room.requires_infrastructure_layer(BuildingInfrastructure.WATER_LAYER)
	if not wants and not requires:
		return Color.TRANSPARENT

	var provider := _infra.get_connected_provider(room, BuildingInfrastructure.WATER_LAYER) as RoomWaterTower
	if provider != null and provider.has_water():
		return Color.GREEN

	if provider != null:
		return Color.RED

	if _infra.room_has_layer(room, BuildingInfrastructure.WATER_LAYER):
		return Color.ORANGE

	if requires:
		return Color.RED

	return Color.YELLOW

func can_place(data, origin: Vector2i) -> bool:
	var pending := {}
	for col in data.width:
		for row in data.height:
			var index := origin + Vector2i(col, row)
			if _infra.has_data_at(index, BuildingInfrastructure.WATER_LAYER):
				return false
			if _is_provider_room_cell(index):
				return false
			pending[index] = true

	var supported := _collect_supported_cells(pending)
	var provider_connected := _collect_provider_connected_cells(pending)

	for index in pending.keys():
		if not supported.has(index):
			return false
		if not provider_connected.has(index):
			return false

	return true

func prune() -> bool:
	var layer: Dictionary = _infra.get_layer(BuildingInfrastructure.WATER_LAYER)
	if layer.is_empty():
		return false

	var supported := _collect_supported_cells()
	var provider_connected := _collect_provider_connected_cells()
	var dirty := false

	for index in layer.keys():
		if supported.has(index) and provider_connected.has(index):
			continue
		layer.erase(index)
		dirty = true

	if not dirty:
		return false

	_infra.compact_layer(BuildingInfrastructure.WATER_LAYER)
	return true

func configure_tileset() -> void:
	var pipe_tile_set: TileSet = _tilemap.tile_set
	if pipe_tile_set == null:
		return

	var source := pipe_tile_set.get_source(_PIPE_SOURCE_ID) as TileSetAtlasSource
	if source == null:
		return

	var image := Image.load_from_file(ProjectSettings.globalize_path(_PIPE_TEXTURE_PATH))
	if image == null or image.is_empty():
		return

	if _pipe_texture == null:
		_pipe_texture = ImageTexture.create_from_image(image)
	source.texture = _pipe_texture
	for tile_index in _PIPE_TILE_COUNT:
		var atlas_coords := Vector2i(tile_index, 0)
		if source.has_tile(atlas_coords):
			continue
		source.create_tile(atlas_coords)

func refresh_visuals() -> void:
	configure_tileset()
	_tilemap.clear()
	_refresh_provider_output_tiles()
	var layer: Dictionary = _infra.get_layer(BuildingInfrastructure.WATER_LAYER)
	for index in layer.keys():
		_tilemap.set_cell(_to_tilemap_coords(index), _PIPE_SOURCE_ID, _get_tile(index))

func _refresh_provider_output_tiles() -> void:
	for provider in _infra.get_provider_rooms(BuildingInfrastructure.WATER_LAYER):
		provider.clear_infrastructure_output_tiles(BuildingInfrastructure.WATER_LAYER)
		var scaffold_count: int = provider.data.height - 1
		for i in range(scaffold_count):
			var floor_y: int = provider.y + i
			var floor_index := Vector2i(provider.x, floor_y)
			var outdoor: bool = floor_y >= 0
			var has_below: bool = i > 0 or _infra.has_data_at(floor_index + Vector2i(0, -1), BuildingInfrastructure.WATER_LAYER)
			var tile: int = (PipeTile.OUTDOOR_TOWER_OUTPUT_DOUBLE_AND_BELOW if outdoor else PipeTile.INDOOR_TOWER_OUTPUT_DOUBLE_AND_BELOW) if has_below \
				else (PipeTile.OUTDOOR_TOWER_OUTPUT_DOUBLE if outdoor else PipeTile.INDOOR_TOWER_OUTPUT_DOUBLE)
			provider.add_infrastructure_output_tile(BuildingInfrastructure.WATER_LAYER, floor_index, tile)

func _collect_supported_cells(pending: Dictionary = {}) -> Dictionary:
	var all_cells := {}
	for index in _infra.get_layer_cells(BuildingInfrastructure.WATER_LAYER):
		all_cells[index] = true
	for index in pending.keys():
		all_cells[index] = true

	var visited := {}
	for index in all_cells.keys():
		if _is_locally_supported(index):
			visited[index] = true

	return visited

func _collect_provider_connected_cells(pending: Dictionary = {}) -> Dictionary:
	var all_cells := {}
	for index in _infra.get_layer_cells(BuildingInfrastructure.WATER_LAYER):
		all_cells[index] = true
	for index in pending.keys():
		all_cells[index] = true

	var open: Array[Vector2i] = []
	var visited := {}

	for index in all_cells.keys():
		if get_provider_neighbor(index) != null:
			open.append(index)

	while not open.is_empty():
		var index: Vector2i = open.pop_back()
		if visited.has(index):
			continue
		visited[index] = true
		for direction in _NETWORK_DIRECTIONS:
			var next: Vector2i = index + direction
			if all_cells.has(next) and not visited.has(next):
				open.append(next)

	return visited

func _is_locally_supported(index: Vector2i) -> bool:
	if index.y <= 0:
		return true
	if _has_support_room(index):
		return true
	return _has_support_below(index)

func _has_support_room(index: Vector2i) -> bool:
	var room := Building.get_room_from_index(index) as RoomBase
	return room != null and room is not RoomEmpty

func _has_support_below(index: Vector2i) -> bool:
	var below := index + _SUPPORT_BELOW_OFFSET
	if _has_support_room(below):
		return true
	return _infra.has_data_at(below, BuildingInfrastructure.WATER_LAYER)

func get_provider_neighbor(index: Vector2i) -> RoomBase:
	var current_room := Building.get_room_from_index(index) as RoomBase
	if _tower_provides_at(current_room, index.y):
		return current_room

	for direction in _HORIZONTAL_DIRECTIONS:
		var room := Building.get_room_from_index(index + direction) as RoomBase
		if _tower_provides_at(room, index.y):
			return room

	var above_room := Building.get_room_from_index(index + _GRID_ABOVE_OFFSET) as RoomBase
	if _tower_provides_at(above_room, index.y + 1):
		return above_room

	return null

func _is_provider_room_cell(index: Vector2i) -> bool:
	var room := Building.get_room_from_index(index) as RoomBase
	return _infra.room_provides_layer(room, BuildingInfrastructure.WATER_LAYER)

func _tower_provides_at(room: RoomBase, y_idx: int) -> bool:
	if room is RoomWaterTower:
		return y_idx < room.y + room.data.height - 1
	return _infra.room_provides_layer(room, BuildingInfrastructure.WATER_LAYER)

func _get_tile(index: Vector2i) -> Vector2i:
	return Vector2i(_get_tile_index(index), 0)

func _get_tile_index(index: Vector2i) -> int:
	var outdoor: bool = _is_outdoor_backing(index)
	if _is_tower_drop_pipe(index):
		var has_pipe_below: bool = _infra.has_data_at(index + Vector2i(0, -1), BuildingInfrastructure.WATER_LAYER)
		if has_pipe_below:
			return PipeTile.OUTDOOR_TOWER_OUTPUT_DOUBLE_AND_BELOW if outdoor else PipeTile.INDOOR_TOWER_OUTPUT_DOUBLE_AND_BELOW
		return PipeTile.OUTDOOR_TOWER_OUTPUT_DOUBLE if outdoor else PipeTile.INDOOR_TOWER_OUTPUT_DOUBLE

	var provider_left: bool = _tower_provides_at(Building.get_room_from_index(index + Vector2i.LEFT) as RoomBase, index.y)
	var provider_right: bool = _tower_provides_at(Building.get_room_from_index(index + Vector2i.RIGHT) as RoomBase, index.y)
	var has_left: bool = provider_left or _infra.has_data_at(index + Vector2i.LEFT, BuildingInfrastructure.WATER_LAYER)
	var has_right: bool = provider_right or _infra.has_data_at(index + Vector2i.RIGHT, BuildingInfrastructure.WATER_LAYER)
	var uses_water := _is_water_consumer_backing(index)

	if uses_water:
		if has_left and has_right:
			return PipeTile.FAUCET_COMPLETE
		if has_right:
			return PipeTile.FAUCET_LEFT
		if has_left:
			return PipeTile.FAUCET_RIGHT
		return PipeTile.FAUCET_COMPLETE
	var has_above: bool = _infra.has_data_at(index + Vector2i(0, 1), BuildingInfrastructure.WATER_LAYER)
	if has_left and has_right:
		return PipeTile.OUTDOOR_COMPLETE_IF_ABOVE if outdoor and has_above else (PipeTile.OUTDOOR_COMPLETE if outdoor else PipeTile.INDOOR_COMPLETE)
	if has_right:
		return PipeTile.OUTDOOR_LEFT_END_IF_ABOVE if outdoor and has_above else (PipeTile.OUTDOOR_LEFT_END if outdoor else PipeTile.INDOOR_LEFT_END)
	if has_left:
		return PipeTile.OUTDOOR_RIGHT_END_IF_ABOVE if outdoor and has_above else (PipeTile.OUTDOOR_RIGHT_END if outdoor else PipeTile.INDOOR_RIGHT_END)
	return PipeTile.OUTDOOR_COMPLETE_IF_ABOVE if outdoor and has_above else (PipeTile.OUTDOOR_COMPLETE if outdoor else PipeTile.INDOOR_COMPLETE)

func _is_outdoor_backing(index: Vector2i) -> bool:
	if index.y < 0:
		return false
	var room := Building.get_room_from_index(index) as RoomBase
	return room == null or room.is_outside_room

func _is_water_consumer_backing(index: Vector2i) -> bool:
	var room := Building.get_room_from_index(index) as RoomBase
	return room != null and room.uses_infrastructure_layer(BuildingInfrastructure.WATER_LAYER)

func _is_tower_drop_pipe(index: Vector2i) -> bool:
	var probe := index + _GRID_ABOVE_OFFSET
	while _infra.has_data_at(probe, BuildingInfrastructure.WATER_LAYER):
		probe += _GRID_ABOVE_OFFSET

	var room := Building.get_room_from_index(probe) as RoomBase
	return room is RoomWaterTower and _tower_provides_at(room, probe.y)

func _to_tilemap_coords(index: Vector2i) -> Vector2i:
	return Vector2i(index.x, index.y * -1 - 1)
