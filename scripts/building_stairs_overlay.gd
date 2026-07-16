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
			var stairs := room as RoomStairs
			if stairs == null:
				continue

			var connects_down := _has_stairs_below(stairs)
			_highlights.append(RoomHighlighter.request_icon(stairs, _ICON_ALL if connects_down else _ICON_ABOVE, RoomHighlighter.Priority.TEMP_INFO_OVERLAY))

			var above := _get_room_above(stairs)
			if above != null and not (above is RoomStairs):
				_highlights.append(RoomHighlighter.request_icon(above, _ICON_BELOW, RoomHighlighter.Priority.TEMP_INFO_OVERLAY))

func hide_info() -> void:
	_active = false
	_clear_display()

func _clear_display() -> void:
	for highlight in _highlights:
		RoomHighlighter.dispose(highlight)
	_highlights.clear()

func _get_room_above(stairs: RoomStairs) -> RoomBase:
	return Building.get_room_from_index(Vector2i(stairs.x, stairs.y + 1)) as RoomBase

func _has_stairs_below(stairs: RoomStairs) -> bool:
	return Building.get_room_from_index(Vector2i(stairs.x, stairs.y - 1)) is RoomStairs
