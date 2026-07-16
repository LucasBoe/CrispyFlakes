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

const _ICON_WATER_RECEIVED := preload("res://assets/sprites/ui/water-received_icon.png")
const _ICON_NO_WATER_RECEIVED := preload("res://assets/sprites/ui/no-water-received_icon.png")
const _ICON_NO_PIPE_CONNECTION_REQUIRED := preload("res://assets/sprites/ui/no-pipe-connection-but-required_icon.png")
const _ICON_NO_PIPE_CONNECTION_OPTIONAL := preload("res://assets/sprites/ui/no-pipe-connection-optional_icon.png")

const _HORIZONTAL_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT]
const _GRID_ABOVE_OFFSET := Vector2i(0, 1)
const _GRID_BELOW_OFFSET := Vector2i(0, -1)
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
			var icon := _get_room_water_icon(room_base)
			if icon == null:
				continue
			_info_highlights.append(RoomHighlighter.request_icon(room_base, icon, RoomHighlighter.Priority.TEMP_INFO_OVERLAY))

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

func _get_room_water_icon(room: RoomBase) -> Texture2D:
	var wants: bool = room.wants_infrastructure_layer(BuildingInfrastructure.WATER_LAYER)
	var requires: bool = room.requires_infrastructure_layer(BuildingInfrastructure.WATER_LAYER)
	if not wants and not requires:
		return null

	var provider := _infra.get_connected_provider(room, BuildingInfrastructure.WATER_LAYER) as RoomWaterTower
	if provider != null and provider.has_water():
		return _ICON_WATER_RECEIVED

	if provider != null:
		return _ICON_NO_WATER_RECEIVED

	if _infra.room_has_layer(room, BuildingInfrastructure.WATER_LAYER):
		return _ICON_NO_WATER_RECEIVED

	if requires:
		return _ICON_NO_PIPE_CONNECTION_REQUIRED

	return _ICON_NO_PIPE_CONNECTION_OPTIONAL

func can_place(data, origin: Vector2i) -> Dictionary:
	var provider_connected := _collect_provider_connected_cells()

	for col in data.width:
		for row in data.height:
			var index := origin + Vector2i(col, row)
			if _infra.has_data_at(index, BuildingInfrastructure.WATER_LAYER):
				return {"valid": false, "reason": "pipe already placed"}
			if _is_provider_room_cell(index):
				return {"valid": false, "reason": "tower supplies here"}
			if not _is_cell_supported(index):
				return {"valid": false, "reason": "needs support below"}
			if not _is_cell_provider_connected(index, provider_connected):
				return {"valid": false, "reason": "connect to water source"}

	return {"valid": true, "reason": ""}

func _is_cell_provider_connected(index: Vector2i, provider_connected: Array) -> bool:
	#directly adjacent to the water tower in all 4 directions
	if get_provider_neighbor(index) != null:
		return true

	#to the left and right of an already-connected water pipe
	for direction in _HORIZONTAL_DIRECTIONS:
		if provider_connected.has(index + direction):
			return true

	#directly below an already-connected water pipe
	return provider_connected.has(index + _GRID_ABOVE_OFFSET)

func _collect_provider_connected_cells() -> Array:
	var connected: Array[Vector2i] = []

	#all cells to the left and right of water pipes
	for index in _infra.get_layer_cells(BuildingInfrastructure.WATER_LAYER):
		for direction in _HORIZONTAL_DIRECTIONS:
			var neighbor: Vector2i = index + direction
			if _infra.has_data_at(neighbor, BuildingInfrastructure.WATER_LAYER):
				connected.append(neighbor)

	var towers: Array[RoomBase] = _infra.get_provider_rooms(BuildingInfrastructure.WATER_LAYER)

	#all cells that are directly adjacent to the water tower sides
	for tower in towers:
		for row in tower.data.height:
			var tower_cell := Vector2i(tower.x, tower.y + row)
			if not _tower_provides_at(tower, tower_cell.y):
				continue
			for direction in _HORIZONTAL_DIRECTIONS:
				var neighbor: Vector2i = tower_cell + direction
				if _infra.has_data_at(neighbor, BuildingInfrastructure.WATER_LAYER):
					connected.append(neighbor)

	#all cells directly below pipes that are below water towers
	for tower in towers:
		var index := Vector2i(tower.x, tower.y - 1)
		while _infra.has_data_at(index, BuildingInfrastructure.WATER_LAYER):
			connected.append(index)
			index += _GRID_BELOW_OFFSET

	return connected

func prune() -> bool:
	var layer: Dictionary = _infra.get_layer(BuildingInfrastructure.WATER_LAYER)
	if layer.is_empty():
		return false

	var dirty := false

	for index in layer.keys():
		if _is_cell_supported(index):
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

func _is_cell_supported(location: Vector2i) -> bool:
	#if underground or ground floor cell return it instantly
	if location.y <= 0:
		return true

	#if cell has ANY room directly at the location return it as well
	if _has_room_at(location):
		return true

	#if cell has ANY room or existing pipes directly below return it as well
	if _has_support_below(location):
		return true

	#else NOT return it
	return false

func _has_room_at(index: Vector2i) -> bool:
	var room = Building.get_room_from_index(index) as RoomBase
	return room != null and not room.is_outside_room

func _has_support_below(index: Vector2i) -> bool:
	var below := index + _SUPPORT_BELOW_OFFSET
	if _has_room_at(below):
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
