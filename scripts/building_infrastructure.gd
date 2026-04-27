extends TileMapLayer
class_name BuildingInfrastructure

signal on_infrastructure_changed_signal(layer_name: StringName)

const WATER_LAYER := &"water"

const _PIPE_SOURCE_ID := 0
const _PIPE_TEXTURE_PATH := "res://assets/sprites/water_pipe_tiles.png"
const _PIPE_TILE_COUNT := 11
enum pipeTileIndexMap {
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
}
const _CARDINAL_DIRECTIONS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]
const _HORIZONTAL_DIRECTIONS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
]
const _SUPPORT_BELOW_OFFSET := Vector2i(0, -1)

var _layers: Dictionary = {}
var _pipe_texture: Texture2D = null

func _ready() -> void:
	_configure_pipe_tileset()

func can_place(data, origin: Vector2i) -> bool:
	var pending := {}
	for col in data.width:
		for row in data.height:
			var index := origin + Vector2i(col, row)
			if has_data_at(index, data.layer_name):
				return false
			pending[index] = true

	var supported := _collect_supported_cells(data.layer_name, pending)
	var has_external_side_anchor := false

	for index in pending.keys():
		if not supported.has(index):
			return false
		if not _has_side_network_neighbor(index, data.layer_name, pending):
			return false
		if _has_external_side_network_neighbor(index, data.layer_name):
			has_external_side_anchor = true

	return has_external_side_anchor

func place(data, origin: Vector2i) -> bool:
	if not can_place(data, origin):
		return false

	var layer: Dictionary = _layers.get(data.layer_name, {})
	for col in data.width:
		for row in data.height:
			var index := origin + Vector2i(col, row)
			layer[index] = data

	_layers[data.layer_name] = layer
	_refresh_layer_visuals(data.layer_name)
	_emit_changed(data.layer_name)
	return true

func clear_under_room(room: RoomBase) -> void:
	for layer_name in _layers.keys():
		var dirty := _remove_cells_under_room(room, layer_name)
		while _prune_unsupported_cells(layer_name):
			dirty = true
		if not dirty:
			continue
		_refresh_layer_visuals(layer_name)
		_emit_changed(layer_name)

func has_data_at(index: Vector2i, layer_name: StringName) -> bool:
	var layer: Dictionary = _layers.get(layer_name, {})
	return layer.has(index)

func room_has_layer(room: RoomBase, layer_name: StringName) -> bool:
	for col in room.data.width:
		for row in room.data.height:
			if has_data_at(Vector2i(room.x + col, room.y + row), layer_name):
				return true
	return false

func room_has_service(room: RoomBase, layer_name: StringName) -> bool:
	if _room_provides_layer(room, layer_name):
		return true
	return get_connected_provider(room, layer_name) != null

func get_connected_provider(room: RoomBase, layer_name: StringName):
	var open: Array[Vector2i] = []
	var visited := {}

	for col in room.data.width:
		for row in room.data.height:
			var index := Vector2i(room.x + col, room.y + row)
			if has_data_at(index, layer_name):
				open.append(index)

	while not open.is_empty():
		var index: Vector2i = open.pop_back()
		if visited.has(index):
			continue
		visited[index] = true

		var current_room := Building.get_room_from_index(index) as RoomBase
		if _room_provides_layer(current_room, layer_name):
			return current_room

		var adjacent_provider := _get_adjacent_provider(index, layer_name)
		if adjacent_provider != null:
			return adjacent_provider

		for direction in _CARDINAL_DIRECTIONS:
			var next: Vector2i = index + direction
			if not visited.has(next) and has_data_at(next, layer_name):
				open.append(next)

	return null

func count_cells_by_data(data) -> int:
	var count := 0
	var layer: Dictionary = _layers.get(data.layer_name, {})
	for value in layer.values():
		if value == data:
			count += 1
	return count

func refresh_visuals() -> void:
	_configure_pipe_tileset()
	_refresh_water_pipe_tiles()

func _emit_changed(layer_name: StringName) -> void:
	on_infrastructure_changed_signal.emit(layer_name)
	GlobalEventHandler.on_infrastructure_changed_signal.emit(layer_name)

func _has_support_room(index: Vector2i) -> bool:
	var room := Building.get_room_from_index(index) as RoomBase
	return room != null and room is not RoomEmpty

func _collect_supported_cells(layer_name: StringName, pending: Dictionary = {}) -> Dictionary:
	var all_cells := {}
	var layer: Dictionary = _layers.get(layer_name, {})

	for index in layer.keys():
		all_cells[index] = true
	for index in pending.keys():
		all_cells[index] = true

	var open: Array[Vector2i] = []
	var visited := {}

	for index in all_cells.keys():
		if _is_locally_supported(index, layer_name):
			open.append(index)

	while not open.is_empty():
		var index: Vector2i = open.pop_back()
		if visited.has(index):
			continue
		visited[index] = true

		for direction in _HORIZONTAL_DIRECTIONS:
			var next: Vector2i = index + direction
			if all_cells.has(next) and not visited.has(next):
				open.append(next)

	return visited

func _prune_unsupported_cells(layer_name: StringName) -> bool:
	var layer: Dictionary = _layers.get(layer_name, {})
	if layer.is_empty():
		return false

	var supported := _collect_supported_cells(layer_name)
	var dirty := false

	for index in layer.keys():
		if supported.has(index) and _has_side_network_neighbor(index, layer_name):
			continue
		layer.erase(index)
		dirty = true

	if not dirty:
		return false

	if layer.is_empty():
		_layers.erase(layer_name)
	else:
		_layers[layer_name] = layer

	return true

func _remove_cells_under_room(room: RoomBase, layer_name: StringName) -> bool:
	var layer: Dictionary = _layers.get(layer_name, {})
	if layer.is_empty():
		return false

	var dirty := false
	for col in room.data.width:
		for row in room.data.height:
			var index := Vector2i(room.x + col, room.y + row)
			if not layer.has(index):
				continue
			layer.erase(index)
			dirty = true

	if not dirty:
		return false

	if layer.is_empty():
		_layers.erase(layer_name)
	else:
		_layers[layer_name] = layer

	return true

func _is_locally_supported(index: Vector2i, layer_name: StringName) -> bool:
	if index.y <= 0:
		return true
	if _has_support_room(index):
		return true
	return _has_support_below(index, layer_name)

func _has_support_below(index: Vector2i, layer_name: StringName) -> bool:
	var below := index + _SUPPORT_BELOW_OFFSET
	if _has_support_room(below):
		return true
	return has_data_at(below, layer_name)

func _has_side_network_neighbor(index: Vector2i, layer_name: StringName, pending: Dictionary = {}) -> bool:
	for direction in _HORIZONTAL_DIRECTIONS:
		var neighbor: Vector2i = index + direction
		if pending.has(neighbor):
			return true
		if has_data_at(neighbor, layer_name):
			return true
		if _room_provides_layer(Building.get_room_from_index(neighbor) as RoomBase, layer_name):
			return true
	return false

func _has_external_side_network_neighbor(index: Vector2i, layer_name: StringName) -> bool:
	for direction in _HORIZONTAL_DIRECTIONS:
		var neighbor: Vector2i = index + direction
		if has_data_at(neighbor, layer_name):
			return true
		if _room_provides_layer(Building.get_room_from_index(neighbor) as RoomBase, layer_name):
			return true
	return false

func _get_adjacent_provider(index: Vector2i, layer_name: StringName) -> RoomBase:
	for direction in _HORIZONTAL_DIRECTIONS:
		var room := Building.get_room_from_index(index + direction) as RoomBase
		if _room_provides_layer(room, layer_name):
			return room
	return null

func _room_provides_layer(room: RoomBase, layer_name: StringName) -> bool:
	if room == null:
		return false
	return room.get_provided_infrastructure_layers().has(layer_name)

func _refresh_layer_visuals(layer_name: StringName) -> void:
	match layer_name:
		WATER_LAYER:
			_configure_pipe_tileset()
			_refresh_water_pipe_tiles()

func _refresh_water_pipe_tiles() -> void:
	clear()
	_refresh_provider_output_tiles(WATER_LAYER)
	var layer: Dictionary = _layers.get(WATER_LAYER, {})
	for index in layer.keys():
		set_cell(_to_tilemap_coords(index), _PIPE_SOURCE_ID, _get_water_pipe_tile(index))

func _to_tilemap_coords(index: Vector2i) -> Vector2i:
	return Vector2i(index.x, index.y * -1 - 1)

func _get_water_pipe_tile(index: Vector2i) -> Vector2i:
	return Vector2i(_get_water_pipe_tile_index(index), 0)

func _get_water_pipe_tile_index(index: Vector2i) -> int:
	var provider_left := _room_provides_layer(Building.get_room_from_index(index + Vector2i.LEFT) as RoomBase, WATER_LAYER)
	var provider_right := _room_provides_layer(Building.get_room_from_index(index + Vector2i.RIGHT) as RoomBase, WATER_LAYER)
	var has_left := provider_left or has_data_at(index + Vector2i.LEFT, WATER_LAYER)
	var has_right := provider_right or has_data_at(index + Vector2i.RIGHT, WATER_LAYER)
	var uses_water := _is_water_consumer_backing(index)
	var outdoor := _is_outdoor_backing(index)

	if uses_water:
		if has_left and has_right:
			return pipeTileIndexMap.FAUCET_COMPLETE
		if has_right:
			return pipeTileIndexMap.FAUCET_LEFT
		if has_left:
			return pipeTileIndexMap.FAUCET_RIGHT
		return pipeTileIndexMap.FAUCET_COMPLETE
	if has_left and has_right:
		return pipeTileIndexMap.OUTDOOR_COMPLETE if outdoor else pipeTileIndexMap.INDOOR_COMPLETE
	if has_right:
		return pipeTileIndexMap.OUTDOOR_LEFT_END if outdoor else pipeTileIndexMap.INDOOR_LEFT_END
	if has_left:
		return pipeTileIndexMap.OUTDOOR_RIGHT_END if outdoor else pipeTileIndexMap.INDOOR_RIGHT_END
	return pipeTileIndexMap.OUTDOOR_COMPLETE if outdoor else pipeTileIndexMap.INDOOR_COMPLETE

func _is_outdoor_backing(index: Vector2i) -> bool:
	var room := Building.get_room_from_index(index) as RoomBase
	return room == null or room.is_outside_room

func _is_water_consumer_backing(index: Vector2i) -> bool:
	var room := Building.get_room_from_index(index) as RoomBase
	return room != null and room.uses_infrastructure_layer(WATER_LAYER)

func _refresh_provider_output_tiles(layer_name: StringName) -> void:
	for provider in _get_provider_rooms(layer_name):
		provider.clear_infrastructure_output_tiles(layer_name)
		var provider_index := Vector2i(provider.x, provider.y)
		provider.add_infrastructure_output_tile(layer_name, provider_index, pipeTileIndexMap.TOWER_OUTPUT_LEFT)
		provider.add_infrastructure_output_tile(layer_name, provider_index, pipeTileIndexMap.TOWER_OUTPUT_RIGHT)

func _get_provider_rooms(layer_name: StringName) -> Array[RoomBase]:
	var providers: Array[RoomBase] = []
	var visited := {}
	for floor in Building.floors.values():
		for room in floor.values():
			var provider := room as RoomBase
			if provider == null or not _room_provides_layer(provider, layer_name):
				continue
			var provider_id := provider.get_instance_id()
			if visited.has(provider_id):
				continue
			visited[provider_id] = true
			providers.append(provider)
	return providers

func _configure_pipe_tileset() -> void:
	var pipe_tile_set := tile_set
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
