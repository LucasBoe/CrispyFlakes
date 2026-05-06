extends Node2D

enum Priority {
	STATUS = 0,           # General status indicators (e.g. no worker assigned)
	ARREST = 1,           # NPC pending arrest
	FIGHT = 2,            # Active fight in room
	SELECTION = 3,        # Player hover / selection / drag
	TEMP_INFO_OVERLAY = 4, # Temporary full-screen info overlays (e.g. water system)
}

const PRIORITY_Z_INDEX = {
	Priority.STATUS:           2150,
	Priority.ARREST:           2160,
	Priority.FIGHT:            2170,
	Priority.SELECTION:        2180,
	Priority.TEMP_INFO_OVERLAY: 2190,
}

const TILE_PX: int = 48
const META_ROOM := &"room"
const META_WORLD_OFFSET_FROM_ROOM_ORIGIN := &"world_offset_from_room_origin"

@onready var rect_dummy = $Rect;
@onready var arrow_dummy = $Arrow;
@onready var _highlight_layer: CanvasLayer = $HighlightLayer
@onready var _drag_layer: CanvasLayer = $DragLayer

@onready var rect_texture_2px = preload("res://assets/sprites/room_highlight.png")
@onready var rect_texture_1px = preload("res://assets/sprites/room_highlight_slim.png")


var active = {}

func _ready():
	rect_dummy.visible = false
	arrow_dummy.visible = false

	GlobalEventHandler.on_room_deleted_signal.connect(_on_room_deleted)

func get_drag_layer() -> CanvasLayer:
	return _drag_layer

func request_rect(room, color = Color.WHITE, size = 2, priority = Priority.STATUS):
	var inst: NinePatchRect = create(rect_dummy, room, priority)

	inst.modulate = color
	inst.texture = texture_from_size(size)
	_position_highlight(inst, room)

	return inst

func texture_from_size(size):
	if size == 2:
		return rect_texture_2px

	return rect_texture_1px

func request_arrow(room, priority = Priority.SELECTION, world_offset_from_room_origin = null):
	var inst = create(arrow_dummy, room, priority)
	if world_offset_from_room_origin is Vector2:
		inst.set_meta(META_WORLD_OFFSET_FROM_ROOM_ORIGIN, world_offset_from_room_origin)
	_position_highlight(inst, room)
	return inst

func create(dummy, room : RoomBase, priority : Priority = Priority.STATUS):
	var instance = dummy.duplicate()
	instance.visible = true
	instance.z_index = PRIORITY_Z_INDEX[priority]
	instance.set_meta(META_ROOM, room)
	_highlight_layer.add_child(instance)

	if not active.has(room):
		active[room] = []

	active[room].append(instance)
	_position_highlight(instance, room)

	return instance

func _position_highlight(highlight, room: RoomBase) -> void:
	if room == null or not is_instance_valid(room):
		return

	if highlight is NinePatchRect:
		var room_size := Vector2(room.data.width * TILE_PX, room.data.height * TILE_PX)
		highlight.anchor_left = 0.0
		highlight.anchor_top = 0.0
		highlight.anchor_right = 0.0
		highlight.anchor_bottom = 0.0
		highlight.position = room.global_position - Vector2(0.0, room_size.y)
		highlight.size = room_size
	elif highlight is Node2D:
		var world_position: Vector2 = room.get_center_position()
		if highlight.has_meta(META_WORLD_OFFSET_FROM_ROOM_ORIGIN):
			var world_offset = highlight.get_meta(META_WORLD_OFFSET_FROM_ROOM_ORIGIN)
			if world_offset is Vector2:
				world_position = room.global_position + world_offset
		highlight.position = world_position

func _on_room_deleted(room):

	if not active.has(room):
		return

	for all in active[room]:
		if is_instance_valid(all):
			all.queue_free()

	active.erase(room)

func dispose(highlight):

	if not is_instance_valid(highlight):
		return

	var invalid_keys = []
	for key in active.keys():
		if key == null or not is_instance_valid(key):
			invalid_keys.append(key)
			continue

		var highlights: Array = active[key]
		if highlights.has(highlight):
			highlights.erase(highlight)
			if highlights.is_empty():
				invalid_keys.append(key)

	for key in invalid_keys:
		if active.has(key):
			active.erase(key)

	highlight.queue_free()
