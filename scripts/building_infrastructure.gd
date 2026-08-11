extends Node2D
class_name BuildingInfrastructure

signal on_infrastructure_changed_signal(layer_name: StringName)

class ElectricityOverlayEntry:
	var overlay: Sprite2D

	func _init(target_overlay: Sprite2D) -> void:
		overlay = target_overlay

const WATER_LAYER := &"water"
const ELECTRICITY_LAYER := &"electricity"
const _ELECTRICITY_SOURCE_ID := 0
const _ELECTRICITY_TILE_ATLAS := Vector2i.ZERO
const _TILE_SIZE := 48.0
const _ELECTRICITY_OVERLAY_1X := preload("res://assets/sprites/electricity_overlay_1x.png")
const _ELECTRICITY_OVERLAY_1X_CONNECTED := preload("res://assets/sprites/electricity_overlay_1x_connected.png")
const _ELECTRICITY_OVERLAY_2X := preload("res://assets/sprites/electricity_overlay_2x.png")
const _ELECTRICITY_OVERLAY_SHADER := preload("res://assets/shaders/electricity_cable_red_replace.gdshader")
const _ELECTRICITY_SPARKLE_SCENE := preload("res://scenes/electricity_sparkle_particles.tscn")
const _ELECTRICITY_OVERLAY_Z_INDEX := 1900
const _ELECTRICITY_OVERLAY_Y_OFFSET := 9.0
const _ICON_NO_ELECTRICITY := preload("res://assets/sprites/ui/no-electricity_icon.png")
const _ELECTRICITY_SPARKLE_INTERVAL := 0.65
const _ELECTRICITY_SPARKLE_ROOM_CHANCE := 0.22
const _ELECTRICITY_SPARKLE_TOP_OFFSET := 6.0
const _ELECTRICITY_SPARKLE_X_MARGIN := 6.0

const _CARDINAL_DIRECTIONS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]

var _layers: Dictionary = {}
var _water: RefCounted
var _water_info_requests: int = 0
var _electricity_info_requests: int = 0
var _electricity_tilemap: TileMapLayer = null
var _electricity_overlay_root: Node2D = null
var _electricity_overlay_entries: Dictionary = {}
var _electricity_info_highlights: Array = []
var _electricity_info_active: bool = false
var _electricity_sparkle_elapsed := 0.0

func _ready() -> void:
	_water = BuildingInfrastructureWater.new()
	_water.setup(self, $WaterPipeTiles)
	_electricity_tilemap = $ElectricityTiles
	_electricity_overlay_root = $ElectricityRoomOverlays
	if _electricity_tilemap != null:
		_electricity_tilemap.visible = false
	if not ElectricityHandler.state_changed.is_connected(_on_electricity_state_changed):
		ElectricityHandler.state_changed.connect(_on_electricity_state_changed)

func _process(delta: float) -> void:
	_electricity_sparkle_elapsed += delta
	if _electricity_sparkle_elapsed < _ELECTRICITY_SPARKLE_INTERVAL:
		return
	_electricity_sparkle_elapsed = 0.0
	_spawn_electricity_sparkles()

# --- Placement ---

func can_place(data, origin: Vector2i) -> Dictionary:
	match data.layer_name:
		WATER_LAYER:
			return _water.can_place(data, origin)
		ELECTRICITY_LAYER:
			return _can_place_electricity(data, origin)
	return {"valid": false, "reason": "target invalid"}

func place(data, origin: Vector2i) -> bool:
	if not can_place(data, origin).valid:
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

# --- Water info overlay ---

func show_water_info() -> void:
	_water_info_requests += 1
	if _water_info_requests == 1:
		_water.show_info()

func hide_water_info() -> void:
	_water_info_requests = max(0, _water_info_requests - 1)
	if _water_info_requests == 0:
		_water.hide_info()

func show_electricity_info() -> void:
	_electricity_info_requests += 1
	if _electricity_info_requests == 1:
		_refresh_electricity_info()

func hide_electricity_info() -> void:
	_electricity_info_requests = max(0, _electricity_info_requests - 1)
	if _electricity_info_requests == 0:
		_clear_electricity_info()

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

func _on_electricity_state_changed() -> void:
	_refresh_electricity_visuals()
	if _electricity_info_requests > 0:
		_refresh_electricity_info()

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

func _can_place_electricity(data: InfrastructureData, origin: Vector2i) -> Dictionary:
	for col in data.width:
		for row in data.height:
			var index := origin + Vector2i(col, row)
			if has_data_at(index, ELECTRICITY_LAYER):
				return {"valid": false, "reason": "electricity already placed"}
			var room := Building.get_room_from_index(index) as RoomBase
			if room == null:
				return {"valid": false, "reason": "requires a room"}
			if room.is_outside_room:
				return {"valid": false, "reason": "indoor rooms only"}
	return {"valid": true, "reason": ""}

func _refresh_electricity_visuals() -> void:
	if _electricity_tilemap == null:
		_ensure_electricity_overlay_root()
	else:
		_electricity_tilemap.clear()
		_electricity_tilemap.visible = false

	_ensure_electricity_overlay_root()
	if _electricity_overlay_root == null:
		return

	var segments: Array[Dictionary] = _collect_electricity_overlay_segments()
	var active_entry_ids := {}
	for segment in segments:
		var entry_id := _segment_entry_id(segment)
		active_entry_ids[entry_id] = true
		var overlay := _get_or_create_electricity_overlay(entry_id)
		_refresh_electricity_overlay(segment, overlay)

	for entry_id in _electricity_overlay_entries.keys():
		if active_entry_ids.has(entry_id):
			continue
		_remove_electricity_overlay(entry_id)

func _ensure_electricity_overlay_root() -> void:
	if is_instance_valid(_electricity_overlay_root):
		return
	_electricity_overlay_root = get_node_or_null("ElectricityRoomOverlays") as Node2D
	if is_instance_valid(_electricity_overlay_root):
		return
	_electricity_overlay_root = Node2D.new()
	_electricity_overlay_root.name = "ElectricityRoomOverlays"
	add_child(_electricity_overlay_root)

func _collect_electricity_overlay_segments() -> Array[Dictionary]:
	var rooms_by_id := {}
	for index in get_layer_cells(ELECTRICITY_LAYER):
		var room := Building.get_room_from_index(index) as RoomBase
		if room == null:
			continue
		var room_id := room.get_instance_id()
		if not rooms_by_id.has(room_id):
			rooms_by_id[room_id] = room

	var segments: Array[Dictionary] = []
	for room_id in rooms_by_id.keys():
		var room := rooms_by_id[room_id] as RoomBase
		if room == null or room.data == null:
			continue
		segments.append(_build_electricity_segment(room, room.x, room.data.width))

	return segments

func _build_electricity_segment(room: RoomBase, start_x: int, length: int) -> Dictionary:
	var has_service := _segment_has_live_service(room, start_x, length)
	var is_connected_room := _segment_is_connected_room(room)
	var is_active := _segment_is_active(room, start_x, length, has_service)
	var is_unstable := _segment_is_unstable(room, has_service, is_active)
	return {
		"room": room,
		"start_x": start_x,
		"length": length,
		"has_service": has_service,
		"is_connected_room": is_connected_room,
		"is_active": is_active,
		"is_unstable": is_unstable,
	}

func _segment_is_connected_room(room: RoomBase) -> bool:
	if room == null:
		return false
	return room.get_electricity_production_amount() > 0 or room.get_electricity_consumption_amount() > 0

func _segment_has_live_service(room: RoomBase, start_x: int, length: int) -> bool:
	if room == null or room.data == null:
		return false
	return room_has_service(room, ELECTRICITY_LAYER)

func _segment_is_active(room: RoomBase, start_x: int, length: int, has_service: bool) -> bool:
	if room == null:
		return false
	if room.get_electricity_production_amount() > 0:
		return true
	if room.get_electricity_consumption_amount() > 0:
		return ElectricityHandler.room_is_powered(room)
	return has_service

func _segment_is_unstable(room: RoomBase, has_service: bool, is_active: bool) -> bool:
	if room == null or not has_service:
		return false
	if not ElectricityHandler.is_production_stable():
		return true
	if room.get_electricity_consumption_amount() > 0 and not is_active:
		return true
	return false

func _segment_entry_id(segment: Dictionary) -> String:
	var room := segment["room"] as RoomBase
	return "%d:%d:%d" % [room.get_instance_id(), int(segment["start_x"]), int(segment["length"])]

func _get_or_create_electricity_overlay(entry_id: String) -> Sprite2D:
	var existing_entry := _electricity_overlay_entries.get(entry_id) as ElectricityOverlayEntry
	if existing_entry != null and is_instance_valid(existing_entry.overlay):
		return existing_entry.overlay

	var overlay := Sprite2D.new()
	overlay.centered = false
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.z_index = _ELECTRICITY_OVERLAY_Z_INDEX
	var material := ShaderMaterial.new()
	material.shader = _ELECTRICITY_OVERLAY_SHADER
	overlay.material = material
	_electricity_overlay_entries[entry_id] = ElectricityOverlayEntry.new(overlay)
	return overlay

func _refresh_electricity_overlay(segment: Dictionary, overlay: Sprite2D) -> void:
	var room := segment["room"] as RoomBase
	if room == null or room.data == null:
		return
	if overlay.get_parent() != room:
		room.add_child(overlay)

	var length := int(segment["length"])
	var has_service := bool(segment["has_service"])
	var is_connected_room := bool(segment["is_connected_room"])
	var texture: Texture2D = _ELECTRICITY_OVERLAY_2X if length > 1 else (_ELECTRICITY_OVERLAY_1X_CONNECTED if is_connected_room else _ELECTRICITY_OVERLAY_1X)
	var scale_x: float = max(1.0, float(length) / 2.0) if length > 1 else 1.0
	overlay.texture = texture
	overlay.scale = Vector2(scale_x, 1.0)

	var local_x := float(int(segment["start_x"]) - room.x) * _TILE_SIZE
	var room_top := -float(room.data.height) * _TILE_SIZE
	overlay.position = Vector2(local_x, room_top + _ELECTRICITY_OVERLAY_Y_OFFSET)

	var shader_material := overlay.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("service_amount", 1.0 if has_service else 0.0)
		shader_material.set_shader_parameter("activity_amount", 1.0 if bool(segment["is_active"]) else 0.0)
		shader_material.set_shader_parameter("unstable_amount", 1.0 if bool(segment["is_unstable"]) else 0.0)

func _remove_electricity_overlay(entry_id: String) -> void:
	var entry := _electricity_overlay_entries.get(entry_id) as ElectricityOverlayEntry
	_electricity_overlay_entries.erase(entry_id)
	if entry == null or not is_instance_valid(entry.overlay):
		return
	entry.overlay.queue_free()

func _refresh_electricity_info() -> void:
	_electricity_info_active = true
	_clear_electricity_info_highlights()
	for floor_dict in Building.floors.values():
		for room in floor_dict.values():
			var room_base := room as RoomBase
			if room_base == null:
				continue
			var icon := _get_room_electricity_icon(room_base)
			if icon == null:
				continue
			_electricity_info_highlights.append(RoomHighlighter.request_icon(room_base, icon, RoomHighlighter.Priority.TEMP_INFO_OVERLAY))

func _clear_electricity_info() -> void:
	_electricity_info_active = false
	_clear_electricity_info_highlights()

func _clear_electricity_info_highlights() -> void:
	for highlight in _electricity_info_highlights:
		RoomHighlighter.dispose(highlight)
	_electricity_info_highlights.clear()

func _get_room_electricity_icon(room: RoomBase) -> Texture2D:
	if room == null:
		return null
	var wants: bool = room.wants_infrastructure_layer(ELECTRICITY_LAYER)
	var requires: bool = room.requires_infrastructure_layer(ELECTRICITY_LAYER)
	var consumes: bool = room.get_electricity_consumption_amount() > 0
	if not wants and not requires and not consumes:
		return null
	if ElectricityHandler.room_is_powered(room):
		return null
	return _ICON_NO_ELECTRICITY

func _spawn_electricity_sparkles() -> void:
	for segment in _collect_electricity_overlay_segments():
		if not bool(segment["has_service"]):
			continue
		if randf() > _ELECTRICITY_SPARKLE_ROOM_CHANCE:
			continue
		_spawn_electricity_sparkle_for_segment(segment)

func _spawn_electricity_sparkle_for_segment(segment: Dictionary) -> void:
	var room := segment["room"] as RoomBase
	if room == null or room.data == null:
		return
	var particles := _ELECTRICITY_SPARKLE_SCENE.instantiate() as GPUParticles2D
	if particles == null:
		return

	var length := int(segment["length"])
	var span_width := float(length) * _TILE_SIZE
	var min_x: float = _ELECTRICITY_SPARKLE_X_MARGIN
	var max_x: float = max(min_x, span_width - _ELECTRICITY_SPARKLE_X_MARGIN)
	var local_x: float = float(int(segment["start_x"]) - room.x) * _TILE_SIZE + randf_range(min_x, max_x)
	var local_y: float = -float(room.data.height) * _TILE_SIZE + _ELECTRICITY_OVERLAY_Y_OFFSET + _ELECTRICITY_SPARKLE_TOP_OFFSET
	room.add_child(particles)
	particles.position = Vector2(local_x, local_y)
	particles.finished.connect(particles.queue_free)
	particles.restart()
	particles.emitting = true
