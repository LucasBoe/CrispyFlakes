extends Node2D
class_name BuildingInfrastructure

signal on_infrastructure_changed_signal(layer_name: StringName)

const WATER_LAYER := &"water"
const ELECTRICITY_LAYER := &"electricity"
const _ELECTRICITY_SOURCE_ID := 0
const _ELECTRICITY_TILE_ATLAS := Vector2i.ZERO

const _CARDINAL_DIRECTIONS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]

var _layers: Dictionary = {}
var _water: RefCounted
var _water_info_requests: int = 0
var _electricity_tilemap: TileMapLayer = null

func _ready() -> void:
	_water = BuildingInfrastructureWater.new()
	_water.setup(self, $WaterPipeTiles)
	_electricity_tilemap = $ElectricityTiles

# --- Placement ---

func can_place(data, origin: Vector2i) -> bool:
	match data.layer_name:
		WATER_LAYER:
			return _water.can_place(data, origin)
		ELECTRICITY_LAYER:
			return _can_place_electricity(data, origin)
	return false

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

func prune_infrastructure() -> void:
	for layer_name in _layers.keys():
		var dirty := false
		if layer_name == WATER_LAYER:
			while _water.prune():
				dirty = true
		if not dirty:
			continue
		_refresh_layer_visuals(layer_name)
		_emit_changed(layer_name)

func remove_at(index: Vector2i, layer_name: StringName) -> bool:
	var layer: Dictionary = _layers.get(layer_name, {})
	if not layer.has(index):
		return false

	layer.erase(index)
	compact_layer(layer_name)

	if layer_name == WATER_LAYER:
		while _water.prune():
			pass

	_refresh_layer_visuals(layer_name)
	_emit_changed(layer_name)
	return true

# --- Queries ---

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
	if room_provides_layer(room, layer_name):
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

		var provider := _get_provider_for_index(index, layer_name)
		if provider != null:
			return provider

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

func get_layer_columns(layer_name: StringName) -> Array[int]:
	var columns: Array[int] = []
	var seen := {}
	var layer: Dictionary = _layers.get(layer_name, {})
	for index in layer.keys():
		if seen.has(index.x):
			continue
		seen[index.x] = true
		columns.append(index.x)
	columns.sort()
	return columns

# --- Water info overlay ---

func show_water_info() -> void:
	_water_info_requests += 1
	if _water_info_requests == 1:
		_water.show_info()

func hide_water_info() -> void:
	_water_info_requests = max(0, _water_info_requests - 1)
	if _water_info_requests == 0:
		_water.hide_info()

# --- Visuals ---

func refresh_visuals() -> void:
	_water.configure_tileset()
	_water.refresh_visuals()
	_refresh_electricity_visuals()

func clear_all() -> void:
	var changed_layers: Array = _layers.keys().duplicate()
	_layers.clear()
	refresh_visuals()
	for layer_name in changed_layers:
		_emit_changed(layer_name)

func restore_layer_cells(data, cells: Array[Vector2i]) -> void:
	var layer: Dictionary = _layers.get(data.layer_name, {})
	for index in cells:
		layer[index] = data
	_layers[data.layer_name] = layer
	_refresh_layer_visuals(data.layer_name)
	_emit_changed(data.layer_name)

# --- Layer helpers used by handlers ---

func get_layer(layer_name: StringName) -> Dictionary:
	return _layers.get(layer_name, {})

func get_layer_cells(layer_name: StringName) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var layer: Dictionary = _layers.get(layer_name, {})
	for index in layer.keys():
		cells.append(index)
	return cells

func compact_layer(layer_name: StringName) -> void:
	if _layers.get(layer_name, {}).is_empty():
		_layers.erase(layer_name)

func room_provides_layer(room: RoomBase, layer_name: StringName) -> bool:
	if room == null:
		return false
	return room.get_provided_infrastructure_layers().has(layer_name)

func get_provider_rooms(layer_name: StringName) -> Array[RoomBase]:
	var providers: Array[RoomBase] = []
	var visited := {}
	for floor_dict in Building.floors.values():
		for room in floor_dict.values():
			var provider := room as RoomBase
			if provider == null or not room_provides_layer(provider, layer_name):
				continue
			var provider_id := provider.get_instance_id()
			if visited.has(provider_id):
				continue
			visited[provider_id] = true
			providers.append(provider)
	return providers

func notify_layer_state_changed(layer_name: StringName) -> void:
	_refresh_layer_visuals(layer_name)
	_emit_changed(layer_name)

# --- Private ---

func _emit_changed(layer_name: StringName) -> void:
	on_infrastructure_changed_signal.emit(layer_name)
	GlobalEventHandler.on_infrastructure_changed_signal.emit(layer_name)

func _refresh_layer_visuals(layer_name: StringName) -> void:
	match layer_name:
		WATER_LAYER:
			_water.refresh_visuals()
		ELECTRICITY_LAYER:
			_refresh_electricity_visuals()

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

	compact_layer(layer_name)
	return true

func _get_adjacent_provider(index: Vector2i, layer_name: StringName) -> RoomBase:
	for direction in _CARDINAL_DIRECTIONS:
		var room := Building.get_room_from_index(index + direction) as RoomBase
		if room_provides_layer(room, layer_name):
			return room
	return null

func _get_provider_for_index(index: Vector2i, layer_name: StringName) -> RoomBase:
	if layer_name == WATER_LAYER:
		return _water.get_provider_neighbor(index)

	var current_room := Building.get_room_from_index(index) as RoomBase
	if room_provides_layer(current_room, layer_name):
		return current_room

	return _get_adjacent_provider(index, layer_name)

func _can_place_electricity(data: InfrastructureData, origin: Vector2i) -> bool:
	for col in data.width:
		for row in data.height:
			var index := origin + Vector2i(col, row)
			if has_data_at(index, ELECTRICITY_LAYER):
				return false
			var room := Building.get_room_from_index(index) as RoomBase
			if room == null or room.is_outside_room:
				return false
	return true

func _refresh_electricity_visuals() -> void:
	if _electricity_tilemap == null:
		return

	_electricity_tilemap.clear()
	for index in get_layer_cells(ELECTRICITY_LAYER):
		_electricity_tilemap.set_cell(Vector2i(index.x, index.y * -1 - 1), _ELECTRICITY_SOURCE_ID, _ELECTRICITY_TILE_ATLAS)
