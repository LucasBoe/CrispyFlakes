class_name BuildingStairsOverlay
extends RefCounted

const _ICON_ABOVE := preload("res://assets/sprites/ui/stairs_rooms-above-left-right_icon.png")
const _ICON_BELOW := preload("res://assets/sprites/ui/stairs_rooms-below-left-right.png")
const _ICON_ALL := preload("res://assets/sprites/ui/stairs_rooms-on-all-sides_icon.png")

var _highlights: Array = []
var _active: bool = false

func setup() -> void:
	GlobalEventHandler.on_room_created_signal.connect(_on_rooms_changed)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_rooms_changed)

func _on_rooms_changed(_room = null) -> void:
	if _active:
		show_info()

func show_info() -> void:
	_active = true
	_clear_display()

	for floor_dict in Building.floors.values():
		for room in floor_dict.values():
			if room is RoomStairs or room is RoomElevator:
				_add_vertical_connector_highlights(room as RoomBase)

func hide_info() -> void:
	_active = false
	_clear_display()

func _clear_display() -> void:
	for highlight in _highlights:
		RoomHighlighter.dispose(highlight)
	_highlights.clear()

func _add_vertical_connector_highlights(room: RoomBase) -> void:
	var below: RoomBase = Building.get_room_from_index(Vector2i(room.x, room.y - 1))
	var connects_down := _is_same_kind(room, below)

	var above := Building.get_room_from_index(Vector2i(room.x, room.y + 1)) as RoomBase
	var connects_up := _is_same_kind(room, above)

	# An elevator's topmost cell is its only floor-level entry point - it never reaches a
	# floor above, unlike stairs, so it only ever shows its own downward connector there,
	# never an upward one, and the room above it (not reachable by the elevator at all)
	# gets no highlight of its own.
	if room is RoomElevator and not connects_up:
		if connects_down:
			_highlights.append(RoomHighlighter.request_icon(room, _ICON_BELOW, RoomHighlighter.Priority.TEMP_INFO_OVERLAY))
	else:
		_highlights.append(RoomHighlighter.request_icon(room, _ICON_ALL if connects_down else _ICON_ABOVE, RoomHighlighter.Priority.TEMP_INFO_OVERLAY))
		if above != null and not connects_up:
			_highlights.append(RoomHighlighter.request_icon(above, _ICON_BELOW, RoomHighlighter.Priority.TEMP_INFO_OVERLAY))

func _is_same_kind(a, b) -> bool:
	if a == null or b == null:
		return false
	return (a is RoomStairs and b is RoomStairs) or (a is RoomElevator and b is RoomElevator)
