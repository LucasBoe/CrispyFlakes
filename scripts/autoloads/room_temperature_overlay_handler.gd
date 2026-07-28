extends Node

class OverlayEntry:
	var room
	var overlay: Sprite2D

	func _init(target_room, target_overlay: Sprite2D) -> void:
		room = target_room
		overlay = target_overlay


class OverlayVisualState:
	var visible: bool
	var color: Color

	func _init(is_visible: bool = false, tint: Color = Color.TRANSPARENT) -> void:
		visible = is_visible
		color = tint


const OVERLAY_TEXTURE := preload("res://assets/sprites/room_temperature_overlay.png")
const OVERLAY_MATERIAL := preload("res://assets/materials/mat_room_temperature_overlay.tres")
const TILE_SIZE := 48.0
const OVERLAY_Z_INDEX := 100
const OVERLAY_ROOT_NAME := &"RoomTemperatureOverlays"
const UPDATE_INTERVAL := 0.25
const MIN_OVERLAY_ALPHA := 0.28
const MAX_OVERLAY_ALPHA := 1.0
const COLD_VISIBLE_TEMPERATURE := 8.0
const COLD_PEAK_TEMPERATURE := -10.0
const WARM_VISIBLE_TEMPERATURE := 14.0
const WARM_PEAK_TEMPERATURE := 20.0
const COLD_BASE_COLOR := Color(0.56, 0.78, 1.0, 1.0)
const COLD_PEAK_COLOR := Color(0.34, 0.60, 1.0, 1.0)
const WARM_BASE_COLOR := Color(1.0, 0.90, 0.38, 1.0)
const WARM_PEAK_COLOR := Color(1.0, 0.56, 0.20, 1.0)

var _entries_by_room_id: Dictionary = {}
var _update_elapsed := 0.0
var _overlay_root: Node2D = null


func _ready() -> void:
	if not GlobalEventHandler.on_room_created_signal.is_connected(_on_room_created):
		GlobalEventHandler.on_room_created_signal.connect(_on_room_created)
	if not GlobalEventHandler.on_room_deleted_signal.is_connected(_on_room_deleted):
		GlobalEventHandler.on_room_deleted_signal.connect(_on_room_deleted)
	call_deferred("_deferred_initialize")


func _process(delta: float) -> void:
	if _entries_by_room_id.is_empty():
		return

	_update_elapsed += delta
	if _update_elapsed < UPDATE_INTERVAL:
		return

	_update_elapsed = 0.0
	_refresh_all_overlays()


func _deferred_initialize() -> void:
	_ensure_overlay_root()
	_rebuild_overlays()


func _on_room_created(room) -> void:
	call_deferred("_sync_room_overlay", room)


func _on_room_deleted(room) -> void:
	_remove_overlay(room)


func _rebuild_overlays() -> void:
	if not is_instance_valid(Building):
		return

	_ensure_overlay_root()
	if not is_instance_valid(_overlay_root):
		return

	var seen_room_ids := {}
	for floor_rooms: Dictionary in Building.floors.values():
		for room in floor_rooms.values():
			if not _is_trackable_room(room):
				continue
			var room_id: int = room.get_instance_id()
			if seen_room_ids.has(room_id):
				continue
			seen_room_ids[room_id] = true
			_sync_room_overlay(room)

	for room_id in _entries_by_room_id.keys():
		if seen_room_ids.has(room_id):
			continue
		_remove_overlay_by_id(room_id)


func _refresh_all_overlays() -> void:
	for room_id in _entries_by_room_id.keys():
		var entry := _entries_by_room_id.get(room_id) as OverlayEntry
		if entry == null or not _is_trackable_room(entry.room):
			_remove_overlay_by_id(room_id)
			continue
		if not is_instance_valid(entry.overlay):
			_remove_overlay_by_id(room_id)
			_sync_room_overlay(entry.room)
			continue
		_refresh_overlay(entry.room, entry.overlay)


func _sync_room_overlay(room) -> void:
	if not _is_trackable_room(room):
		_remove_overlay(room)
		return

	_ensure_overlay_root()
	if not is_instance_valid(_overlay_root):
		return

	var tracked_room := room as RoomBase
	var overlay := _get_or_create_overlay(tracked_room)
	_refresh_overlay(tracked_room, overlay)


func _get_or_create_overlay(room: RoomBase) -> Sprite2D:
	var room_id := room.get_instance_id()
	var entry := _entries_by_room_id.get(room_id) as OverlayEntry
	if entry != null and is_instance_valid(entry.overlay):
		return entry.overlay

	var overlay := Sprite2D.new()
	overlay.centered = false
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.z_index = OVERLAY_Z_INDEX
	overlay.texture = OVERLAY_TEXTURE
	overlay.material = OVERLAY_MATERIAL
	_overlay_root.add_child(overlay)
	_entries_by_room_id[room_id] = OverlayEntry.new(room, overlay)
	return overlay


func _refresh_overlay(room: RoomBase, overlay: Sprite2D) -> void:
	if overlay.get_parent() != _overlay_root:
		_overlay_root.add_child(overlay)
	_layout_overlay(room, overlay)

	var visual_state := _resolve_visual_state(_sample_room_temperature(room))
	overlay.visible = visual_state.visible
	if not visual_state.visible:
		return

	overlay.modulate = visual_state.color


func _layout_overlay(room: RoomBase, overlay: Sprite2D) -> void:
	if room == null or room.data == null:
		return

	overlay.global_position = room.global_position + Vector2(0.0, -float(room.data.height) * TILE_SIZE)
	overlay.scale = Vector2(float(room.data.width), float(room.data.height))


func _resolve_visual_state(temperature: float) -> OverlayVisualState:
	var normalized := 0.0
	var tint := Color.TRANSPARENT
	if temperature <= COLD_VISIBLE_TEMPERATURE:
		normalized = clampf(
			(COLD_VISIBLE_TEMPERATURE - temperature) / (COLD_VISIBLE_TEMPERATURE - COLD_PEAK_TEMPERATURE),
			0.0,
			1.0
		)
		tint = _get_temperature_color(-1.0, normalized)
	elif temperature >= WARM_VISIBLE_TEMPERATURE:
		normalized = clampf(
			(temperature - WARM_VISIBLE_TEMPERATURE) / (WARM_PEAK_TEMPERATURE - WARM_VISIBLE_TEMPERATURE),
			0.0,
			1.0
		)
		tint = _get_temperature_color(1.0, normalized)
	else:
		return OverlayVisualState.new()

	tint.a = lerpf(MIN_OVERLAY_ALPHA, MAX_OVERLAY_ALPHA, normalized)
	return OverlayVisualState.new(true, tint)


func _get_temperature_color(temperature: float, normalized_strength: float) -> Color:
	if temperature < 0.0:
		return COLD_BASE_COLOR.lerp(COLD_PEAK_COLOR, normalized_strength)
	return WARM_BASE_COLOR.lerp(WARM_PEAK_COLOR, normalized_strength)


func _sample_room_temperature(room) -> float:
	if room == null or not is_instance_valid(TemperatureHandler):
		return 0.0
	if not TemperatureHandler.has_method("get_temperature_for_room"):
		return 0.0
	return float(TemperatureHandler.get_temperature_for_room(room))


func _remove_overlay(room) -> void:
	if room == null or not is_instance_valid(room):
		return
	_remove_overlay_by_id(room.get_instance_id())


func _remove_overlay_by_id(room_id: int) -> void:
	var entry := _entries_by_room_id.get(room_id) as OverlayEntry
	if entry != null and is_instance_valid(entry.overlay):
		entry.overlay.queue_free()
	_entries_by_room_id.erase(room_id)


func _ensure_overlay_root() -> void:
	if is_instance_valid(_overlay_root):
		if _overlay_root.get_parent() == Building:
			return
		_overlay_root.reparent(Building)
		return

	if not is_instance_valid(Building):
		return

	var existing_root := Building.get_node_or_null(NodePath(String(OVERLAY_ROOT_NAME))) as Node2D
	if existing_root != null:
		_overlay_root = existing_root
		return

	_overlay_root = Node2D.new()
	_overlay_root.name = String(OVERLAY_ROOT_NAME)
	_overlay_root.z_as_relative = false
	_overlay_root.z_index = 0
	Building.add_child(_overlay_root)


func _is_trackable_room(room) -> bool:
	return room != null \
	and is_instance_valid(room) \
	and room is RoomBase \
	and room.data != null \
	and not room.is_outside_room \
	and not room.data.is_outdoor
